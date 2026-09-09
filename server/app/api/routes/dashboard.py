from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.security import get_current_user, require_manager
from app.db.session import get_db
from app.models.models import Transaction, TxType, Unit, User

router = APIRouter(tags=["dashboard"])


def _month_range(month: date):
    start = datetime(month.year, month.month, 1)
    if month.month == 12:
        end = datetime(month.year + 1, 1, 1)
    else:
        end = datetime(month.year, month.month + 1, 1)
    return start, end


@router.get("/units/{unit_id}/dashboard")
def my_dashboard(
    unit_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Resident dashboard: my balance + what I paid this month."""
    if user.unit_id != unit_id and user.role.value != "manager":
        raise HTTPException(403, "Not your unit")
    unit = db.get(Unit, unit_id)
    if not unit:
        raise HTTPException(404, "Unit not found")

    start, end = _month_range(date.today().replace(day=1))
    paid_this_month = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(
            Transaction.unit_id == unit_id,
            Transaction.type == TxType.payment,
            Transaction.created_at >= start,
            Transaction.created_at < end,
        )
        .scalar()
    )
    charged_this_month = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(
            Transaction.unit_id == unit_id,
            Transaction.type == TxType.charge,
            Transaction.created_at >= start,
            Transaction.created_at < end,
        )
        .scalar()
    )
    return {
        "unit_id": unit.id,
        "resident_name": unit.resident_name,
        "balance": unit.balance,
        "paid_this_month": paid_this_month,
        "charged_this_month": charged_this_month,
    }


@router.get("/buildings/{building_id}/dashboard")
def building_dashboard(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    """Manager dashboard: building totals + per-unit breakdown."""
    start, end = _month_range(date.today().replace(day=1))

    units = db.query(Unit).filter(Unit.building_id == building_id).all()
    per_unit = []
    total_balance = 0
    total_paid = 0
    total_charged = 0

    for unit in units:
        paid = (
            db.query(func.coalesce(func.sum(Transaction.amount), 0))
            .filter(
                Transaction.unit_id == unit.id,
                Transaction.type == TxType.payment,
                Transaction.created_at >= start,
                Transaction.created_at < end,
            )
            .scalar()
        )
        charged = (
            db.query(func.coalesce(func.sum(Transaction.amount), 0))
            .filter(
                Transaction.unit_id == unit.id,
                Transaction.type == TxType.charge,
                Transaction.created_at >= start,
                Transaction.created_at < end,
            )
            .scalar()
        )
        total_balance += unit.balance
        total_paid += paid
        total_charged += charged
        per_unit.append({
            "unit_id": unit.id,
            "unit_number": unit.unit_number,
            "resident_name": unit.resident_name,
            "balance": unit.balance,
            "paid_this_month": paid,
            "charged_this_month": charged,
        })

    # building-level expenses this month (not tied to a unit)
    expenses = (
        db.query(func.coalesce(func.sum(Transaction.amount), 0))
        .filter(
            Transaction.building_id == building_id,
            Transaction.type == TxType.expense,
            Transaction.created_at >= start,
            Transaction.created_at < end,
        )
        .scalar()
    )

    return {
        "building_id": building_id,
        "total_balance": total_balance,
        "total_paid_this_month": total_paid,
        "total_charged_this_month": total_charged,
        "expenses_this_month": expenses,
        "units": per_unit,
    }
