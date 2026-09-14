#!/usr/bin/env bash
# Customer entrypoint. start/stop wrap up.sh/down.sh. upgrade fetches the
# matching Compose files from GitHub Releases (takta-app/takt-deploy) and
# merges .env so AUTH_SECRET and local URLs survive.
set -euo pipefail

cd "$(dirname "$0")"

GH_REPO="${TAKT_DEPLOY_REPO:-takta-app/takt-deploy}"
API_LATEST="https://api.github.com/repos/${GH_REPO}/releases/latest"
DOWNLOAD="https://github.com/${GH_REPO}/releases/download"

usage() {
  cat <<EOF
Usage: ./setup.sh [start|stop|upgrade] [args…]

  start     Start (or recreate) the stack. Same as ./up.sh
  stop      Stop. Same as ./down.sh (pass --purge to wipe data)
  upgrade   Fetch the latest GitHub Release, merge .env, then start

Hub image tag (TAKT_VERSION) has no v-prefix: 0.2.0
GitHub Release / CLI tag has a v-prefix:     v0.2.0
EOF
}

env_val() {
  local file="$1"
  local key="$2"
  grep "^${key}=" "$file" 2>/dev/null | cut -d= -f2- | tail -1 || true
}

latest_tag() {
  local json tag
  json="$(curl -fsSL "$API_LATEST")"
  tag="$(printf '%s' "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"
  if [[ -z "$tag" ]]; then
    echo "Could not read latest release from ${API_LATEST}" >&2
    exit 1
  fi
  printf '%s\n' "$tag"
}

download_asset() {
  local tag="$1"
  local name="$2"
  local dest="$3"
  local url="${DOWNLOAD}/${tag}/${name}"
  echo "GET ${url}"
  curl -fsSL "$url" -o "$dest"
}

merge_env() {
  local old="$1"
  local template="$2"
  local dest="$3"
  local version="$4"
  local tmp
  tmp="$(mktemp)"
  umask 077
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" || "$line" == \#* ]]; then
      printf '%s\n' "$line" >>"$tmp"
      continue
    fi
    local key="${line%%=*}"
    local def="${line#*=}"
    if [[ "$key" == "TAKT_VERSION" ]]; then
      printf 'TAKT_VERSION=%s\n' "$version" >>"$tmp"
      continue
    fi
    local prev=""
    if [[ -f "$old" ]]; then
      prev="$(env_val "$old" "$key")"
    fi
    if [[ -n "$prev" ]]; then
      printf '%s=%s\n' "$key" "$prev" >>"$tmp"
    else
      printf '%s=%s\n' "$key" "$def" >>"$tmp"
    fi
  done <"$template"
  mv "$tmp" "$dest"
}

upgrade() {
  command -v curl >/dev/null || { echo "curl is required for upgrade" >&2; exit 1; }
  [[ -f .env ]] || { echo "No .env — run ./setup.sh start first." >&2; exit 1; }

  local tag version current
  tag="$(latest_tag)"
  version="${tag#v}"
  current="$(env_val .env TAKT_VERSION)"
  current="${current#v}"

  echo "Installed: ${current:-unknown}"
  echo "Latest:    ${version} (${tag})"
  if [[ -n "$current" && "$current" == "$version" ]]; then
    echo "Already on ${version}."
    exit 0
  fi

  read -r -p "Upgrade to ${version}? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi

  echo "Stopping…"
  ./down.sh

  local ts archive
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  archive="archive/${ts}"
  mkdir -p "$archive"
  [[ -f compose.yaml ]] && cp compose.yaml "$archive/"
  [[ -f .env ]] && cp .env "$archive/"
  echo "Archived compose.yaml and .env under ${archive}/"

  local work
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  for f in compose.yaml up.sh down.sh backup-loop.sh setup.sh env.example NOTICE; do
    download_asset "$tag" "$f" "${work}/${f}" || {
      echo "Missing ${f} on ${tag}. Is the GitHub Release complete?" >&2
      exit 1
    }
  done
  chmod +x "${work}/up.sh" "${work}/down.sh" "${work}/setup.sh"
  mv "${work}/env.example" "${work}/.env.example"

  merge_env .env "${work}/.env.example" .env "$version"
  cp "${work}/compose.yaml" "${work}/up.sh" "${work}/down.sh" "${work}/backup-loop.sh" \
    "${work}/setup.sh" "${work}/.env.example" "${work}/NOTICE" .

  rm -rf "$work"
  trap - RETURN
  echo "Starting ${version}…"
  exec ./up.sh
}

cmd="${1:-start}"
shift || true
case "$cmd" in
  start | up) exec ./up.sh "$@" ;;
  stop | down) exec ./down.sh "$@" ;;
  upgrade) upgrade ;;
  -h | --help | help) usage ;;
  *)
    echo "unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
