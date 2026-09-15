from datetime import datetime, date
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, Field

from app.models.models import Role, TxType, RoundStatus, RsvpStatus


# ---------- Auth ----------
class InviteCreate(BaseModel):
    phone: str = Field(min_length=5, max_length=30)


class InviteOut(BaseModel):
    phone: str
    code: str
    expires_at: datetime


class LoginRequest(BaseModel):
    phone: str
    code: str = Field(min_length=4, max_length=6)


class TokenOut(BaseModel):
    access_token: str
    role: Role
    unit_id: int
    building_id: int


# ---------- Building / Units ----------
class BuildingCreate(BaseModel):
    name: str
    address: str = ""
    monthly_fee: Decimal = Decimal(0)
    water_unit_price: Decimal = Decimal(0)
    electricity_unit_price: Decimal = Decimal(0)


class BuildingOut(BaseModel):
    id: int
    name: str
    address: str
    monthly_fee: Decimal
    water_unit_price: Decimal
    electricity_unit_price: Decimal
    currency: str

    class Config:
        from_attributes = True


class BuildingUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    monthly_fee: Optional[Decimal] = None
    water_unit_price: Optional[Decimal] = None
    electricity_unit_price: Optional[Decimal] = None


class UnitCreate(BaseModel):
    unit_number: str
    resident_name: str
    phone: str
    monthly_fee: Optional[Decimal] = None  # null → building default


class UnitUpdate(BaseModel):
    unit_number: Optional[str] = None
    resident_name: Optional[str] = None
    phone: Optional[str] = None
    monthly_fee: Optional[Decimal] = None


class UserOut(BaseModel):
    id: int
    phone: str
    unit_id: int
    role: Role

    class Config:
        from_attributes = True


class RoleUpdate(BaseModel):
    role: Role


class UnitOut(BaseModel):
    id: int
    unit_number: str
    resident_name: str
    phone: str
    monthly_fee: Optional[Decimal]
    balance: Decimal

    class Config:
        from_attributes = True


# ---------- Transactions ----------
class TransactionCreate(BaseModel):
    unit_id: Optional[int] = None
    type: TxType
    amount: Decimal
    category: str = ""
    note: str = ""


class TransactionOut(BaseModel):
    id: int
    unit_id: Optional[int]
    type: TxType
    amount: Decimal
    category: str
    note: str
    receipt_photo_path: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


# ---------- Meters ----------
class MeterRoundCreate(BaseModel):
    month: date  # first day of month


class ReadingCreate(BaseModel):
    unit_id: int
    current_value: Decimal
    photo_path: Optional[str] = None       # meter photo — proof
    bill_photo_path: Optional[str] = None  # water bill — proof


class ReadingOut(BaseModel):
    id: int
    unit_id: int
    previous_value: Decimal
    current_value: Decimal
    consumption: Decimal
    cost: Decimal
    photo_path: Optional[str]
    bill_photo_path: Optional[str]

    class Config:
        from_attributes = True


class MeterRoundOut(BaseModel):
    id: int
    month: date
    status: RoundStatus
    readings: list[ReadingOut] = []

    class Config:
        from_attributes = True


class PublicMeterCreate(BaseModel):
    name: str
    meter_type: str = "electricity"
    unit_price: Decimal = Decimal(0)


class PublicMeterOut(BaseModel):
    id: int
    name: str
    meter_type: str
    unit_price: Decimal

    class Config:
        from_attributes = True


class PublicReadingCreate(BaseModel):
    month: date
    current_value: Decimal
    photo_path: Optional[str] = None       # meter photo — proof
    bill_photo_path: Optional[str] = None  # company bill — proof


class PublicReadingOut(BaseModel):
    id: int
    meter_id: int
    month: date
    previous_value: Decimal
    current_value: Decimal
    consumption: Decimal
    cost: Decimal
    photo_path: Optional[str]
    bill_photo_path: Optional[str]

    class Config:
        from_attributes = True


# ---------- Meetings ----------
class MeetingCreate(BaseModel):
    title: str
    starts_at: datetime
    location: str = ""
    agenda: str = ""


class MeetingOut(BaseModel):
    id: int
    title: str
    starts_at: datetime
    location: str
    agenda: str

    class Config:
        from_attributes = True


class RsvpRequest(BaseModel):
    status: RsvpStatus


# ---------- Announcements ----------
class AnnouncementCreate(BaseModel):
    body: str


class AnnouncementOut(BaseModel):
    id: int
    body: str
    created_at: datetime

    class Config:
        from_attributes = True
