# Mokhtar Server

FastAPI + PostgreSQL backend for the Mokhtar building-management app. Designed to run on a Raspberry Pi 4/5 via Docker.

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

On the Pi, run them in a throwaway stack so the real database stays clean
(fresh volumes, API on 8001, wiped afterwards):

```bash
API_PORT=8001 DB_PORT=15432 docker compose -p mokhtar-e2e up -d --build
BASE_URL=http://localhost:8001 python3 tests/e2e.py
docker compose -p mokhtar-e2e down -v
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
| Meters | `POST /buildings/{id}/meter-rounds` → `POST /meter-rounds/{id}/readings` (accepts `photo_path` + `bill_photo_path`) → `POST /meter-rounds/{id}/issue`; corrections while open: `PATCH/DELETE /readings/{id}`, `DELETE /meter-rounds/{id}` (409 once issued); `GET /units/{id}/meter-readings` |
| Public meters | `POST/GET /buildings/{id}/public-meters`, `POST /public-meters/{id}/readings` (photos supported; cost auto-recorded as building expense) |
| Photos | `POST /photos` (manager upload, JPEG/PNG/WebP), `GET /photos/{name}` (any resident — transparency) |
| Meetings | `POST/GET /buildings/{id}/meetings`, `PATCH/DELETE /meetings/{id}` (manager edit/cancel), `POST /meetings/{id}/rsvp` |
| Announcements | `POST/GET /buildings/{id}/announcements` |

## Notes

- Currency: ILS (configurable per building via `DEFAULT_CURRENCY`).
- Auth: Mokhtar-issued one-time 6-digit codes (no SMS) → long-lived JWT.
- Monthly fees: automatic cron job charges all units on the 1st at 06:00 (per-unit fee override supported; unpaid amounts stay as debt). Manual trigger via `/charges/run`.
- User management: manager can promote residents to co-manager, demote them, and deactivate users (unit + financial history are preserved). The building's last manager cannot be demoted.
- Push notifications: Firebase FCM (planned) — users register their device token; server sends pushes on charges, invoices, meetings, announcements.
- Tables are auto-created on startup (Alembic migrations come later).
- Photos: stored under `PHOTOS_DIR` (volume `/data/photos` in compose); meter + bill photos attach to both water and public-meter readings; receipts via `receipt_photo_path`.

## Deploying on Raspberry Pi (full runbook)

Tested target: **Pi 4 running Raspberry Pi OS Lite 64-bit** (arm64 is **required** — the 32-bit OS won't run the images). Pi 5 works the same.

### 1. Flash the SD card (Raspberry Pi Imager)

- Device: your Pi · OS: **Raspberry Pi OS Lite (64-bit)** · Storage: the SD card.
- In the Imager's ⚙ customization: hostname `mokhtar-pi`, create username+password, configure Wi-Fi (or use Ethernet — more reliable), **enable SSH**.
- No need to pre-format the card — the Imager overwrites it. (Manual format if ever needed: MS-DOS (FAT) + Master Boot Record.)
- Raspberry Pi Connect: optional, not needed (SSH on LAN covers admin; a tunnel comes later if remote access is wanted).

### 2. Install Docker (on the Pi)

```bash
ssh <user>@mokhtar-pi.local
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker
```

### 3. Get the code

```bash
git clone https://github.com/wmashal/Mokhtar.git   # public repo — no credentials needed
cd Mokhtar/server
```

Alternative without git (copy current code from a Mac): `rsync -avz ~/AndroidStudioProjects/Mokhtar/server/ <user>@mokhtar-pi.local:Mokhtar/server/`

### 4. Launch

```bash
cd ~/Mokhtar/server
echo "JWT_SECRET=$(openssl rand -hex 32)" > .env   # permanent — compose reads it on every start/reboot
docker compose up -d --build                        # first build ~5–10 min on Pi 4
curl localhost:8000/health                          # → {"status":"ok"}
hostname -I                                         # the Pi's LAN IP, e.g. 192.168.10.65
```

- Both services have `restart: unless-stopped` — they come back after a Pi reboot.
- **Reserve the Pi's IP** in the router (DHCP reservation) so the app never breaks.
- Use an SSD (USB) for the Postgres volume if possible — SD cards wear out under a database.

### 5. Build the phone app against the Pi

```bash
# on the dev machine:
cd app && flutter build apk --release --dart-define=API_URL=http://192.168.10.65:8000
# APK: app/build/app/outputs/flutter-apk/app-release.apk
```

### 6. Bootstrap the real building (once)

```bash
curl -X POST http://<pi-ip>:8000/buildings -H 'Content-Type: application/json' \
  -d '{"name":"اسم العمارة","monthly_fee":50,"water_unit_price":2.5,"electricity_unit_price":0.65}'
curl -X POST http://<pi-ip>:8000/buildings/1/setup-manager -H 'Content-Type: application/json' \
  -d '{"unit_number":"1","resident_name":"اسم المختار","phone":"05xxxxxxxx"}'
curl -X POST http://<pi-ip>:8000/buildings/1/bootstrap-code   # → manager's first login code
```

Then log in on the phone; everything else (apartments, residents, codes, meters) is done from the app.
Equivalent direct-SQL path: insert into `buildings`, `units`, `users` (`role` = `manager`/`resident`) and one `invite_codes` row. For a test run instead: `python3 tests/seed_demo.py` on the Pi (prints demo codes); reset with `docker compose down -v && docker compose up -d`.

### 7. Database access from a client (optional)

Postgres is published on the LAN at `mokhtar-pi.local:5432` — user `mokhtar`, password `mokhtar`, database `mokhtar`, SSL off.
⚠️ Weak default password: anyone on the building Wi-Fi could connect. Harden when convenient:

```bash
docker compose exec db psql -U mokhtar -c "ALTER USER mokhtar PASSWORD 'new-strong-password';"
# then set the same value as POSTGRES_PASSWORD in docker-compose.yml and: docker compose up -d
```

CLI alternative without exposing the port: `docker compose exec db psql -U mokhtar mokhtar`.

### 8. Backups

`scripts/backup.sh` dumps Postgres + photos to `~/mokhtar-backups` (keeps 14 days):

```bash
crontab -e   # add:  0 3 * * * /home/<user>/Mokhtar/server/scripts/backup.sh
```

### Notes

- Remote access (optional): Cloudflare Tunnel or WireGuard — see main README §4.1.
- Schema changes need a manual `ALTER` or a fresh volume (Alembic migrations not wired yet).
