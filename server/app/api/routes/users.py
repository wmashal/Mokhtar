from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import check_building_access, require_manager
from app.db.session import get_db
from app.models.models import InviteCode, MeetingRsvp, Role, Unit, User
from app.schemas.schemas import RoleUpdate, UnitOut, UnitUpdate, UserOut

router = APIRouter(tags=["users"])


def _same_building_or_403(unit: Unit, current: User):
    check_building_access(current, unit.building_id)


@router.get("/buildings/{building_id}/users", response_model=list[UserOut])
def list_users(
    building_id: int,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    check_building_access(current, building_id)
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
    The system-admin role is deployment-level (ADMIN_PHONE) — never granted here.
    """
    if body.role == Role.admin:
        raise HTTPException(403, "System admin is configured on the server, not here")
    target = db.get(User, user_id)
    if not target:
        raise HTTPException(404, "User not found")
    if target.role == Role.admin:
        raise HTTPException(403, "Cannot change the system admin's role")
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
    if target.role == Role.admin:
        raise HTTPException(403, "Cannot deactivate the system admin")
    _same_building_or_403(target.unit, current)
    if target.id == current.id:
        raise HTTPException(409, "You cannot remove yourself")

    unit = target.unit
    db.query(InviteCode).filter(InviteCode.phone == target.phone).delete()
    db.query(MeetingRsvp).filter(MeetingRsvp.user_id == target.id).delete()
    db.delete(target)
    db.commit()
    return unit
