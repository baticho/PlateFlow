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


@router.get("/home-sections")
async def get_home_sections(
    per_category: int = Query(10, ge=1, le=30),
    db: AsyncSession = Depends(get_db),
):
    """Every category with a random handful of its published recipes — a fresh mix on each call."""
    from sqlalchemy import func, select
    from sqlalchemy.orm import selectinload

    from app.domains.categories.models import Category, recipe_categories
    from app.domains.recipes.models import Recipe, RecipeStatus

    categories = (await db.execute(
        select(Category).options(selectinload(Category.translations)).order_by(Category.id)
    )).scalars().all()

    sections = []
    for cat in categories:
        recipes = (await db.execute(
            select(Recipe)
            .join(recipe_categories, recipe_categories.c.recipe_id == Recipe.id)
            .where(recipe_categories.c.category_id == cat.id, Recipe.status == RecipeStatus.PUBLISHED)
            .options(selectinload(Recipe.translations))
            .order_by(func.random())
            .limit(per_category)
        )).scalars().all()
        if not recipes:
            continue
        sections.append({
            "category": {
                "id": cat.id,
                "slug": cat.slug,
                "translations": [{"language_code": t.language_code, "name": t.name} for t in cat.translations],
            },
            "recipes": recipes,
        })
    return {"sections": sections}


@router.get("/random")
async def get_random_recipe(
    category_id: int | None = Query(None),
    category_slug: str | None = Query(None),
    cuisine_id: int | None = Query(None),
    exclude: list[uuid.UUID] = Query(default=[]),
    db: AsyncSession = Depends(get_db),
):
    """One random published recipe (optionally within a category / cuisine, skipping `exclude` ids)."""
    from sqlalchemy import func, select

    from app.domains.recipes.models import Recipe, RecipeStatus

    query = select(Recipe.id, Recipe.servings).where(Recipe.status == RecipeStatus.PUBLISHED)
    if category_id or category_slug:
        from app.domains.categories.models import Category, recipe_categories
        query = query.join(recipe_categories)
        if category_id:
            query = query.where(recipe_categories.c.category_id == category_id)
        else:
            query = query.join(Category, Category.id == recipe_categories.c.category_id).where(Category.slug == category_slug)
    if cuisine_id:
        query = query.where(Recipe.cuisine_id == cuisine_id)
    row = None
    if exclude:
        row = (await db.execute(query.where(Recipe.id.notin_(exclude)).order_by(func.random()).limit(1))).first()
    if row is None:  # nothing left after excluding -> allow repeats
        row = (await db.execute(query.order_by(func.random()).limit(1))).first()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No recipes found")
    return {"id": str(row.id), "servings": row.servings}


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
