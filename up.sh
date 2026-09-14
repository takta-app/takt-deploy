#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

WAIT_TIMEOUT="${TAKT_WAIT_TIMEOUT:-600}"

env_val() {
  local key="$1"
  grep "^${key}=" .env 2>/dev/null | cut -d= -f2- | tail -1 || true
}

set_env_val() {
  local key="$1"
  local value="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v k="$key" -v v="$value" '
    BEGIN { FS=OFS="=" }
    $1 == k { print k, v; seen=1; next }
    { print }
    END { if (!seen) print k "=" v }
  ' .env >"$tmp"
  mv "$tmp" .env
}

if [[ ! -f .env ]]; then
  umask 077
  secret="$(openssl rand -base64 32)"
  {
    echo "AUTH_SECRET=${secret}"
    grep -v '^AUTH_SECRET=' .env.example
  } > .env
  echo "Wrote deploy/.env with a generated AUTH_SECRET."
fi

secret="$(env_val AUTH_SECRET)"
if [[ -z "${secret}" ]]; then
  # .env copied from .env.example by hand: fill in the secret instead of failing.
  secret="$(openssl rand -base64 32)"
  umask 077
  { echo "AUTH_SECRET=${secret}"; grep -v '^AUTH_SECRET=' .env; } > .env.tmp && mv .env.tmp .env
  echo "AUTH_SECRET was empty; generated one in .env."
fi

takt_version="$(env_val TAKT_VERSION)"
if [[ -z "${takt_version}" ]]; then
  echo "TAKT_VERSION is required in .env (Hub tag without a v-prefix, e.g. 0.2.0)." >&2
  exit 1
fi
if [[ "${takt_version}" == v* ]]; then
  takt_version="${takt_version#v}"
  set_env_val TAKT_VERSION "$takt_version"
  echo "TAKT_VERSION stripped to ${takt_version} (Docker Hub tags have no v-prefix)."
fi

url="$(env_val AUTH_URL)"
url="${url:-http://localhost:3001}"
root="$(cd .. && pwd)"

use_build=0
compose_args=()
for arg in "$@"; do
  if [[ "$arg" == "--build" ]]; then
    use_build=1
  else
    compose_args+=("$arg")
  fi
done

echo "Takt:  ${url}/register"
# The CLI (MCP) is optional. The tester bundle (scripts/package-tester.sh)
# ships it as ./cli with prebuilt binaries; a clone has it at ../cli.
cli_install=""
cli_docs=""
if [[ -f "./cli/install.sh" ]]; then
  cli_install="$(pwd)/cli/install.sh"
  cli_docs="README.md (CLI och MCP)"
elif [[ -f "${root}/cli/install.sh" ]]; then
  cli_install="${root}/cli/install.sh"
  cli_docs="${root}/docs/mcp.md"
fi
if [[ -n "$cli_install" ]]; then
  cat <<EOF
CLI:   ${cli_install}
Then:  takt login --url ${url}
MCP:   command: takt, args: ["mcp"]
Token stays in takt login; do not put TAKT_TOKEN in MCP config.
See ${cli_docs}
EOF
fi
echo

compose() {
  docker compose --env-file .env "$@"
}

if [[ "$use_build" -eq 1 ]]; then
  compose -f compose.yaml -f compose.build.yaml up -d --wait --wait-timeout "$WAIT_TIMEOUT" postgres s3
else
  compose up -d --wait --wait-timeout "$WAIT_TIMEOUT" postgres s3
fi

compose stop backup >/dev/null 2>&1 || true

ts="$(date -u +%Y%m%dT%H%M%SZ)"
dump="/backups/takt-pre-update-${ts}.dump"
echo "Dumping database to ${dump} (volume) before migrate…"
compose exec -T postgres pg_dump -U takt -d takt -Fc -f "$dump"

if [[ "$use_build" -eq 1 ]]; then
  if [[ ${#compose_args[@]} -gt 0 ]]; then
    compose -f compose.yaml -f compose.build.yaml up --build -d --wait --wait-timeout "$WAIT_TIMEOUT" "${compose_args[@]}"
  else
    compose -f compose.yaml -f compose.build.yaml up --build -d --wait --wait-timeout "$WAIT_TIMEOUT" postgres s3 app
  fi
else
  compose pull app
  if [[ ${#compose_args[@]} -gt 0 ]]; then
    compose up -d --wait --wait-timeout "$WAIT_TIMEOUT" "${compose_args[@]}"
  else
    compose up -d --wait --wait-timeout "$WAIT_TIMEOUT" postgres s3 app
  fi
fi

compose up -d backup

compose ps
echo "Open ${url}/register — create the first account, then complete the setup wizard."
