#!/bin/sh
# Nightly backup: Postgres dump + photos archive → ~/mokhtar-backups/
# Install on the Pi:  crontab -e  →  0 3 * * * /home/pi/Mokhtar/server/scripts/backup.sh
set -eu

DIR=~/mokhtar-backups
mkdir -p "$DIR"
STAMP=$(date +%Y%m%d_%H%M%S)

cd "$(dirname "$0")/.."
docker compose exec -T db pg_dump -U mokhtar mokhtar | gzip > "$DIR/db_$STAMP.sql.gz"
docker run --rm -v server_photos:/data alpine tar czf - -C /data . > "$DIR/photos_$STAMP.tar.gz"

# keep the last 14 days
find "$DIR" -name "db_*.sql.gz" -mtime +14 -delete
find "$DIR" -name "photos_*.tar.gz" -mtime +14 -delete
echo "backup done: $STAMP"
