#!/usr/bin/env bash
# Delete org audit_event rows older than AUDIT_RETENTION_DAYS (default 365).
# Run from deploy/ against the install stack. Compose does not start this.
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f .env ]]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

DAYS="${AUDIT_RETENTION_DAYS:-365}"
if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]]; then
	echo "AUDIT_RETENTION_DAYS must be a positive integer" >&2
	exit 1
fi

docker compose --env-file .env exec -T postgres \
	psql -U takt -d takt -v ON_ERROR_STOP=1 \
	-c "DELETE FROM audit_event WHERE \"createdAt\" < now() - make_interval(days => ${DAYS});"
