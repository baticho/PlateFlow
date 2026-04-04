import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Difficulty(str, enum.Enum):
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"


class RecipeStatus(str, enum.Enum):
    DRAFT = "draft"
    PUBLISHED = "published"


class Recipe(Base):
    __tablename__ = "recipes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cuisine_id: Mapped[int | None] = mapped_column(ForeignKey("cuisines.id"), nullable=True)
    prep_time_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    cook_time_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    total_time_minutes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    servings: Mapped[int] = mapped_column(Integer, default=4, nullable=False)
    difficulty: Mapped[Difficulty] = mapped_column(Enum(Difficulty), default=Difficulty.EASY, nullable=False)
    status: Mapped[RecipeStatus] = mapped_column(
        Enum(RecipeStatus), default=RecipeStatus.DRAFT, nullable=False
    )
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    cuisine = relationship("Cuisine", back_populates="recipes")
    translations = relationship("RecipeTranslation", back_populates="recipe", cascade="all, delete-orphan")
    steps = relationship("RecipeStep", back_populates="recipe", cascade="all, delete-orphan", order_by="RecipeStep.order")
    ingredients = relationship("RecipeIngredient", back_populates="recipe", cascade="all, delete-orphan")
    categories = relationship("Category", secondary="recipe_categories", back_populates="recipes")
    tags = relationship("Tag", secondary="recipe_tags", back_populates="recipes")
    favorites = relationship("Favorite", back_populates="recipe", cascade="all, delete-orphan")


class RecipeTranslation(Base):
    __tablename__ = "recipe_translations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    recipe_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False)
    language_code: Mapped[str] = mapped_column(String(5), nullable=False)
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    recipe = relationship("Recipe", back_populates="translations")

    __table_args__ = (
        {"schema": None},
    )


class RecipeStep(Base):
    __tablename__ = "recipe_steps"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    recipe_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False)
    order: Mapped[int] = mapped_column(Integer, nullable=False)

    recipe = relationship("Recipe", back_populates="steps")
    translations = relationship("RecipeStepTranslation", back_populates="step", cascade="all, delete-orphan")


class RecipeStepTranslation(Base):
    __tablename__ = "recipe_step_translations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    step_id: Mapped[int] = mapped_column(Integer, ForeignKey("recipe_steps.id", ondelete="CASCADE"), nullable=False)
    language_code: Mapped[str] = mapped_column(String(5), nullable=False)
    instruction: Mapped[str] = mapped_column(Text, nullable=False)
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    step = relationship("RecipeStep", back_populates="translations")


class RecipeIngredient(Base):
    __tablename__ = "recipe_ingredients"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    recipe_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False)
    ingredient_id: Mapped[int] = mapped_column(Integer, ForeignKey("ingredients.id"), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    unit: Mapped[str] = mapped_column(String(50), nullable=False)
    is_optional: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    recipe = relationship("Recipe", back_populates="ingredients")
    ingredient = relationship("Ingredient", back_populates="recipe_ingredients")
