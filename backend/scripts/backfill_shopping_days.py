"""One-off: give shopping-list rows created before per-day tracking a plan day.

    python -m scripts.backfill_shopping_days          # dry run (prints what would change)
    python -m scripts.backfill_shopping_days --apply

For every "Week of YYYY-MM-DD" list, the matching meal plan says on which days each ingredient is
needed. A day-less row is assigned to that day; if the ingredient is needed on several days the row
is split proportionally to each day's need. Totals and checked state are preserved, rows whose
ingredient is not in the plan are left without a day.
"""
import asyncio
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import select  # noqa: E402
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine  # noqa: E402

from app.config import settings  # noqa: E402
from app.models import *  # noqa: F401,F403,E402
from app.domains.meal_plans.models import MealPlan, MealPlanItem  # noqa: E402
from app.domains.recipes.models import Recipe, RecipeIngredient  # noqa: E402
from app.domains.shopping_lists.models import ShoppingList, ShoppingListItem  # noqa: E402


async def backfill(db, apply: bool) -> None:
    lists = (await db.execute(select(ShoppingList))).scalars().all()
    for sl in lists:
        try:
            week = date.fromisoformat(sl.name.removeprefix("Week of ").strip())
        except ValueError:
            continue
        rows = (await db.execute(select(ShoppingListItem).where(
            ShoppingListItem.shopping_list_id == sl.id, ShoppingListItem.day_of_week.is_(None)))).scalars().all()
        if not rows:
            continue
        plan = (await db.execute(select(MealPlan).where(
            MealPlan.user_id == sl.user_id, MealPlan.week_start_date == week))).scalar_one_or_none()
        if not plan:
            print(f"list {sl.id}: no plan for {week}, {len(rows)} rows left without a day")
            continue
        items = (await db.execute(select(MealPlanItem).where(
            MealPlanItem.meal_plan_id == plan.id, MealPlanItem.is_deleted == False))).scalars().all()  # noqa: E712

        # (ingredient, unit) -> {day: quantity needed}
        needs: dict[tuple, dict[int, float]] = defaultdict(lambda: defaultdict(float))
        for it in items:
            recipe = await db.get(Recipe, it.recipe_id)
            if not recipe:
                continue
            ratio = it.servings / recipe.servings if recipe.servings else 1
            for ri in (await db.execute(select(RecipeIngredient).where(RecipeIngredient.recipe_id == it.recipe_id))).scalars():
                needs[(ri.ingredient_id, ri.unit)][it.day_of_week] += float(ri.quantity) * ratio

        assigned = split = skipped = 0
        for row in rows:
            days = needs.get((row.ingredient_id, row.unit))
            if not days:
                skipped += 1
                continue
            total_need = sum(days.values())
            parts = sorted(days.items())
            qty = float(row.quantity)
            if len(parts) == 1 or total_need <= 0:
                row.day_of_week = parts[0][0]
                assigned += 1
                continue
            split += 1
            first_day, first_need = parts[0]
            row.day_of_week = first_day
            row.quantity = round(qty * first_need / total_need, 2)
            for day, need in parts[1:]:
                db.add(ShoppingListItem(
                    shopping_list_id=row.shopping_list_id, ingredient_id=row.ingredient_id,
                    quantity=round(qty * need / total_need, 2), unit=row.unit, is_checked=row.is_checked,
                    added_from_recipe_id=row.added_from_recipe_id, day_of_week=day,
                ))
        print(f"list {sl.id} ({sl.name}): {assigned} rows got a day, {split} split over several days, "
              f"{skipped} not in the plan (left without a day)")

    if apply:
        await db.commit()
        print("applied")
    else:
        await db.rollback()
        print("dry run — nothing written (use --apply)")


async def main():
    engine = create_async_engine(settings.DATABASE_URL)
    async with async_sessionmaker(engine, expire_on_commit=False)() as db:
        await backfill(db, "--apply" in sys.argv)


if __name__ == "__main__":
    asyncio.run(main())
