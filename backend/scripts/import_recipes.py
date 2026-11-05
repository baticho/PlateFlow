"""Import enriched recipes (JSONL) into PlateFlow.

    python -m scripts.import_recipes media/_import/enriched.jsonl
    python -m scripts.import_recipes --link-images      # only refresh image_url fields

Idempotent: media/_import/map.json remembers source_recipe_id -> recipe uuid, so re-runs only add new ones.
Ingredients are matched case-insensitively by English name (reuses seed ingredients).
Images are linked when media/recipes/<source_id>.jpg / media/ingredients/<ingredient_id>.jpg exist.
"""
import asyncio
import shutil
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import settings
from app.domains.categories.models import Category, CategoryTranslation, recipe_categories
from app.domains.cuisines.models import Cuisine, CuisineTranslation
from app.domains.ingredients.models import Ingredient, IngredientCategory, IngredientTranslation, MeasurementUnit
from app.domains.recipes.models import (
    Difficulty, Recipe, RecipeIngredient, RecipeStatus, RecipeStep, RecipeStepTranslation, RecipeTranslation,
)
from app.domains.tags.models import Tag, TagTranslation, recipe_tags
from app.domains.users.models import User
from app.models import *  # noqa: F401,F403

MEDIA = Path(__file__).resolve().parent.parent / "media"
MAP_FILE = MEDIA / "_import" / "map.json"

CATEGORY_MAP = {"dinner": "dinner", "breakfast": "breakfast", "snack": "snack", "simple": "lunch", "lunch": "lunch"}
CATEGORY_NAMES = {"lunch": ("Lunch", "Обяд"), "vegetarian": ("Vegetarian", "Вегетарианско"),
                  "vegan": ("Vegan", "Веганско"), "quick": ("Quick (under 30 min)", "Бързо (до 30 мин)"),
                  "dinner": ("Dinner", "Вечеря"), "breakfast": ("Breakfast", "Закуска"), "snack": ("Snack", "Снакс")}
TAG_NAMES = {
    "vegetarian": ("Vegetarian", "Вегетарианско"), "vegan": ("Vegan", "Веганско"),
    "gluten-free": ("Gluten-Free", "Без глутен"), "dairy-free": ("Dairy-Free", "Без лактоза"),
    "high-protein": ("High Protein", "Богато на протеин"), "low-carb": ("Low Carb", "Нисковъглехидратно"),
    "quick": ("Quick", "Бързо"), "spicy": ("Spicy", "Пикантно"),
}
CUISINES = {  # code: (continent, en, bg)
    "BG": ("europe", "Bulgarian", "Българска"), "IT": ("europe", "Italian", "Италианска"),
    "FR": ("europe", "French", "Френска"), "GR": ("europe", "Greek", "Гръцка"), "ES": ("europe", "Spanish", "Испанска"),
    "TR": ("europe", "Turkish", "Турска"), "DE": ("europe", "German", "Немска"), "GB": ("europe", "British", "Британска"),
    "PT": ("europe", "Portuguese", "Португалска"), "JP": ("asia", "Japanese", "Японска"),
    "CN": ("asia", "Chinese", "Китайска"), "IN": ("asia", "Indian", "Индийска"), "TH": ("asia", "Thai", "Тайска"),
    "KR": ("asia", "Korean", "Корейска"), "VN": ("asia", "Vietnamese", "Виетнамска"),
    "ID": ("asia", "Indonesian", "Индонезийска"), "LB": ("asia", "Lebanese", "Ливанска"),
    "IL": ("asia", "Israeli", "Израелска"), "US": ("north_america", "American", "Американска"),
    "MX": ("north_america", "Mexican", "Мексиканска"), "CA": ("north_america", "Canadian", "Канадска"),
    "CU": ("north_america", "Cuban", "Кубинска"), "JM": ("north_america", "Jamaican", "Ямайска"),
    "BR": ("south_america", "Brazilian", "Бразилска"), "PE": ("south_america", "Peruvian", "Перуанска"),
    "AR": ("south_america", "Argentinian", "Аржентинска"), "MA": ("africa", "Moroccan", "Мароканска"),
    "ET": ("africa", "Ethiopian", "Етиопска"), "EG": ("africa", "Egyptian", "Египетска"),
    "AU": ("oceania", "Australian", "Австралийска"),
}
DEFAULT_UNITS = {"g": MeasurementUnit.GRAM, "kg": MeasurementUnit.GRAM, "ml": MeasurementUnit.MILLILITER,
                 "l": MeasurementUnit.MILLILITER, "piece": MeasurementUnit.PIECE}


