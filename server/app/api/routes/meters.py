from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import require_manager, get_current_user
from app.db.session import get_db
from app.models.models import (
    Building, MeterReading, MeterRound, RoundStatus, Transaction, TxType, Unit, User,
)
from app.schemas.schemas import (
    MeterRoundCreate, MeterRoundOut, ReadingCreate, ReadingOut,
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
