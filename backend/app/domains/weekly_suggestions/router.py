from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.domains.recipes.models import Recipe
from app.domains.weekly_suggestions.models import WeeklySuggestion

router = APIRouter()


@router.get("/")
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
    return {"week_start": week_start, "items": [s.recipe for s in suggestions]}
