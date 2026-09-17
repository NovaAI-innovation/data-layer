#!/usr/bin/env bash
# data-layer/scripts/wire-mcp.sh — mirrored methodology.
#
# Wires the Agent Zero runtime's MCP server (az-retrieval-mcp) so it can read
# AND write (via the install-governed bootstrap paths) against the postgres
# service running in the same compose stack. Designed to be run from outside
# the Agent Zero container (typically on the docker host) — it uses docker
# exec to modify the A0 container's /a0/usr/settings.json, install the MCP
# entrypoint tree from the data-layer-adapters submodule, restart the run_ui
# supervisor program, and verify via the 36-test e2e suite FROM WITHIN the
# A0 runtime.
#
# This is the "mirrored methodology" the principal directive 2026-09-17
# required: it works against ANY compose-deployed Agent Zero stack because it
# reads container names + credentials from the live compose network and the
# host's .env, not from hardcoded paths.
#
# Usage:
#   bash scripts/wire-mcp.sh                            # auto-discover
#   bash scripts/wire-mcp.sh <a0_container> <compose_project>
#   bash scripts/wire-mcp.sh --dry-run                  # show plan only
#   bash scripts/wire-mcp.sh --skip-restart             # for manual restart
#
# Exit codes:
#   0 = all checks green (e2e 36/36, settings.json valid, run_ui RUNNING)
#   2 = usage / bad args
#   3 = compose / docker unavailable
#   4 = A0 container not found
#   5 = MCP install failed
#   6 = run_ui restart failed
#   7 = e2e suite failed (any non-ok status)

set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [<a0_container> [compose_project]] [--dry-run] [--skip-restart]

Auto-discovers the A0 container (looks for one whose image is the A0 image)
and the compose project (current directory). With explicit args, uses them
verbatim. --dry-run prints the plan and exits 0. --skip-restart does not
restart run_ui (use when you'll restart manually).
USAGE
}

log()  { printf '[wire-mcp %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf '[wire-mcp FAIL] %s\n' "$*" >&2; exit 3; }

DRY_RUN=0
SKIP_RESTART=0
explicit_a0=""
explicit_project=""
for arg in "$@"; do
  case "$arg" in
    --dry-run)       DRY_RUN=1 ;;
    --skip-restart)  SKIP_RESTART=1 ;;
    --help|-h)       usage; exit 0 ;;
    -*)              usage >&2; exit 2 ;;
    *)               if [[ -z "$explicit_a0" ]]; then explicit_a0="$arg"; elif [[ -z "$explicit_project" ]]; then explicit_project="$arg"; else usage >&2; exit 2; fi ;;
  esac
done

command -v docker >/dev/null 2>&1 || fail "docker not available on PATH"
docker info >/dev/null 2>&1 || fail "docker daemon not responding"
command -v docker >/dev/null && docker compose version >/dev/null 2>&1 || fail "docker compose plugin missing"

# --- discover A0 container + compose project --------------------------------
discover_a0() {
  if [[ -n "$explicit_a0" ]]; then echo "$explicit_a0"; return; fi
  # A0 container pattern: container_name starts with data-layer-a0 (per compose)
  docker ps -a --format '{{.Names}}' | grep -E '^(data-layer-)?a0(-|$)' | head -1 || true
}

discover_project() {
  if [[ -n "$explicit_project" ]]; then echo "$explicit_project"; return; fi
  # Use cwd as project root if a compose file is here, else the umbrella repo
  if [[ -f docker-compose.yml ]]; then basename "$(pwd)"; return; fi
  local base
  base="${DATA_LAYER_BASE:-/opt/data-layer}"
  if [[ -f "$base/docker-compose.yml" ]]; then basename "$base"; return; fi
  echo "data-layer"
}

A0_CONT=$(discover_a0)
PROJECT=$(discover_project)

[[ -n "$A0_CONT" ]] || fail "no A0 container found (expected 'a0' or 'data-layer-a0'; pass it explicitly: $0 <a0_container>)"
docker inspect "$A0_CONT" >/dev/null 2>&1 || fail "A0 container '$A0_CONT' not present in docker (use explicit name?)"

# --- discover the postgres service + read its password from .env -----------
ENV_FILE="${ENV_FILE:-${DATA_LAYER_BASE:-/opt/data-layer}/.env}"
[[ -f "$ENV_FILE" ]] || fail ".env not found at $ENV_FILE (export ENV_FILE or set DATA_LAYER_BASE)"

POSTGRES_PASSWORD=$(grep -E '^POSTGRES_PASSWORD=' "$ENV_FILE" | head -1 | cut -d= -f2-)
DATA_LAYER_AGENT_ZERO_PASSWORD=$(grep -E '^DATA_LAYER_AGENT_ZERO_PASSWORD=' "$ENV_FILE" | head -1 | cut -d= -f2-)
[[ -n "$POSTGRES_PASSWORD" ]] || fail "POSTGRES_PASSWORD missing from $ENV_FILE"
[[ -n "$DATA_LAYER_AGENT_ZERO_PASSWORD" ]] || fail "DATA_LAYER_AGENT_ZERO_PASSWORD missing from $ENV_FILE"

# Postgres service hostname inside the compose network (standard internal port)
POSTGRES_SVC="${POSTGRES_SVC:-data-layer-postgres}"
DSN="postgresql://postgres:${POSTGRES_PASSWORD}@${POSTGRES_SVC}:5432/postgres"
DSN_AGENT_ZERO="postgresql://agent_zero:${DATA_LAYER_AGENT_ZERO_PASSWORD}@${POSTGRES_SVC}:5432/postgres"

