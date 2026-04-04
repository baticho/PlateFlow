import uuid
from datetime import date, datetime

from pydantic import BaseModel


class MealPlanItemCreate(BaseModel):
    recipe_id: uuid.UUID
    day_of_week: int
    meal_type: str


class MealPlanCreate(BaseModel):
    week_start_date: date
    items: list[MealPlanItemCreate] = []


class MealPlanItemResponse(BaseModel):
    id: int
    recipe_id: uuid.UUID
    day_of_week: int
    meal_type: str

    model_config = {"from_attributes": True}


class MealPlanResponse(BaseModel):
    id: int
    week_start_date: date
    items: list[MealPlanItemResponse]
    created_at: datetime

    model_config = {"from_attributes": True}
