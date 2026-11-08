from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_user, get_plan_owner
from app.database import get_db
from app.domains.meal_plans.models import MealPlan, MealPlanItem, MealType
from app.domains.meal_plans.schemas import (
    MealPlanCreate,
    MealPlanItemCreate,
    MealPlanItemMove,
    MealPlanItemResponse,
    MealPlanItemServingsUpdate,
    MealPlanItemSwap,
    MealPlanResponse,
)
from app.domains.recipes.models import Recipe
from app.domains.subscriptions.models import SubscriptionPlan
from app.domains.users.models import User

router = APIRouter()


async def _get_plan_limits(db: AsyncSession, user: User) -> SubscriptionPlan | None:
    if user.subscription_plan_id is None:
        return None
    result = await db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.id == user.subscription_plan_id)
    )
    return result.scalar_one_or_none()


def _is_free_plan(plan: SubscriptionPlan | None) -> bool:
    """Free users (no subscription or 'free' slug) get the rolling 7-day model:
    a single budget of recipes spread across [today, today+6], no history."""
    if plan is None:
        return True
    return plan.slug == "free"


def _max_meal_plans(plan: SubscriptionPlan | None) -> int:
    return plan.max_meal_plans if plan else 1


def _max_recipes_per_week(plan: SubscriptionPlan | None) -> int:
    return plan.max_recipes_per_week if plan else 5


async def _count_items_in_rolling_window(
    db: AsyncSession, user_id, today: date
) -> int:
    """Count meal plan items whose date falls within [today, today+6], including
    soft-deleted items. The free-plan budget is cumulative — once a slot is
    spent, removing the item must not free it."""
    end_date = today + timedelta(days=6)
    result = await db.execute(
        select(MealPlanItem.day_of_week, MealPlan.week_start_date)
        .join(MealPlan, MealPlanItem.meal_plan_id == MealPlan.id)
        .where(
            MealPlan.user_id == user_id,
            MealPlan.week_start_date >= today - timedelta(days=6),
            MealPlan.week_start_date <= end_date,
        )
    )
    count = 0
    for day_of_week, week_start in result.all():
        item_date = week_start + timedelta(days=day_of_week)
        if today <= item_date <= end_date:
            count += 1
    return count


_PLAN_OPTS = [
    selectinload(MealPlan.items.and_(MealPlanItem.is_deleted == False))  # noqa: E712
    .selectinload(MealPlanItem.recipe)
    .selectinload(Recipe.translations)
]


@router.get("/current", response_model=MealPlanResponse)
async def get_current_meal_plan(
    current_user: User = Depends(get_plan_owner),
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


@router.get("/by-monday/{monday}", response_model=MealPlanResponse)
async def get_plan_by_monday(
    monday: date,
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
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
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
    sub_plan = await _get_plan_limits(db, current_user)

    # Free users live in a rolling 7-day window that may span two ISO weeks,
    # so they don't have a max-plans cap — the recipe count is the real limit.
    if not _is_free_plan(sub_plan):
        max_plans = _max_meal_plans(sub_plan)
        today = date.today()
        current_week_monday = today - timedelta(days=today.weekday())
        count_result = await db.execute(
            select(func.count())
            .select_from(MealPlan)
            .where(
                MealPlan.user_id == current_user.id,
                MealPlan.week_start_date >= current_week_monday,
            )
        )
        existing_count = count_result.scalar_one()
        if existing_count >= max_plans:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Your plan allows a maximum of {max_plans} active meal plan(s). Upgrade to create more.",
            )

        max_recipes = _max_recipes_per_week(sub_plan)
        if len(data.items) > max_recipes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Your plan allows a maximum of {max_recipes} recipes per week. Upgrade to add more.",
            )

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
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")

    sub_plan = await _get_plan_limits(db, current_user)
    max_recipes = _max_recipes_per_week(sub_plan)

    if _is_free_plan(sub_plan):
        # Free: rolling 7-day window. Reject items outside [today, today+6]
        # and cap the total across all of the user's plans in that window.
        today = date.today()
        target_date = plan.week_start_date + timedelta(days=item.day_of_week)
        if target_date < today or target_date > today + timedelta(days=6):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Free plan only supports recipes for the next 7 days. Upgrade for full planning.",
            )
        rolling_count = await _count_items_in_rolling_window(db, current_user.id, today)
        if rolling_count >= max_recipes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Free plan allows a maximum of {max_recipes} recipes in the next 7 days. Upgrade for more.",
            )
    else:
        item_count_result = await db.execute(
            select(func.count()).select_from(MealPlanItem).where(
                MealPlanItem.meal_plan_id == plan_id,
                MealPlanItem.is_deleted == False,  # noqa: E712
            )
        )
        item_count = item_count_result.scalar_one()
        if item_count >= max_recipes:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Your plan allows a maximum of {max_recipes} recipes per week. Upgrade to add more.",
            )

    new_item = MealPlanItem(
        meal_plan_id=plan.id,
        recipe_id=item.recipe_id,
        day_of_week=item.day_of_week,
        meal_type=item.meal_type,
        servings=item.servings,
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
    current_user: User = Depends(get_plan_owner),
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
        .where(
            MealPlanItem.id == item_id,
            MealPlanItem.meal_plan_id == plan_id,
            MealPlanItem.is_deleted == False,  # noqa: E712
        )
        .options(selectinload(MealPlanItem.recipe).selectinload(Recipe.translations))
    )
    item = item_result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    item.is_completed = True
    await db.flush()
    return item


