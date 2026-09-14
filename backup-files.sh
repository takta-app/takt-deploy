#!/usr/bin/env bash
# Tarball of the work-item file store (S3 volume). pg_dump does not include it.
# Run from deploy/ on a cron next to ./audit-prune.sh. Compose does not start this.
#
#   FILES_BACKUP_DIR   destination on the host (default ./file-backups)
#   FILES_BACKUP_KEEP  tarballs to keep (default 14)
#
# Object keys live in Postgres, so pair each tarball with a dump from the same
# window. Copy both off-site; a local directory is not a DR plan.
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f .env ]]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

DEST="${FILES_BACKUP_DIR:-./file-backups}"
KEEP="${FILES_BACKUP_KEEP:-14}"
if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [[ "$KEEP" -lt 1 ]]; then
	echo "FILES_BACKUP_KEEP must be a positive integer" >&2
	exit 1
fi

# Compose project `takt-install` + volume `takt-install-s3-data` (compose.yaml).
VOLUME="${FILES_BACKUP_VOLUME:-takt-install_takt-install-s3-data}"
if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
	echo "Docker volume ${VOLUME} not found. Is the stack up? (override with FILES_BACKUP_VOLUME)" >&2
	exit 1
fi

mkdir -p "$DEST"
dest_abs="$(cd "$DEST" && pwd)"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
name="takt-files-${ts}.tar.gz"

docker run --rm \
	-v "${VOLUME}:/data:ro" \
	-v "${dest_abs}:/out" \
	alpine:3 \
	sh -c "tar -czf /out/${name}.tmp -C /data . && mv /out/${name}.tmp /out/${name}"
echo "wrote ${dest_abs}/${name}"

# Filenames are takt-files-YYYYMMDDTHHMMSSZ.tar.gz — no spaces.
i=0
for file in $(ls -1t "$dest_abs"/takt-files-*.tar.gz 2>/dev/null || true); do
	i=$((i + 1))
	if [[ "$i" -gt "$KEEP" ]]; then
		rm -f "$file"
	fi
done
