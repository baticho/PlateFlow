from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.domains.users.models import User
from app.domains.users.schemas import UserResponse, UserUpdateRequest

router = APIRouter()


async def _load_user_with_plan(db: AsyncSession, user_id) -> User:
    result = await db.execute(
        select(User).options(selectinload(User.subscription_plan)).where(User.id == user_id)
    )
    return result.scalar_one()


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user = await _load_user_with_plan(db, current_user.id)
    return UserResponse.from_user(user)


@router.put("/me", response_model=UserResponse)
async def update_me(
    data: UserUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if data.full_name is not None:
        current_user.full_name = data.full_name
    if data.preferred_language is not None:
        current_user.preferred_language = data.preferred_language
    if data.preferred_unit_system is not None:
        current_user.preferred_unit_system = data.preferred_unit_system
    await db.flush()
    user = await _load_user_with_plan(db, current_user.id)
    return UserResponse.from_user(user)
