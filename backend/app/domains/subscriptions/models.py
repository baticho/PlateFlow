from sqlalchemy import Boolean, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    slug: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    price_monthly: Mapped[float] = mapped_column(Numeric(10, 2), default=0, nullable=False)
    price_yearly: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    max_recipes_per_week: Mapped[int] = mapped_column(Integer, default=5, nullable=False)
    max_meal_plans: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    can_export_shopping_list: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    can_use_delivery: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    users = relationship("User", back_populates="subscription_plan")