@router.patch("/{plan_id}/items/{item_id}/servings", response_model=MealPlanItemResponse)
async def update_item_servings(
    plan_id: int,
    item_id: int,
    body: MealPlanItemServingsUpdate,
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
    """Change the portions of a planned recipe and move the shopping list by the difference
    (more portions add the extra amounts; fewer take them back out of what is still unchecked)."""
    plan = (await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )).scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")
    item = (await db.execute(
        select(MealPlanItem)
        .where(
            MealPlanItem.id == item_id,
            MealPlanItem.meal_plan_id == plan_id,
            MealPlanItem.is_deleted == False,  # noqa: E712
        )
        .options(selectinload(MealPlanItem.recipe).selectinload(Recipe.translations))
    )).scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    delta = body.servings - item.servings
    if delta > 0:
        shopping_list = await _get_or_create_week_shopping_list(db, current_user.id, plan.week_start_date)
        await _apply_recipe_to_shopping_list(db, shopping_list.id, item.recipe_id, delta, item.day_of_week)
    elif delta < 0:
        await _remove_recipe_from_shopping_list(db, current_user.id, plan.week_start_date, item.recipe_id, -delta,
                                                item.day_of_week)
    item.servings = body.servings
    await db.flush()
    return item


@router.patch("/{plan_id}/items/{item_id}/move", response_model=MealPlanItemResponse)
async def move_meal_plan_item(
    plan_id: int,
    item_id: int,
    body: MealPlanItemMove,
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
    """Move a planned recipe to another day (and optionally meal), e.g. it was not cooked on Friday.
    The same row moves (no new quota slot); its still-unchecked shopping rows move with it, and
    what was already bought stays bought — nothing is added to buy again."""
    plan = (await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )).scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")
    item = (await db.execute(
        select(MealPlanItem).where(
            MealPlanItem.id == item_id,
            MealPlanItem.meal_plan_id == plan_id,
            MealPlanItem.is_deleted == False,  # noqa: E712
        )
    )).scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    meal_type = item.meal_type
    if body.meal_type:
        try:
            meal_type = MealType(body.meal_type.lower())
        except ValueError:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid meal type")

    today = date.today()
    if body.date < today:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot move a recipe into the past.")
    if _is_free_plan(await _get_plan_limits(db, current_user)) and body.date > today + timedelta(days=6):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Free plan only supports recipes for the next 7 days. Upgrade for full planning.",
        )

    new_monday = body.date - timedelta(days=body.date.weekday())
    new_day = body.date.weekday()
    target = plan
    if new_monday != plan.week_start_date:
        target = (await db.execute(
            select(MealPlan).where(MealPlan.user_id == current_user.id, MealPlan.week_start_date == new_monday)
        )).scalar_one_or_none()
        if target is None:
            target = MealPlan(user_id=current_user.id, week_start_date=new_monday)
            db.add(target)
            await db.flush()

    await _move_recipe_in_shopping_list(
        db, current_user.id, item.recipe_id, item.servings,
        plan.week_start_date, item.day_of_week, new_monday, new_day,
    )
    item.meal_plan_id = target.id
    item.day_of_week = new_day
    item.meal_type = meal_type
    item.is_completed = False
    await db.flush()

    return (await db.execute(
        select(MealPlanItem)
        .where(MealPlanItem.id == item.id)
        .options(selectinload(MealPlanItem.recipe).selectinload(Recipe.translations))
        .execution_options(populate_existing=True)
    )).scalar_one()


