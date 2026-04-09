import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class LanguageCode(str, enum.Enum):
    EN = "en"
    BG = "bg"


class UnitSystem(str, enum.Enum):
    METRIC = "metric"
    IMPERIAL = "imperial"


class AdminRole(str, enum.Enum):
    SUPER_ADMIN = "super_admin"
    CONTENT_MANAGER = "content_manager"
    SUPPORT = "support"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    google_oauth_id: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    preferred_language: Mapped[LanguageCode] = mapped_column(
        Enum(LanguageCode), default=LanguageCode.EN, nullable=False
    )
    preferred_unit_system: Mapped[UnitSystem] = mapped_column(
        Enum(UnitSystem), default=UnitSystem.METRIC, nullable=False
    )
    subscription_plan_id: Mapped[int | None] = mapped_column(
        ForeignKey("subscription_plans.id"), nullable=True
    )
    trial_ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    admin_role: Mapped[AdminRole | None] = mapped_column(Enum(AdminRole), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    subscription_plan = relationship("SubscriptionPlan", back_populates="users")
    favorites = relationship("Favorite", back_populates="user", cascade="all, delete-orphan")
    meal_plans = relationship("MealPlan", back_populates="user", cascade="all, delete-orphan")
    shopping_lists = relationship("ShoppingList", back_populates="user", cascade="all, delete-orphan")
