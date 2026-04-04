from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.domains.cuisines.models import Cuisine
from app.domains.cuisines.schemas import CuisineResponse

router = APIRouter()


@router.get("/", response_model=list[CuisineResponse])
async def list_cuisines(
    continent: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    query = select(Cuisine).options(selectinload(Cuisine.translations))
    if continent:
        query = query.where(Cuisine.continent == continent)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{cuisine_id}", response_model=CuisineResponse)
async def get_cuisine(cuisine_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Cuisine)
        .where(Cuisine.id == cuisine_id)
        .options(selectinload(Cuisine.translations))
    )
    cuisine = result.scalar_one_or_none()
    if not cuisine:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cuisine not found")
    return cuisine
