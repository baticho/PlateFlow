import uuid
from datetime import date, datetime, timedelta, timezone

import io
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from PIL import Image, ImageOps
from pydantic import BaseModel, EmailStr
from sqlalchemy import delete, func, insert, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased, selectinload

from app.core.deps import get_current_admin
from app.core.security import hash_password
from app.database import get_db
from app.domains.categories.models import Category, CategoryTranslation, recipe_categories
from app.domains.cuisines.models import Cuisine, CuisineTranslation
from app.domains.ingredients.models import Ingredient, IngredientTranslation
from app.domains.recipes.models import (
    Difficulty,
    Recipe,
    RecipeIngredient,
    RecipeStatus,
    RecipeStep,
    RecipeStepTranslation,
    RecipeTranslation,
)
from app.domains.subscriptions.models import SubscriptionPlan
from app.domains.tags.models import Tag, TagTranslation, recipe_tags
from app.domains.users.models import AdminRole, Household, User
from app.domains.weekly_suggestions.models import WeeklySuggestion

router = APIRouter()


# ─── Statistics ───────────────────────────────────────────────────────────────

@router.get("/statistics/dashboard")
async def dashboard_stats(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    total_users = (await db.execute(select(func.count(User.id)))).scalar_one()
    active_users = (await db.execute(
        select(func.count(User.id)).where(User.is_active == True)  # noqa: E712
    )).scalar_one()
    total_recipes = (await db.execute(select(func.count(Recipe.id)))).scalar_one()
    published_recipes = (await db.execute(
        select(func.count(Recipe.id)).where(Recipe.status == RecipeStatus.PUBLISHED)
    )).scalar_one()
    total_ingredients = (await db.execute(select(func.count(Ingredient.id)))).scalar_one()

    return {
        "total_users": total_users,
        "active_users": active_users,
        "total_recipes": total_recipes,
        "published_recipes": published_recipes,
        "total_ingredients": total_ingredients,
    }


# ─── Users ────────────────────────────────────────────────────────────────────

USER_ROLES = ["user"] + [r.value for r in AdminRole]


def user_out(u: User, households: dict | None = None, plans: dict | None = None) -> dict:
    hh = (households or {}).get(u.household_id) if u.household_id else None
    return {
        "household_id": u.household_id,
        "household_name": hh.name if hh else None,
        "is_household_owner": bool(hh and hh.owner_id == u.id),
        "subscription_plan_slug": (plans or {}).get(u.subscription_plan_id),
        "id": u.id, "email": u.email, "full_name": u.full_name, "is_active": u.is_active,
        "is_admin": u.is_admin, "admin_role": u.admin_role.value if u.admin_role else None,
        "role": u.admin_role.value if u.admin_role else ("super_admin" if u.is_admin else "user"),
        "preferred_language": getattr(u.preferred_language, "value", u.preferred_language),
        "subscription_plan_id": u.subscription_plan_id, "trial_ends_at": u.trial_ends_at,
        "created_at": u.created_at, "updated_at": u.updated_at,
    }


@router.get("/users")
async def admin_list_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
    q: str | None = Query(None),
    role: str | None = Query(None),
    active: bool | None = Query(None),
    plan: str | None = Query(None),
    sort: str = Query("created_at"),
    order: str = Query("desc"),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    query = select(User)
    if q:
        query = query.where(
            (User.email.ilike(f"%{q}%")) | (User.full_name.ilike(f"%{q}%"))
        )
    if role == "user":
        query = query.where(User.is_admin.is_(False))
    elif role in USER_ROLES:
        query = query.where(User.admin_role == AdminRole(role))
    if active is not None:
        query = query.where(User.is_active.is_(active))
    if plan == "none":
        query = query.where(User.subscription_plan_id.is_(None))
    elif plan:
        query = query.where(User.subscription_plan_id.in_(select(SubscriptionPlan.id).where(SubscriptionPlan.slug == plan)))
    cols = {"name": User.full_name, "email": User.email, "created_at": User.created_at,
            "role": User.admin_role, "active": User.is_active, "plan": User.subscription_plan_id,
            "family": User.household_id}
    col = cols.get(sort, User.created_at)
    query = query.order_by(col.desc().nulls_last() if order == "desc" else col.asc().nulls_first(), User.id)
    total = (await db.execute(select(func.count()).select_from(query.subquery()))).scalar_one()
    users = (await db.execute(query.offset((page - 1) * page_size).limit(page_size))).scalars().all()
    households = {h.id: h for h in (await db.execute(select(Household))).scalars()}
    plans = {p.id: p.slug for p in (await db.execute(select(SubscriptionPlan))).scalars()}
    return {"items": [user_out(u, households, plans) for u in users], "total": total, "page": page,
            "pages": (total + page_size - 1) // page_size}


@router.get("/users/{user_id}")
async def admin_get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user_out(user)


class AdminCreateUser(BaseModel):
    email: EmailStr
    password: str
    full_name: str


@router.post("/users", status_code=status.HTTP_201_CREATED)
async def admin_create_user(
    data: AdminCreateUser,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    existing = (await db.execute(select(User).where(User.email == data.email))).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    user = User(
        email=data.email,
        password_hash=hash_password(data.password),
        full_name=data.full_name,
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user_out(user)


class AdminUpdateUser(BaseModel):
    is_active: bool | None = None
    admin_role: str | None = None
    password: str | None = None
    subscription_plan_id: int | None = None   # send 0 to clear (= free)


@router.patch("/users/{user_id}")
async def admin_update_user(
    user_id: uuid.UUID,
    data: AdminUpdateUser,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == _admin.id and (data.admin_role is not None or data.is_active is False):
        raise HTTPException(status_code=400, detail="You cannot change your own role or deactivate yourself")
    if data.is_active is not None:
        user.is_active = data.is_active
    if data.admin_role is not None:
        if data.admin_role not in USER_ROLES:
            raise HTTPException(status_code=400, detail=f"Role must be one of {USER_ROLES}")
        user.admin_role = None if data.admin_role == "user" else AdminRole(data.admin_role)
        user.is_admin = data.admin_role != "user"
    if data.password is not None:
        user.password_hash = hash_password(data.password)
    if data.subscription_plan_id is not None:
        if data.subscription_plan_id == 0:
            user.subscription_plan_id = None
        else:
            if not await db.get(SubscriptionPlan, data.subscription_plan_id):
                raise HTTPException(status_code=400, detail="Unknown subscription plan")
            user.subscription_plan_id = data.subscription_plan_id
    await db.flush()
    await db.refresh(user)
    return user_out(user)


# ─── Families (households) ─────────────────────────────────────────────────

class HouseholdCreate(BaseModel):
    name: str
    owner_id: uuid.UUID


class HouseholdMember(BaseModel):
    user_id: uuid.UUID


async def _household_out(db: AsyncSession, h: Household) -> dict:
    members = (await db.execute(select(User).where(User.household_id == h.id).order_by(User.full_name))).scalars().all()
    return {"id": h.id, "name": h.name, "owner_id": h.owner_id,
            "members": [{"id": m.id, "full_name": m.full_name, "email": m.email, "is_owner": m.id == h.owner_id}
                        for m in members]}


@router.get("/households")
async def admin_list_households(db: AsyncSession = Depends(get_db), _admin: User = Depends(get_current_admin)):
    hs = (await db.execute(select(Household).order_by(Household.name))).scalars().all()
    return [await _household_out(db, h) for h in hs]


@router.post("/households", status_code=status.HTTP_201_CREATED)
async def admin_create_household(data: HouseholdCreate, db: AsyncSession = Depends(get_db),
                                 _admin: User = Depends(get_current_admin)):
    owner = await db.get(User, data.owner_id)
    if not owner:
        raise HTTPException(status_code=404, detail="User not found")
    if owner.household_id:
        raise HTTPException(status_code=400, detail="User is already in a family")
    import secrets
    h = Household(name=data.name.strip() or f"{owner.full_name} family", owner_id=owner.id,
                  invite_code="".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(8)))
    db.add(h)
    await db.flush()
    owner.household_id = h.id
    await db.flush()
    return await _household_out(db, h)


@router.post("/households/{household_id}/members")
async def admin_add_household_member(household_id: int, data: HouseholdMember, db: AsyncSession = Depends(get_db),
                                     _admin: User = Depends(get_current_admin)):
    h = await db.get(Household, household_id)
    user = await db.get(User, data.user_id)
    if not h or not user:
        raise HTTPException(status_code=404, detail="Family or user not found")
    owns_other = (await db.execute(select(Household).where(Household.owner_id == user.id, Household.id != h.id))).scalar_one_or_none()
    if owns_other:
        raise HTTPException(status_code=400, detail=f"User owns the family '{owns_other.name}'; remove it first")
    user.household_id = h.id
    await db.flush()
    return await _household_out(db, h)


@router.delete("/households/{household_id}/members/{user_id}")
async def admin_remove_household_member(household_id: int, user_id: uuid.UUID, db: AsyncSession = Depends(get_db),
                                        _admin: User = Depends(get_current_admin)):
    h = await db.get(Household, household_id)
    if not h:
        raise HTTPException(status_code=404, detail="Family not found")
    if h.owner_id == user_id:   # removing the owner dissolves the family
        for m in (await db.execute(select(User).where(User.household_id == h.id))).scalars():
            m.household_id = None
        await db.flush()
        await db.delete(h)
        await db.flush()
        return {"dissolved": True}
    user = await db.get(User, user_id)
    if user and user.household_id == h.id:
        user.household_id = None
        await db.flush()
    return await _household_out(db, h)


# ─── Recipes ──────────────────────────────────────────────────────────────────

@router.get("/recipes")
async def admin_list_recipes(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=200),
    q: str | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    difficulty: str | None = Query(None),
    has_image: bool | None = Query(None),
    lang: str = Query("en"),
    sort: str = Query("created_at"),
    order: str = Query("desc"),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    tr = aliased(RecipeTranslation)
    query = (select(Recipe).options(selectinload(Recipe.translations))
             .outerjoin(tr, (tr.recipe_id == Recipe.id) & (tr.language_code == lang)))
    if q:
        query = query.where(Recipe.id.in_(
            select(RecipeTranslation.recipe_id).where(RecipeTranslation.title.ilike(f"%{q}%"))))
    if status_filter:
        query = query.where(Recipe.status == RecipeStatus(status_filter))
    if difficulty:
        query = query.where(Recipe.difficulty == Difficulty(difficulty))
    if has_image is not None:
        query = query.where(Recipe.image_url.is_not(None) if has_image else Recipe.image_url.is_(None))
    cols = {"title": func.lower(tr.title), "status": Recipe.status, "difficulty": Recipe.difficulty,
            "time": Recipe.total_time_minutes, "servings": Recipe.servings, "created_at": Recipe.created_at,
            "image": Recipe.image_url.is_not(None)}
    col = cols.get(sort, Recipe.created_at)
    query = query.order_by(col.desc().nulls_last() if order == "desc" else col.asc().nulls_last(), Recipe.id)
    total = (await db.execute(select(func.count()).select_from(query.subquery()))).scalar_one()
    recipes = (await db.execute(query.offset((page - 1) * page_size).limit(page_size))).scalars().all()
    return {"items": recipes, "total": total, "page": page, "pages": (total + page_size - 1) // page_size}


class AdminUpdateRecipe(BaseModel):
    status: str | None = None
    cuisine_id: int | None = None
    prep_time_minutes: int | None = None
    cook_time_minutes: int | None = None
    servings: int | None = None
    difficulty: str | None = None
    image_url: str | None = None


@router.patch("/recipes/{recipe_id}")
async def admin_update_recipe(
    recipe_id: uuid.UUID,
    data: AdminUpdateRecipe,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(Recipe).where(Recipe.id == recipe_id))
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(recipe, field, value)
    if data.prep_time_minutes is not None or data.cook_time_minutes is not None:
        recipe.total_time_minutes = recipe.prep_time_minutes + recipe.cook_time_minutes
    await db.flush()
    return recipe


@router.delete("/recipes/{recipe_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_recipe(
    recipe_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(Recipe).where(Recipe.id == recipe_id))
    recipe = result.scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    await db.delete(recipe)


# ─── Recipe editor (full read / write in the admin form's shape) ─────────────

class RecipeForm(BaseModel):
    translations: dict[str, dict] = {}          # {"en": {"title", "description"}, "bg": {...}}
    steps: dict[str, list[str | None]] = {}      # {"en": ["step 1", ...], "bg": [...]}
    ingredients: list[dict] = []                 # [{"ingredient_id", "quantity", "unit", "is_optional"}]
    category_ids: list[int] = []
    tag_ids: list[int] = []
    cuisine_id: int | None = None
    prep_time_minutes: int = 0
    cook_time_minutes: int = 0
    servings: int = 2
    difficulty: str = "easy"
    status: str = "draft"
    image_url: str | None = None


async def _recipe_full(db: AsyncSession, recipe_id: uuid.UUID) -> Recipe:
    recipe = (await db.execute(
        select(Recipe).where(Recipe.id == recipe_id).options(
            selectinload(Recipe.translations),
            selectinload(Recipe.steps).selectinload(RecipeStep.translations),
            selectinload(Recipe.ingredients).selectinload(RecipeIngredient.ingredient)
            .selectinload(Ingredient.translations),
            selectinload(Recipe.categories), selectinload(Recipe.tags),
        )
    )).scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe


@router.get("/recipes/{recipe_id}/full")
async def admin_get_recipe_full(
    recipe_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    r = await _recipe_full(db, recipe_id)
    steps: dict[str, list[str]] = {}
    for st in sorted(r.steps, key=lambda x: x.order):
        for t in st.translations:
            steps.setdefault(t.language_code, []).append(t.instruction)
    return {
        "id": r.id,
        "translations": {t.language_code: {"title": t.title, "description": t.description} for t in r.translations},
        "steps": steps,
        "ingredients": [
            {"ingredient_id": i.ingredient_id, "quantity": float(i.quantity), "unit": i.unit,
             "is_optional": i.is_optional,
             "ingredient_translations": [{"language_code": t.language_code, "name": t.name}
                                         for t in i.ingredient.translations]}
            for i in r.ingredients
        ],
        "category_ids": [c.id for c in r.categories],
        "tag_ids": [t.id for t in r.tags],
        "cuisine_id": r.cuisine_id,
        "prep_time_minutes": r.prep_time_minutes, "cook_time_minutes": r.cook_time_minutes,
        "servings": r.servings, "difficulty": r.difficulty.value, "status": r.status.value,
        "image_url": r.image_url,
    }


async def _save_recipe_form(db: AsyncSession, recipe: Recipe, data: RecipeForm) -> None:
    recipe.cuisine_id = data.cuisine_id
    recipe.prep_time_minutes = data.prep_time_minutes or 0
    recipe.cook_time_minutes = data.cook_time_minutes or 0
    recipe.total_time_minutes = recipe.prep_time_minutes + recipe.cook_time_minutes
    recipe.servings = data.servings or 2
    recipe.difficulty = Difficulty(data.difficulty)
    recipe.status = RecipeStatus(data.status)
    recipe.image_url = data.image_url
    await db.flush()
    rid = recipe.id

    await db.execute(delete(RecipeTranslation).where(RecipeTranslation.recipe_id == rid))
    for lang, tr in data.translations.items():
        if tr and (tr.get("title") or "").strip():
            db.add(RecipeTranslation(recipe_id=rid, language_code=lang, title=tr["title"].strip()[:500],
                                     description=(tr.get("description") or None)))

    step_ids = select(RecipeStep.id).where(RecipeStep.recipe_id == rid)
    await db.execute(delete(RecipeStepTranslation).where(RecipeStepTranslation.step_id.in_(step_ids)))
    await db.execute(delete(RecipeStep).where(RecipeStep.recipe_id == rid))
    n_steps = max([len([x for x in v if x and x.strip()]) for v in data.steps.values()] or [0])
    cleaned = {lang: [x.strip() for x in v if x and x.strip()] for lang, v in data.steps.items()}
    for i in range(n_steps):
        step = RecipeStep(recipe_id=rid, order=i + 1)
        db.add(step)
        await db.flush()
        for lang, items in cleaned.items():
            if i < len(items):
                db.add(RecipeStepTranslation(step_id=step.id, language_code=lang, instruction=items[i]))

    await db.execute(delete(RecipeIngredient).where(RecipeIngredient.recipe_id == rid))
    seen = set()
    for ing in data.ingredients:
        iid = ing.get("ingredient_id")
        if not iid or iid in seen:
            continue
        seen.add(iid)
        db.add(RecipeIngredient(recipe_id=rid, ingredient_id=iid, quantity=float(ing.get("quantity") or 0),
                                unit=(ing.get("unit") or "g"), is_optional=bool(ing.get("is_optional"))))

    await db.execute(delete(recipe_categories).where(recipe_categories.c.recipe_id == rid))
    for cid in dict.fromkeys(data.category_ids):
        await db.execute(insert(recipe_categories).values(recipe_id=rid, category_id=cid))
    await db.execute(delete(recipe_tags).where(recipe_tags.c.recipe_id == rid))
    for tid in dict.fromkeys(data.tag_ids):
        await db.execute(insert(recipe_tags).values(recipe_id=rid, tag_id=tid))
    await db.flush()


@router.put("/recipes/{recipe_id}")
async def admin_save_recipe(
    recipe_id: uuid.UUID,
    data: RecipeForm,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    recipe = (await db.execute(select(Recipe).where(Recipe.id == recipe_id))).scalar_one_or_none()
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if not (data.translations.get("en") or {}).get("title"):
        raise HTTPException(status_code=400, detail="English title is required")
    await _save_recipe_form(db, recipe, data)
    return {"id": recipe.id}


@router.post("/recipes", status_code=status.HTTP_201_CREATED)
async def admin_create_recipe(
    data: RecipeForm,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    if not (data.translations.get("en") or {}).get("title"):
        raise HTTPException(status_code=400, detail="English title is required")
    recipe = Recipe(created_by=_admin.id, difficulty=Difficulty.EASY, status=RecipeStatus.DRAFT)
    db.add(recipe)
    await db.flush()
    await _save_recipe_form(db, recipe, data)
    return {"id": recipe.id}


@router.get("/tags")
async def admin_list_tags(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    tags = (await db.execute(select(Tag).options(selectinload(Tag.translations)).order_by(Tag.slug))).scalars().all()
    return [{"id": t.id, "slug": t.slug,
             "translations": [{"language_code": x.language_code, "name": x.name} for x in t.translations]}
            for t in tags]


# ─── Categories ───────────────────────────────────────────────────────────────

class CategoryCreate(BaseModel):
    slug: str
    icon_url: str | None = None
    translations: list[dict]


@router.post("/categories", status_code=status.HTTP_201_CREATED)
async def admin_create_category(
    data: CategoryCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    cat = Category(slug=data.slug, icon_url=data.icon_url)
    db.add(cat)
    await db.flush()
    for t in data.translations:
        db.add(CategoryTranslation(category_id=cat.id, language_code=t["language_code"], name=t["name"]))
    await db.flush()
    return cat


@router.delete("/categories/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_category(
    category_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(Category).where(Category.id == category_id))
    cat = result.scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await db.delete(cat)


# ─── Cuisines ─────────────────────────────────────────────────────────────────

class CuisineCreate(BaseModel):
    continent: str
    country_code: str
    translations: list[dict]


@router.post("/cuisines", status_code=status.HTTP_201_CREATED)
async def admin_create_cuisine(
    data: CuisineCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    cuisine = Cuisine(continent=data.continent, country_code=data.country_code)
    db.add(cuisine)
    await db.flush()
    for t in data.translations:
        db.add(CuisineTranslation(cuisine_id=cuisine.id, language_code=t["language_code"], name=t["name"]))
    await db.flush()
    return cuisine


# ─── Uploads ──────────────────────────────────────────────────────────────────

MEDIA_DIR = Path(__file__).resolve().parent.parent.parent / "media"
UPLOAD_KINDS = {"recipes", "ingredients", "steps", "categories"}
MAX_UPLOAD_BYTES = 15 * 1024 * 1024


@router.post("/upload")
async def admin_upload_image(
    kind: str = Query("recipes"),
    file: UploadFile = File(...),
    _admin: User = Depends(get_current_admin),
):
    """Store an uploaded image under /media/uploads/<kind>/ as JPEG and return its URL."""
    if kind not in UPLOAD_KINDS:
        raise HTTPException(status_code=400, detail=f"kind must be one of {sorted(UPLOAD_KINDS)}")
    raw = await file.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image too large (max 15 MB)")
    try:
        img = Image.open(io.BytesIO(raw))
        img = ImageOps.exif_transpose(img).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="File is not a valid image")
    img.thumbnail((1600, 1600))
    out_dir = MEDIA_DIR / "uploads" / kind
    out_dir.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}.jpg"
    img.save(out_dir / name, "JPEG", quality=88, optimize=True)
    return {"url": f"/media/uploads/{kind}/{name}"}


# ─── Ingredients ──────────────────────────────────────────────────────────────

class IngredientCreate(BaseModel):
    default_unit: str = "g"
    category: str = "other"
    calories_per_100g: float | None = None
    protein_per_100g: float | None = None
    carbs_per_100g: float | None = None
    fat_per_100g: float | None = None
    image_url: str | None = None
    translations: list[dict]


@router.post("/ingredients", status_code=status.HTTP_201_CREATED)
async def admin_create_ingredient(
    data: IngredientCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    ing = Ingredient(
        default_unit=data.default_unit,
        category=data.category,
        calories_per_100g=data.calories_per_100g,
        protein_per_100g=data.protein_per_100g,
        carbs_per_100g=data.carbs_per_100g,
        fat_per_100g=data.fat_per_100g,
        image_url=data.image_url,
    )
    db.add(ing)
    await db.flush()
    for t in data.translations:
        db.add(IngredientTranslation(ingredient_id=ing.id, language_code=t["language_code"], name=t["name"]))
    await db.flush()
    return ing


class IngredientUpdate(BaseModel):
    default_unit: str | None = None
    category: str | None = None
    image_url: str | None = None
    translations: list[dict] | None = None


@router.patch("/ingredients/{ingredient_id}")
async def admin_update_ingredient(
    ingredient_id: int,
    data: IngredientUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(
        select(Ingredient).where(Ingredient.id == ingredient_id).options(selectinload(Ingredient.translations))
    )
    ing = result.scalar_one_or_none()
    if not ing:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    for field in ("default_unit", "category", "image_url"):
        value = getattr(data, field)
        if value is not None:
            setattr(ing, field, value or None)
    if data.translations is not None:
        existing = {t.language_code: t for t in ing.translations}
        for t in data.translations:
            if t["language_code"] in existing:
                existing[t["language_code"]].name = t["name"]
            else:
                db.add(IngredientTranslation(ingredient_id=ing.id, language_code=t["language_code"], name=t["name"]))
    await db.flush()
    return {"id": ing.id, "image_url": ing.image_url}


@router.delete("/ingredients/{ingredient_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_ingredient(
    ingredient_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(Ingredient).where(Ingredient.id == ingredient_id))
    ing = result.scalar_one_or_none()
    if not ing:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    await db.delete(ing)


# ─── Tags ─────────────────────────────────────────────────────────────────────

class TagCreate(BaseModel):
    slug: str
    translations: list[dict]


@router.post("/tags", status_code=status.HTTP_201_CREATED)
async def admin_create_tag(
    data: TagCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    tag = Tag(slug=data.slug)
    db.add(tag)
    await db.flush()
    for t in data.translations:
        db.add(TagTranslation(tag_id=tag.id, language_code=t["language_code"], name=t["name"]))
    await db.flush()
    return tag


# ─── Subscription Plans ───────────────────────────────────────────────────────

class SubscriptionPlanCreate(BaseModel):
    slug: str
    name: str
    price_monthly: float = 0
    price_yearly: float | None = None
    max_recipes_per_week: int = 5
    max_meal_plans: int = 1
    can_export_shopping_list: bool = False
    can_use_delivery: bool = False


@router.get("/subscription-plans")
async def admin_list_plans(
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(SubscriptionPlan))
    return result.scalars().all()


@router.post("/subscription-plans", status_code=status.HTTP_201_CREATED)
async def admin_create_plan(
    data: SubscriptionPlanCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    plan = SubscriptionPlan(**data.model_dump())
    db.add(plan)
    await db.flush()
    return plan


@router.patch("/subscription-plans/{plan_id}")
async def admin_update_plan(
    plan_id: int,
    data: SubscriptionPlanCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = result.scalar_one_or_none()
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(plan, field, value)
    await db.flush()
    return plan


# ─── Weekly Suggestions ───────────────────────────────────────────────────────

class WeeklySuggestionCreate(BaseModel):
    week_start_date: date
    recipe_id: uuid.UUID
    position: int = 0


@router.post("/weekly-suggestions", status_code=status.HTTP_201_CREATED)
async def admin_create_suggestion(
    data: WeeklySuggestionCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    existing = await db.execute(
        select(WeeklySuggestion).where(
            WeeklySuggestion.week_start_date == data.week_start_date,
            WeeklySuggestion.position == data.position,
        )
    )
    if existing.scalars().first():
        raise HTTPException(status_code=409, detail="Position already taken for this week")
    suggestion = WeeklySuggestion(
        week_start_date=data.week_start_date,
        recipe_id=data.recipe_id,
        position=data.position,
    )
    db.add(suggestion)
    await db.flush()
    return suggestion


@router.delete("/weekly-suggestions/{suggestion_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_suggestion(
    suggestion_id: int,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(WeeklySuggestion).where(WeeklySuggestion.id == suggestion_id))
    s = result.scalar_one_or_none()
    if not s:
        raise HTTPException(status_code=404, detail="Suggestion not found")
    await db.delete(s)


class WeeklySuggestionUpdate(BaseModel):
    position: int


@router.patch("/weekly-suggestions/{suggestion_id}")
async def admin_update_suggestion(
    suggestion_id: int,
    data: WeeklySuggestionUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(WeeklySuggestion).where(WeeklySuggestion.id == suggestion_id))
    s = result.scalar_one_or_none()
    if not s:
        raise HTTPException(status_code=404, detail="Suggestion not found")
    s.position = data.position
    await db.flush()
    return s


# ─── Admin User Management ────────────────────────────────────────────────────

class CreateAdminUser(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    admin_role: str = "content_manager"


@router.post("/admins", status_code=status.HTTP_201_CREATED)
async def create_admin_user(
    data: CreateAdminUser,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    if current_admin.admin_role != AdminRole.SUPER_ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Super admin required")
    existing = (await db.execute(select(User).where(User.email == data.email))).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    admin = User(
        email=data.email,
        password_hash=hash_password(data.password),
        full_name=data.full_name,
        is_admin=True,
        admin_role=data.admin_role,
    )
    db.add(admin)
    await db.flush()
    return admin
