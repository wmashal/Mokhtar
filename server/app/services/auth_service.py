import random
from datetime import datetime, timedelta

from fastapi import HTTPException
from jose import jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.models import InviteCode, Role, User


def ensure_admin(db: Session):
    """Seed (or elevate) the system admin from ADMIN_PHONE. Called at startup."""
    if not settings.admin_phone:
        return
    user = db.query(User).filter(User.phone == settings.admin_phone).first()
    if user:
        if user.role != Role.admin:
            user.role = Role.admin  # elevate the mokhtar's own account
            db.commit()
    else:
        db.add(User(phone=settings.admin_phone, unit_id=None, role=Role.admin))
        db.commit()


def create_invite_code(db: Session, phone: str) -> InviteCode:
    """Mokhtar issues a one-time code for a phone number."""
    code = f"{random.randint(0, 999999):06d}"
    invite = InviteCode(
        phone=phone,
        code=code,
        expires_at=datetime.utcnow() + timedelta(days=settings.invite_code_expire_days),
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)
    return invite


def verify_and_login(db: Session, phone: str, code: str) -> tuple[User, str]:
    """Verify code, burn it, return user + JWT."""
    invite = (
        db.query(InviteCode)
        .filter(InviteCode.phone == phone, InviteCode.used_at.is_(None))
        .order_by(InviteCode.created_at.desc())
        .first()
    )
    if not invite:
        raise HTTPException(404, "No pending invite for this phone number")
    if invite.expires_at < datetime.utcnow():
        raise HTTPException(410, "Code expired — ask the Mokhtar for a new one")
    if invite.attempts >= settings.invite_code_max_attempts:
        raise HTTPException(429, "Too many attempts — ask the Mokhtar for a new code")
    if invite.code != code:
        invite.attempts += 1
        db.commit()
        raise HTTPException(401, "Wrong code")

    user = db.query(User).filter(User.phone == phone).first()
    if not user:
        raise HTTPException(404, "Phone number not registered in this building")

    invite.used_at = datetime.utcnow()  # one-time use
    db.commit()

    token = jwt.encode(
        {
            "sub": str(user.id),
            "role": user.role.value,
            "unit_id": user.unit_id,
            "building_id": user.unit.building_id if user.unit else None,
            "exp": datetime.utcnow() + timedelta(days=settings.jwt_expire_days),
        },
        settings.jwt_secret,
        algorithm=settings.jwt_algorithm,
    )
    return user, token
