from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.domains.auth.schemas import (
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.domains.auth.service import (
    authenticate_user,
    create_tokens,
    refresh_access_token,
    register_user,
)

router = APIRouter()


@router.post("/register", response_model=TokenResponse)
async def register(data: RegisterRequest, db: AsyncSession = Depends(get_db)):
    user = await register_user(
        db,
        email=data.email,
        password=data.password,
        full_name=data.full_name,
        preferred_language=data.preferred_language,
        preferred_unit_system=data.preferred_unit_system,
    )
    return create_tokens(str(user.id))


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = await authenticate_user(db, data.email, data.password)
    return create_tokens(str(user.id))


@router.post("/refresh", response_model=TokenResponse)
async def refresh(data: RefreshRequest, db: AsyncSession = Depends(get_db)):
    return await refresh_access_token(db, data.refresh_token)
