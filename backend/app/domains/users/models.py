import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, String, func
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

    household_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("households.id", ondelete="SET NULL", use_alter=True), nullable=True, index=True
    )

    subscription_plan = relationship("SubscriptionPlan", back_populates="users")
    household = relationship("Household", foreign_keys=[household_id], back_populates="members")
    favorites = relationship("Favorite", back_populates="user", cascade="all, delete-orphan")
    meal_plans = relationship("MealPlan", back_populates="user", cascade="all, delete-orphan")
    shopping_lists = relationship("ShoppingList", back_populates="user", cascade="all, delete-orphan")


class Household(Base):
    """A family: members share the owner's meal plan, shopping list and subscription."""
    __tablename__ = "households"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    invite_code: Mapped[str | None] = mapped_column(String(16), unique=True, nullable=True)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    owner = relationship("User", foreign_keys=[owner_id])
    members = relationship("User", foreign_keys="User.household_id", back_populates="household")
