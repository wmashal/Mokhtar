from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import (
    check_building_access, get_current_user, require_manager,
)
from app.db.session import get_db
from app.models.models import Meeting, MeetingRsvp, User
from app.schemas.schemas import MeetingCreate, MeetingOut, MeetingUpdate, RsvpRequest

router = APIRouter(tags=["meetings"])


@router.post("/buildings/{building_id}/meetings", response_model=MeetingOut)
def create_meeting(
    building_id: int,
    body: MeetingCreate,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    check_building_access(current, building_id)
    meeting = Meeting(building_id=building_id, **body.model_dump())
    db.add(meeting)
    db.commit()
    db.refresh(meeting)
    # TODO: push notification to all residents
    return meeting


@router.get("/buildings/{building_id}/meetings", response_model=list[MeetingOut])
def list_meetings(
    building_id: int,
    db: Session = Depends(get_db),
    current: User = Depends(get_current_user),
):
    check_building_access(current, building_id)
    return (
        db.query(Meeting)
        .filter(Meeting.building_id == building_id)
        .order_by(Meeting.starts_at.desc())
        .all()
    )


@router.patch("/meetings/{meeting_id}", response_model=MeetingOut)
def update_meeting(
    meeting_id: int,
    body: MeetingUpdate,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    """Manager edits a meeting (wrong time, place, title...)."""
    meeting = db.get(Meeting, meeting_id)
    if not meeting:
        raise HTTPException(404, "Meeting not found")
    check_building_access(current, meeting.building_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(meeting, field, value)
    db.commit()
    db.refresh(meeting)
    # TODO: push notification about the change
    return meeting


@router.delete("/meetings/{meeting_id}")
def cancel_meeting(
    meeting_id: int,
    db: Session = Depends(get_db),
    current: User = Depends(require_manager),
):
    """Manager cancels a meeting; RSVPs go with it."""
    meeting = db.get(Meeting, meeting_id)
    if not meeting:
        raise HTTPException(404, "Meeting not found")
    check_building_access(current, meeting.building_id)
    db.delete(meeting)  # RSVPs cascade
    db.commit()
    # TODO: push notification about the cancellation
    return {"ok": True}


@router.post("/meetings/{meeting_id}/rsvp")
def rsvp(
    meeting_id: int,
    body: RsvpRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    meeting = db.get(Meeting, meeting_id)
    if not meeting:
        raise HTTPException(404, "Meeting not found")
    check_building_access(user, meeting.building_id)
    rsvp = (
        db.query(MeetingRsvp)
        .filter(MeetingRsvp.meeting_id == meeting_id, MeetingRsvp.user_id == user.id)
        .first()
    )
    if rsvp:
        rsvp.status = body.status
    else:
        db.add(MeetingRsvp(meeting_id=meeting_id, user_id=user.id, status=body.status))
    db.commit()
    return {"ok": True}
