from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import (
    check_building_access, get_current_user, require_admin, require_manager,
)
from app.db.session import get_db
from app.models.models import (
    Building, InviteCode, MeetingRsvp, MeterReading, PublicMeter, Role,
    Transaction, Unit, User,
)
from app.schemas.schemas import (
    BuildingCreate, BuildingOut, BuildingUpdate, UnitCreate, UnitOut, UnitUpdate,
)

router = APIRouter(tags=["building"])


@router.post("/buildings", response_model=BuildingOut)
def create_building(
    body: BuildingCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """System admin adds a building."""
    building = Building(**body.model_dump())
    db.add(building)
    db.commit()
    db.refresh(building)
    return building


@router.get("/buildings")
def list_buildings(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """System admin: every building with unit/manager counts."""
    out = []
    for b in db.query(Building).order_by(Building.id).all():
        users = [u.user for u in b.units if u.user]
        out.append({
            "id": b.id,
            "name": b.name,
            "address": b.address,
            "monthly_fee": b.monthly_fee,
            "water_unit_price": b.water_unit_price,
            "electricity_unit_price": b.electricity_unit_price,
            "currency": b.currency,
            "unit_count": len(b.units),
            "manager_count": sum(1 for u in users if u.role == Role.manager),
        })
    return out


@router.get("/buildings/{building_id}", response_model=BuildingOut)
def get_building(
    building_id: int,
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    building = db.get(Building, building_id)
    if not building:
        raise HTTPException(404, "Building not found")
    check_building_access(current, building_id)
    return building


@router.patch("/buildings/{building_id}", response_model=BuildingOut)
def update_building(
    building_id: int,
    body: BuildingUpdate,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    """Manager updates building settings — e.g. water/electricity prices.
    A new electricity price becomes the price of all public electricity meters."""
    building = db.get(Building, building_id)
    if not building:
        raise HTTPException(404, "Building not found")
    check_building_access(current, building_id)
    updates = body.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(building, field, value)
    if "electricity_unit_price" in updates:
        db.query(PublicMeter).filter(
            PublicMeter.building_id == building_id,
            PublicMeter.meter_type == "electricity",
        ).update({PublicMeter.unit_price: building.electricity_unit_price})
    db.commit()
    db.refresh(building)
    return building


@router.post("/buildings/{building_id}/setup-manager")
def setup_manager(
    building_id: int,
    body: UnitCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """System admin assigns the building's Mokhtar: creates his unit + manager account.
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
def bootstrap_code(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Admin issues the manager's first login code.
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
    current: User = Depends(require_manager),
):
    """Mokhtar adds a unit; creates a resident user account for its phone."""
    check_building_access(current, building_id)
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
    current: User = Depends(require_manager),
):
    """Mokhtar updates a unit: number, resident, phone, custom monthly fee.
    A phone change also moves the resident's login to the new number."""
    unit = db.get(Unit, unit_id)
    if not unit:
        raise HTTPException(404, "Unit not found")
    check_building_access(current, unit.building_id)
    updates = body.model_dump(exclude_unset=True)
    new_phone = updates.get("phone")
    if new_phone and new_phone != unit.phone:
        if db.query(Unit).filter(Unit.phone == new_phone).first():
            raise HTTPException(409, "Phone number already registered")
    for field, value in updates.items():
        setattr(unit, field, value)
    if new_phone and unit.user:
        unit.user.phone = unit.phone
    db.commit()
    db.refresh(unit)
    return unit


@router.delete("/units/{unit_id}")
def delete_unit(
    unit_id: int,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    """Mokhtar removes a unit created by mistake. Blocked when the unit has
    transactions or meter readings (history is never destroyed) or when its
    user is the building's last manager."""
    unit = db.get(Unit, unit_id)
    if not unit:
        raise HTTPException(404, "Unit not found")
    check_building_access(current, unit.building_id)

    has_history = (
        db.query(Transaction).filter(Transaction.unit_id == unit_id).first()
        or db.query(MeterReading).filter(MeterReading.unit_id == unit_id).first()
    )
    if has_history:
        raise HTTPException(
            409, "Unit has financial history — it cannot be deleted")

    user = unit.user
    if user and user.role == Role.manager:
        managers = (
            db.query(User)
            .join(Unit)
            .filter(Unit.building_id == unit.building_id, User.role == Role.manager)
            .count()
        )
        if managers <= 1:
            raise HTTPException(409, "Cannot delete the last manager's unit")

    if user:
        db.query(InviteCode).filter(InviteCode.phone == user.phone).delete()
        db.query(MeetingRsvp).filter(MeetingRsvp.user_id == user.id).delete()
        db.delete(user)
    db.delete(unit)
    db.commit()
    return {"ok": True, "deleted_unit_id": unit_id}


@router.get("/buildings/{building_id}/units", response_model=list[UnitOut])
def list_units(
    building_id: int,
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    check_building_access(current, building_id)
    return db.query(Unit).filter(Unit.building_id == building_id).all()
