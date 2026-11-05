"""Download every external (http/https) image_url into /media and point the DB at the local file.

    python -m scripts.localize_images
"""
import asyncio
import io
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import httpx
from PIL import Image
from sqlalchemy import select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import settings
from app.domains.categories.models import Category
from app.domains.ingredients.models import Ingredient
from app.domains.recipes.models import Recipe, RecipeStepTranslation
from app.models import *  # noqa: F401,F403

MEDIA = Path(__file__).resolve().parent.parent / "media"


async def fetch(client, url, kind):
    r = await client.get(url, follow_redirects=True, timeout=60)
    r.raise_for_status()
    img = Image.open(io.BytesIO(r.content)).convert("RGB")
    img.thumbnail((1600, 1600))
    out = MEDIA / "uploads" / kind
    out.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}.jpg"
    img.save(out / name, "JPEG", quality=88, optimize=True)
    return f"/media/uploads/{kind}/{name}"


async def main():
    engine = create_async_engine(settings.DATABASE_URL)
    Session = async_sessionmaker(engine, expire_on_commit=False)
    targets = [(Recipe, "image_url", "recipes"), (Ingredient, "image_url", "ingredients"),
               (RecipeStepTranslation, "image_url", "steps"), (Category, "icon_url", "categories")]
    ok = fail = 0
    async with Session() as db, httpx.AsyncClient(headers={"User-Agent": "PlateFlow/1.0"}) as client:
        for model, field, kind in targets:
            col = getattr(model, field)
            rows = (await db.execute(select(model).where(col.like("http%")))).scalars().all()
            for row in rows:
                try:
                    setattr(row, field, await fetch(client, getattr(row, field), kind))
                    ok += 1
                except Exception as e:
                    print(f"✗ {model.__name__} {row.id}: {e!r}"[:200])
                    setattr(row, field, None)
                    fail += 1
            await db.commit()
    print(f"✓ localized {ok} images, {fail} failed (cleared)")


if __name__ == "__main__":
    asyncio.run(main())
