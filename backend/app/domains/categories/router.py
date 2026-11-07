from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.domains.categories.models import Category, CategoryTranslation
from app.domains.categories.schemas import CategoryCreateRequest, CategoryResponse

router = APIRouter()


@router.get("/", response_model=list[CategoryResponse])
async def list_categories(db: AsyncSession = Depends(get_db)):
    from sqlalchemy import func

    from app.domains.categories.models import recipe_categories
    from app.domains.recipes.models import Recipe, RecipeStatus

    result = await db.execute(
        select(Category).options(selectinload(Category.translations)).order_by(Category.id)
    )
    categories = result.scalars().all()
    counts = dict((await db.execute(
        select(recipe_categories.c.category_id, func.count())
        .join(Recipe, Recipe.id == recipe_categories.c.recipe_id)
        .where(Recipe.status == RecipeStatus.PUBLISHED)
        .group_by(recipe_categories.c.category_id)
    )).all())
    return [
        CategoryResponse(id=c.id, slug=c.slug, icon_url=c.icon_url,
                         translations=c.translations, recipe_count=counts.get(c.id, 0))
        for c in categories
    ]


@router.get("/{category_id}", response_model=CategoryResponse)
async def get_category(category_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Category)
        .where(Category.id == category_id)
        .options(selectinload(Category.translations))
    )
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    return cat
