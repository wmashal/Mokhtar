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
| Building | `GET/PATCH /buildings/{id}` — manager edits fee/water/electricity prices; electricity price propagates to public electricity meters |
| Units | `POST/GET /buildings/{id}/units`, `PATCH /units/{id}` (number/name/phone/fee; phone change moves the login), `DELETE /units/{id}` (409 if financial history or last manager) |
| Users | `GET /buildings/{id}/users`, `PATCH /users/{id}/role` (promote/demote co-managers), `DELETE /users/{id}` (removes login; unit + history kept) |
| Finance | `POST/GET /buildings/{id}/transactions`, `GET /units/{id}/statement`, `POST /buildings/{id}/charges/run` (manual monthly charge trigger) |
| Meters | `POST /buildings/{id}/meter-rounds` → `POST /meter-rounds/{id}/readings` (accepts `photo_path` + `bill_photo_path`) → `POST /meter-rounds/{id}/issue`; `GET /units/{id}/meter-readings` |
| Public meters | `POST/GET /buildings/{id}/public-meters`, `POST /public-meters/{id}/readings` (photos supported; cost auto-recorded as building expense) |
| Photos | `POST /photos` (manager upload, JPEG/PNG/WebP), `GET /photos/{name}` (any resident — transparency) |
| Meetings | `POST/GET /buildings/{id}/meetings`, `POST /meetings/{id}/rsvp` |
| Announcements | `POST/GET /buildings/{id}/announcements` |

## Notes

- Currency: ILS (configurable per building via `DEFAULT_CURRENCY`).
- Auth: Mokhtar-issued one-time 6-digit codes (no SMS) → long-lived JWT.
- Monthly fees: automatic cron job charges all units on the 1st at 06:00 (per-unit fee override supported; unpaid amounts stay as debt). Manual trigger via `/charges/run`.
- User management: manager can promote residents to co-manager, demote them, and deactivate users (unit + financial history are preserved). The building's last manager cannot be demoted.
- Push notifications: Firebase FCM (planned) — users register their device token; server sends pushes on charges, invoices, meetings, announcements.
- Tables are auto-created on startup (Alembic migrations come later).
- Photos: stored under `PHOTOS_DIR` (volume `/data/photos` in compose); meter + bill photos attach to both water and public-meter readings; receipts via `receipt_photo_path`.

## Deploying on Raspberry Pi

Tested target: **Pi 4/5 running Raspberry Pi OS 64-bit** (arm64 — required; the 32-bit OS won't run the images).

```bash
# On the Pi (Docker + Docker Compose plugin installed):
sudo apt update && sudo apt install -y docker.io docker-compose-v2  # or the official Docker script
git clone <repo> && cd Mokhtar/server
JWT_SECRET=<random-long-string> docker compose up -d --build
```

- Both services have `restart: unless-stopped` — they come back after a Pi reboot.
- API listens on `http://<pi-lan-ip>:8000`. Point the app at it:
  `flutter build apk --dart-define=API_URL=http://192.168.1.50:8000` (use the Pi's real IP; consider a DHCP reservation so it never changes).
- Use an SSD for the Postgres volume, not the SD card.
- Backups: `scripts/backup.sh` dumps Postgres + photos to `~/mokhtar-backups` (keeps 14 days). Install with cron: `0 3 * * * /home/pi/Mokhtar/server/scripts/backup.sh`.
- Remote access (optional): Cloudflare Tunnel or WireGuard — see main README §4.1.
- Note: schema changes need a manual `ALTER` or a fresh volume (Alembic migrations not wired yet).
