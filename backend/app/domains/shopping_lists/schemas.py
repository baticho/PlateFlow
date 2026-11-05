import uuid
from datetime import datetime

from pydantic import BaseModel, ValidationInfo, model_validator


def _recipe_title(item, lang: str) -> str | None:
    recipe = item.__dict__.get('recipe')   # only when eager-loaded; never trigger lazy IO
    if not recipe:
        return None
    trs = recipe.__dict__.get('translations') or []
    tr = next((t for t in trs if t.language_code == lang), None) or next((t for t in trs if t.language_code == 'en'), None)
    return tr.title if tr else None


class ShoppingListItemResponse(BaseModel):
    id: int
    ingredient_id: int
    ingredient_name: str
    ingredient_category: str
    ingredient_image_url: str | None = None
    calories_per_100g: float | None = None
    protein_per_100g: float | None = None
    carbs_per_100g: float | None = None
    fat_per_100g: float | None = None
    recipe_id: str | None = None
    recipe_title: str | None = None
    quantity: float
    unit: str
    is_checked: bool

    model_config = {"from_attributes": True}

    @model_validator(mode='before')
    @classmethod
    def resolve_ingredient(cls, v, info: ValidationInfo):
        if hasattr(v, 'ingredient') and v.ingredient:
            lang = (info.context.get('lang', 'en') if (info and info.context) else 'en')
            translation = next(
                (t for t in v.ingredient.translations if t.language_code == lang),
                next(
                    (t for t in v.ingredient.translations if t.language_code == 'en'),
                    v.ingredient.translations[0] if v.ingredient.translations else None,
                ),
            )
            return {
                'id': v.id,
                'ingredient_id': v.ingredient_id,
                'ingredient_name': translation.name if translation else f'#{v.ingredient_id}',
                'ingredient_category': v.ingredient.category.value,
                'ingredient_image_url': v.ingredient.image_url,
                **{k: (float(getattr(v.ingredient, k)) if getattr(v.ingredient, k) is not None else None)
                   for k in ('calories_per_100g', 'protein_per_100g', 'carbs_per_100g', 'fat_per_100g')},
                'recipe_id': str(v.added_from_recipe_id) if v.added_from_recipe_id else None,
                'recipe_title': _recipe_title(v, lang),
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
