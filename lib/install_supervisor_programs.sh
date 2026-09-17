#!/usr/bin/env bash
# data-layer/lib/install_supervisor_programs.sh — generate + install supervisor
# programs for the native data-layer deployment (unique names data-layer-*).
#
# DEPRECATED 2026-09-17: the canonical deployment path is now docker compose
# (docker-compose.yml at the repo root; hardened A0 via deploy/). This script
# is retained for optional native-mode hosts ONLY (per docs/remediation
# playbook: compose = initial approach, supervisor programs = fallback rung).
# Do not use inside the Agent Zero runtime container.
#
# Idempotent: re-running writes identical bytes when nothing changed; supervisor
# picks changes up via reread/update at the end. NEVER starts programs —
# starting belongs to service_ctl.sh ensure (health-first, 3-rung ladder).
#
# Ports follow the +1 rule (docs/remediation-2026-09-16.md §1):
#   postgres 5433, valkey 6380, falkordb 6381, qdrant 6334/6335.
set -euo pipefail

SOURCE="${BASH_SOURCE[0]:-$0}"
LIB_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
DATA_LAYER_BASE="${DATA_LAYER_BASE:-$(cd "$LIB_DIR/.." && pwd)}"
# shellcheck disable=SC1091
[[ -f "$DATA_LAYER_BASE/.env" ]] && { set -a; source "$DATA_LAYER_BASE/.env"; set +a; }

PG_PORT="${DATA_LAYER_PG_PORT:-5433}"
REDIS_PORT="${DATA_LAYER_REDIS_PORT:-6380}"
FALKORDB_PORT="${DATA_LAYER_FALKORDB_PORT:-6381}"
QDRANT_HTTP_PORT="${DATA_LAYER_QDRANT_HTTP_PORT:-6334}"
QDRANT_GRPC_PORT="${DATA_LAYER_QDRANT_GRPC_PORT:-6335}"

PG_BIN="$(ls /usr/lib/postgresql/*/bin/postgres 2>/dev/null | sort -V | tail -1 || true)"
PG_BIN="${PG_BIN:-/usr/lib/postgresql/18/bin/postgres}"
PG_DATA="${PG_DATA:-/var/lib/postgresql/18/main}"
PG_CONF="${PG_CONF:-/etc/postgresql/18/main/postgresql.conf}"
VALKEY_BIN="${VALKEY_BIN:-/usr/bin/valkey-server}"
REDIS_BIN="${REDIS_BIN:-/usr/bin/redis-server}"
FALKORDB_SO="${FALKORDB_SO:-/var/lib/falkordb/bin/falkordb.so}"
QDRANT_BIN="${QDRANT_BIN:-/usr/local/bin/qdrant}"
QDRANT_CONF="${QDRANT_CONF:-/opt/qdrant/config/production.yaml}"
HOOK_PY="$DATA_LAYER_BASE/data-layer-adapters/lib/redis_publish_hook.py"
A0_PY="${A0_PY:-/opt/venv/bin/python}"
CONF_DIR="/etc/supervisor/conf.d"

