import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr


class UserResponse(BaseModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str
    preferred_language: str
    preferred_unit_system: str
    is_active: bool
    is_admin: bool
    created_at: datetime
    subscription_plan_slug: str | None = None
    subscription_plan_name: str | None = None
    trial_ends_at: datetime | None = None
    household_id: int | None = None
    household_name: str | None = None
    is_household_owner: bool = False

    model_config = {"from_attributes": True}

    @classmethod
    def from_user(cls, user, plan_user=None, household=None) -> "UserResponse":
        plan_user = plan_user or user
        return cls(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            preferred_language=user.preferred_language,
            preferred_unit_system=user.preferred_unit_system,
            is_active=user.is_active,
            is_admin=user.is_admin,
            created_at=user.created_at,
            trial_ends_at=user.trial_ends_at,
            subscription_plan_slug=plan_user.subscription_plan.slug if plan_user.subscription_plan else None,
            subscription_plan_name=plan_user.subscription_plan.name if plan_user.subscription_plan else None,
            household_id=household.id if household else None,
            household_name=household.name if household else None,
            is_household_owner=bool(household and household.owner_id == user.id),
        )


class UserUpdateRequest(BaseModel):
    full_name: str | None = None
    preferred_language: str | None = None
    preferred_unit_system: str | None = None
