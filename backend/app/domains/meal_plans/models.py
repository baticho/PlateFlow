import enum
import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, Integer, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class MealType(str, enum.Enum):
    BREAKFAST = "breakfast"
    LUNCH = "lunch"
    DINNER = "dinner"
    SNACK = "snack"


class MealPlan(Base):
    __tablename__ = "meal_plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    week_start_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user = relationship("User", back_populates="meal_plans")
    items = relationship("MealPlanItem", back_populates="meal_plan", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("user_id", "week_start_date", name="uq_user_week"),
    )


class MealPlanItem(Base):
    __tablename__ = "meal_plan_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    meal_plan_id: Mapped[int] = mapped_column(Integer, ForeignKey("meal_plans.id", ondelete="CASCADE"), nullable=False)
    recipe_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("recipes.id"), nullable=False)
    day_of_week: Mapped[int] = mapped_column(Integer, nullable=False)  # 0=Monday, 6=Sunday
    meal_type: Mapped[MealType] = mapped_column(Enum(MealType), nullable=False)
    servings: Mapped[int] = mapped_column(Integer, default=1, server_default='1', nullable=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, server_default='false', nullable=False)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, server_default='false', nullable=False)

    meal_plan = relationship("MealPlan", back_populates="items")
    recipe = relationship("Recipe")
