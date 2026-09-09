from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import get_current_user, require_manager
from app.db.session import get_db
from app.models.models import Building, Unit, User, Role
from app.schemas.schemas import (
    BuildingCreate, BuildingOut, UnitCreate, UnitOut, UnitUpdate,
)

router = APIRouter(tags=["building"])


@router.post("/buildings", response_model=BuildingOut)
def create_building(body: BuildingCreate, db: Session = Depends(get_db)):
    """Bootstrap: create the building (run once at setup)."""
    building = Building(**body.model_dump())
    db.add(building)
    db.commit()
    db.refresh(building)
    return building


@router.get("/buildings/{building_id}", response_model=BuildingOut)
def get_building(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    building = db.get(Building, building_id)
    if not building:
        raise HTTPException(404, "Building not found")
    return building


@router.post("/buildings/{building_id}/setup-manager")
def setup_manager(
    building_id: int,
    body: UnitCreate,
    db: Session = Depends(get_db),
):
    """One-time bootstrap: create the Mokhtar's unit + manager account.
    Only works while the building has no manager yet."""
    if not db.get(Building, building_id):
        raise HTTPException(404, "Building not found")
    has_manager = (
        db.query(User)
        .join(Unit)
        .filter(Unit.building_id == building_id, User.role == Role.manager)
        .first()
    )
    if has_manager:
        raise HTTPException(409, "Building already has a manager")

    unit = Unit(building_id=building_id, **body.model_dump())
    db.add(unit)
    db.flush()
    db.add(User(phone=body.phone, unit_id=unit.id, role=Role.manager))
    db.commit()
    return {"ok": True, "unit_id": unit.id, "hint": "Issue an invite code via /auth/invite is not possible yet — use /auth/bootstrap-code instead"}


@router.post("/buildings/{building_id}/bootstrap-code")
def bootstrap_code(building_id: int, db: Session = Depends(get_db)):
    """One-time: issue a login code for the building's manager (no auth required).
    Only works if the manager has never logged in."""
    from app.services import auth_service

    manager = (
        db.query(User)
        .join(Unit)
        .filter(Unit.building_id == building_id, User.role == Role.manager)
        .first()
    )
    if not manager:
        raise HTTPException(404, "No manager for this building")
    from app.models.models import InviteCode
    has_logged_in = (
        db.query(InviteCode)
        .filter(InviteCode.phone == manager.phone, InviteCode.used_at.isnot(None))
        .first()
    )
    if has_logged_in:
        raise HTTPException(409, "Manager already activated — use /auth/invite")

    invite = auth_service.create_invite_code(db, manager.phone)
    return {"phone": invite.phone, "code": invite.code, "expires_at": invite.expires_at}


@router.post("/buildings/{building_id}/units", response_model=UnitOut)
def add_unit(
    building_id: int,
    body: UnitCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Mokhtar adds a unit; creates a resident user account for its phone."""
    if not db.get(Building, building_id):
        raise HTTPException(404, "Building not found")
    if db.query(Unit).filter(Unit.phone == body.phone).first():
        raise HTTPException(409, "Phone number already registered")

    unit = Unit(building_id=building_id, **body.model_dump())
    db.add(unit)
    db.flush()
    db.add(User(phone=body.phone, unit_id=unit.id, role=Role.resident))
    db.commit()
    db.refresh(unit)
    return unit


@router.patch("/units/{unit_id}", response_model=UnitOut)
def update_unit(
    unit_id: int,
    body: UnitUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Mokhtar updates a unit — e.g., a custom monthly fee."""
    unit = db.get(Unit, unit_id)
    if not unit:
        raise HTTPException(404, "Unit not found")
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(unit, field, value)
    db.commit()
    db.refresh(unit)
    return unit


@router.get("/buildings/{building_id}/units", response_model=list[UnitOut])
def list_units(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return db.query(Unit).filter(Unit.building_id == building_id).all()
