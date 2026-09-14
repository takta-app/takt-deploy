#!/bin/sh
# Official Postgres 18+ images store the cluster at $PGDATA
# (/var/lib/postgresql/19/docker) and mount the volume at /var/lib/postgresql.
# Takt volumes created before that change hold cluster files at the volume root
# (old mount: /var/lib/postgresql/data). Rearrange, then start the image.
set -eu

ROOT="${TAKT_PG_ROOT:-/var/lib/postgresql}"
PGDATA="${PGDATA:-$ROOT/19/docker}"

is_cluster() {
	[ -f "$1/PG_VERSION" ]
}

move_cluster() {
	src="$1"
	dest="$2"
	mkdir -p "$dest"
	for path in "$src"/*; do
		[ -e "$path" ] || continue
		name="${path##*/}"
		# Skip the major-version directory the dest lives in.
		case "$name" in
		[0-9] | [0-9][0-9]) continue ;;
		esac
		mv "$path" "$dest/"
	done
}

if ! is_cluster "$PGDATA"; then
	if is_cluster "$ROOT"; then
		move_cluster "$ROOT" "$PGDATA"
	elif is_cluster "$ROOT/data"; then
		move_cluster "$ROOT/data" "$PGDATA"
	fi
fi

if [ "${TAKT_PG_MIGRATE_ONLY:-}" = "1" ]; then
	exit 0
fi

exec docker-entrypoint.sh "$@"
