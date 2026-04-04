import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import get_current_admin
from app.core.security import hash_password
from app.database import get_db
from app.domains.categories.models import Category, CategoryTranslation
from app.domains.cuisines.models import Cuisine, CuisineTranslation
from app.domains.ingredients.models import Ingredient, IngredientTranslation
from app.domains.recipes.models import (
    Recipe,
    RecipeIngredient,
    RecipeStatus,
    RecipeStep,
    RecipeStepTranslation,
    RecipeTranslation,
)
from app.domains.subscriptions.models import SubscriptionPlan
from app.domains.tags.models import Tag, TagTranslation
from app.domains.users.models import AdminRole, User
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

@router.get("/users")
async def admin_list_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    q: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    query = select(User)
    if q:
        query = query.where(
            (User.email.ilike(f"%{q}%")) | (User.full_name.ilike(f"%{q}%"))
        )
    total = (await db.execute(select(func.count()).select_from(query.subquery()))).scalar_one()
    users = (await db.execute(query.offset((page - 1) * page_size).limit(page_size))).scalars().all()
    return {"items": users, "total": total, "page": page, "pages": (total + page_size - 1) // page_size}


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
    return user


class AdminUpdateUser(BaseModel):
    is_active: bool | None = None
    admin_role: str | None = None


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
    if data.is_active is not None:
        user.is_active = data.is_active
    if data.admin_role is not None:
        user.admin_role = data.admin_role
        user.is_admin = data.admin_role is not None
    await db.flush()
    return user


# ─── Recipes ──────────────────────────────────────────────────────────────────

@router.get("/recipes")
async def admin_list_recipes(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    q: str | None = Query(None),
    status_filter: str | None = Query(None, alias="status"),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    query = select(Recipe).options(selectinload(Recipe.translations))
    if q:
        query = query.join(RecipeTranslation).where(RecipeTranslation.title.ilike(f"%{q}%"))
    if status_filter:
        query = query.where(Recipe.status == status_filter)
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


# ─── Ingredients ──────────────────────────────────────────────────────────────

class IngredientCreate(BaseModel):
    default_unit: str = "g"
    category: str = "other"
    calories_per_100g: float | None = None
    protein_per_100g: float | None = None
    carbs_per_100g: float | None = None
    fat_per_100g: float | None = None
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
    )
    db.add(ing)
    await db.flush()
    for t in data.translations:
        db.add(IngredientTranslation(ingredient_id=ing.id, language_code=t["language_code"], name=t["name"]))
    await db.flush()
    return ing


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
