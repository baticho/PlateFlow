from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    APP_NAME: str = "PlateFlow"
    APP_ENV: str = "development"
    DEBUG: bool = True

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://plateflow:plateflow_secret@db:5432/plateflow"

    # Redis
    REDIS_URL: str = "redis://redis:6379/0"

    # JWT
    JWT_SECRET_KEY: str = "change-me-to-a-random-secret-key"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Google OAuth
    GOOGLE_CLIENT_ID: str = ""

    # CORS
    BACKEND_CORS_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # First admin
    FIRST_ADMIN_EMAIL: str = "admin@plateflow.com"
    FIRST_ADMIN_PASSWORD: str = "admin123"

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
