import uuid
from typing import Any

from sqlalchemy import func, or_, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domains.categories.models import Category
from app.domains.recipes.models import (
    Recipe,
    RecipeIngredient,
    RecipeStatus,
    RecipeStep,
    RecipeStepTranslation,
    RecipeTranslation,
)
from app.domains.tags.models import Tag


async def get_recipes(
    db: AsyncSession,
    language: str = "en",
    page: int = 1,
    page_size: int = 20,
    q: str | None = None,
    category_id: int | None = None,
    cuisine_id: int | None = None,
    max_time: int | None = None,
    difficulty: str | None = None,
    ingredient_ids: list[int] | None = None,
) -> dict[str, Any]:
    query = (
        select(Recipe)
        .where(Recipe.status == RecipeStatus.PUBLISHED)
        .options(selectinload(Recipe.translations))
    )

    if q:
        query = query.join(
            RecipeTranslation,
            RecipeTranslation.recipe_id == Recipe.id,
        ).where(
            RecipeTranslation.language_code == language,
            or_(
                RecipeTranslation.title.ilike(f"%{q}%"),
                RecipeTranslation.description.ilike(f"%{q}%"),
            ),
        )

    if category_id:
        from app.domains.categories.models import recipe_categories
        query = query.join(recipe_categories).where(
            recipe_categories.c.category_id == category_id
        )

    if cuisine_id:
        query = query.where(Recipe.cuisine_id == cuisine_id)

    if max_time:
        query = query.where(Recipe.total_time_minutes <= max_time)

    if difficulty:
        query = query.where(Recipe.difficulty == difficulty)

    if ingredient_ids:
        from app.domains.recipes.models import RecipeIngredient
        for ing_id in ingredient_ids:
            subq = select(RecipeIngredient.recipe_id).where(
                RecipeIngredient.ingredient_id == ing_id
            )
            query = query.where(Recipe.id.in_(subq))

    count_query = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_query)).scalar_one()

    query = query.offset((page - 1) * page_size).limit(page_size)
    recipes = (await db.execute(query)).scalars().all()

    return {
        "items": recipes,
        "total": total,
        "page": page,
        "page_size": page_size,
        "pages": (total + page_size - 1) // page_size,
    }


async def get_recipe_by_id(db: AsyncSession, recipe_id: uuid.UUID) -> Recipe | None:
    result = await db.execute(
        select(Recipe)
        .where(Recipe.id == recipe_id)
        .options(
            selectinload(Recipe.translations),
            selectinload(Recipe.steps).selectinload(RecipeStep.translations),
            selectinload(Recipe.ingredients),
        )
    )
    return result.scalar_one_or_none()


async def create_recipe(db: AsyncSession, data: dict, created_by: uuid.UUID) -> Recipe:
    recipe = Recipe(
        cuisine_id=data.get("cuisine_id"),
        prep_time_minutes=data.get("prep_time_minutes", 0),
        cook_time_minutes=data.get("cook_time_minutes", 0),
        total_time_minutes=data.get("prep_time_minutes", 0) + data.get("cook_time_minutes", 0),
        servings=data.get("servings", 4),
        difficulty=data.get("difficulty", "easy"),
        image_url=data.get("image_url"),
        created_by=created_by,
    )
    db.add(recipe)
    await db.flush()

    # Translations
    for t in data.get("translations", []):
        db.add(RecipeTranslation(
            recipe_id=recipe.id,
            language_code=t["language_code"],
            title=t["title"],
            description=t.get("description"),
        ))

    # Steps
    for step_data in data.get("steps", []):
        step = RecipeStep(recipe_id=recipe.id, order=step_data["order"])
        db.add(step)
        await db.flush()
        for st in step_data.get("translations", []):
            db.add(RecipeStepTranslation(
                step_id=step.id,
                language_code=st["language_code"],
                instruction=st["instruction"],
                image_url=st.get("image_url"),
            ))

    # Ingredients
    for ing in data.get("ingredients", []):
        db.add(RecipeIngredient(
            recipe_id=recipe.id,
            ingredient_id=ing["ingredient_id"],
            quantity=ing["quantity"],
            unit=ing["unit"],
            is_optional=ing.get("is_optional", False),
        ))

    # Categories
    if data.get("category_ids"):
        cats = (await db.execute(
            select(Category).where(Category.id.in_(data["category_ids"]))
        )).scalars().all()
        recipe.categories = list(cats)

    # Tags
    if data.get("tag_ids"):
        tags = (await db.execute(
            select(Tag).where(Tag.id.in_(data["tag_ids"]))
        )).scalars().all()
        recipe.tags = list(tags)

    await db.flush()
    return recipe
