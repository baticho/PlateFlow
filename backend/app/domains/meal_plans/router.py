import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user
from app.database import get_db
from app.domains.meal_plans.models import MealPlan, MealPlanItem
from app.domains.meal_plans.schemas import MealPlanCreate, MealPlanItemCreate, MealPlanResponse
from app.domains.users.models import User

router = APIRouter()


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
        .options(selectinload(MealPlan.items))
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
    return plan


@router.post("/{plan_id}/items")
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
    return new_item


@router.post("/{plan_id}/generate-shopping-list")
async def generate_shopping_list(
    plan_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from collections import defaultdict

    from sqlalchemy.orm import selectinload

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

    # Aggregate ingredients
    agg: dict[tuple, float] = defaultdict(float)
    for item in plan.items:
        ings = (await db.execute(
            select(RecipeIngredient).where(RecipeIngredient.recipe_id == item.recipe_id)
        )).scalars().all()
        for ing in ings:
            agg[(ing.ingredient_id, ing.unit)] += ing.quantity

    shopping_list = ShoppingList(
        user_id=current_user.id,
        name=f"Week of {plan.week_start_date}",
    )
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
