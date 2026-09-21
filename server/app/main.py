from fastapi import FastAPI
from sqlalchemy import text

from app.api.routes import announcements, auth, buildings, dashboard, finance, meetings, meters, photos, users
from app.core.config import settings
from app.db.session import SessionLocal, engine
from app.jobs.scheduler import start_scheduler
from app.services import auth_service

app = FastAPI(title=settings.app_name, version="0.1.0")


def _migrate():
    """Idempotent schema tweaks that create_all does not cover (old DBs)."""
    with engine.begin() as conn:
        # system admin has no unit (added 2026-09; no-op on fresh DBs)
        conn.execute(text("ALTER TABLE users ALTER COLUMN unit_id DROP NOT NULL"))
        conn.execute(text("ALTER TYPE role ADD VALUE IF NOT EXISTS 'admin'"))


@app.on_event("startup")
def _startup():
    _migrate()
    with SessionLocal() as db:
        auth_service.ensure_admin(db)
    start_scheduler()

app.include_router(auth.router)
app.include_router(buildings.router)
app.include_router(dashboard.router)
app.include_router(finance.router)
app.include_router(meters.router)
app.include_router(meetings.router)
app.include_router(announcements.router)
app.include_router(photos.router)
app.include_router(users.router)


@app.get("/health")
def health():
    return {"status": "ok"}
