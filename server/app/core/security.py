from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.models.models import Role, User

bearer = HTTPBearer()


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    try:
        payload = jwt.decode(
            creds.credentials, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise HTTPException(401, "Invalid or expired token")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(401, "User not found")
    return user


def require_manager(user: User = Depends(get_current_user)) -> User:
    if user.role != Role.manager:
        raise HTTPException(403, "Manager role required")
    return user
