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

    model_config = {"from_attributes": True}

    @classmethod
    def from_user(cls, user) -> "UserResponse":
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
            subscription_plan_slug=user.subscription_plan.slug if user.subscription_plan else None,
            subscription_plan_name=user.subscription_plan.name if user.subscription_plan else None,
        )


class UserUpdateRequest(BaseModel):
    full_name: str | None = None
    preferred_language: str | None = None
    preferred_unit_system: str | None = None
