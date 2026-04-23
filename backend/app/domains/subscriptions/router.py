from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.domains.subscriptions.models import SubscriptionPlan
from app.domains.users.models import User
from app.domains.users.schemas import UserResponse

router = APIRouter()

PREMIUM_SLUGS = {"premium_monthly", "premium_yearly"}
TRIAL_SLUG = "trial"


async def _load_plan(db: AsyncSession, slug: str) -> SubscriptionPlan:
    result = await db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.slug == slug, SubscriptionPlan.is_active == True)  # noqa: E712
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Plan '{slug}' not found")
    return plan


async def _load_user_with_plan(db: AsyncSession, user_id) -> User:
    result = await db.execute(
        select(User).options(selectinload(User.subscription_plan)).where(User.id == user_id)
    )
    return result.scalar_one()


@router.get("/")
async def list_plans(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.is_active == True)  # noqa: E712
    )
    return result.scalars().all()


@router.post("/activate-premium", response_model=UserResponse)
async def activate_premium(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan = await _load_plan(db, "premium_monthly")
    current_user.subscription_plan_id = plan.id
    current_user.trial_ends_at = None
    await db.flush()
    user = await _load_user_with_plan(db, current_user.id)
    return UserResponse.from_user(user)


@router.post("/start-trial", response_model=UserResponse)
async def start_trial(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user_with_plan = await _load_user_with_plan(db, current_user.id)
    current_slug = user_with_plan.subscription_plan.slug if user_with_plan.subscription_plan else None

    if current_slug in PREMIUM_SLUGS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Already on a premium plan")

    if current_slug == TRIAL_SLUG or (
        current_user.trial_ends_at is not None and current_user.trial_ends_at > datetime.now(UTC)
    ):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Trial already active or used")

    plan = await _load_plan(db, TRIAL_SLUG)
    current_user.subscription_plan_id = plan.id
    current_user.trial_ends_at = datetime.now(UTC) + timedelta(days=14)
    await db.flush()
    user = await _load_user_with_plan(db, current_user.id)
    return UserResponse.from_user(user)
