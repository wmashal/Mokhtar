from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.security import require_manager
from app.db.session import get_db
from app.models.models import User
from app.schemas.schemas import InviteCreate, InviteOut, LoginRequest, TokenOut
from app.services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/invite", response_model=InviteOut)
def create_invite(
    body: InviteCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Mokhtar issues a one-time login code for a phone number."""
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
        building_id=user.unit.building_id,
    )
