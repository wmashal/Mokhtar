import enum
from datetime import datetime, date

from sqlalchemy import (
    Column, Integer, String, ForeignKey, DateTime, Date, Enum, Numeric, Text, Boolean
)
from sqlalchemy.orm import relationship

from app.db.session import Base


class Role(str, enum.Enum):
    manager = "manager"
    resident = "resident"


class TxType(str, enum.Enum):
    charge = "charge"      # monthly fee or invoice added to a unit's debt
    payment = "payment"    # resident paid
    expense = "expense"    # building money spent


class RoundStatus(str, enum.Enum):
    open = "open"
    issued = "issued"


class RsvpStatus(str, enum.Enum):
    attending = "attending"
    not_attending = "not_attending"


class Building(Base):
    __tablename__ = "buildings"
    id = Column(Integer, primary_key=True)
    name = Column(String(200), nullable=False)
    address = Column(String(300), default="")
    monthly_fee = Column(Numeric(12, 2), nullable=False, default=0)
    water_unit_price = Column(Numeric(12, 4), nullable=False, default=0)
    currency = Column(String(3), nullable=False, default="ILS")
    created_at = Column(DateTime, default=datetime.utcnow)

    units = relationship("Unit", back_populates="building", cascade="all, delete-orphan")


class Unit(Base):
    __tablename__ = "units"
    id = Column(Integer, primary_key=True)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=False)
    unit_number = Column(String(20), nullable=False)
    resident_name = Column(String(200), nullable=False)
    phone = Column(String(30), nullable=False, unique=True, index=True)
    monthly_fee = Column(Numeric(12, 2), nullable=True)  # null → use building default
    balance = Column(Numeric(12, 2), nullable=False, default=0)  # negative = owes money
    created_at = Column(DateTime, default=datetime.utcnow)

    building = relationship("Building", back_populates="units")
    user = relationship("User", back_populates="unit", uselist=False)


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    phone = Column(String(30), nullable=False, unique=True, index=True)
    unit_id = Column(Integer, ForeignKey("units.id"), nullable=False)
    role = Column(Enum(Role), nullable=False, default=Role.resident)
    fcm_token = Column(String(500), nullable=True)  # device token for push
    created_at = Column(DateTime, default=datetime.utcnow)

    unit = relationship("Unit", back_populates="user")


class InviteCode(Base):
    """One-time login code issued by the Mokhtar for a phone number."""
    __tablename__ = "invite_codes"
    id = Column(Integer, primary_key=True)
    phone = Column(String(30), nullable=False, index=True)
    code = Column(String(6), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    attempts = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)


class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=False)
    unit_id = Column(Integer, ForeignKey("units.id"), nullable=True)  # null for building-level expenses
    type = Column(Enum(TxType), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False)
    category = Column(String(50), default="")  # elevator, electricity, cleaning, water, other
    note = Column(Text, default="")
    receipt_photo_path = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class MeterRound(Base):
    __tablename__ = "meter_rounds"
    id = Column(Integer, primary_key=True)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=False)
    month = Column(Date, nullable=False)  # first day of the month
    status = Column(Enum(RoundStatus), nullable=False, default=RoundStatus.open)
    created_at = Column(DateTime, default=datetime.utcnow)

    readings = relationship("MeterReading", back_populates="round", cascade="all, delete-orphan")


class MeterReading(Base):
    __tablename__ = "meter_readings"
    id = Column(Integer, primary_key=True)
    round_id = Column(Integer, ForeignKey("meter_rounds.id"), nullable=False)
    unit_id = Column(Integer, ForeignKey("units.id"), nullable=False)
    previous_value = Column(Numeric(12, 2), nullable=False)
    current_value = Column(Numeric(12, 2), nullable=False)
    consumption = Column(Numeric(12, 2), nullable=False)
    cost = Column(Numeric(12, 2), nullable=False)
    photo_path = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    round = relationship("MeterRound", back_populates="readings")


class Meeting(Base):
    __tablename__ = "meetings"
    id = Column(Integer, primary_key=True)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=False)
    title = Column(String(200), nullable=False)
    starts_at = Column(DateTime, nullable=False)
    location = Column(String(300), default="")
    agenda = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.utcnow)

    rsvps = relationship("MeetingRsvp", back_populates="meeting", cascade="all, delete-orphan")


class MeetingRsvp(Base):
    __tablename__ = "meeting_rsvps"
    id = Column(Integer, primary_key=True)
    meeting_id = Column(Integer, ForeignKey("meetings.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    status = Column(Enum(RsvpStatus), nullable=False)

    meeting = relationship("Meeting", back_populates="rsvps")


class Announcement(Base):
    __tablename__ = "announcements"
    id = Column(Integer, primary_key=True)
    building_id = Column(Integer, ForeignKey("buildings.id"), nullable=False)
    body = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