async def _move_recipe_in_shopping_list(db: AsyncSession, user_id, recipe_id, servings: int,
                                        old_week: date, old_day: int, new_week: date, new_day: int) -> None:
    """Move what this recipe still needs (unchecked rows) from the old day to the new one.
    Only the amount actually found unchecked moves, so bought products are not asked for again."""
    from app.domains.recipes.models import RecipeIngredient
    from app.domains.shopping_lists.models import ShoppingList, ShoppingListItem

    old_list = (await db.execute(
        select(ShoppingList).where(ShoppingList.user_id == user_id, ShoppingList.name == f"Week of {old_week}")
    )).scalar_one_or_none()
    if not old_list:
        return
    recipe = (await db.execute(select(Recipe).where(Recipe.id == recipe_id))).scalar_one_or_none()
    if not recipe:
        return
    ratio = servings / recipe.servings if recipe.servings > 0 else 1
    ings = (await db.execute(select(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe_id))).scalars().all()

    old_rows = (await db.execute(
        select(ShoppingListItem).where(
            ShoppingListItem.shopping_list_id == old_list.id,
            ShoppingListItem.is_checked == False,  # noqa: E712
        )
    )).scalars().all()
    old_by_key = {}
    for r in old_rows:
        old_by_key.setdefault((r.ingredient_id, r.unit, r.day_of_week), r)

    new_list = old_list if new_week == old_week else await _get_or_create_week_shopping_list(db, user_id, new_week)
    new_rows = old_rows if new_list is old_list else (await db.execute(
        select(ShoppingListItem).where(
            ShoppingListItem.shopping_list_id == new_list.id,
            ShoppingListItem.is_checked == False,  # noqa: E712
        )
    )).scalars().all()
    new_by_key = {}
    for r in new_rows:
        new_by_key.setdefault((r.ingredient_id, r.unit, r.day_of_week), r)

    for ing in ings:
        key = next((k for k in ((ing.ingredient_id, ing.unit, old_day), (ing.ingredient_id, ing.unit, None))
                    if k in old_by_key), None)
        if key is None:
            continue  # already bought (checked) or cleared: nothing left to move
        row = old_by_key[key]
        take = min(float(row.quantity), float(ing.quantity) * ratio)
        left = float(row.quantity) - take
        if left <= 0.01:
            take = float(row.quantity)
            await db.delete(row)
            old_by_key.pop(key)
            if new_by_key.get(key) is row:
                new_by_key.pop(key)
        else:
            row.quantity = left
        dest_key = (ing.ingredient_id, ing.unit, new_day)
        dest = new_by_key.get(dest_key)
        if dest is not None:
            dest.quantity = float(dest.quantity) + take
        else:
            dest = ShoppingListItem(
                shopping_list_id=new_list.id,
                ingredient_id=ing.ingredient_id,
                quantity=take,
                unit=ing.unit,
                is_checked=False,
                added_from_recipe_id=recipe_id,
                day_of_week=new_day,
            )
            db.add(dest)
            new_by_key[dest_key] = dest
            if new_list is old_list:
                old_by_key.setdefault(dest_key, dest)


@router.patch("/{plan_id}/items/{item_id}/recipe", response_model=MealPlanItemResponse)
async def swap_item_recipe(
    plan_id: int,
    item_id: int,
    body: MealPlanItemSwap,
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
    """Replace the recipe of a planned meal ("re-roll"): a random one of the meal's category,
    or `recipe_id` (e.g. undo back to the previous one). Same day, meal and portions; the old
    recipe's unbought products leave the shopping list and the new one's are added."""
    from app.domains.categories.models import Category, recipe_categories
    from app.domains.recipes.models import RecipeStatus

    plan = (await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )).scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")
    item = (await db.execute(
        select(MealPlanItem).where(
            MealPlanItem.id == item_id,
            MealPlanItem.meal_plan_id == plan_id,
            MealPlanItem.is_deleted == False,  # noqa: E712
        )
    )).scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    if body.recipe_id is not None:
        new_id = (await db.execute(
            select(Recipe.id).where(Recipe.id == body.recipe_id, Recipe.status == RecipeStatus.PUBLISHED)
        )).scalar_one_or_none()
        if new_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
    else:
        # avoid recipes already planned this week (and the current one)
        week_ids = (await db.execute(
            select(MealPlanItem.recipe_id).where(
                MealPlanItem.meal_plan_id == plan.id, MealPlanItem.is_deleted == False  # noqa: E712
            )
        )).scalars().all()
        meal = item.meal_type.value if hasattr(item.meal_type, "value") else str(item.meal_type)
        q = (select(Recipe.id)
             .join(recipe_categories, recipe_categories.c.recipe_id == Recipe.id)
             .join(Category, Category.id == recipe_categories.c.category_id)
             .where(Recipe.status == RecipeStatus.PUBLISHED, Category.slug == meal.lower()))
        new_id = (await db.execute(
            q.where(Recipe.id.notin_(set(week_ids) | {item.recipe_id})).order_by(func.random()).limit(1)
        )).scalar_one_or_none()
        if new_id is None:
            new_id = (await db.execute(
                q.where(Recipe.id != item.recipe_id).order_by(func.random()).limit(1)
            )).scalar_one_or_none()
        if new_id is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No recipes found")

    if new_id != item.recipe_id:
        await _remove_recipe_from_shopping_list(db, current_user.id, plan.week_start_date, item.recipe_id,
                                                item.servings, item.day_of_week)
        shopping_list = await _get_or_create_week_shopping_list(db, current_user.id, plan.week_start_date)
        await db.flush()
        await _apply_recipe_to_shopping_list(db, shopping_list.id, new_id, item.servings, item.day_of_week)
        item.recipe_id = new_id
        item.is_completed = False
        await db.flush()

    return (await db.execute(
        select(MealPlanItem)
        .where(MealPlanItem.id == item.id)
        .options(selectinload(MealPlanItem.recipe).selectinload(Recipe.translations))
        .execution_options(populate_existing=True)
    )).scalar_one()


