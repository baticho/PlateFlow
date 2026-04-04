import uuid
from datetime import datetime

from pydantic import BaseModel


class ShoppingListItemResponse(BaseModel):
    id: int
    ingredient_id: int
    quantity: float
    unit: str
    is_checked: bool

    model_config = {"from_attributes": True}


class ShoppingListResponse(BaseModel):
    id: int
    name: str
    items: list[ShoppingListItemResponse]
    created_at: datetime

    model_config = {"from_attributes": True}
