import logging
from datetime import date

from apscheduler.schedulers.background import BackgroundScheduler

from app.db.session import SessionLocal
from app.services.charge_service import charge_all_buildings

log = logging.getLogger("jobs")


def _monthly_charge_job():
    log.info("Running monthly charge job for %s", date.today())
    db = SessionLocal()
    try:
        results = charge_all_buildings(db, date.today().replace(day=1))
        log.info("Monthly charge results: %s", results)
    finally:
        db.close()


def start_scheduler() -> BackgroundScheduler:
    scheduler = BackgroundScheduler()
    # 1st of every month at 06:00 server local time
    scheduler.add_job(_monthly_charge_job, "cron", day=1, hour=6, minute=0,
                      id="monthly_charges", replace_existing=True)
    scheduler.start()
    log.info("Scheduler started: monthly charges on day=1 at 06:00")
    return scheduler