@router.delete("/{plan_id}/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_meal_plan_item(
    plan_id: int,
    item_id: int,
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(MealPlan).where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")

    item_result = await db.execute(
        select(MealPlanItem).where(
            MealPlanItem.id == item_id,
            MealPlanItem.meal_plan_id == plan_id,
            MealPlanItem.is_deleted == False,  # noqa: E712
        )
    )
    item = item_result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    # Soft-delete: free-plan quota is cumulative, so the row must remain
    # visible to _count_items_in_rolling_window.
    item.is_deleted = True
    await db.flush()

    # Take this recipe's ingredients back out of the week's shopping list
    # (only what is still unchecked; rows that drop to zero are removed).
    await _remove_recipe_from_shopping_list(db, current_user.id, plan.week_start_date, item.recipe_id, item.servings,
                                            item.day_of_week)
    await db.flush()


async def _remove_recipe_from_shopping_list(db: AsyncSession, user_id, week_start_date: date, recipe_id, servings: int,
                                            day_of_week: int | None = None) -> None:
    from app.domains.recipes.models import Recipe, RecipeIngredient
    from app.domains.shopping_lists.models import ShoppingList, ShoppingListItem

    shopping_list = (await db.execute(
        select(ShoppingList).where(ShoppingList.user_id == user_id, ShoppingList.name == f"Week of {week_start_date}")
    )).scalar_one_or_none()
    if not shopping_list:
        return
    recipe = (await db.execute(select(Recipe).where(Recipe.id == recipe_id))).scalar_one_or_none()
    if not recipe:
        return
    ratio = servings / recipe.servings if recipe.servings > 0 else 1
    ings = (await db.execute(select(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe_id))).scalars().all()
    rows = (await db.execute(
        select(ShoppingListItem).where(
            ShoppingListItem.shopping_list_id == shopping_list.id,
            ShoppingListItem.is_checked == False,  # noqa: E712
        )
    )).scalars().all()
    # prefer the row for this recipe's day; fall back to rows without a day (added before per-day tracking)
    by_key = {}
    for r in rows:
        by_key.setdefault((r.ingredient_id, r.unit, r.day_of_week), r)
    for ing in ings:
        key = next((k for k in ((ing.ingredient_id, ing.unit, day_of_week), (ing.ingredient_id, ing.unit, None))
                    if k in by_key), None)
        if key is None:
            continue
        row = by_key[key]
        left = float(row.quantity) - float(ing.quantity) * ratio
        if left <= 0.01:
            await db.delete(row)
            by_key.pop(key)
        else:
            row.quantity = left


async def _get_or_create_week_shopping_list(
    db: AsyncSession, user_id, week_start_date: date,
):
    """Find-or-create the shopping list for a meal plan week."""
    from app.domains.shopping_lists.models import ShoppingList

    list_name = f"Week of {week_start_date}"
    existing_result = await db.execute(
        select(ShoppingList).where(
            ShoppingList.user_id == user_id,
            ShoppingList.name == list_name,
        )
    )
    existing = existing_result.scalar_one_or_none()
    if existing:
        return existing
    shopping_list = ShoppingList(user_id=user_id, name=list_name)
    db.add(shopping_list)
    await db.flush()
    return shopping_list


async def _apply_recipe_to_shopping_list(
    db: AsyncSession, shopping_list_id: int, recipe_id, servings: int, day_of_week: int | None = None,
) -> None:
    """Aggregate one recipe's ingredients into a shopping list:
    - If an unchecked row exists for (ingredient_id, unit): increase its quantity.
    - Else (no row, or only a checked row): insert a new unchecked row with the
      recipe's quantity. The checked row is left untouched — the user already
      bought that amount; the new amount is what they still need.
    Quantities are scaled by `servings / recipe.servings`.
    Rows are kept per plan day (`day_of_week`) so the list can be split by day;
    the app merges them back into one row per ingredient in the default view.
    """
    from app.domains.recipes.models import Recipe, RecipeIngredient
    from app.domains.shopping_lists.models import ShoppingListItem

    recipe = (await db.execute(
        select(Recipe).where(Recipe.id == recipe_id)
    )).scalar_one()
    ings = (await db.execute(
        select(RecipeIngredient).where(RecipeIngredient.recipe_id == recipe_id)
    )).scalars().all()
    ratio = servings / recipe.servings if recipe.servings > 0 else 1

    existing_items = (await db.execute(
        select(ShoppingListItem).where(
            ShoppingListItem.shopping_list_id == shopping_list_id
        )
    )).scalars().all()
    unchecked_by_key: dict[tuple, ShoppingListItem] = {}
    for it in existing_items:
        if not it.is_checked:
            unchecked_by_key.setdefault((it.ingredient_id, it.unit, it.day_of_week), it)

    for ing in ings:
        qty_needed = float(ing.quantity) * ratio
        key = (ing.ingredient_id, ing.unit, day_of_week)
        unchecked_row = unchecked_by_key.get(key)
        if unchecked_row is not None:
            unchecked_row.quantity = float(unchecked_row.quantity) + qty_needed
            continue
        new_row = ShoppingListItem(
            shopping_list_id=shopping_list_id,
            ingredient_id=ing.ingredient_id,
            quantity=qty_needed,
            unit=ing.unit,
            is_checked=False,
            added_from_recipe_id=recipe_id,
            day_of_week=day_of_week,
        )
        db.add(new_row)
        unchecked_by_key[key] = new_row


@router.post("/{plan_id}/items/{item_id}/sync-shopping-list")
async def sync_shopping_list_for_item(
    plan_id: int,
    item_id: int,
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
    """Append a single just-added meal plan item's ingredients to the week's
    shopping list. Does NOT touch existing items beyond the aggregation rule —
    cleared (deleted) items stay cleared, checked items stay checked."""
    plan_result = await db.execute(
        select(MealPlan).where(
            MealPlan.id == plan_id, MealPlan.user_id == current_user.id
        )
    )
    plan = plan_result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")

    item_result = await db.execute(
        select(MealPlanItem).where(
            MealPlanItem.id == item_id,
            MealPlanItem.meal_plan_id == plan_id,
            MealPlanItem.is_deleted == False,  # noqa: E712
        )
    )
    item = item_result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    shopping_list = await _get_or_create_week_shopping_list(
        db, current_user.id, plan.week_start_date
    )
    await _apply_recipe_to_shopping_list(
        db, shopping_list.id, item.recipe_id, item.servings, item.day_of_week
    )
    await db.flush()
    return {"shopping_list_id": shopping_list.id}


@router.post("/{plan_id}/generate-shopping-list")
async def generate_shopping_list(
    plan_id: int,
    current_user: User = Depends(get_plan_owner),
    db: AsyncSession = Depends(get_db),
):
    """Manual full rebuild. Deletes only unchecked items (preserves checked-off
    history), then aggregates every active meal plan item back into the list."""
    from app.domains.shopping_lists.models import ShoppingListItem

    result = await db.execute(
        select(MealPlan)
        .where(MealPlan.id == plan_id, MealPlan.user_id == current_user.id)
        .options(selectinload(MealPlan.items.and_(MealPlanItem.is_deleted == False)))  # noqa: E712
    )
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meal plan not found")

    shopping_list = await _get_or_create_week_shopping_list(
        db, current_user.id, plan.week_start_date
    )

    await db.execute(
        delete(ShoppingListItem).where(
            ShoppingListItem.shopping_list_id == shopping_list.id,
            ShoppingListItem.is_checked == False,  # noqa: E712
        )
    )
    await db.flush()

    for meal_item in plan.items:
        await _apply_recipe_to_shopping_list(
            db, shopping_list.id, meal_item.recipe_id, meal_item.servings, meal_item.day_of_week
        )
    await db.flush()
    return {"shopping_list_id": shopping_list.id}
