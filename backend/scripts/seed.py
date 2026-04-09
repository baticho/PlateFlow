"""Seed script: run with  python -m scripts.seed  from backend/ directory.

Flags:
  --force   Truncate all seed tables first, then re-seed.
"""
import asyncio
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import insert, select, text
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.config import settings
from app.core.security import hash_password
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
from app.domains.categories.models import recipe_categories
from app.domains.subscriptions.models import SubscriptionPlan
from app.domains.tags.models import Tag, TagTranslation, recipe_tags
from app.domains.users.models import AdminRole, User
from app.domains.weekly_suggestions.models import WeeklySuggestion
from app.models import *  # noqa: F401, F403 — ensure all models registered


async def seed(force: bool = False):
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    Session = async_sessionmaker(engine, expire_on_commit=False)

    async with Session() as db:
        # ── Guard: skip if already seeded (unless --force) ───────────────────
        existing = await db.scalar(select(SubscriptionPlan).limit(1))
        if existing:
            if not force:
                print("⚠️  Database already seeded. Run with --force to truncate and re-seed.")
                return
            print("⚡ --force: truncating seed tables…")
            await db.execute(text(
                "TRUNCATE weekly_suggestions, recipe_tags, recipe_categories, "
                "recipe_ingredients, recipe_step_translations, recipe_steps, "
                "recipe_translations, recipes, ingredient_translations, ingredients, "
                "tag_translations, tags, cuisine_translations, cuisines, "
                "category_translations, categories, users, subscription_plans "
                "RESTART IDENTITY CASCADE"
            ))
            await db.commit()
            print("✓ Tables cleared")

        # ── Subscription Plans ───────────────────────────────────────────────
        plans_data = [
            {"slug": "free", "name": "Free", "price_monthly": 0, "max_recipes_per_week": 5, "max_meal_plans": 1, "can_export_shopping_list": False, "can_use_delivery": False},
            {"slug": "trial", "name": "Trial (14 days)", "price_monthly": 0, "max_recipes_per_week": 999, "max_meal_plans": 7, "can_export_shopping_list": True, "can_use_delivery": True},
            {"slug": "premium_monthly", "name": "Premium Monthly", "price_monthly": 4.99, "max_recipes_per_week": 999, "max_meal_plans": 7, "can_export_shopping_list": True, "can_use_delivery": True},
            {"slug": "premium_yearly", "name": "Premium Yearly", "price_monthly": 3.33, "price_yearly": 39.99, "max_recipes_per_week": 999, "max_meal_plans": 7, "can_export_shopping_list": True, "can_use_delivery": True},
        ]
        plan_objects = {}
        for p in plans_data:
            plan = SubscriptionPlan(**p)
            db.add(plan)
            plan_objects[p["slug"]] = plan
        await db.flush()
        print(f"✓ {len(plans_data)} subscription plans")

        # ── Admin User ───────────────────────────────────────────────────────
        admin = User(
            email=settings.FIRST_ADMIN_EMAIL,
            password_hash=hash_password(settings.FIRST_ADMIN_PASSWORD),
            full_name="Super Admin",
            is_admin=True,
            admin_role=AdminRole.SUPER_ADMIN,
            subscription_plan_id=plan_objects["premium_monthly"].id,
        )
        db.add(admin)
        await db.flush()
        print(f"✓ Admin user: {settings.FIRST_ADMIN_EMAIL}")

        # ── Categories ───────────────────────────────────────────────────────
        categories_data = [
            {"slug": "breakfast", "en": "Breakfast", "bg": "Закуска"},
            {"slug": "lunch", "en": "Lunch", "bg": "Обяд"},
            {"slug": "dinner", "en": "Dinner", "bg": "Вечеря"},
            {"slug": "snack", "en": "Snack", "bg": "Закуска / Снакс"},
            {"slug": "salad", "en": "Salad", "bg": "Салата"},
            {"slug": "soup", "en": "Soup", "bg": "Супа"},
            {"slug": "dessert", "en": "Dessert", "bg": "Десерт"},
            {"slug": "pasta", "en": "Pasta", "bg": "Паста"},
            {"slug": "grill", "en": "Grill", "bg": "Скара"},
            {"slug": "vegetarian", "en": "Vegetarian", "bg": "Вегетарианско"},
            {"slug": "vegan", "en": "Vegan", "bg": "Веганско"},
            {"slug": "quick", "en": "Quick (under 30 min)", "bg": "Бързо (до 30 мин)"},
        ]
        cat_objects = {}
        for c in categories_data:
            cat = Category(slug=c["slug"])
            db.add(cat)
            await db.flush()
            db.add(CategoryTranslation(category_id=cat.id, language_code="en", name=c["en"]))
            db.add(CategoryTranslation(category_id=cat.id, language_code="bg", name=c["bg"]))
            cat_objects[c["slug"]] = cat
        await db.flush()
        print(f"✓ {len(categories_data)} categories")

        # ── Cuisines ─────────────────────────────────────────────────────────
        cuisines_data = [
            {"continent": "europe", "country_code": "BG", "en": "Bulgarian", "bg": "Българска"},
            {"continent": "europe", "country_code": "IT", "en": "Italian", "bg": "Италианска"},
            {"continent": "europe", "country_code": "FR", "en": "French", "bg": "Френска"},
            {"continent": "europe", "country_code": "GR", "en": "Greek", "bg": "Гръцка"},
            {"continent": "asia", "country_code": "JP", "en": "Japanese", "bg": "Японска"},
            {"continent": "asia", "country_code": "CN", "en": "Chinese", "bg": "Китайска"},
            {"continent": "asia", "country_code": "IN", "en": "Indian", "bg": "Индийска"},
            {"continent": "asia", "country_code": "TH", "en": "Thai", "bg": "Тайска"},
            {"continent": "north_america", "country_code": "US", "en": "American", "bg": "Американска"},
            {"continent": "north_america", "country_code": "MX", "en": "Mexican", "bg": "Мексиканска"},
            {"continent": "south_america", "country_code": "BR", "en": "Brazilian", "bg": "Бразилска"},
            {"continent": "africa", "country_code": "MA", "en": "Moroccan", "bg": "Мароканска"},
            {"continent": "europe", "country_code": "ES", "en": "Spanish", "bg": "Испанска"},
            {"continent": "europe", "country_code": "TR", "en": "Turkish", "bg": "Турска"},
        ]
        cuisine_objects = {}
        for c in cuisines_data:
            cuisine = Cuisine(continent=c["continent"], country_code=c["country_code"])
            db.add(cuisine)
            await db.flush()
            db.add(CuisineTranslation(cuisine_id=cuisine.id, language_code="en", name=c["en"]))
            db.add(CuisineTranslation(cuisine_id=cuisine.id, language_code="bg", name=c["bg"]))
            cuisine_objects[c["country_code"]] = cuisine
        await db.flush()
        print(f"✓ {len(cuisines_data)} cuisines")

        # ── Tags ─────────────────────────────────────────────────────────────
        tags_data = [
            {"slug": "quick", "en": "Quick", "bg": "Бързо"},
            {"slug": "healthy", "en": "Healthy", "bg": "Здравословно"},
            {"slug": "budget", "en": "Budget-friendly", "bg": "Бюджетно"},
            {"slug": "gluten-free", "en": "Gluten-Free", "bg": "Без глутен"},
            {"slug": "dairy-free", "en": "Dairy-Free", "bg": "Без лактоза"},
            {"slug": "high-protein", "en": "High Protein", "bg": "Богато на протеин"},
            {"slug": "meal-prep", "en": "Meal Prep", "bg": "Meal Prep"},
            {"slug": "family", "en": "Family Friendly", "bg": "За семейство"},
        ]
        tag_objects = {}
        for t in tags_data:
            tag = Tag(slug=t["slug"])
            db.add(tag)
            await db.flush()
            db.add(TagTranslation(tag_id=tag.id, language_code="en", name=t["en"]))
            db.add(TagTranslation(tag_id=tag.id, language_code="bg", name=t["bg"]))
            tag_objects[t["slug"]] = tag
        await db.flush()
        print(f"✓ {len(tags_data)} tags")

        # ── Ingredients ──────────────────────────────────────────────────────
        ingredients_data = [
            {"default_unit": "g", "category": "produce", "en": "Tomato", "bg": "Домат", "cal": 18, "prot": 0.9, "carbs": 3.9, "fat": 0.2},
            {"default_unit": "g", "category": "produce", "en": "Potato", "bg": "Картоф", "cal": 77, "prot": 2.0, "carbs": 17, "fat": 0.1},
            {"default_unit": "g", "category": "produce", "en": "Onion", "bg": "Лук", "cal": 40, "prot": 1.1, "carbs": 9.3, "fat": 0.1},
            {"default_unit": "g", "category": "produce", "en": "Garlic", "bg": "Чесън", "cal": 149, "prot": 6.4, "carbs": 33, "fat": 0.5},
            {"default_unit": "g", "category": "produce", "en": "Carrot", "bg": "Морков", "cal": 41, "prot": 0.9, "carbs": 10, "fat": 0.2},
            {"default_unit": "g", "category": "produce", "en": "Bell Pepper", "bg": "Чушка", "cal": 31, "prot": 1.0, "carbs": 6.0, "fat": 0.3},
            {"default_unit": "g", "category": "produce", "en": "Cucumber", "bg": "Краставица", "cal": 15, "prot": 0.7, "carbs": 3.6, "fat": 0.1},
            {"default_unit": "g", "category": "produce", "en": "Zucchini", "bg": "Тиквичка", "cal": 17, "prot": 1.2, "carbs": 3.1, "fat": 0.3},
            {"default_unit": "g", "category": "meat", "en": "Chicken Breast", "bg": "Пилешки гърди", "cal": 165, "prot": 31, "carbs": 0, "fat": 3.6},
            {"default_unit": "g", "category": "meat", "en": "Ground Beef", "bg": "Кайма", "cal": 250, "prot": 26, "carbs": 0, "fat": 15},
            {"default_unit": "g", "category": "meat", "en": "Pork Loin", "bg": "Свинско контра филе", "cal": 242, "prot": 27, "carbs": 0, "fat": 14},
            {"default_unit": "g", "category": "dairy", "en": "Eggs", "bg": "Яйца", "cal": 155, "prot": 13, "carbs": 1.1, "fat": 11},
            {"default_unit": "g", "category": "dairy", "en": "Butter", "bg": "Масло", "cal": 717, "prot": 0.9, "carbs": 0.1, "fat": 81},
            {"default_unit": "ml", "category": "dairy", "en": "Milk", "bg": "Мляко", "cal": 61, "prot": 3.2, "carbs": 4.8, "fat": 3.3},
            {"default_unit": "g", "category": "dairy", "en": "Feta Cheese", "bg": "Сирене", "cal": 264, "prot": 14, "carbs": 4.1, "fat": 21},
            {"default_unit": "g", "category": "grains", "en": "Rice", "bg": "Ориз", "cal": 130, "prot": 2.7, "carbs": 28, "fat": 0.3},
            {"default_unit": "g", "category": "grains", "en": "Pasta", "bg": "Паста", "cal": 131, "prot": 5.0, "carbs": 25, "fat": 1.1},
            {"default_unit": "g", "category": "grains", "en": "Flour", "bg": "Брашно", "cal": 364, "prot": 10, "carbs": 76, "fat": 1.0},
            {"default_unit": "ml", "category": "oils", "en": "Olive Oil", "bg": "Зехтин", "cal": 884, "prot": 0, "carbs": 0, "fat": 100},
            {"default_unit": "g", "category": "spices", "en": "Salt", "bg": "Сол", "cal": 0, "prot": 0, "carbs": 0, "fat": 0},
            {"default_unit": "g", "category": "spices", "en": "Black Pepper", "bg": "Черен пипер", "cal": 255, "prot": 10, "carbs": 64, "fat": 3.3},
            {"default_unit": "g", "category": "spices", "en": "Paprika", "bg": "Червен пипер / Паприка", "cal": 282, "prot": 14, "carbs": 54, "fat": 13},
            {"default_unit": "g", "category": "produce", "en": "Spinach", "bg": "Спанак", "cal": 23, "prot": 2.9, "carbs": 3.6, "fat": 0.4},
            {"default_unit": "g", "category": "produce", "en": "Mushrooms", "bg": "Гъби", "cal": 22, "prot": 3.1, "carbs": 3.3, "fat": 0.3},
            {"default_unit": "g", "category": "canned", "en": "Canned Tomatoes", "bg": "Консервирани домати", "cal": 32, "prot": 1.6, "carbs": 6.5, "fat": 0.4},
            # ── New Ingredients (from PDF recipes) ──────────────────────────────
            {"default_unit": "g", "category": "produce", "en": "Avocado", "bg": "Авокадо", "cal": 160, "prot": 2.0, "carbs": 9.0, "fat": 15},
            {"default_unit": "g", "category": "produce", "en": "Cilantro", "bg": "Кориандър", "cal": 23, "prot": 2.1, "carbs": 3.7, "fat": 0.5},
            {"default_unit": "g", "category": "produce", "en": "Jalapeño", "bg": "Халапеньо", "cal": 29, "prot": 0.9, "carbs": 6.5, "fat": 0.4},
            {"default_unit": "g", "category": "grains", "en": "Flour Tortilla", "bg": "Пшенична тортиля", "cal": 312, "prot": 8.0, "carbs": 52, "fat": 7.0},
            {"default_unit": "g", "category": "dairy", "en": "Mozzarella Cheese", "bg": "Моцарела", "cal": 280, "prot": 28, "carbs": 2.2, "fat": 17},
            {"default_unit": "g", "category": "produce", "en": "Shallot", "bg": "Шалот", "cal": 72, "prot": 2.5, "carbs": 17, "fat": 0.1},
            {"default_unit": "g", "category": "spices", "en": "Turmeric", "bg": "Куркума", "cal": 312, "prot": 9.7, "carbs": 68, "fat": 3.3},
            {"default_unit": "g", "category": "spices", "en": "Chili Powder", "bg": "Чили на прах", "cal": 282, "prot": 13, "carbs": 50, "fat": 14},
            {"default_unit": "g", "category": "meat", "en": "Bacon", "bg": "Бекон", "cal": 541, "prot": 37, "carbs": 1.4, "fat": 42},
            {"default_unit": "g", "category": "produce", "en": "Romaine Lettuce", "bg": "Романо салата", "cal": 17, "prot": 1.2, "carbs": 3.3, "fat": 0.3},
            {"default_unit": "g", "category": "produce", "en": "Grape Tomatoes", "bg": "Чери домати", "cal": 18, "prot": 0.9, "carbs": 3.9, "fat": 0.2},
            {"default_unit": "g", "category": "produce", "en": "Lemon", "bg": "Лимон", "cal": 29, "prot": 1.1, "carbs": 9.3, "fat": 0.3},
            {"default_unit": "g", "category": "sauces", "en": "Mayonnaise", "bg": "Майонеза", "cal": 680, "prot": 1.0, "carbs": 0.6, "fat": 75},
            {"default_unit": "g", "category": "produce", "en": "Cauliflower", "bg": "Карфиол", "cal": 25, "prot": 1.9, "carbs": 5.0, "fat": 0.3},
            {"default_unit": "g", "category": "produce", "en": "Butter Lettuce", "bg": "Маслена салата", "cal": 13, "prot": 1.4, "carbs": 2.2, "fat": 0.2},
            {"default_unit": "g", "category": "frozen", "en": "Frozen Corn", "bg": "Замразена царевица", "cal": 86, "prot": 3.3, "carbs": 19, "fat": 1.2},
            {"default_unit": "g", "category": "canned", "en": "Chickpeas", "bg": "Нахут", "cal": 164, "prot": 8.9, "carbs": 27, "fat": 2.6},
            {"default_unit": "g", "category": "spices", "en": "Cayenne Pepper", "bg": "Кайен пипер", "cal": 318, "prot": 12, "carbs": 57, "fat": 17},
            {"default_unit": "g", "category": "spices", "en": "Garlic Powder", "bg": "Чесън на прах", "cal": 331, "prot": 17, "carbs": 73, "fat": 0.7},
            {"default_unit": "g", "category": "dairy", "en": "Greek Yogurt", "bg": "Гръцко кисело мляко", "cal": 59, "prot": 10, "carbs": 3.6, "fat": 0.4},
            {"default_unit": "g", "category": "sauces", "en": "Salsa", "bg": "Салса", "cal": 36, "prot": 1.7, "carbs": 7.0, "fat": 0.4},
            {"default_unit": "g", "category": "spices", "en": "Taco Seasoning", "bg": "Тако подправка", "cal": 200, "prot": 8.0, "carbs": 38, "fat": 4.0},
            {"default_unit": "g", "category": "produce", "en": "Banana", "bg": "Банан", "cal": 89, "prot": 1.1, "carbs": 23, "fat": 0.3},
            {"default_unit": "g", "category": "baking", "en": "Dark Chocolate Chips", "bg": "Черен шоколад на парчета", "cal": 546, "prot": 4.9, "carbs": 60, "fat": 31},
            {"default_unit": "g", "category": "baking", "en": "Shredded Coconut", "bg": "Настъргана кокосова стружка", "cal": 660, "prot": 6.9, "carbs": 24, "fat": 65},
            {"default_unit": "g", "category": "baking", "en": "Brown Sugar", "bg": "Кафява захар", "cal": 380, "prot": 0.1, "carbs": 98, "fat": 0},
            {"default_unit": "g", "category": "baking", "en": "Cornstarch", "bg": "Нишесте", "cal": 381, "prot": 0.3, "carbs": 91, "fat": 0.1},
            {"default_unit": "ml", "category": "spices", "en": "Vanilla Extract", "bg": "Ванилен екстракт", "cal": 288, "prot": 0.1, "carbs": 13, "fat": 0.1},
            {"default_unit": "ml", "category": "oils", "en": "Coconut Oil", "bg": "Кокосово масло", "cal": 892, "prot": 0, "carbs": 0, "fat": 100},
            {"default_unit": "g", "category": "baking", "en": "Baking Powder", "bg": "Бакпулвер", "cal": 53, "prot": 0, "carbs": 28, "fat": 0},
            {"default_unit": "g", "category": "baking", "en": "Baking Soda", "bg": "Сода бикарбонат", "cal": 0, "prot": 0, "carbs": 0, "fat": 0},
            {"default_unit": "g", "category": "produce", "en": "Arugula", "bg": "Рукола", "cal": 25, "prot": 2.6, "carbs": 3.7, "fat": 0.7},
            {"default_unit": "g", "category": "produce", "en": "Parsley", "bg": "Магданоз", "cal": 36, "prot": 3.0, "carbs": 6.3, "fat": 0.8},
            {"default_unit": "g", "category": "meat", "en": "Ground Pork", "bg": "Свинска кайма", "cal": 263, "prot": 26, "carbs": 0, "fat": 17},
            {"default_unit": "g", "category": "dairy", "en": "Parmesan Cheese", "bg": "Пармезан", "cal": 431, "prot": 38, "carbs": 4.1, "fat": 29},
            {"default_unit": "g", "category": "sauces", "en": "Dijon Mustard", "bg": "Дижонска горчица", "cal": 66, "prot": 3.6, "carbs": 6.4, "fat": 3.3},
            {"default_unit": "g", "category": "other", "en": "Honey", "bg": "Мед", "cal": 304, "prot": 0.3, "carbs": 82, "fat": 0},
            {"default_unit": "g", "category": "grains", "en": "Panko Bread Crumbs", "bg": "Галета", "cal": 395, "prot": 13, "carbs": 82, "fat": 3.2},
            {"default_unit": "g", "category": "spices", "en": "Onion Powder", "bg": "Лук на прах", "cal": 341, "prot": 10, "carbs": 79, "fat": 1.0},
            {"default_unit": "g", "category": "meat", "en": "Ground Chicken", "bg": "Пилешка кайма", "cal": 143, "prot": 17, "carbs": 0, "fat": 8.1},
            {"default_unit": "g", "category": "grains", "en": "Sourdough Bread", "bg": "Хляб с квас", "cal": 274, "prot": 9.5, "carbs": 51, "fat": 2.4},
            {"default_unit": "g", "category": "canned", "en": "Tomato Sauce", "bg": "Доматен сос", "cal": 29, "prot": 1.6, "carbs": 6.5, "fat": 0.3},
            {"default_unit": "g", "category": "spices", "en": "Italian Seasoning", "bg": "Италианска подправка", "cal": 265, "prot": 11, "carbs": 61, "fat": 4.8},
            {"default_unit": "g", "category": "spices", "en": "Crushed Red Pepper", "bg": "Люти чушки на люспи", "cal": 324, "prot": 12, "carbs": 57, "fat": 17},
            {"default_unit": "g", "category": "dairy", "en": "Cheddar Cheese", "bg": "Чедър", "cal": 402, "prot": 25, "carbs": 1.3, "fat": 33},
            {"default_unit": "g", "category": "produce", "en": "Green Onions", "bg": "Зелен лук", "cal": 32, "prot": 1.8, "carbs": 7.3, "fat": 0.2},
            {"default_unit": "g", "category": "produce", "en": "Lime", "bg": "Лайм", "cal": 30, "prot": 0.7, "carbs": 11, "fat": 0.2},
            {"default_unit": "ml", "category": "other", "en": "Red Wine Vinegar", "bg": "Червен винен оцет", "cal": 19, "prot": 0.1, "carbs": 0.3, "fat": 0},
            {"default_unit": "ml", "category": "other", "en": "Chicken Broth", "bg": "Пилешки бульон", "cal": 15, "prot": 1.5, "carbs": 1.4, "fat": 0.5},
            {"default_unit": "g", "category": "sauces", "en": "Alfredo Sauce", "bg": "Алфредо сос", "cal": 131, "prot": 3.2, "carbs": 5.2, "fat": 11},
            {"default_unit": "g", "category": "grains", "en": "Cheese Ravioli", "bg": "Равиоли", "cal": 253, "prot": 11, "carbs": 37, "fat": 7.2},
            {"default_unit": "g", "category": "other", "en": "Pine Nuts", "bg": "Пинолии", "cal": 673, "prot": 14, "carbs": 13, "fat": 68},
        ]
        ing_objects = {}
        for i in ingredients_data:
            ing = Ingredient(
                default_unit=i["default_unit"],
                category=i["category"],
                calories_per_100g=i.get("cal"),
                protein_per_100g=i.get("prot"),
                carbs_per_100g=i.get("carbs"),
                fat_per_100g=i.get("fat"),
            )
            db.add(ing)
            await db.flush()
            db.add(IngredientTranslation(ingredient_id=ing.id, language_code="en", name=i["en"]))
            db.add(IngredientTranslation(ingredient_id=ing.id, language_code="bg", name=i["bg"]))
            ing_objects[i["en"]] = ing
        await db.flush()
        print(f"✓ {len(ingredients_data)} ingredients")

        # ── Sample Recipes ───────────────────────────────────────────────────
        bg_cuisine = cuisine_objects.get("BG")
        it_cuisine = cuisine_objects.get("IT")
        gr_cuisine = cuisine_objects.get("GR")
        us_cuisine = cuisine_objects.get("US")
        mx_cuisine = cuisine_objects.get("MX")

        sample_recipes = [
            {
                "cuisine": bg_cuisine,
                "prep": 10, "cook": 20, "servings": 2, "difficulty": "easy",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["salad", "vegetarian", "quick"],
                "tags": ["quick", "healthy"],
                "image_url": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop",
                "title_en": "Bulgarian Shopska Salad",
                "desc_en": "A classic Bulgarian summer salad with fresh vegetables and feta cheese.",
                "title_bg": "Шопска салата",
                "desc_bg": "Класическата българска лятна салата с пресни зеленчуци и сирене.",
                "steps_en": ["Dice tomatoes, cucumbers, and bell peppers.", "Add grated feta cheese on top.", "Season with salt and olive oil."],
                "steps_bg": ["Нарежете доматите, краставиците и чушките на кубчета.", "Настържете сирено отгоре.", "Посолете и полейте зехтин."],
                "ingredients": [
                    ("Tomato", 300, "g"), ("Cucumber", 200, "g"), ("Bell Pepper", 150, "g"),
                    ("Feta Cheese", 100, "g"), ("Olive Oil", 30, "ml"), ("Salt", 5, "g"),
                ],
            },
            {
                "cuisine": it_cuisine,
                "prep": 5, "cook": 20, "servings": 2, "difficulty": "easy",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["pasta", "quick"],
                "tags": ["quick", "budget"],
                "image_url": "https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=600&auto=format&fit=crop",
                "title_en": "Spaghetti Aglio e Olio",
                "desc_en": "A simple yet flavourful Italian classic — ready in 25 minutes.",
                "title_bg": "Спагети с чесън и зехтин",
                "desc_bg": "Проста, но вкусна италианска класика — готова за 25 минути.",
                "steps_en": ["Cook pasta according to package instructions.", "Sauté garlic in olive oil until golden.", "Toss pasta with garlic oil, season with pepper."],
                "steps_bg": ["Сварете пастата по инструкциите.", "Запържете чесъна в зехтина до златисто.", "Смесете пастата с маслото, поправете на сол и пипер."],
                "ingredients": [
                    ("Pasta", 200, "g"), ("Garlic", 30, "g"), ("Olive Oil", 60, "ml"),
                    ("Salt", 5, "g"), ("Black Pepper", 2, "g"),
                ],
            },
            {
                "cuisine": bg_cuisine,
                "prep": 15, "cook": 40, "servings": 2, "difficulty": "medium",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["dinner"],
                "tags": ["family", "healthy"],
                "image_url": "https://images.unsplash.com/photo-1574484284002-952d92456975?w=600&auto=format&fit=crop",
                "title_en": "Moussaka",
                "desc_en": "Traditional Bulgarian moussaka with potatoes and ground meat.",
                "title_bg": "Мусака",
                "desc_bg": "Традиционна българска мусака с картофи и кайма.",
                "steps_en": ["Fry onion and ground beef.", "Layer with sliced potatoes in a baking dish.", "Pour egg-milk mixture on top and bake at 180°C for 40 min."],
                "steps_bg": ["Запържете лука и каймата.", "Наредете с нарязани картофи в тава.", "Залейте с яйчено-млечна смес и печете на 180°C за 40 мин."],
                "ingredients": [
                    ("Potato", 600, "g"), ("Ground Beef", 400, "g"), ("Onion", 100, "g"),
                    ("Eggs", 100, "g"), ("Milk", 200, "ml"), ("Olive Oil", 30, "ml"),
                    ("Salt", 8, "g"), ("Black Pepper", 3, "g"),
                ],
            },
            {
                "cuisine": gr_cuisine,
                "prep": 10, "cook": 5, "servings": 2, "difficulty": "easy",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["salad", "vegetarian", "quick"],
                "tags": ["quick", "healthy"],
                "image_url": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&auto=format&fit=crop",
                "title_en": "Greek Salad",
                "desc_en": "Fresh Mediterranean salad with tomatoes, olives and feta.",
                "title_bg": "Гръцка салата",
                "desc_bg": "Свежа средиземноморска салата с домати, маслини и сирене.",
                "steps_en": ["Chop tomatoes, cucumber and onion.", "Add olives and feta cheese.", "Drizzle with olive oil and season."],
                "steps_bg": ["Нарежете доматите, краставицата и лука.", "Добавете маслините и фета.", "Полейте зехтин и подправете."],
                "ingredients": [
                    ("Tomato", 250, "g"), ("Cucumber", 150, "g"), ("Feta Cheese", 80, "g"),
                    ("Olive Oil", 20, "ml"), ("Salt", 3, "g"),
                ],
            },
            {
                "cuisine": bg_cuisine,
                "prep": 5, "cook": 10, "servings": 2, "difficulty": "easy",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["breakfast", "quick"],
                "tags": ["quick", "budget", "healthy"],
                "image_url": "https://images.unsplash.com/photo-1510693206972-df098062cb71?w=600&auto=format&fit=crop",
                "title_en": "Scrambled Eggs with Vegetables",
                "desc_en": "Quick and nutritious scrambled eggs with peppers and tomatoes.",
                "title_bg": "Разбити яйца със зеленчуци",
                "desc_bg": "Бързи и питателни разбити яйца с чушки и домати.",
                "steps_en": ["Beat eggs with salt.", "Sauté diced pepper and tomato.", "Add eggs and stir until set."],
                "steps_bg": ["Разбийте яйцата със сол.", "Запържете нарязаните чушка и домат.", "Добавете яйцата и бъркайте до стягане."],
                "ingredients": [
                    ("Eggs", 150, "g"), ("Bell Pepper", 80, "g"), ("Tomato", 100, "g"),
                    ("Olive Oil", 15, "ml"), ("Salt", 3, "g"), ("Black Pepper", 1, "g"),
                ],
            },
            {
                "cuisine": bg_cuisine,
                "prep": 10, "cook": 20, "servings": 2, "difficulty": "easy",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["dinner", "grill", "quick"],
                "tags": ["healthy", "high-protein"],
                "image_url": "https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=600&auto=format&fit=crop",
                "title_en": "Grilled Chicken Breast",
                "desc_en": "Juicy grilled chicken breast with herbs and lemon.",
                "title_bg": "Пилешки гърди на скара",
                "desc_bg": "Сочни пилешки гърди на скара с билки и лимон.",
                "steps_en": ["Season chicken with salt, pepper and paprika.", "Grill on medium-high heat for 10 min per side.", "Rest for 5 min before serving."],
                "steps_bg": ["Подправете пилешкото със сол, пипер и червен пипер.", "Печете на средно-силен огън по 10 мин от всяка страна.", "Оставете да почине 5 мин преди сервиране."],
                "ingredients": [
                    ("Chicken Breast", 400, "g"), ("Olive Oil", 20, "ml"),
                    ("Salt", 5, "g"), ("Black Pepper", 2, "g"), ("Paprika", 3, "g"),
                ],
            },
            {
                "cuisine": it_cuisine,
                "prep": 10, "cook": 35, "servings": 2, "difficulty": "medium",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["pasta", "dinner"],
                "tags": ["family", "meal-prep"],
                "image_url": "https://images.unsplash.com/photo-1598866594230-a7c12756260f?w=600&auto=format&fit=crop",
                "title_en": "Pasta Bolognese",
                "desc_en": "Rich and hearty Italian meat sauce with pasta.",
                "title_bg": "Паста Болонезе",
                "desc_bg": "Богат и ситен италиански месен сос с паста.",
                "steps_en": ["Brown ground beef with onion.", "Add canned tomatoes and simmer 30 min.", "Cook pasta and toss with sauce."],
                "steps_bg": ["Запържете каймата с лука до покафеняване.", "Добавете консервираните домати и варете 30 мин.", "Сварете пастата и смесете с соса."],
                "ingredients": [
                    ("Pasta", 300, "g"), ("Ground Beef", 400, "g"), ("Onion", 100, "g"),
                    ("Canned Tomatoes", 400, "g"), ("Olive Oil", 30, "ml"),
                    ("Salt", 8, "g"), ("Black Pepper", 3, "g"),
                ],
            },
        # ── New Recipes (from PDF files) ─────────────────────────────────────
        {
            "cuisine": mx_cuisine,
            "prep": 10, "cook": 10, "servings": 2, "difficulty": "easy",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["breakfast", "quick"],
            "tags": ["quick", "healthy"],
            "image_url": None,
            "title_en": "Indian Spiced Egg, Cheese & Avocado Breakfast Burrito",
            "desc_en": "A vibrant breakfast burrito with Indian-spiced scrambled eggs, mozzarella, and creamy avocado.",
            "title_bg": "Индийско закусочно бурито с яйца, сирене и авокадо",
            "desc_bg": "Ароматно закусочно бурито с яйца, куркума, моцарела и кремообразно авокадо.",
            "steps_en": [
                "Dice shallot and tomato. Mince jalapeño and cilantro. Combine in a bowl with turmeric, salt, and chili powder.",
                "Heat olive oil in a skillet over medium-high heat. Add veggie mix and cook, stirring, for 3-4 minutes until softened.",
                "Whisk eggs in a bowl, pour into the skillet and scramble with the veggies until set, about 2 minutes. Remove from heat.",
                "Grate mozzarella and slice avocado.",
                "Lay tortillas flat. Divide egg scramble, mozzarella, and avocado between them. Roll tightly, cut in half, and serve.",
            ],
            "steps_bg": [
                "Нарежете шалота и домата. Нарежете халапеньото и кориандъра. Смесете в купа с куркума, сол и чили на прах.",
                "Загрейте зехтин в тиган на средно-силен огън. Добавете зеленчуците и запържете, разбърквайки, 3-4 минути до омекване.",
                "Разбийте яйцата в купа, изсипете в тигана и разбъркайте заедно с зеленчуците до стягане, около 2 минути. Свалете от огъня.",
                "Настържете моцарелата и нарежете авокадото.",
                "Наредете тортиите. Разпределете яйчената смес, моцарелата и авокадото между тях. Завийте плътно, разрежете наполовина и сервирайте.",
            ],
            "ingredients": [
                ("Eggs", 200, "g"), ("Avocado", 75, "g"), ("Mozzarella Cheese", 28, "g"),
                ("Shallot", 40, "g"), ("Tomato", 150, "g"), ("Jalapeño", 15, "g"),
                ("Cilantro", 15, "g"), ("Flour Tortilla", 180, "g"), ("Olive Oil", 7, "ml"),
                ("Turmeric", 2, "g"), ("Salt", 1, "g"), ("Chili Powder", 1, "g"),
            ],
        },
        {
            "cuisine": us_cuisine,
            "prep": 15, "cook": 20, "servings": 2, "difficulty": "easy",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["salad", "lunch"],
            "tags": ["healthy", "high-protein"],
            "image_url": None,
            "title_en": "BLT Salad with Grilled Chicken & Avocado",
            "desc_en": "A fresh salad with grilled chicken, crispy bacon, avocado, and tomatoes with a lemony garlic dressing.",
            "title_bg": "BLT салата с пилешко на скара и авокадо",
            "desc_bg": "Свежа салата с пилешко на скара, хрупкав бекон, авокадо и домати с лимонов дресинг.",
            "steps_en": [
                "Season chicken with olive oil, salt, and pepper. Grill with bacon over medium heat for 3-4 minutes per side until chicken is cooked through and bacon is crispy.",
                "Mince garlic and whisk with lemon juice, mayonnaise, olive oil, salt, and pepper to prepare the dressing.",
                "Slice avocado, halve grape tomatoes, and chop romaine lettuce into strips.",
                "Slice grilled chicken into strips and crumble the bacon.",
                "Arrange lettuce on plates, top with tomatoes, avocado, chicken, and bacon. Drizzle with dressing and serve.",
            ],
            "steps_bg": [
                "Натрийте пилешкото с зехтин, сол и пипер. Печете заедно с бекона на средно-силен огън по 3-4 минути от страна до готовност.",
                "Нарежете ситно чесъна и разбийте с лимонов сок, майонеза, зехтин, сол и пипер за дресинга.",
                "Нарежете авокадото, разполовете чери доматите и нарежете романо салатата на ленти.",
                "Нарежете пилешкото на ленти и натрошете бекона.",
                "Наредете маруля в чиниите, отгоре наредете доматите, авокадото, пилешкото и бекона. Полейте с дресинг и сервирайте.",
            ],
            "ingredients": [
                ("Chicken Breast", 340, "g"), ("Bacon", 120, "g"), ("Avocado", 150, "g"),
                ("Romaine Lettuce", 150, "g"), ("Grape Tomatoes", 150, "g"), ("Garlic", 5, "g"),
                ("Lemon", 50, "g"), ("Mayonnaise", 15, "g"), ("Olive Oil", 45, "ml"),
                ("Salt", 4, "g"), ("Black Pepper", 2, "g"),
            ],
        },
        {
            "cuisine": mx_cuisine,
            "prep": 10, "cook": 20, "servings": 2, "difficulty": "medium",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["vegan", "vegetarian", "lunch"],
            "tags": ["healthy"],
            "image_url": None,
            "title_en": "Roasted Cauliflower, Chickpea, Corn & Avocado Burrito",
            "desc_en": "A hearty vegan burrito with roasted cauliflower, chickpeas, corn, and creamy avocado.",
            "title_bg": "Веганско бурито с печен карфиол, нахут и царевица",
            "desc_bg": "Питателно веганско бурито с печен карфиол, нахут, замразена царевица и авокадо.",
            "steps_en": [
                "Preheat oven to 220°C. Toss cauliflower florets with olive oil and half the spice mix (chili powder, garlic powder, cayenne, salt). Roast for 20 minutes until golden.",
                "Dice onion and sauté in olive oil for 3-4 minutes. Add drained chickpeas, frozen corn, minced cilantro, and remaining spices. Cook 3-4 minutes more.",
                "Dice tomato and slice avocado.",
                "Lay tortillas flat and divide the cauliflower and chickpea-corn filling down the center. Top with tomato, avocado, and lettuce leaves.",
                "Fold in the sides and roll the burritos tightly. Cut in half and serve.",
            ],
            "steps_bg": [
                "Загрейте фурната до 220°C. Разбъркайте карфиола с зехтин и половината подправки (чили на прах, чесън на прах, кайен пипер, сол). Печете 20 минути до златисто.",
                "Нарежете лука и запържете в зехтин 3-4 минути. Добавете нахута, замразената царевица, кориандъра и останалите подправки. Гответе още 3-4 минути.",
                "Нарежете домата и нарежете авокадото.",
                "Наредете тортиите. Разпределете пълнежа от карфиол, нахут и царевица в средата. Добавете домат, авокадо и листа маруля.",
                "Сгънете страните и завийте бурито плътно. Разрежете наполовина и сервирайте.",
            ],
            "ingredients": [
                ("Cauliflower", 300, "g"), ("Chickpeas", 250, "g"), ("Frozen Corn", 80, "g"),
                ("Avocado", 75, "g"), ("Butter Lettuce", 100, "g"), ("Tomato", 150, "g"),
                ("Onion", 75, "g"), ("Cilantro", 15, "g"), ("Flour Tortilla", 180, "g"),
                ("Olive Oil", 20, "ml"), ("Chili Powder", 4, "g"), ("Garlic Powder", 1, "g"),
                ("Cayenne Pepper", 1, "g"), ("Salt", 2, "g"),
            ],
        },
        {
            "cuisine": mx_cuisine,
            "prep": 5, "cook": 15, "servings": 2, "difficulty": "easy",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["dinner"],
            "tags": ["family"],
            "image_url": None,
            "title_en": 'Beef Tortilla "Enchilada" Skillet Bake with Bell Pepper & Zucchini',
            "desc_en": "A quick Mexican-style skillet bake with seasoned ground beef, vegetables, and melted cheese.",
            "title_bg": "Мексикански тиган с говеждо, чушки и тиквичка",
            "desc_bg": "Бързо мексиканско ястие с подправено говеждо, зеленчуци, салса и топено сирене.",
            "steps_en": [
                "Preheat oven to 230°C. Dice zucchini and bell pepper.",
                "Brown ground beef in an ovenproof skillet with taco seasoning and salt for 3 minutes, breaking it apart with a spoon.",
                "Add zucchini and bell pepper. Cook until beef is cooked through and vegetables are soft, 4-5 minutes.",
                "Tear tortillas into pieces. Add to the skillet with salsa and Greek yogurt. Stir and heat through, 2 minutes.",
                "Top with shredded mozzarella and bake until melted and golden, 7-8 minutes. Serve directly from the skillet.",
            ],
            "steps_bg": [
                "Загрейте фурната до 230°C. Нарежете тиквичката и чушката на кубчета.",
                "Запечете каймата в тиган, подходящ за фурна, с тако подправка и сол около 3 минути, разбивайки я с лъжица.",
                "Добавете тиквичката и чушката. Гответе до готовност на каймата и омекване на зеленчуците, 4-5 минути.",
                "Разкъсайте тортиите на парчета. Добавете в тигана заедно със салсата и киселото мляко. Разбъркайте и затоплете 2 минути.",
                "Поръсете с настъргана моцарела и запечете до разтопяване и златисто, 7-8 минути. Сервирайте директно от тигана.",
            ],
            "ingredients": [
                ("Ground Beef", 340, "g"), ("Bell Pepper", 150, "g"), ("Zucchini", 200, "g"),
                ("Greek Yogurt", 60, "g"), ("Salsa", 240, "g"), ("Mozzarella Cheese", 60, "g"),
                ("Flour Tortilla", 120, "g"), ("Taco Seasoning", 22, "g"),
                ("Olive Oil", 10, "ml"), ("Salt", 1, "g"),
            ],
        },
        {
            "cuisine": us_cuisine,
            "prep": 15, "cook": 20, "servings": 2, "difficulty": "easy",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["dessert"],
            "tags": ["budget"],
            "image_url": None,
            "title_en": 'Giant Coconut-Chocolate Chip "Banana Bread" Cookie',
            "desc_en": "Soft and chewy giant cookies with mashed banana, shredded coconut, and dark chocolate chips.",
            "title_bg": "Гигантска бисквита с кокос и черен шоколад à la Банан",
            "desc_bg": "Меки и вкусни гигантски бисквити с банан, кокосова стружка и парчета черен шоколад.",
            "steps_en": [
                "Preheat oven to 180°C and line a baking sheet with parchment paper.",
                "Mash banana with brown sugar, coconut oil, and vanilla extract until smooth.",
                "Stir in shredded coconut and dark chocolate chips.",
                "Mix flour, cornstarch, baking powder, baking soda, and salt in a small bowl. Add to the banana mixture and stir to combine.",
                "Scoop the batter into 2 portions on the baking sheet, spread into 8 cm circles, and bake for 20 minutes until golden. Allow to cool slightly before serving.",
            ],
            "steps_bg": [
                "Загрейте фурната до 180°C и наредете хартия за печене върху тава.",
                "Намачкайте банана с кафявата захар, кокосовото масло и ванилята до гладка смес.",
                "Добавете кокосовата стружка и парчетата черен шоколад и разбъркайте.",
                "Смесете брашното, нишестето, бакпулвера, содата и солта в отделна купа. Добавете към банановата смес и разбъркайте.",
                "Наредете тестото в 2 кръга върху тавата, оформете до диаметър 8 см и печете 20 минути до златисто. Охладете малко преди сервиране.",
            ],
            "ingredients": [
                ("Banana", 60, "g"), ("Dark Chocolate Chips", 43, "g"), ("Shredded Coconut", 30, "g"),
                ("Flour", 30, "g"), ("Brown Sugar", 36, "g"), ("Cornstarch", 1, "g"),
                ("Vanilla Extract", 2, "ml"), ("Coconut Oil", 14, "ml"),
                ("Baking Powder", 0.5, "g"), ("Baking Soda", 0.5, "g"), ("Salt", 0.5, "g"),
            ],
        },
        {
            "cuisine": it_cuisine,
            "prep": 15, "cook": 10, "servings": 2, "difficulty": "medium",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["dinner"],
            "tags": ["healthy", "high-protein"],
            "image_url": None,
            "title_en": "Cheesy Pork Stuffed Peppers with Crispy Bread Crumbs & Dressed Arugula",
            "desc_en": "Broiled bell peppers stuffed with seasoned ground pork and Parmesan, served with dressed arugula salad.",
            "title_bg": "Пълнени чушки със свинска кайма, пармезан и хрупкава галета",
            "desc_bg": "Печени чушки пълнени с ароматна свинска кайма и пармезан, с хрупкава галета и рукола.",
            "steps_en": [
                "Preheat oven to broil (high). Halve and seed bell peppers lengthwise. Drizzle with olive oil, season with salt and pepper, and broil cut-side down for 6-8 minutes until lightly charred and tender.",
                "Brown ground pork in a skillet with garlic powder, onion powder, salt, and pepper for 4-5 minutes. Stir in grated Parmesan and minced parsley. Remove from heat.",
                "Whisk lemon juice with olive oil, Dijon mustard, honey, and salt for the dressing.",
                "Stuff peppers with pork filling, top with panko bread crumbs. Broil 1 minute until crumbs are toasted.",
                "Toss arugula in the dressing and serve alongside the stuffed peppers.",
            ],
            "steps_bg": [
                "Загрейте фурната на режим скара (висок). Разрежете чушките наполовина по дължина и изчистете семките. Полейте зехтин, подправете и запечете с лицето надолу 6-8 минути до омекване.",
                "Запечете свинската кайма в тиган с чесън на прах, лук на прах, сол и пипер 4-5 минути. Добавете пармезана и магданоза и разбъркайте. Свалете от огъня.",
                "Разбийте лимоновия сок с зехтин, дижонска горчица, мед и сол за дресинга.",
                "Напълнете чушките с каймения пълнеж и поръсете с галета. Запечете 1 минута до хрупкавост.",
                "Разбъркайте руколата с дресинга и сервирайте до пълнените чушки.",
            ],
            "ingredients": [
                ("Ground Pork", 340, "g"), ("Bell Pepper", 300, "g"), ("Arugula", 70, "g"),
                ("Parsley", 15, "g"), ("Parmesan Cheese", 28, "g"), ("Lemon", 50, "g"),
                ("Olive Oil", 30, "ml"), ("Dijon Mustard", 5, "g"), ("Honey", 7, "g"),
                ("Garlic Powder", 2, "g"), ("Onion Powder", 2, "g"), ("Panko Bread Crumbs", 28, "g"),
                ("Black Pepper", 1, "g"), ("Salt", 3, "g"),
            ],
        },
        {
            "cuisine": it_cuisine,
            "prep": 10, "cook": 15, "servings": 2, "difficulty": "medium",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["dinner"],
            "tags": ["family"],
            "image_url": None,
            "title_en": 'Saucy "Chicken Parmesan" Patty Melt with Mozzarella',
            "desc_en": "Juicy ground chicken patties smothered in tomato sauce and melted mozzarella, served on toasted sourdough.",
            "title_bg": "Пилешко Пармеджана с моцарела на препечен хляб",
            "desc_bg": "Сочни пилешки кюфтета с доматен сос и моцарела, поднесени върху хрупкав хляб с квас.",
            "steps_en": [
                "Preheat oven to broil (high). Mix tomato sauce with minced garlic, Italian seasoning, salt, and black pepper.",
                "Combine ground chicken with 2 tbsp of the tomato sauce, panko bread crumbs, salt, and crushed red pepper. Form into 2 patties.",
                "Drizzle patties with olive oil and broil for 10 minutes, flipping halfway, until cooked through and golden.",
                "Top patties with remaining tomato sauce and sliced mozzarella. Add sourdough slices to the baking sheet. Broil 1-2 minutes until cheese melts and bread is toasted.",
                "Place toast on plates, top with saucy patties, and serve.",
            ],
            "steps_bg": [
                "Загрейте фурната на режим скара (висок). Смесете доматения сос с нарязан чесън, италианска подправка, сол и черен пипер.",
                "Смесете пилешката кайма с 2 с.л. от доматения сос, галетата, солта и люти чушки на люспи. Оформете 2 кюфтета.",
                "Полейте кюфтетата с зехтин и печете на скара 10 минути, обръщайки наполовина, до готовност и златисто.",
                "Сложете останалия доматен сос и нарязана моцарела върху кюфтетата. Добавете хляба в тавата. Печете 1-2 минути до разтопено сирене и хрупкав хляб.",
                "Наредете хляба в чиниите, отгоре сложете кюфтетата и сервирайте.",
            ],
            "ingredients": [
                ("Ground Chicken", 225, "g"), ("Mozzarella Cheese", 57, "g"), ("Sourdough Bread", 80, "g"),
                ("Tomato Sauce", 113, "g"), ("Garlic", 5, "g"), ("Panko Bread Crumbs", 40, "g"),
                ("Italian Seasoning", 2, "g"), ("Crushed Red Pepper", 1, "g"),
                ("Olive Oil", 5, "ml"), ("Salt", 2, "g"), ("Black Pepper", 1, "g"),
            ],
        },
        {
            "cuisine": mx_cuisine,
            "prep": 10, "cook": 10, "servings": 2, "difficulty": "easy",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["lunch", "salad"],
            "tags": ["healthy", "quick"],
            "image_url": None,
            "title_en": "Avocado-Lime Chicken Salad & Cheddar Rolls",
            "desc_en": "Shredded poached chicken mixed with mashed avocado, lime, cheddar, and Greek yogurt, rolled in flour tortillas.",
            "title_bg": "Пилешка салата с авокадо и лайм в тортиля с чедър",
            "desc_bg": "Скъсано пилешко с авокадо, лайм, чедър и гръцко кисело мляко, увито в пшенична тортиля.",
            "steps_en": [
                "Season chicken with salt and pepper. Poach in gently simmering water for 8-10 minutes until cooked through. Drain and shred with a fork.",
                "Soak minced shallot in red wine vinegar with a pinch of salt for 5 minutes, then drain.",
                "Mash avocado in a bowl with lime juice. Add sliced green onions, grated cheddar, Greek yogurt, garlic powder, salt, and pepper. Mix well.",
                "Add shredded chicken and drained shallot to the bowl. Stir to combine the salad.",
                "Divide the chicken salad between tortillas, spread evenly, roll tightly, and slice in half. Serve.",
            ],
            "steps_bg": [
                "Подправете пилешкото със сол и пипер. Варете в леко кипяща вода 8-10 минути до готовност. Отцедете и скъсайте на влакна с вилица.",
                "Накиснете нарязания шалот в червен винен оцет с щипка сол за 5 минути, след което отцедете.",
                "Намачкайте авокадото в купа с лаймов сок. Добавете зеления лук, настърган чедър, гръцко кисело мляко, чесън на прах, сол и пипер. Разбъркайте добре.",
                "Добавете скъсаното пилешко и отцедения шалот в купата. Разбъркайте за пилешката салата.",
                "Разпределете салатата между тортиите, наредете равномерно, завийте плътно и разрежете наполовина. Сервирайте.",
            ],
            "ingredients": [
                ("Chicken Breast", 340, "g"), ("Avocado", 150, "g"), ("Cheddar Cheese", 28, "g"),
                ("Lime", 67, "g"), ("Green Onions", 50, "g"), ("Shallot", 40, "g"),
                ("Greek Yogurt", 60, "g"), ("Flour Tortilla", 180, "g"), ("Red Wine Vinegar", 8, "ml"),
                ("Garlic Powder", 1, "g"), ("Salt", 2, "g"), ("Black Pepper", 0.5, "g"),
            ],
        },
        {
            "cuisine": mx_cuisine,
            "prep": 10, "cook": 20, "servings": 2, "difficulty": "medium",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["dinner"],
            "tags": ["family"],
            "image_url": None,
            "title_en": "Chicken & Jalapeño Enchiladas with Creamy White Sauce",
            "desc_en": "Rolled chicken and jalapeño enchiladas baked with a homemade creamy white sauce and melted mozzarella.",
            "title_bg": "Пилешки енчиладас с халапеньо и кремообразен бял сос",
            "desc_bg": "Пилешки енчиладас с халапеньо, запечени с домашен кремообразен бял сос и моцарела.",
            "steps_en": [
                "Poach chicken in boiling water for 8-12 minutes. Remove and shred. Sauté diced jalapeños, onion, and garlic in olive oil with chili powder and salt until soft, 4-5 minutes. Mix with shredded chicken.",
                "Make white sauce: melt butter over medium heat, whisk in flour for 1 minute, add chicken broth and salt, whisk until thickened (2-3 min). Remove from heat, cool slightly, whisk in Greek yogurt.",
                "Grate mozzarella. Preheat oven to broil. Grease a baking dish. Place chicken filling in each tortilla with a spoonful of cheese, roll tightly, and place seam-side down.",
                "Pour white sauce over enchiladas and top with remaining mozzarella. Broil until bubbly and golden, 3-4 minutes.",
                "Dice tomato and green onion. Serve enchiladas topped with fresh tomato and green onion.",
            ],
            "steps_bg": [
                "Варете пилешкото в кипяща вода 8-12 минути. Извадете и скъсайте. Запържете халапеньото, лука и чесъна в зехтин с чили на прах и сол до омекване, 4-5 минути. Смесете с пилешкото.",
                "Пригответе белия сос: разтопете маслото, добавете брашното и бъркайте 1 минута, добавете бульона и сол, бъркайте до сгъстяване (2-3 мин). Свалете от огъня, охладете малко и разбъркайте с кисело мляко.",
                "Настържете моцарелата. Загрейте фурната на режим скара. Намажете тава. Сложете пълнежа в средата на всяка тортиля с малко сирене, завийте и наредете с шева надолу.",
                "Полейте с бял сос и поръсете с останалата моцарела. Запечете до кипене и златисто, 3-4 минути.",
                "Нарежете домата и зеления лук. Сервирайте енчиладасите поръсени с пресен домат и зелен лук.",
            ],
            "ingredients": [
                ("Chicken Breast", 340, "g"), ("Chicken Broth", 240, "ml"), ("Garlic", 10, "g"),
                ("Green Onions", 50, "g"), ("Jalapeño", 60, "g"), ("Mozzarella Cheese", 75, "g"),
                ("Greek Yogurt", 60, "g"), ("Flour Tortilla", 240, "g"), ("Tomato", 150, "g"),
                ("Onion", 75, "g"), ("Flour", 12, "g"), ("Butter", 21, "g"),
                ("Chili Powder", 2, "g"), ("Olive Oil", 10, "ml"), ("Salt", 5, "g"),
            ],
        },
        {
            "cuisine": it_cuisine,
            "prep": 5, "cook": 15, "servings": 2, "difficulty": "easy",
            "status": RecipeStatus.PUBLISHED,
            "categories": ["pasta", "dinner", "quick"],
            "tags": ["quick", "family"],
            "image_url": None,
            "title_en": "Creamy Tuscan Ravioli with Mushrooms, Tomatoes, Spinach & Pine Nuts",
            "desc_en": "Fresh cheese ravioli tossed with sautéed mushrooms, spinach, grape tomatoes, and Alfredo sauce, topped with pine nuts.",
            "title_bg": "Кремообразни равиоли с гъби, спанак, домати и пинолии",
            "desc_bg": "Пресни равиоли с гъби, спанак, чери домати и алфредо сос, поръсени с пинолии.",
            "steps_en": [
                "Cook ravioli in salted boiling water for 5 minutes until just tender. Drain and set aside.",
                "Melt butter in a skillet over medium-high heat. Add minced garlic and cook until fragrant, about 30 seconds. Add sliced mushrooms and cook until golden, 3-4 minutes.",
                "Halve grape tomatoes. Add to the skillet with Italian seasoning, crushed red pepper, salt, and pepper. Cook until tomatoes soften, 3-4 minutes.",
                "Add spinach in handfuls, letting each handful wilt before adding more.",
                "Add ravioli and Alfredo sauce. Stir and cook until heated through, 2-3 minutes. Serve sprinkled with pine nuts.",
            ],
            "steps_bg": [
                "Сварете равиолите в подсолена кипяща вода около 5 минути до готовност. Отцедете и оставете настрана.",
                "Разтопете маслото в тиган на средно-силен огън. Добавете нарязания чесън и запържете до ухание, около 30 секунди. Добавете нарязаните гъби и запържете до златисто, 3-4 минути.",
                "Разполовете чери доматите. Добавете в тигана с италианска подправка, люти чушки на люспи, сол и пипер. Гответе до омекване, 3-4 минути.",
                "Добавете спанака на шепи, изчаквайки всяка шепа да повехне.",
                "Добавете равиолите и алфредо соса. Разбъркайте и гответе до затопляне, 2-3 минути. Сервирайте поръсени с пинолии.",
            ],
            "ingredients": [
                ("Cheese Ravioli", 255, "g"), ("Alfredo Sauce", 226, "g"), ("Spinach", 142, "g"),
                ("Grape Tomatoes", 300, "g"), ("Mushrooms", 227, "g"), ("Garlic", 5, "g"),
                ("Pine Nuts", 18, "g"), ("Butter", 14, "g"), ("Italian Seasoning", 2, "g"),
                ("Crushed Red Pepper", 1, "g"), ("Salt", 1, "g"), ("Black Pepper", 1, "g"),
            ],
        },
        ]

        recipe_objects = []
        for r in sample_recipes:
            recipe = Recipe(
                cuisine_id=r["cuisine"].id if r["cuisine"] else None,
                prep_time_minutes=r["prep"],
                cook_time_minutes=r["cook"],
                total_time_minutes=r["prep"] + r["cook"],
                servings=r["servings"],
                difficulty=r["difficulty"],
                status=r["status"],
                image_url=r.get("image_url"),
                created_by=admin.id,
            )
            db.add(recipe)
            await db.flush()

            db.add(RecipeTranslation(recipe_id=recipe.id, language_code="en", title=r["title_en"], description=r["desc_en"]))
            db.add(RecipeTranslation(recipe_id=recipe.id, language_code="bg", title=r["title_bg"], description=r["desc_bg"]))

            for idx, (step_en, step_bg) in enumerate(zip(r["steps_en"], r["steps_bg"]), 1):
                step = RecipeStep(recipe_id=recipe.id, order=idx)
                db.add(step)
                await db.flush()
                db.add(RecipeStepTranslation(step_id=step.id, language_code="en", instruction=step_en))
                db.add(RecipeStepTranslation(step_id=step.id, language_code="bg", instruction=step_bg))

            for ing_name, qty, unit in r["ingredients"]:
                if ing_name in ing_objects:
                    db.add(RecipeIngredient(
                        recipe_id=recipe.id,
                        ingredient_id=ing_objects[ing_name].id,
                        quantity=qty,
                        unit=unit,
                    ))

            for s in r["categories"]:
                if s in cat_objects:
                    await db.execute(insert(recipe_categories).values(recipe_id=recipe.id, category_id=cat_objects[s].id))
            for s in r["tags"]:
                if s in tag_objects:
                    await db.execute(insert(recipe_tags).values(recipe_id=recipe.id, tag_id=tag_objects[s].id))

            recipe_objects.append(recipe)

        await db.flush()
        print(f"✓ {len(sample_recipes)} sample recipes")

        # ── Weekly Suggestions (current week) ────────────────────────────────
        today = date.today()
        week_start = today - timedelta(days=today.weekday())
        # Positions 1-5: weekly picks (use first 5 recipes)
        for pos, recipe in enumerate(recipe_objects[:5], start=1):
            db.add(WeeklySuggestion(
                week_start_date=week_start,
                recipe_id=recipe.id,
                position=pos,
                is_active=True,
            ))
        await db.flush()
        print(f"✓ 5 weekly suggestions for {week_start}")

        await db.commit()
        print("\n✅ Database seeded successfully!")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed(force="--force" in sys.argv))
