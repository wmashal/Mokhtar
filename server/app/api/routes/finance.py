from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import get_current_user, require_manager
from app.db.session import get_db
from app.models.models import Transaction, TxType, Unit, User
from app.schemas.schemas import TransactionCreate, TransactionOut
from app.services.charge_service import generate_monthly_charges

router = APIRouter(tags=["finance"])


@router.post("/buildings/{building_id}/transactions", response_model=TransactionOut)
def add_transaction(
    building_id: int,
    body: TransactionCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Record a payment, charge, or expense. Updates unit balance if unit-linked."""
    tx = Transaction(building_id=building_id, **body.model_dump())

    if body.unit_id:
        unit = db.get(Unit, body.unit_id)
        if not unit or unit.building_id != building_id:
            raise HTTPException(404, "Unit not found in this building")
        if body.type == TxType.payment:
            unit.balance += body.amount
        elif body.type == TxType.charge:
            unit.balance -= body.amount

    db.add(tx)
    db.commit()
    db.refresh(tx)
    return tx


@router.get("/buildings/{building_id}/transactions", response_model=list[TransactionOut])
def list_transactions(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Full transparent statement — visible to every resident."""
    return (
        db.query(Transaction)
        .filter(Transaction.building_id == building_id)
        .order_by(Transaction.created_at.desc())
        .all()
    )


@router.post("/buildings/{building_id}/charges/run")
def run_monthly_charges(
    building_id: int,
    month: date | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Manual trigger for monthly charges (backup to the automatic 1st-of-month job).
    Idempotent — safe to run multiple times for the same month."""
    month = (month or date.today()).replace(day=1)
    return generate_monthly_charges(db, building_id, month)


@router.get("/units/{unit_id}/statement", response_model=list[TransactionOut])
def unit_statement(
    unit_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """A unit's own transactions (residents see only their own; manager sees all)."""
    if user.unit_id != unit_id and user.role.value != "manager":
        raise HTTPException(403, "Not your unit")
    return (
        db.query(Transaction)
        .filter(Transaction.unit_id == unit_id)
        .order_by(Transaction.created_at.desc())
        .all()
    )
