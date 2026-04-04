from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.middleware.i18n import I18nMiddleware

app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# i18n
app.add_middleware(I18nMiddleware)


# Routers
from app.domains.auth.router import router as auth_router  # noqa: E402
from app.domains.categories.router import router as categories_router  # noqa: E402
from app.domains.cuisines.router import router as cuisines_router  # noqa: E402
from app.domains.favorites.router import router as favorites_router  # noqa: E402
from app.domains.ingredients.router import router as ingredients_router  # noqa: E402
from app.domains.meal_plans.router import router as meal_plans_router  # noqa: E402
from app.domains.recipes.router import router as recipes_router  # noqa: E402
from app.domains.shopping_lists.router import router as shopping_lists_router  # noqa: E402
from app.domains.subscriptions.router import router as subscriptions_router  # noqa: E402
from app.domains.users.router import router as users_router  # noqa: E402
from app.domains.weekly_suggestions.router import router as weekly_suggestions_router  # noqa: E402
from app.admin.router import router as admin_router  # noqa: E402

app.include_router(auth_router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(users_router, prefix="/api/v1/users", tags=["Users"])
app.include_router(recipes_router, prefix="/api/v1/recipes", tags=["Recipes"])
app.include_router(categories_router, prefix="/api/v1/categories", tags=["Categories"])
app.include_router(cuisines_router, prefix="/api/v1/cuisines", tags=["Cuisines"])
app.include_router(ingredients_router, prefix="/api/v1/ingredients", tags=["Ingredients"])
app.include_router(meal_plans_router, prefix="/api/v1/meal-plans", tags=["Meal Plans"])
app.include_router(shopping_lists_router, prefix="/api/v1/shopping-lists", tags=["Shopping Lists"])
app.include_router(favorites_router, prefix="/api/v1/favorites", tags=["Favorites"])
app.include_router(subscriptions_router, prefix="/api/v1/subscriptions", tags=["Subscriptions"])
app.include_router(weekly_suggestions_router, prefix="/api/v1/weekly-suggestions", tags=["Weekly Suggestions"])
app.include_router(admin_router, prefix="/api/v1/admin", tags=["Admin"])


@app.get("/health")
async def health_check():
    return {"status": "healthy", "app": settings.APP_NAME}
