from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.domains.recipes.models import Recipe
from app.domains.weekly_suggestions.models import WeeklySuggestion

router = APIRouter()


@router.get("")
async def get_weekly_suggestions(
    week_start: date | None = Query(None),
    db: AsyncSession = Depends(get_db),
):
    if not week_start:
        today = date.today()
        week_start = today - timedelta(days=today.weekday())

    result = await db.execute(
        select(WeeklySuggestion)
        .where(
            WeeklySuggestion.week_start_date == week_start,
            WeeklySuggestion.is_active == True,  # noqa: E712
        )
        .options(selectinload(WeeklySuggestion.recipe).selectinload(Recipe.translations))
        .order_by(WeeklySuggestion.position)
    )
    suggestions = result.scalars().all()

    # Fall back to the most recent active suggestions when none exist for this week
    if not suggestions:
        fallback_result = await db.execute(
            select(WeeklySuggestion)
            .where(WeeklySuggestion.is_active == True)  # noqa: E712
            .options(selectinload(WeeklySuggestion.recipe).selectinload(Recipe.translations))
            .order_by(WeeklySuggestion.week_start_date.desc(), WeeklySuggestion.position)
        )
        suggestions = fallback_result.scalars().all()

    return {
        "week_start": week_start,
        "items": [
            {
                "id": s.id,
                "position": s.position,
                "recipe": {
                    "id": str(s.recipe.id),
                    "image_url": s.recipe.image_url,
                    "total_time_minutes": s.recipe.total_time_minutes,
                    "difficulty": s.recipe.difficulty,
                    "servings": s.recipe.servings,
                    "translations": [
                        {
                            "language_code": t.language_code,
                            "title": t.title,
                            "description": t.description,
                        }
                        for t in s.recipe.translations
                    ],
                },
            }
            for s in suggestions
        ],
    }
