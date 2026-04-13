import requests as http_requests
from fastapi import HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.domains.users.models import LanguageCode, UnitSystem, User


async def register_user(
    db: AsyncSession,
    email: str,
    password: str,
    full_name: str,
    preferred_language: str = "en",
    preferred_unit_system: str = "metric",
) -> User:
    result = await db.execute(select(User).where(User.email == email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    user = User(
        email=email,
        password_hash=hash_password(password),
        full_name=full_name,
        preferred_language=LanguageCode(preferred_language),
        preferred_unit_system=UnitSystem(preferred_unit_system),
    )
    db.add(user)
    await db.flush()
    return user


async def authenticate_user(db: AsyncSession, email: str, password: str) -> User:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user or not user.password_hash or not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )
    return user


def create_tokens(user_id: str) -> dict:
    return {
        "access_token": create_access_token(user_id),
        "refresh_token": create_refresh_token(user_id),
        "token_type": "bearer",
    }


async def google_sign_in(
    db: AsyncSession,
    id_token_str: str | None = None,
    access_token_str: str | None = None,
    preferred_language: str = "en",
    preferred_unit_system: str = "metric",
) -> User:
    if not id_token_str and not access_token_str:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either id_token or access_token is required",
        )

    if id_token_str:
        try:
            idinfo = google_id_token.verify_oauth2_token(
                id_token_str,
                google_requests.Request(),
                settings.GOOGLE_CLIENT_ID,
            )
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google token",
            )
        google_user_id: str = idinfo["sub"]
        email: str = idinfo["email"]
        full_name: str = idinfo.get("name", email.split("@")[0])
    else:
        resp = http_requests.get(
            "https://www.googleapis.com/oauth2/v1/userinfo",
            params={"access_token": access_token_str},
            timeout=10,
        )
        if resp.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google access token",
            )
        userinfo = resp.json()
        google_user_id = userinfo["id"]
        email = userinfo["email"]
        full_name = userinfo.get("name", email.split("@")[0])

    # Try to find by google_oauth_id
    result = await db.execute(select(User).where(User.google_oauth_id == google_user_id))
    user = result.scalar_one_or_none()

    if not user:
        # Try to find by email (link existing account)
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user:
            user.google_oauth_id = google_user_id

    if not user:
        user = User(
            email=email,
            password_hash=None,
            google_oauth_id=google_user_id,
            full_name=full_name,
            preferred_language=LanguageCode(preferred_language),
            preferred_unit_system=UnitSystem(preferred_unit_system),
        )
        db.add(user)
        await db.flush()

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    return user


async def refresh_access_token(db: AsyncSession, refresh_token: str) -> dict:
    payload = decode_token(refresh_token)
    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )
    user_id = payload.get("sub")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )
    return create_tokens(str(user.id))
