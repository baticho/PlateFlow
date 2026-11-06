import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.database import get_db
from app.domains.recipes.schemas import RecipeCreateRequest, RecipeDetail
from app.domains.recipes.service import create_recipe, get_recipe_by_id, get_recipes
from app.domains.users.models import User
from app.middleware.i18n import current_language

router = APIRouter()


@router.get("/")
async def list_recipes(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    q: str | None = Query(None),
    category_id: int | None = Query(None),
    cuisine_id: int | None = Query(None),
    max_time: int | None = Query(None),
    difficulty: str | None = Query(None),
    ingredient_ids: list[int] | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    lang = current_language.get()
    return await get_recipes(
        db,
        language=lang,
        page=page,
        page_size=page_size,
        q=q,
        category_id=category_id,
        cuisine_id=cuisine_id,
        max_time=max_time,
        difficulty=difficulty,
        ingredient_ids=ingredient_ids,
    )


@router.get("/suggested")
async def get_suggested_recipes(db: AsyncSession = Depends(get_db)):
    from datetime import date, timedelta

    from sqlalchemy import select
    from sqlalchemy.orm import selectinload

    from app.domains.recipes.models import Recipe, RecipeStatus
    from app.domains.weekly_suggestions.models import WeeklySuggestion

    today = date.today()
    monday = today - timedelta(days=today.weekday())

    result = await db.execute(
        select(WeeklySuggestion)
        .where(
            WeeklySuggestion.week_start_date == monday,
            WeeklySuggestion.is_active == True,  # noqa: E712
        )
        .options(selectinload(WeeklySuggestion.recipe).selectinload(Recipe.translations))
        .order_by(WeeklySuggestion.position)
    )
    suggestions = result.scalars().all()
    return {"items": [s.recipe for s in suggestions]}


@router.get("/random")
async def get_random_recipe(
    category_id: int | None = Query(None),
    cuisine_id: int | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """Id of one random published recipe (optionally within a category / cuisine)."""
    from sqlalchemy import func, select

    from app.domains.recipes.models import Recipe, RecipeStatus

    query = select(Recipe.id).where(Recipe.status == RecipeStatus.PUBLISHED)
    if category_id:
        from app.domains.categories.models import recipe_categories
        query = query.join(recipe_categories).where(recipe_categories.c.category_id == category_id)
    if cuisine_id:
        query = query.where(Recipe.cuisine_id == cuisine_id)
    recipe_id = (await db.execute(query.order_by(func.random()).limit(1))).scalar_one_or_none()
    if not recipe_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No recipes found")
    return {"id": str(recipe_id)}


@router.get("/{recipe_id}", response_model=RecipeDetail)
async def get_recipe(recipe_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    recipe = await get_recipe_by_id(db, recipe_id)
    if not recipe:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
    return recipe


@router.post("/", response_model=RecipeDetail, status_code=status.HTTP_201_CREATED)
async def create_recipe_endpoint(
    data: RecipeCreateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    recipe = await create_recipe(db, data.model_dump(), current_user.id)
    return await get_recipe_by_id(db, recipe.id)
