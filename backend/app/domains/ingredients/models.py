import enum

from sqlalchemy import Enum, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class IngredientCategory(str, enum.Enum):
    PRODUCE = "produce"
    DAIRY = "dairy"
    MEAT = "meat"
    SEAFOOD = "seafood"
    GRAINS = "grains"
    SPICES = "spices"
    OILS = "oils"
    SAUCES = "sauces"
    BAKING = "baking"
    CANNED = "canned"
    FROZEN = "frozen"
    BEVERAGES = "beverages"
    OTHER = "other"


class MeasurementUnit(str, enum.Enum):
    GRAM = "g"
    KILOGRAM = "kg"
    MILLILITER = "ml"
    LITER = "l"
    TEASPOON = "tsp"
    TABLESPOON = "tbsp"
    CUP = "cup"
    PIECE = "piece"
    OUNCE = "oz"
    POUND = "lb"
    FLUID_OUNCE = "fl_oz"


class Ingredient(Base):
    __tablename__ = "ingredients"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    default_unit: Mapped[MeasurementUnit] = mapped_column(
        Enum(MeasurementUnit), default=MeasurementUnit.GRAM, nullable=False
    )
    category: Mapped[IngredientCategory] = mapped_column(
        Enum(IngredientCategory), default=IngredientCategory.OTHER, nullable=False
    )
    calories_per_100g: Mapped[float | None] = mapped_column(Numeric(8, 2), nullable=True)
    protein_per_100g: Mapped[float | None] = mapped_column(Numeric(8, 2), nullable=True)
    carbs_per_100g: Mapped[float | None] = mapped_column(Numeric(8, 2), nullable=True)
    fat_per_100g: Mapped[float | None] = mapped_column(Numeric(8, 2), nullable=True)

    translations = relationship("IngredientTranslation", back_populates="ingredient", cascade="all, delete-orphan")
    recipe_ingredients = relationship("RecipeIngredient", back_populates="ingredient")


class IngredientTranslation(Base):
    __tablename__ = "ingredient_translations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ingredient_id: Mapped[int] = mapped_column(Integer, ForeignKey("ingredients.id", ondelete="CASCADE"), nullable=False)
    language_code: Mapped[str] = mapped_column(String(5), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)

    ingredient = relationship("Ingredient", back_populates="translations")