log()  { printf '[sup-programs %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf '[sup-programs FAIL] %s\n' "$*" >&2; exit 3; }

[[ -d "$CONF_DIR" ]] || fail "supervisor conf dir missing: $CONF_DIR (is supervisord installed?)"
mkdir -p /var/lib/valkey /var/lib/falkordb/data /opt/qdrant/config /opt/qdrant/snapshots /var/log/data-layer

# --- native qdrant config on +1 host ports (derived from repo template) ---
if [[ -f "$DATA_LAYER_BASE/data-layer-qdrant/qdrant_config.yaml" ]]; then
  sed -e "s/^  http_port:.*/  http_port: $QDRANT_HTTP_PORT/" \
      -e "s/^  grpc_port:.*/  grpc_port: $QDRANT_GRPC_PORT/" \
      -e "s#^  storage_path:.*#  storage_path: /opt/qdrant/storage#" \
      "$DATA_LAYER_BASE/data-layer-qdrant/qdrant_config.yaml" > "$QDRANT_CONF"
  log "qdrant native config written: $QDRANT_CONF (http=$QDRANT_HTTP_PORT grpc=$QDRANT_GRPC_PORT)"
fi

write_conf() {
  local file="$1" content="$2"
  if [[ -f "$file" ]] && [[ "$(cat "$file")" == "$content" ]]; then
    log "unchanged: $file"
  else
    printf '%s\n' "$content" > "$file"
    log "written: $file"
  fi
}

# --- postgres (SOT; listens on PG_PORT per postgresql.conf cutover) ---
write_conf "$CONF_DIR/data-layer-postgres.conf" "[program:data-layer-postgres]
command=$PG_BIN -D $PG_DATA -c config_file=$PG_CONF
user=postgres
priority=10
autostart=true
autorestart=true
startsecs=5
startretries=5
stopsignal=INT
stopwaitsecs=30
stdout_logfile=/var/log/data-layer/postgres.log
stderr_logfile=/var/log/data-layer/postgres.err.log"

# --- valkey (ephemeral cache; no persistence by contract) ---
write_conf "$CONF_DIR/data-layer-valkey.conf" "[program:data-layer-valkey]
command=$VALKEY_BIN --bind 127.0.0.1 --port $REDIS_PORT --dir /var/lib/valkey --save \"\" --appendonly no --daemonize no
user=valkey
priority=20
autostart=true
autorestart=true
startsecs=3
startretries=5
stopwaitsecs=10
stdout_logfile=/var/log/data-layer/valkey.log
stderr_logfile=/var/log/data-layer/valkey.err.log"

# --- falkordb (graph module; RDB snapshot for graph durability) ---
write_conf "$CONF_DIR/data-layer-falkordb.conf" "[program:data-layer-falkordb]
command=$REDIS_BIN --loadmodule $FALKORDB_SO --bind 127.0.0.1 --port $FALKORDB_PORT --dir /var/lib/falkordb/data --save 60 1 --daemonize no
priority=30
autostart=true
autorestart=true
startsecs=3
startretries=5
stopwaitsecs=15
stdout_logfile=/var/log/data-layer/falkordb.log
stderr_logfile=/var/log/data-layer/falkordb.err.log"

# --- qdrant (vector/RAG; native binary + +1 host-port config) ---
write_conf "$CONF_DIR/data-layer-qdrant.conf" "[program:data-layer-qdrant]
command=$QDRANT_BIN --config-path $QDRANT_CONF
priority=40
autostart=true
autorestart=true
startsecs=5
startretries=5
stopwaitsecs=30
stdout_logfile=/var/log/data-layer/qdrant.log
stderr_logfile=/var/log/data-layer/qdrant.err.log"

# --- publish-hook sidecar (best-effort; optional) ---
if [[ -f "$HOOK_PY" ]]; then
  write_conf "$CONF_DIR/data-layer-hook.conf" "[program:data-layer-hook]
command=$A0_PY $HOOK_PY
priority=50
autostart=true
autorestart=true
startsecs=3
startretries=3
stopwaitsecs=10
environment=DATA_LAYER_REDIS_URL=\"redis://localhost:$REDIS_PORT/0\",DATA_LAYER_REDIS_HOST=\"localhost\",DATA_LAYER_REDIS_PORT=\"$REDIS_PORT\",DATA_LAYER_REDIS_PREFIX=\"dl:\",DATA_LAYER_POSTGRES_DSN=\"postgresql://postgres@localhost:$PG_PORT/postgres\",DATA_LAYER_DW_SESSION_PRESENCE=\"true\",DATA_LAYER_DW_TOOL_EXECUTION=\"true\"
stdout_logfile=/var/log/data-layer/hook.log
stderr_logfile=/var/log/data-layer/hook.err.log"
else
  log "publish hook not present; skipping data-layer-hook program"
fi

if command -v supervisorctl >/dev/null 2>&1; then
  supervisorctl reread || true
  supervisorctl update || true
  log "supervisor registered data-layer programs"
else
  fail "supervisorctl not available; programs written but not registered"
fi
log "done"
