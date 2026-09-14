#!/bin/sh
# Instance snapshots for Takt. Runs next to Postgres (Compose), not in the app.
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backups}"
INTERVAL="${BACKUP_INTERVAL_SECS:-1800}"
KEEP="${BACKUP_KEEP:-48}"

mkdir -p "$BACKUP_DIR"

trap 'exit 0' TERM INT HUP

dump() {
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  dest="$BACKUP_DIR/takt-${ts}.dump"
  tmp="${dest}.tmp"
  pg_dump -Fc -f "$tmp"
  chmod 644 "$tmp"
  mv "$tmp" "$dest"
  echo "wrote $dest"

  i=0
  # Filenames are takt-YYYYMMDDTHHMMSSZ.dump — no spaces.
  set -- $(ls -1t "$BACKUP_DIR"/takt-*.dump 2>/dev/null || true)
  for file in "$@"; do
    i=$((i + 1))
    if [ "$i" -gt "$KEEP" ]; then
      rm -f "$file"
    fi
  done
}

dump
while true; do
  sleep "$INTERVAL" &
  wait $! || true
  dump
done