def recipe_image(source_id):
    return f"/media/recipes/{source_id}.jpg" if (MEDIA / "recipes" / f"{source_id}.jpg").exists() else None


def staging_image(ing_id, slug):
    """copy a pre-generated media/ingredients/_staging/<slug>.jpg to the ingredient's own image"""
    src = MEDIA / "ingredients" / "_staging" / f"{slug}.jpg"
    if not slug or not src.exists():
        return None
    shutil.copyfile(src, MEDIA / "ingredients" / f"{ing_id}.jpg")
    return f"/media/ingredients/{ing_id}.jpg"


def ingredient_image(ing_id):
    return f"/media/ingredients/{ing_id}.jpg" if (MEDIA / "ingredients" / f"{ing_id}.jpg").exists() else None


async def get_or_create_slugged(db, model, tr_model, fk, slug, names):
    obj = (await db.execute(select(model).where(model.slug == slug))).scalar_one_or_none()
    if obj:
        return obj
    obj = model(slug=slug)
    db.add(obj)
    await db.flush()
    for lang, name in zip(("en", "bg"), names):
        db.add(tr_model(**{fk: obj.id, "language_code": lang, "name": name}))
    return obj


async def link_images(db, id_map):
    n = 0
    for sid, rid in id_map.items():
        r = await db.get(Recipe, rid)
        url = recipe_image(sid)
        if r and url and r.image_url != url:
            r.image_url = url
            n += 1
    for ing in (await db.execute(select(Ingredient))).scalars():
        url = ingredient_image(ing.id)
        if url and ing.image_url != url:
            ing.image_url = url
            n += 1
    print(f"✓ linked {n} images")


async def import_one(db, d, admin, ing_cache, cuisine_cache):
    code = (d.get("cuisine_country") or "").upper()[:2]
    cuisine = cuisine_cache.get(code)
    if not cuisine and code in CUISINES:
        cont, en, bg = CUISINES[code]
        cuisine = Cuisine(continent=cont, country_code=code)
        db.add(cuisine)
        await db.flush()
        db.add(CuisineTranslation(cuisine_id=cuisine.id, language_code="en", name=en))
        db.add(CuisineTranslation(cuisine_id=cuisine.id, language_code="bg", name=bg))
        cuisine_cache[code] = cuisine

    sid = str(d["source_recipe_id"])
    prep, cook = int(d.get("prep_minutes") or 0), int(d.get("cook_minutes") or 0)
    total = int(d.get("cooking_minutes") or prep + cook)
    recipe = Recipe(
        cuisine_id=cuisine.id if cuisine else None, prep_time_minutes=prep, cook_time_minutes=cook,
        total_time_minutes=total, servings=2, difficulty=Difficulty(d["difficulty"]),
        status=RecipeStatus.PUBLISHED, image_url=recipe_image(sid), created_by=admin.id if admin else None,
    )
    db.add(recipe)
    await db.flush()
    db.add(RecipeTranslation(recipe_id=recipe.id, language_code="en", title=d["title_en"][:500],
                             description=d.get("description_en")))
    db.add(RecipeTranslation(recipe_id=recipe.id, language_code="bg", title=d["title_bg"][:500],
                             description=d.get("description_bg")))

    for i, st in enumerate(d["steps"], 1):
        step = RecipeStep(recipe_id=recipe.id, order=i)
        db.add(step)
        await db.flush()
        db.add(RecipeStepTranslation(step_id=step.id, language_code="en", instruction=st["en"]))
        db.add(RecipeStepTranslation(step_id=step.id, language_code="bg", instruction=st["bg"]))

    seen = set()
    for ing in d["ingredients"]:
        key = ing["name_en"].strip().lower()
        ing_id = ing_cache.get(key)
        if not ing_id:
            obj = Ingredient(default_unit=DEFAULT_UNITS.get(ing["unit"], MeasurementUnit.GRAM),
                             category=IngredientCategory(ing["category"]))
            db.add(obj)
            await db.flush()
            db.add(IngredientTranslation(ingredient_id=obj.id, language_code="en", name=key))
            db.add(IngredientTranslation(ingredient_id=obj.id, language_code="bg", name=ing["name_bg"].strip().lower()))
            ing_id = ing_cache[key] = obj.id
            obj.image_url = staging_image(obj.id, ing.get("staging"))
        elif ing.get("staging"):
            obj = await db.get(Ingredient, ing_id)
            if obj and not obj.image_url:
                obj.image_url = staging_image(ing_id, ing["staging"])
        if ing_id in seen:
            continue
        seen.add(ing_id)
        db.add(RecipeIngredient(recipe_id=recipe.id, ingredient_id=ing_id, quantity=round(float(ing["quantity"]), 2),
                                unit=ing["unit"], is_optional=bool(ing.get("optional"))))

    cat_slugs = {CATEGORY_MAP.get((d.get("category") or "").lower(), "dinner")}
    cat_slugs |= {t for t in d.get("tags", []) if t in ("vegetarian", "vegan", "quick")}
    for slug in cat_slugs:
        c = await get_or_create_slugged(db, Category, CategoryTranslation, "category_id", slug,
                                        CATEGORY_NAMES.get(slug, (slug.title(), slug)))
        await db.execute(recipe_categories.insert().values(recipe_id=recipe.id, category_id=c.id))
    for slug in set(d.get("tags", [])):
        t = await get_or_create_slugged(db, Tag, TagTranslation, "tag_id", slug, TAG_NAMES[slug])
        await db.execute(recipe_tags.insert().values(recipe_id=recipe.id, tag_id=t.id))
    return recipe


