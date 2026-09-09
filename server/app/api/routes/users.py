from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import get_current_user, require_manager
from app.db.session import get_db
from app.models.models import InviteCode, MeetingRsvp, Role, Unit, User
from app.schemas.schemas import RoleUpdate, UnitOut, UnitUpdate, UserOut

router = APIRouter(tags=["users"])


def _same_building_or_403(unit: Unit, current: User):
    if unit.building_id != current.unit.building_id:
        raise HTTPException(403, "Not your building")


@router.get("/buildings/{building_id}/users", response_model=list[UserOut])
def list_users(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    return (
        db.query(User)
        .join(Unit)
        .filter(Unit.building_id == building_id)
        .all()
    )


@router.patch("/users/{user_id}/role", response_model=UserOut)
def change_role(
    user_id: int,
    body: RoleUpdate,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    """Promote a resident to manager (co-admin) or demote back to resident.

    Guard: you cannot demote yourself if you're the building's last manager.
    """
    target = db.get(User, user_id)
    if not target:
        raise HTTPException(404, "User not found")
    _same_building_or_403(target.unit, current)

    if target.id == current.id and body.role == Role.resident:
        managers = (
            db.query(User)
            .join(Unit)
            .filter(Unit.building_id == current.unit.building_id, User.role == Role.manager)
            .count()
        )
        if managers <= 1:
            raise HTTPException(409, "Cannot demote the last manager of the building")

    target.role = body.role
    db.commit()
    db.refresh(target)
    return target


@router.delete("/users/{user_id}", response_model=UnitOut)
def deactivate_user(
    user_id: int,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    """Remove a user's login (resident left / lost phone). The unit and its
    financial history are kept — only the login access and invite codes are removed."""
    target = db.get(User, user_id)
    if not target:
        raise HTTPException(404, "User not found")
    _same_building_or_403(target.unit, current)
    if target.id == current.id:
        raise HTTPException(409, "You cannot remove yourself")

    unit = target.unit
    db.query(InviteCode).filter(InviteCode.phone == target.phone).delete()
    db.query(MeetingRsvp).filter(MeetingRsvp.user_id == target.id).delete()
    db.delete(target)
    db.commit()
    return unit
