from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.domains.stores.models import Store

router = APIRouter()


@router.get("/")
async def list_stores(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Store).where(Store.is_active == True))  # noqa: E712
    return result.scalars().all()
