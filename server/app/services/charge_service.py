from datetime import date

from sqlalchemy.orm import Session

from app.models.models import Building, Transaction, TxType, Unit


def generate_monthly_charges(db: Session, building_id: int, month: date) -> dict:
    """Charge each unit its monthly fee for `month` (first day of month).

    Idempotent: skips units already charged for that month.
    Fee: unit.monthly_fee if set, else building.monthly_fee.
    """
    building = db.get(Building, building_id)
    if not building:
        raise ValueError("Building not found")

    note_marker = f"Monthly fee {month:%Y-%m}"
    charged, skipped = [], []

    for unit in db.query(Unit).filter(Unit.building_id == building_id).all():
        already = (
            db.query(Transaction)
            .filter(
                Transaction.unit_id == unit.id,
                Transaction.type == TxType.charge,
                Transaction.category == "monthly_fee",
                Transaction.note == note_marker,
            )
            .first()
        )
        if already:
            skipped.append(unit.id)
            continue

        fee = unit.monthly_fee if unit.monthly_fee is not None else building.monthly_fee
        if fee <= 0:
            skipped.append(unit.id)
            continue

        unit.balance -= fee
        db.add(Transaction(
            building_id=building_id,
            unit_id=unit.id,
            type=TxType.charge,
            amount=fee,
            category="monthly_fee",
            note=note_marker,
        ))
        charged.append(unit.id)

    db.commit()
    return {"month": f"{month:%Y-%m}", "charged": charged, "skipped": skipped}


def charge_all_buildings(db: Session, month: date) -> list[dict]:
    """Entry point for the scheduler: charge every building."""
    results = []
    for building in db.query(Building).all():
        results.append(generate_monthly_charges(db, building.id, month))
    return results
