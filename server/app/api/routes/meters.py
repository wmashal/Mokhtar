from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import require_manager, get_current_user
from app.db.session import get_db
from app.models.models import (
    Building, MeterReading, MeterRound, PublicMeter, PublicMeterReading,
    RoundStatus, Transaction, TxType, Unit, User,
)
from app.schemas.schemas import (
    MeterRoundCreate, MeterRoundOut, PublicMeterCreate, PublicMeterOut,
    PublicReadingCreate, PublicReadingOut, ReadingCreate, ReadingOut,
)

router = APIRouter(tags=["meters"])


def _last_reading_value(db: Session, building_id: int, unit_id: int):
    """Most recent confirmed reading for a unit, used as 'previous'."""
    row = (
        db.query(MeterReading)
        .join(MeterRound)
        .filter(MeterRound.building_id == building_id, MeterReading.unit_id == unit_id)
        .order_by(MeterReading.created_at.desc())
        .first()
    )
    return row.current_value if row else None


@router.post("/buildings/{building_id}/meter-rounds", response_model=MeterRoundOut)
def open_round(
    building_id: int,
    body: MeterRoundCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Mokhtar opens a monthly reading round."""
    round_ = MeterRound(building_id=building_id, month=body.month)
    db.add(round_)
    db.commit()
    db.refresh(round_)
    return round_


@router.post("/meter-rounds/{round_id}/readings", response_model=ReadingOut)
def add_reading(
    round_id: int,
    body: ReadingCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Record one unit's reading; computes consumption and cost automatically."""
    round_ = db.get(MeterRound, round_id)
    if not round_:
        raise HTTPException(404, "Round not found")
    if round_.status != RoundStatus.open:
        raise HTTPException(409, "Round already issued")

    building = db.get(Building, round_.building_id)
    previous = _last_reading_value(db, round_.building_id, body.unit_id)
    if previous is None:
        previous = body.current_value  # first-ever reading → zero consumption
    if body.current_value < previous:
        raise HTTPException(422, "Current reading is lower than previous")

    consumption = body.current_value - previous
    cost = consumption * building.water_unit_price

    reading = MeterReading(
        round_id=round_id,
        unit_id=body.unit_id,
        previous_value=previous,
        current_value=body.current_value,
        consumption=consumption,
        cost=cost,
        photo_path=body.photo_path,
        bill_photo_path=body.bill_photo_path,
    )
    db.add(reading)
    db.commit()
    db.refresh(reading)
    return reading


@router.post("/meter-rounds/{round_id}/issue", response_model=MeterRoundOut)
def issue_round(
    round_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Close the round: each reading becomes a charge on the unit's balance."""
    round_ = db.get(MeterRound, round_id)
    if not round_:
        raise HTTPException(404, "Round not found")
    if round_.status != RoundStatus.open:
        raise HTTPException(409, "Round already issued")

    for reading in round_.readings:
        if reading.cost > 0:
            unit = db.get(Unit, reading.unit_id)
            unit.balance -= reading.cost
            db.add(Transaction(
                building_id=round_.building_id,
                unit_id=reading.unit_id,
                type=TxType.charge,
                amount=reading.cost,
                category="water",
                note=f"Water {round_.month:%Y-%m}: {reading.consumption} units",
            ))

    round_.status = RoundStatus.issued
    db.commit()
    db.refresh(round_)
    return round_


@router.get("/buildings/{building_id}/meter-rounds", response_model=list[MeterRoundOut])
def list_rounds(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return (
        db.query(MeterRound)
        .filter(MeterRound.building_id == building_id)
        .order_by(MeterRound.month.desc())
        .all()
    )


# ---------- Resident: my water reading history ----------

@router.get("/units/{unit_id}/meter-readings")
def my_readings(
    unit_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """A resident sees their own meter history: previous/current/diff/cost per month."""
    if user.unit_id != unit_id and user.role.value != "manager":
        raise HTTPException(403, "Not your unit")
    rows = (
        db.query(MeterReading, MeterRound)
        .join(MeterRound, MeterReading.round_id == MeterRound.id)
        .filter(MeterReading.unit_id == unit_id)
        .order_by(MeterRound.month.desc())
        .all()
    )
    return [
        {
            "month": round_.month,
            "previous_value": r.previous_value,
            "current_value": r.current_value,
            "consumption": r.consumption,
            "cost": r.cost,
            "photo_path": r.photo_path,
            "bill_photo_path": r.bill_photo_path,
        }
        for r, round_ in rows
    ]


# ---------- Public meters (shared building electricity etc.) ----------

@router.post("/buildings/{building_id}/public-meters", response_model=PublicMeterOut)
def create_public_meter(
    building_id: int,
    body: PublicMeterCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    if not db.get(Building, building_id):
        raise HTTPException(404, "Building not found")
    meter = PublicMeter(building_id=building_id, **body.model_dump())
    # Electricity meters default to the building's kWh price (from Settings)
    if meter.meter_type == "electricity" and not meter.unit_price:
        meter.unit_price = db.get(Building, building_id).electricity_unit_price
    db.add(meter)
    db.commit()
    db.refresh(meter)
    return meter


@router.get("/buildings/{building_id}/public-meters")
def list_public_meters(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """All residents can see public meters with their readings (transparency)."""
    meters = db.query(PublicMeter).filter(PublicMeter.building_id == building_id).all()
    return [
        {
            "id": m.id,
            "name": m.name,
            "meter_type": m.meter_type,
            "unit_price": m.unit_price,
            "readings": [
                {
                    "id": r.id,
                    "month": r.month,
                    "previous_value": r.previous_value,
                    "current_value": r.current_value,
                    "consumption": r.consumption,
                    "cost": r.cost,
                    "photo_path": r.photo_path,
                    "bill_photo_path": r.bill_photo_path,
                }
                for r in sorted(m.readings, key=lambda x: x.month, reverse=True)
            ],
        }
        for m in meters
    ]


@router.post("/public-meters/{meter_id}/readings", response_model=PublicReadingOut)
def add_public_reading(
    meter_id: int,
    body: PublicReadingCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Record a monthly reading for a shared meter; computes consumption & cost."""
    meter = db.get(PublicMeter, meter_id)
    if not meter:
        raise HTTPException(404, "Meter not found")

    last = (
        db.query(PublicMeterReading)
        .filter(PublicMeterReading.meter_id == meter_id)
        .order_by(PublicMeterReading.month.desc())
        .first()
    )
    previous = last.current_value if last else body.current_value
    if body.current_value < previous:
        raise HTTPException(422, "Current reading is lower than previous")

    consumption = body.current_value - previous
    cost = consumption * meter.unit_price

    reading = PublicMeterReading(
        meter_id=meter_id,
        month=body.month,
        previous_value=previous,
        current_value=body.current_value,
        consumption=consumption,
        cost=cost,
        photo_path=body.photo_path,
        bill_photo_path=body.bill_photo_path,
    )
    db.add(reading)

    # record the cost as a building expense
    if cost > 0:
        db.add(Transaction(
            building_id=meter.building_id,
            unit_id=None,
            type=TxType.expense,
            amount=cost,
            category=meter.meter_type,
            note=f"{meter.name} {body.month:%Y-%m}: {consumption} units",
        ))

    db.commit()
    db.refresh(reading)
    return reading
