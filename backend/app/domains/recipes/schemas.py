import uuid
from datetime import datetime

from pydantic import BaseModel, model_validator


class RecipeTranslationSchema(BaseModel):
    language_code: str
    title: str
    description: str | None = None

    model_config = {"from_attributes": True}


class RecipeStepTranslationSchema(BaseModel):
    language_code: str
    instruction: str
    image_url: str | None = None

    model_config = {"from_attributes": True}


class RecipeStepSchema(BaseModel):
    id: int
    order: int
    translations: list[RecipeStepTranslationSchema]

    model_config = {"from_attributes": True}


class RecipeIngredientTranslationSchema(BaseModel):
    language_code: str
    name: str

    model_config = {"from_attributes": True}


class RecipeIngredientSchema(BaseModel):
    id: int
    ingredient_id: int
    quantity: float
    unit: str
    is_optional: bool
    ingredient_translations: list[RecipeIngredientTranslationSchema] = []
    ingredient_image_url: str | None = None
    ingredient_category: str | None = None
    calories_per_100g: float | None = None
    protein_per_100g: float | None = None
    carbs_per_100g: float | None = None
    fat_per_100g: float | None = None

    model_config = {"from_attributes": True}

    @model_validator(mode='before')
    @classmethod
    def extract_ingredient_translations(cls, v):
        if hasattr(v, 'ingredient'):
            ing = v.ingredient
            return {
                'ingredient_category': ing.category.value if ing else None,
                **{k: (float(getattr(ing, k)) if ing and getattr(ing, k) is not None else None)
                   for k in ('calories_per_100g', 'protein_per_100g', 'carbs_per_100g', 'fat_per_100g')},
                'id': v.id,
                'ingredient_id': v.ingredient_id,
                'quantity': float(v.quantity),
                'unit': v.unit,
                'is_optional': v.is_optional,
                'ingredient_translations': [
                    {'language_code': t.language_code, 'name': t.name}
                    for t in (v.ingredient.translations if v.ingredient else [])
                ],
                'ingredient_image_url': v.ingredient.image_url if v.ingredient else None,
            }
        return v


class RecipeListItem(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None = None
    image_url: str | None = None
    total_time_minutes: int
    difficulty: str
    servings: int
    created_at: datetime

    model_config = {"from_attributes": True}


class RecipeDetail(BaseModel):
    id: uuid.UUID
    cuisine_id: int | None
    prep_time_minutes: int
    cook_time_minutes: int
    total_time_minutes: int
    servings: int
    difficulty: str
    status: str
    image_url: str | None
    calories: float | None = None
    protein_g: float | None = None
    carbs_g: float | None = None
    fat_g: float | None = None
    fiber_g: float | None = None
    sugar_g: float | None = None
    saturated_fat_g: float | None = None
    sodium_mg: float | None = None
    translations: list[RecipeTranslationSchema]
    steps: list[RecipeStepSchema]
    ingredients: list[RecipeIngredientSchema]
    created_at: datetime

    model_config = {"from_attributes": True}


class RecipeCreateRequest(BaseModel):
    cuisine_id: int | None = None
    prep_time_minutes: int = 0
    cook_time_minutes: int = 0
    servings: int = 4
    difficulty: str = "easy"
    image_url: str | None = None
    category_ids: list[int] = []
    tag_ids: list[int] = []
    translations: list[RecipeTranslationSchema]
    ingredients: list[dict] = []
    steps: list[dict] = []


class RecipeUpdateRequest(BaseModel):
    cuisine_id: int | None = None
    prep_time_minutes: int | None = None
    cook_time_minutes: int | None = None
    servings: int | None = None
    difficulty: str | None = None
    image_url: str | None = None
    status: str | None = None
    category_ids: list[int] | None = None
    tag_ids: list[int] | None = None
    translations: list[RecipeTranslationSchema] | None = None