async def main(path, only_link=False):
    engine = create_async_engine(settings.DATABASE_URL)
    Session = async_sessionmaker(engine, expire_on_commit=False)
    id_map = json.loads(MAP_FILE.read_text()) if MAP_FILE.exists() else {}

    async with Session() as db:
        if not only_link:
            admin = (await db.execute(select(User).where(User.is_admin.is_(True)).limit(1))).scalar_one_or_none()
            ing_cache = {}
            q = select(IngredientTranslation).where(IngredientTranslation.language_code == "en")
            for tr in (await db.execute(q)).scalars():
                ing_cache.setdefault(tr.name.strip().lower(), tr.ingredient_id)
            cuisine_cache = {c.country_code: c for c in (await db.execute(select(Cuisine))).scalars()}

            added = failed = 0
            for line in Path(path).open(encoding="utf8"):
                d = json.loads(line)
                sid = str(d["source_recipe_id"])
                if sid in id_map:
                    continue
                try:
                    recipe = await import_one(db, d, admin, ing_cache, cuisine_cache)
                    await db.commit()
                except Exception as e:  # keep going; one bad record must not stop the batch
                    await db.rollback()
                    failed += 1
                    print(f"✗ {sid} {d.get('title_en')}: {e!r}"[:300])
                    # cache may hold ids created in the rolled-back transaction
                    ing_cache = {}
                    for tr in (await db.execute(q)).scalars():
                        ing_cache.setdefault(tr.name.strip().lower(), tr.ingredient_id)
                    cuisine_cache = {c.country_code: c for c in (await db.execute(select(Cuisine))).scalars()}
                    continue
                id_map[sid] = str(recipe.id)
                MAP_FILE.parent.mkdir(parents=True, exist_ok=True)
                MAP_FILE.write_text(json.dumps(id_map))
                added += 1
            total_ing = (await db.execute(select(func.count(Ingredient.id)))).scalar_one()
            print(f"✓ imported {added} new recipes, {failed} failed ({len(id_map)} total imported), "
                  f"{total_ing} ingredients in DB")

        await link_images(db, id_map)
        await db.commit()


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    asyncio.run(main(args[0] if args else str(MEDIA / "_import" / "enriched.jsonl"), "--link-images" in sys.argv))
