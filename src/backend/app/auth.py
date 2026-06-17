import hashlib
import os
from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

SECRET_KEY = os.getenv("JWT_SECRET", "gathel-secret-key-change-in-production")
ALGORITHM  = "HS256"
TOKEN_EXPIRE_HOURS = 8

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def hash_password(plain: str) -> str:
    """SHA2-256 sobre UTF-16-LE — coincide con HASHBYTES('SHA2_256', N'...') de SQL Server."""
    return hashlib.sha256(plain.encode("utf-16-le")).hexdigest().upper()


def verify_password(plain: str, stored_hash: str) -> bool:
    return hash_password(plain) == stored_hash.upper()


def create_access_token(data: dict) -> str:
    payload = data.copy()
    payload["exp"] = datetime.now(timezone.utc) + timedelta(hours=TOKEN_EXPIRE_HOURS)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def get_current_player_id(token: str = Depends(oauth2_scheme)) -> int:
    credentials_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        player_id = payload.get("sub")
        if player_id is None:
            raise credentials_exc
        return int(player_id)
    except JWTError:
        raise credentials_exc
