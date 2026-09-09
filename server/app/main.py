from fastapi import FastAPI

from app.api.routes import announcements, auth, buildings, dashboard, finance, meetings, meters, users
from app.core.config import settings
from app.jobs.scheduler import start_scheduler

app = FastAPI(title=settings.app_name, version="0.1.0")


@app.on_event("startup")
def _startup():
    start_scheduler()

app.include_router(auth.router)
app.include_router(buildings.router)
app.include_router(dashboard.router)
app.include_router(finance.router)
app.include_router(meters.router)
app.include_router(meetings.router)
app.include_router(announcements.router)
app.include_router(users.router)


@app.get("/health")
def health():
    return {"status": "ok"}
