import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.domains.favorites.models import Favorite
from app.domains.recipes.models import Recipe
from app.domains.users.models import User

router = APIRouter()


@router.get("/")
async def list_favorites(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Favorite)
        .where(Favorite.user_id == current_user.id)
        .options(selectinload(Favorite.recipe).selectinload(Recipe.translations))
    )
    favorites = result.scalars().all()
    return {"items": [f.recipe for f in favorites]}


@router.post("/{recipe_id}", status_code=status.HTTP_201_CREATED)
async def add_favorite(
    recipe_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(Favorite).where(
            Favorite.user_id == current_user.id, Favorite.recipe_id == recipe_id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Already in favorites")
    db.add(Favorite(user_id=current_user.id, recipe_id=recipe_id))
    await db.flush()
    return {"message": "Added to favorites"}


@router.delete("/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_favorite(
    recipe_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Favorite).where(
            Favorite.user_id == current_user.id, Favorite.recipe_id == recipe_id
        )
    )
    fav = result.scalar_one_or_none()
    if not fav:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not in favorites")
    await db.delete(fav)
