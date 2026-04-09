import uuid
from datetime import datetime

from pydantic import BaseModel, model_validator


class ShoppingListItemResponse(BaseModel):
    id: int
    ingredient_id: int
    ingredient_name: str
    ingredient_category: str
    quantity: float
    unit: str
    is_checked: bool

    model_config = {"from_attributes": True}

    @model_validator(mode='before')
    @classmethod
    def resolve_ingredient(cls, v):
        if hasattr(v, 'ingredient') and v.ingredient:
            en = next(
                (t for t in v.ingredient.translations if t.language_code == 'en'),
                v.ingredient.translations[0] if v.ingredient.translations else None,
            )
            return {
                'id': v.id,
                'ingredient_id': v.ingredient_id,
                'ingredient_name': en.name if en else f'#{v.ingredient_id}',
                'ingredient_category': v.ingredient.category.value,
                'quantity': float(v.quantity),
                'unit': v.unit,
                'is_checked': v.is_checked,
            }
        return v


class ShoppingListResponse(BaseModel):
    id: int
    name: str
    items: list[ShoppingListItemResponse]
    created_at: datetime

    model_config = {"from_attributes": True}
