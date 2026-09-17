#!/usr/bin/env bash
# Stop Takt. Containers and network are removed; the database, S3 files and
# backups stay in their Docker volumes, so compose up brings everything back.
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
# AUTH_SECRET empty until openssl fills it; a dummy here is only for interpolation.
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
  # An earlier copy of this folder (other path, other Compose project name)
  # can leave takt-install-* containers, networks and volumes that still hold
  # the ports. Remove those too. Local dev is project "takt" (takt-postgres,
  # takt-s3, takt-backup, takt_takt-*) and does not match this prefix.
  leftover_containers="$(docker ps -aq --filter 'name=takt-install-' 2>/dev/null || true)"
  if [[ -n "$leftover_containers" ]]; then
    # shellcheck disable=SC2086
    docker rm -f $leftover_containers >/dev/null
  fi
  leftover_networks="$(docker network ls -q --filter 'name=takt-install' 2>/dev/null || true)"
  if [[ -n "$leftover_networks" ]]; then
    # shellcheck disable=SC2086
    docker network rm $leftover_networks >/dev/null 2>&1 || true
  fi
  leftover_volumes="$(docker volume ls -q --filter 'name=takt-install-' 2>/dev/null || true)"
  if [[ -n "$leftover_volumes" ]]; then
    # shellcheck disable=SC2086
    docker volume rm $leftover_volumes >/dev/null
  fi
  echo "Takt stopped and all data removed. docker compose --env-file .env up -d starts a fresh installation."
else
  compose_down down --remove-orphans
  echo "Takt stopped. Data kept; docker compose --env-file .env up -d starts it again."
fi
