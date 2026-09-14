#!/usr/bin/env bash
# Stop Takt. Containers and network are removed; the database, S3 files and
# backups stay in their Docker volumes, so ./up.sh brings everything back.
#
#   ./down.sh            stop, keep data
#   ./down.sh --purge    stop AND delete all data (asks you to confirm)
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "No .env here; nothing to stop." >&2
  exit 0
fi

purge=0
for arg in "$@"; do
  case "$arg" in
    --purge) purge=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Compose interpolates AUTH_SECRET even for `down`. The tester bundle ships
# AUTH_SECRET empty until ./up.sh; a dummy here is only for interpolation.
compose_down() {
  local secret
  secret="$(grep '^AUTH_SECRET=' .env | cut -d= -f2- || true)"
  if [[ -z "$secret" ]]; then
    AUTH_SECRET=unused docker compose --env-file .env "$@"
  else
    docker compose --env-file .env "$@"
  fi
}

if [[ "$purge" -eq 1 ]]; then
  echo "This deletes the Postgres database, uploaded files and backups of this installation."
  read -r -p "Type 'delete' to continue: " answer
  if [[ "$answer" != "delete" ]]; then
    echo "Aborted; nothing removed."
    exit 1
  fi
  compose_down down --volumes --remove-orphans
  echo "Takt stopped and all data removed. ./up.sh starts a fresh installation."
else
  compose_down down --remove-orphans
  echo "Takt stopped. Data kept; ./up.sh starts it again."
fi
