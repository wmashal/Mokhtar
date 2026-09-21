from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import require_manager
from app.db.session import get_db
from app.models.models import InviteCode, Role, User
from app.schemas.schemas import InviteCreate, InviteOut, LoginRequest, TokenOut
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/admin-bootstrap", response_model=InviteOut)
def admin_bootstrap(db: Session = Depends(get_db)):
    """First-ever login for the system admin (phone from ADMIN_PHONE env).
    Works only until the admin's first successful login — same trust model as
    the per-building bootstrap code. Run it right after deployment."""
    if not settings.admin_phone:
        raise HTTPException(404, "No system admin configured on this server")
    has_logged_in = (
        db.query(InviteCode)
        .filter(InviteCode.phone == settings.admin_phone, InviteCode.used_at.isnot(None))
        .first()
    )
    if has_logged_in:
        raise HTTPException(409, "Admin already activated — ask any manager for a new code")
    return auth_service.create_invite_code(db, settings.admin_phone)


@router.post("/invite", response_model=InviteOut)
def create_invite(
    body: InviteCreate,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    """Mokhtar issues a one-time login code for a phone number."""
    target = db.query(User).filter(User.phone == body.phone).first()
    if target and target.role == Role.admin and current.role != Role.admin:
        raise HTTPException(403, "Cannot issue a code for the system admin")
    invite = auth_service.create_invite_code(db, body.phone)
    return invite


@router.post("/login", response_model=TokenOut)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    """Resident logs in with phone + one-time code, gets a long-lived JWT."""
    user, token = auth_service.verify_and_login(db, body.phone, body.code)
    return TokenOut(
        access_token=token,
        role=user.role,
        unit_id=user.unit_id,
        building_id=user.unit.building_id if user.unit else None,
    )
