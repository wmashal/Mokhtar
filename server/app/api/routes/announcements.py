from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.security import get_current_user, require_manager
from app.db.session import get_db
from app.models.models import Announcement, User
from app.schemas.schemas import AnnouncementCreate, AnnouncementOut

router = APIRouter(tags=["announcements"])


@router.post("/buildings/{building_id}/announcements", response_model=AnnouncementOut)
def create_announcement(
    building_id: int,
    body: AnnouncementCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_manager),
):
    ann = Announcement(building_id=building_id, body=body.body)
    db.add(ann)
    db.commit()
    db.refresh(ann)
    # TODO: push notification to all residents
    return ann


@router.get("/buildings/{building_id}/announcements", response_model=list[AnnouncementOut])
def list_announcements(
    building_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    return (
        db.query(Announcement)
        .filter(Announcement.building_id == building_id)
        .order_by(Announcement.created_at.desc())
        .all()
    )
