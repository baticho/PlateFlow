"""Import all models so Alembic can detect them."""

from app.domains.categories.models import Category, CategoryTranslation, recipe_categories  # noqa: F401
from app.domains.cuisines.models import Cuisine, CuisineTranslation  # noqa: F401
from app.domains.favorites.models import Favorite  # noqa: F401
from app.domains.ingredients.models import Ingredient, IngredientTranslation  # noqa: F401
from app.domains.meal_plans.models import MealPlan, MealPlanItem  # noqa: F401
from app.domains.recipes.models import (  # noqa: F401
    Recipe,
    RecipeIngredient,
    RecipeStep,
    RecipeStepTranslation,
    RecipeTranslation,
)
from app.domains.shopping_lists.models import ShoppingList, ShoppingListItem  # noqa: F401
from app.domains.stores.models import Store  # noqa: F401
from app.domains.subscriptions.models import SubscriptionPlan  # noqa: F401
from app.domains.tags.models import Tag, TagTranslation, recipe_tags  # noqa: F401
from app.domains.users.models import User  # noqa: F401
from app.domains.weekly_suggestions.models import WeeklySuggestion  # noqa: F401
