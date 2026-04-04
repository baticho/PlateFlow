"""Seed script: run with  python -m scripts.seed  from backend/ directory."""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

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
from app.domains.subscriptions.models import SubscriptionPlan
from app.domains.tags.models import Tag, TagTranslation
from app.domains.users.models import AdminRole, User
from app.domains.weekly_suggestions.models import WeeklySuggestion
from app.models import *  # noqa: F401, F403 — ensure all models registered


async def seed():
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    Session = async_sessionmaker(engine, expire_on_commit=False)

    async with Session() as db:
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

        sample_recipes = [
            {
                "cuisine": bg_cuisine,
                "prep": 10, "cook": 20, "servings": 4, "difficulty": "easy",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["salad", "vegetarian"],
                "tags": ["quick", "healthy"],
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
                "prep": 15, "cook": 40, "servings": 4, "difficulty": "medium",
                "status": RecipeStatus.PUBLISHED,
                "categories": ["dinner"],
                "tags": ["family", "healthy"],
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
        ]

        for r in sample_recipes:
            recipe = Recipe(
                cuisine_id=r["cuisine"].id if r["cuisine"] else None,
                prep_time_minutes=r["prep"],
                cook_time_minutes=r["cook"],
                total_time_minutes=r["prep"] + r["cook"],
                servings=r["servings"],
                difficulty=r["difficulty"],
                status=r["status"],
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

            recipe.categories = [cat_objects[s] for s in r["categories"] if s in cat_objects]
            recipe.tags = [tag_objects[s] for s in r["tags"] if s in tag_objects]

        await db.flush()
        print(f"✓ {len(sample_recipes)} sample recipes")

        await db.commit()
        print("\n✅ Database seeded successfully!")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
