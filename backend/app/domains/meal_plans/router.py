import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.domains.meal_plans.models import MealPlan, MealPlanItem
from app.domains.meal_plans.schemas import MealPlanCreate, MealPlanItemCreate, MealPlanItemResponse, MealPlanResponse
from app.domains.recipes.models import Recipe, RecipeTranslation
from app.domains.users.models import User

router = APIRouter()

_PLAN_OPTS = [
    selectinload(MealPlan.items)
    .selectinload(MealPlanItem.recipe)
    .selectinload(Recipe.translations)
]


@router.get("/current", response_model=MealPlanResponse)
async def get_current_meal_plan(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    today = date.today()
    monday = today - timedelta(days=today.weekday())
    result = await db.execute(
        select(MealPlan)
        .where(MealPlan.user_id == current_user.id, MealPlan.week_start_date == monday)
        .options(*_PLAN_OPTS)
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No meal plan for this week")
    return plan


@router.post("/", response_model=MealPlanResponse, status_code=status.HTTP_201_CREATED)
async def create_meal_plan(
    data: MealPlanCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    plan = MealPlan(user_id=current_user.id, week_start_date=data.week_start_date)
    db.add(plan)
    await db.flush()

    for item in data.items:
        db.add(MealPlanItem(
            meal_plan_id=plan.id,
            recipe_id=item.recipe_id,
            day_of_week=item.day_of_week,
            meal_type=item.meal_type,
        ))
    await db.flush()

    # Re-fetch with full relations
    result = await db.execute(
        select(MealPlan).where(MealPlan.id == plan.id).options(*_PLAN_OPTS)
    )
    return result.scalar_one()


@router.post("/{plan_id}/items", response_model=MealPlanItemResponse)
async def add_meal_plan_item(
    plan_id: int,
    item: MealPlanItemCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")

    new_item = MealPlanItem(
        meal_plan_id=plan.id,
        recipe_id=item.recipe_id,
        day_of_week=item.day_of_week,
        meal_type=item.meal_type,
    )
    db.add(new_item)
    await db.flush()

    # Re-fetch with recipe + translations
    item_result = await db.execute(
        select(MealPlanItem)
        .where(MealPlanItem.id == new_item.id)
        .options(
            selectinload(MealPlanItem.recipe).selectinload(Recipe.translations)
        )
    )
    return item_result.scalar_one()


@router.patch("/{plan_id}/items/{item_id}/complete", response_model=MealPlanItemResponse)
async def mark_item_complete(
    plan_id: int,
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")

    item_result = await db.execute(
        select(MealPlanItem)
        .where(MealPlanItem.id == item_id, MealPlanItem.meal_plan_id == plan_id)
        .options(selectinload(MealPlanItem.recipe).selectinload(Recipe.translations))
    )
    item = item_result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    item.is_completed = True
    await db.flush()
    return item


@router.delete("/{plan_id}/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_meal_plan_item(
    plan_id: int,
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")

    item_result = await db.execute(
        select(MealPlanItem).where(MealPlanItem.id == item_id, MealPlanItem.meal_plan_id == plan_id)
    )
    item = item_result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    await db.delete(item)
    await db.flush()


@router.post("/{plan_id}/generate-shopping-list")
async def generate_shopping_list(
    plan_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from collections import defaultdict

    from app.domains.recipes.models import RecipeIngredient
    from app.domains.shopping_lists.models import ShoppingList, ShoppingListItem

    result = await db.execute(
        select(MealPlan)
        .where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
        .options(selectinload(MealPlan.items))
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")

    # Aggregate ingredients across all meal plan items
    agg: dict[tuple, float] = defaultdict(float)
    for meal_item in plan.items:
        ings = (await db.execute(
            select(RecipeIngredient).where(RecipeIngredient.recipe_id == meal_item.recipe_id)
        )).scalars().all()
        for ing in ings:
            agg[(ing.ingredient_id, ing.unit)] += float(ing.quantity)

    list_name = f"Week of {plan.week_start_date}"

    # Check if a list already exists for this week — make it idempotent
    existing_result = await db.execute(
        select(ShoppingList).where(
            ShoppingList.user_id == current_user.id,
            ShoppingList.name == list_name,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if existing:
        # Delete old items and reuse the list
        await db.execute(
            delete(ShoppingListItem).where(ShoppingListItem.shopping_list_id == existing.id)
        )
        shopping_list = existing
    else:
        shopping_list = ShoppingList(user_id=current_user.id, name=list_name)
        db.add(shopping_list)
        await db.flush()

    for (ing_id, unit), qty in agg.items():
        db.add(ShoppingListItem(
            shopping_list_id=shopping_list.id,
            ingredient_id=ing_id,
            quantity=qty,
            unit=unit,
        ))
    await db.flush()
    return {"shopping_list_id": shopping_list.id, "items_count": len(agg)}
