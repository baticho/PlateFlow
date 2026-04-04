import uuid
from datetime import datetime

from pydantic import BaseModel


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


class RecipeIngredientSchema(BaseModel):
    id: int
    ingredient_id: int
    quantity: float
    unit: str
    is_optional: bool

    model_config = {"from_attributes": True}


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
