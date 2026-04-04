from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.domains.ingredients.models import Ingredient, IngredientTranslation
from app.domains.ingredients.schemas import IngredientResponse

router = APIRouter()


@router.get("/", response_model=list[IngredientResponse])
async def list_ingredients(
    q: str | None = Query(None),
    category: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    query = select(Ingredient).options(selectinload(Ingredient.translations))
    if q:
        query = query.join(IngredientTranslation).where(
            IngredientTranslation.name.ilike(f"%{q}%")
        )
    if category:
        query = query.where(Ingredient.category == category)
    result = await db.execute(query)
    return result.scalars().all()
