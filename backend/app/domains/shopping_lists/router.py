from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.domains.ingredients.models import Ingredient, IngredientTranslation
from app.domains.shopping_lists.models import ShoppingList, ShoppingListItem
from app.domains.shopping_lists.schemas import ShoppingListItemResponse, ShoppingListResponse
from app.domains.users.models import User
from app.middleware.i18n import current_language

router = APIRouter()


@router.get("/", response_model=list[ShoppingListResponse])
async def list_shopping_lists(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    lang = current_language.get()

    result = await db.execute(
        select(ShoppingList)
        .where(ShoppingList.user_id == current_user.id)
        .options(
            selectinload(ShoppingList.items)
            .selectinload(ShoppingListItem.ingredient)
            .selectinload(Ingredient.translations)
        )
        .order_by(ShoppingList.created_at.desc())
    )
    lists = result.scalars().all()

    # Build responses with language-aware ingredient names
    response = []
    for sl in lists:
        items = [
            ShoppingListItemResponse.model_validate(item, context={'lang': lang})
            for item in sl.items
        ]
        response.append(ShoppingListResponse(
            id=sl.id,
            name=sl.name,
            items=items,
            created_at=sl.created_at,
        ))
    return response


@router.put("/{list_id}/items/{item_id}/toggle")
async def toggle_item(
    list_id: int,
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ShoppingList).where(
            ShoppingList.id == list_id, ShoppingList.user_id == current_user.id
        )
    )
    shopping_list = result.scalar_one_or_none()
    if not shopping_list:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shopping list not found")

    item_result = await db.execute(
        select(ShoppingListItem).where(
            ShoppingListItem.id == item_id, ShoppingListItem.shopping_list_id == list_id
        )
    )
    item = item_result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    item.is_checked = not item.is_checked
    await db.flush()
    return {"id": item.id, "is_checked": item.is_checked}