# --- plan ------------------------------------------------------------------
cat <<PLAN
[wire-mcp] PLAN
  A0 container   : $A0_CONT
  compose project: $PROJECT
  postgres svc   : $POSTGRES_SVC:5432
  DSN (postgres) : $DSN
PLAN

if [[ "$DRY_RUN" == "1" ]]; then
  log "dry-run complete; no changes made"
  exit 0
fi

# --- 1. install the MCP entrypoint + tree into the A0 container ------------
log "step 1/5 — installing MCP entrypoint + tree into $A0_CONT:/a0/usr/mcp/"
ADAPTERS_DIR="${ADAPTERS_DIR:-${DATA_LAYER_BASE:-/opt/data-layer}/data-layer-adapters}"
[[ -d "$ADAPTERS_DIR/mcp" ]] || fail "adapters MCP source not found at $ADAPTERS_DIR/mcp"

docker exec -i "$A0_CONT" sh -c 'mkdir -p /a0/usr/mcp && rm -rf /a0/usr/mcp/__pycache__'
# Stream the tree in (tar over stdin handles directories cleanly)
tar czf - -C "$ADAPTERS_DIR" mcp | docker exec -i "$A0_CONT" sh -c 'cd /a0/usr && tar xzf -'
# The adapters mcp/ source does not carry a top-level __init__.py (it is a
# plain namespace package on disk). Create one in the deployed location so
# `import mcp.tests.test_server` resolves cleanly from inside the A0 runtime.
docker exec "$A0_CONT" sh -c 'test -f /a0/usr/mcp/__init__.py || touch /a0/usr/mcp/__init__.py'
docker exec "$A0_CONT" sh -c 'ls /a0/usr/mcp/server.py /a0/usr/mcp/__init__.py /a0/usr/mcp/tests >/dev/null 2>&1 && echo MCP_ENTRYPOINT_OK || echo MCP_ENTRYPOINT_MISSING'

# --- 2. patch /a0/usr/settings.json inside the A0 container ---------------
log "step 2/5 — wiring MCP DSN into /a0/usr/settings.json inside $A0_CONT"
docker exec -i \
  -e "WIRE_MCP_DSN=$DSN" \
  -e "WIRE_MCP_AGENT_ZERO_DSN=$DSN_AGENT_ZERO" \
  "$A0_CONT" /opt/venv-a0/bin/python - <<PY
import json, os, sys
path='/a0/usr/settings.json'
try:
    s=json.load(open(path))
except Exception as e:
    print('SETTINGS_READ_FAIL', e); sys.exit(5)
dsn = os.environ.get('WIRE_MCP_DSN') or ''
dsn2 = os.environ.get('WIRE_MCP_AGENT_ZERO_DSN') or ''
servers = json.loads(s['mcp_servers'])
if 'mcpServers' not in servers: servers['mcpServers'] = {}
servers['mcpServers']['az-retrieval-mcp'] = {
    'command': 'python3',
    'args': ['/a0/usr/mcp/server.py'],
    'env': {
        'DATA_LAYER_POSTGRES_DSN': dsn,
        'DATA_LAYER_AGENT_ZERO_DSN': dsn2,
    },
}
s['mcp_servers'] = json.dumps(servers, indent=2)
json.dump(s, open(path, 'w'), indent=2)
print('SETTINGS_WRITTEN')
PY

# --- 3. restart the run_ui supervisor program ------------------------------
if [[ "$SKIP_RESTART" == "1" ]]; then
  log "step 3/5 — SKIPPED restart (--skip-restart)"
else
  log "step 3/5 — restarting run_ui inside $A0_CONT (supervisor bounce)"
  docker exec "$A0_CONT" supervisorctl restart run_ui 2>&1 | head -3 || fail "supervisorctl restart failed inside $A0_CONT"
  sleep 4
fi

# --- 4. wait for run_ui to come RUNNING ------------------------------------
log "step 4/5 — waiting for run_ui to be RUNNING"
for i in $(seq 1 30); do
  st=$(docker exec "$A0_CONT" supervisorctl status run_ui 2>/dev/null | awk '{print $2}' || echo "UNKNOWN")
  if [[ "$st" == "RUNNING" ]]; then log "run_ui RUNNING after ${i}s"; break; fi
  sleep 1
done
[[ "$st" == "RUNNING" ]] || fail "run_ui not RUNNING after 30s (last: $st)"

# --- 5. run the 36-test e2e suite FROM WITHIN the A0 runtime --------------
log "step 5/5 — running MCP e2e suite (36 tests) from within $A0_CONT"
TEST_OUT=$(docker exec -e "DATA_LAYER_TEST_DSN=$DSN" "$A0_CONT" sh -c '
  cd /a0/usr
  PYTHONPATH=/a0/usr /opt/venv-a0/bin/python -m unittest mcp.tests.test_server -v 2>&1 | tail -60
')
echo "$TEST_OUT" | tail -50

if echo "$TEST_OUT" | grep -qE '^OK(\s|$)'; then
  RAN=$(echo "$TEST_OUT" | grep -oE 'Ran [0-9]+ tests' | awk '{print $2}')
  log "PASS — $RAN tests OK in MCP e2e (mirrored methodology verified from within $A0_CONT runtime)"
  exit 0
elif echo "$TEST_OUT" | grep -qE '^FAILED'; then
  log "FAIL — MCP e2e suite reported failures (see output above)"
  exit 7
else
  log "FAIL — MCP e2e suite did not report OK or FAILED (see output)"
  exit 7
fi
