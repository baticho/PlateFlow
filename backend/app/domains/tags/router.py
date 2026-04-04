from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.domains.tags.models import Tag

router = APIRouter()


@router.get("/")
async def list_tags(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Tag).options(selectinload(Tag.translations)))
    return result.scalars().all()
