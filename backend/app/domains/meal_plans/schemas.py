import uuid
from datetime import date, datetime

from pydantic import BaseModel, model_validator

from app.middleware.i18n import current_language


class MealPlanItemCreate(BaseModel):
    recipe_id: uuid.UUID
    day_of_week: int
    meal_type: str
    servings: int = 1


class MealPlanCreate(BaseModel):
    week_start_date: date
    items: list[MealPlanItemCreate] = []


class MealPlanItemResponse(BaseModel):
    id: int
    recipe_id: uuid.UUID
    recipe_title: str
    recipe_image_url: str | None
    day_of_week: int
    meal_type: str
    servings: int = 1
    is_completed: bool = False

    model_config = {"from_attributes": True}

    @model_validator(mode='before')
    @classmethod
    def resolve_recipe(cls, v):
        if hasattr(v, 'recipe') and v.recipe:
            lang = current_language.get()
            trs = v.recipe.translations
            en = (next((t for t in trs if t.language_code == lang), None)
                  or next((t for t in trs if t.language_code == 'en'), None)
                  or (trs[0] if trs else None))
            return {
                'id': v.id,
                'recipe_id': v.recipe_id,
                'recipe_title': en.title if en else str(v.recipe_id),
                'recipe_image_url': v.recipe.image_url,
                'day_of_week': v.day_of_week,
                'meal_type': v.meal_type,
                'servings': v.servings,
                'is_completed': v.is_completed,
            }
        return v


class MealPlanResponse(BaseModel):
    id: int
    week_start_date: date
    items: list[MealPlanItemResponse]
    created_at: datetime

    model_config = {"from_attributes": True}
