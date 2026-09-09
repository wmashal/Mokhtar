from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.security import get_current_user, require_manager
from app.db.session import get_db
from app.models.models import Meeting, MeetingRsvp, User
from app.schemas.schemas import MeetingCreate, MeetingOut, RsvpRequest

router = APIRouter(tags=["meetings"])


@router.post("/buildings/{building_id}/meetings", response_model=MeetingOut)
def create_meeting(
    building_id: int,
    body: MeetingCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
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
    _: User = Depends(get_current_user),
):
    return (
        db.query(Meeting)
        .filter(Meeting.building_id == building_id)
        .order_by(Meeting.starts_at.desc())
        .all()
    )


@router.post("/meetings/{meeting_id}/rsvp")
def rsvp(
    meeting_id: int,
    body: RsvpRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if not db.get(Meeting, meeting_id):
        raise HTTPException(404, "Meeting not found")
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
