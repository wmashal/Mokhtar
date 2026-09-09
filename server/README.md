# Mokhtar Server

FastAPI + PostgreSQL backend for the Mokhtar building-management app. Designed to run on a Raspberry Pi 5 via Docker.

## Quick start (local dev)

```bash
cd server
docker compose up -d --build
# API at http://localhost:8000 — docs at http://localhost:8000/docs
```

## Run tests

```bash
python3 tests/e2e.py
```

## API overview

| Flow | Endpoints |
|---|---|
| Bootstrap | `POST /buildings` → `POST /buildings/{id}/setup-manager` → `POST /buildings/{id}/bootstrap-code` |
| Auth | `POST /auth/invite` (manager) → `POST /auth/login` (phone + code → JWT) |
| Units | `POST/GET /buildings/{id}/units`, `PATCH /units/{id}` (custom fee) |
| Users | `GET /buildings/{id}/users`, `PATCH /users/{id}/role` (promote/demote co-managers), `DELETE /users/{id}` (removes login; unit + history kept) |
| Finance | `POST/GET /buildings/{id}/transactions`, `GET /units/{id}/statement`, `POST /buildings/{id}/charges/run` (manual monthly charge trigger) |
| Meters | `POST /buildings/{id}/meter-rounds` → `POST /meter-rounds/{id}/readings` → `POST /meter-rounds/{id}/issue` |
| Meetings | `POST/GET /buildings/{id}/meetings`, `POST /meetings/{id}/rsvp` |
| Announcements | `POST/GET /buildings/{id}/announcements` |

## Notes

- Currency: ILS (configurable per building via `DEFAULT_CURRENCY`).
- Auth: Mokhtar-issued one-time 6-digit codes (no SMS) → long-lived JWT.
- Monthly fees: automatic cron job charges all units on the 1st at 06:00 (per-unit fee override supported; unpaid amounts stay as debt). Manual trigger via `/charges/run`.
- User management: manager can promote residents to co-manager, demote them, and deactivate users (unit + financial history are preserved). The building's last manager cannot be demoted.
- Push notifications: Firebase FCM (planned) — users register their device token; server sends pushes on charges, invoices, meetings, announcements.
- Tables are auto-created on startup (Alembic migrations come later).
- Photo upload endpoint for meters/receipts: TODO (Phase 2).

## Deploying on Raspberry Pi

```bash
# On the Pi (Docker + Docker Compose installed):
git clone <repo> && cd Mokhtar/server
JWT_SECRET=<random-long-string> docker compose up -d --build
```

- Use an SSD for the Postgres volume, not the SD card.
- Backups: nightly `docker compose exec db pg_dump -U mokhtar mokhtar > backup.sql`.
- Remote access (optional): Cloudflare Tunnel or WireGuard — see main README §4.1.
