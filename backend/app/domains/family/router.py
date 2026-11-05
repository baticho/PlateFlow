import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.domains.subscriptions.models import SubscriptionPlan
from app.domains.users.models import Household, User

router = APIRouter()

MAX_FAMILY_MEMBERS = 4          # members besides the owner
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # no 0/O/1/I


def _new_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(8))


async def _is_premium(db: AsyncSession, user: User) -> bool:
    if user.subscription_plan_id is None:
        return False
    plan = await db.get(SubscriptionPlan, user.subscription_plan_id)
    return bool(plan and plan.slug.startswith("premium"))


async def _members(db: AsyncSession, h: Household) -> list[User]:
    return list((await db.execute(
        select(User).where(User.household_id == h.id).order_by(User.created_at)
    )).scalars())


async def _state(db: AsyncSession, user: User) -> dict:
    h = await db.get(Household, user.household_id) if user.household_id else None
    if not h:
        return {"family": None, "can_create": await _is_premium(db, user), "max_members": MAX_FAMILY_MEMBERS}
    is_owner = h.owner_id == user.id
    members = await _members(db, h)
    return {
        "family": {
            "id": h.id,
            "name": h.name,
            "is_owner": is_owner,
            "invite_code": h.invite_code if is_owner else None,
            "members": [{"id": str(m.id), "full_name": m.full_name, "email": m.email,
                         "is_owner": m.id == h.owner_id, "is_me": m.id == user.id} for m in members],
            "slots_left": max(0, MAX_FAMILY_MEMBERS - (len(members) - 1)),
        },
        "can_create": False,
        "max_members": MAX_FAMILY_MEMBERS,
    }


async def _owned_household(db: AsyncSession, user: User) -> Household:
    h = await db.get(Household, user.household_id) if user.household_id else None
    if not h or h.owner_id != user.id:
        raise HTTPException(status_code=403, detail="Only the family owner can do this")
    return h


class CreateFamily(BaseModel):
    name: str | None = None


class JoinFamily(BaseModel):
    code: str


@router.get("/")
async def get_family(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await _state(db, user)


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_family(data: CreateFamily, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if user.household_id:
        raise HTTPException(status_code=400, detail="You are already in a family")
    if not await _is_premium(db, user):
        raise HTTPException(status_code=403, detail="A Premium plan is required to create a family")
    h = Household(name=(data.name or "").strip()[:255] or f"{user.full_name}", owner_id=user.id, invite_code=_new_code())
    db.add(h)
    await db.flush()
    user.household_id = h.id
    await db.flush()
    return await _state(db, user)


@router.post("/join")
async def join_family(data: JoinFamily, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if user.household_id:
        raise HTTPException(status_code=400, detail="Leave your current family first")
    code = data.code.strip().upper().replace(" ", "").replace("-", "")
    h = (await db.execute(select(Household).where(Household.invite_code == code))).scalar_one_or_none()
    if not h:
        raise HTTPException(status_code=404, detail="Invalid invite code")
    if len(await _members(db, h)) - 1 >= MAX_FAMILY_MEMBERS:
        raise HTTPException(status_code=400, detail="This family is full")
    user.household_id = h.id
    await db.flush()
    return await _state(db, user)


@router.post("/invite-code")
async def regenerate_code(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    h = await _owned_household(db, user)
    h.invite_code = _new_code()
    await db.flush()
    return await _state(db, user)


@router.delete("/members/{member_id}")
async def remove_member(member_id: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    h = await _owned_household(db, user)
    member = next((m for m in await _members(db, h) if str(m.id) == member_id), None)
    if not member or member.id == user.id:
        raise HTTPException(status_code=404, detail="Member not found")
    member.household_id = None
    await db.flush()
    return await _state(db, user)


@router.post("/leave")
async def leave_family(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    h = await db.get(Household, user.household_id) if user.household_id else None
    if not h:
        raise HTTPException(status_code=400, detail="You are not in a family")
    if h.owner_id == user.id:          # the owner leaving dissolves the family
        for m in await _members(db, h):
            m.household_id = None
        await db.flush()
        await db.delete(h)
    else:
        user.household_id = None
    await db.flush()
    return await _state(db, user)
