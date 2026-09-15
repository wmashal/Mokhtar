import re
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app.core.config import settings
from app.core.security import get_current_user, require_manager
from app.models.models import User

router = APIRouter(tags=["photos"])

_ALLOWED = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
_NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")


@router.post("/photos")
def upload_photo(file: UploadFile, _: User = Depends(require_manager)):
    """Mokhtar uploads a photo (meter / bill / receipt). Returns the stored name."""
    ext = _ALLOWED.get(file.content_type)
    if not ext:
        raise HTTPException(415, "Only JPEG/PNG/WebP images are allowed")
    dest = Path(settings.photos_dir)
    dest.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}{ext}"
    (dest / name).write_bytes(file.file.read())
    return {"path": name}


@router.get("/photos/{name}")
def get_photo(name: str, _: User = Depends(get_current_user)):
    """Every resident can view any photo — transparency (meter proof, bills)."""
    if not _NAME_RE.match(name) or ".." in name:
        raise HTTPException(400, "Invalid photo name")
    path = Path(settings.photos_dir) / name
    if not path.is_file():
        raise HTTPException(404, "Photo not found")
    return FileResponse(path)
