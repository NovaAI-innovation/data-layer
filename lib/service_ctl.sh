#!/usr/bin/env bash
# data-layer/lib/service_ctl.sh — 3-rung service lifecycle ladder (native mode).
#
# DEPRECATED 2026-09-17: the canonical deployment path is now docker compose
# (docker-compose.yml at the repo root; hardened A0 via deploy/). Retained for
# optional native-mode hosts ONLY (fallback rung per docs/remediation
# playbook). Do not use inside the Agent Zero runtime container.
#
# Usage: service_ctl.sh {ensure|start|stop|status} [postgres|valkey|falkordb|qdrant|hook|all]
#
# Rung 1: supervisor program (autorestart persistence; unique data-layer-* names)
# Rung 2: direct launch fallback (daemonize/nohup + pidfile)
# Rung 3: fail-out-loud (non-zero exit naming the failed rung + log path)
#
# `ensure` is the idempotent entry point: healthy => no-op; unhealthy => ladder.
set -uo pipefail

SOURCE="${BASH_SOURCE[0]:-$0}"
LIB_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
DATA_LAYER_BASE="${DATA_LAYER_BASE:-$(cd "$LIB_DIR/.." && pwd)}"
# shellcheck disable=SC1091
[[ -f "$DATA_LAYER_BASE/.env" ]] && { set -a; source "$DATA_LAYER_BASE/.env"; set +a; }

PG_PORT="${DATA_LAYER_PG_PORT:-5433}"
REDIS_PORT="${DATA_LAYER_REDIS_PORT:-6380}"
FALKORDB_PORT="${DATA_LAYER_FALKORDB_PORT:-6381}"
QDRANT_HTTP_PORT="${DATA_LAYER_QDRANT_HTTP_PORT:-6334}"

PID_DIR="/var/run/data-layer"
mkdir -p "$PID_DIR" /var/log/data-layer

log()  { printf '[service_ctl %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
die()  { printf '[service_ctl FAIL] %s\n' "$*" >&2; exit 3; }

health_pg()       { pg_isready -h 127.0.0.1 -p "$PG_PORT" -q 2>/dev/null; }
health_valkey()   { redis-cli -p "$REDIS_PORT" PING 2>/dev/null | grep -q PONG; }
health_falkordb() { redis-cli -p "$FALKORDB_PORT" PING 2>/dev/null | grep -q PONG && redis-cli -p "$FALKORDB_PORT" MODULE LIST 2>/dev/null | grep -qi graph; }
health_qdrant()   { curl -fsS "http://127.0.0.1:$QDRANT_HTTP_PORT/healthz" >/dev/null 2>&1; }
health_hook()     { [[ -f "$PID_DIR/hook.pid" ]] && kill -0 "$(cat "$PID_DIR/hook.pid")" 2>/dev/null; }

health() {
  case "$1" in
    postgres)  health_pg ;;
    valkey)    health_valkey ;;
    falkordb)  health_falkordb ;;
    qdrant)    health_qdrant ;;
    hook)      health_hook ;;
    *) return 2 ;;
  esac
}

wait_health() {
  local svc="$1" tries="${2:-30}"
  for _ in $(seq 1 "$tries"); do
    health "$svc" && return 0
    sleep 1
  done
  return 1
}

sup_start() {
  command -v supervisorctl >/dev/null 2>&1 || return 1
  supervisorctl status "data-layer-$1" >/dev/null 2>&1 || return 1
  local st
  st=$(supervisorctl status "data-layer-$1" 2>/dev/null | awk '{print $2}')
  [[ "$st" == "RUNNING" ]] && return 0
  supervisorctl start "data-layer-$1" >/dev/null 2>&1 || return 1
  return 0
}

direct_start_pg() {
  if command -v pg_ctlcluster >/dev/null 2>&1 && pg_lsclusters -h 2>/dev/null | grep -q .; then
    local ver clus
    ver=$(pg_lsclusters -h | tail -1 | awk '{print $1}'); clus=$(pg_lsclusters -h | tail -1 | awk '{print $2}')
    pg_ctlcluster "$ver" "$clus" start >/dev/null 2>&1 || true
  else
    local bin
    bin=$(ls /usr/lib/postgresql/*/bin/postgres 2>/dev/null | sort -V | tail -1)
    [[ -n "$bin" ]] || return 1
    nohup su postgres -c "$bin -D /var/lib/postgresql/18/main -c config_file=/etc/postgresql/18/main/postgresql.conf" >/var/log/data-layer/postgres.direct.log 2>&1 &
  fi
}

direct_start_valkey() {
  nohup /usr/bin/valkey-server --bind 127.0.0.1 --port "$REDIS_PORT" --dir /var/lib/valkey --save "" --appendonly no --daemonize yes --pidfile "$PID_DIR/valkey.pid" >/var/log/data-layer/valkey.direct.log 2>&1
}

direct_start_falkordb() {
  nohup /usr/bin/redis-server --loadmodule /var/lib/falkordb/bin/falkordb.so --bind 127.0.0.1 --port "$FALKORDB_PORT" --dir /var/lib/falkordb/data --save 60 1 --daemonize yes --pidfile "$PID_DIR/falkordb.pid" >/var/log/data-layer/falkordb.direct.log 2>&1
}

direct_start_qdrant() {
  nohup /usr/local/bin/qdrant --config-path /opt/qdrant/config/production.yaml >/var/log/data-layer/qdrant.direct.log 2>&1 &
  echo $! > "$PID_DIR/qdrant.pid"
}

direct_start_hook() {
  local py="$DATA_LAYER_BASE/data-layer-adapters/lib/redis_publish_hook.py"
  [[ -f "$py" ]] || return 1
  DATA_LAYER_REDIS_URL="redis://localhost:$REDIS_PORT/0" \
  DATA_LAYER_REDIS_HOST=localhost DATA_LAYER_REDIS_PORT="$REDIS_PORT" \
  DATA_LAYER_REDIS_PREFIX=dl: \
  DATA_LAYER_POSTGRES_DSN="postgresql://postgres@localhost:$PG_PORT/postgres" \
  DATA_LAYER_DW_SESSION_PRESENCE=true DATA_LAYER_DW_TOOL_EXECUTION=true \
  nohup /opt/venv/bin/python "$py" >/var/log/data-layer/hook.direct.log 2>&1 &
  echo $! > "$PID_DIR/hook.pid"
}

ensure_one() {
  local svc="$1"
  if health "$svc"; then log "$svc: healthy (no action)"; return 0; fi
  log "$svc: unhealthy — rung 1 (supervisor)"
  if sup_start "$svc" && wait_health "$svc" 30; then log "$svc: healthy via supervisor"; return 0; fi
  log "$svc: supervisor rung unavailable/failed — rung 2 (direct launch)"
  "direct_start_$svc" || true
  if wait_health "$svc" 30; then log "$svc: healthy via direct launch"; return 0; fi
  printf '[service_ctl FAIL] %s: unhealthy after supervisor + direct launch (rung 3 fail-out-loud); inspect /var/log/data-layer/%s.*.log\n' "$svc" "$svc" >&2
  return 3
}

stop_one() {
  supervisorctl stop "data-layer-$1" >/dev/null 2>&1 || true
  if [[ -f "$PID_DIR/$1.pid" ]]; then
    kill "$(cat "$PID_DIR/$1.pid")" 2>/dev/null || true
    rm -f "$PID_DIR/$1.pid"
  fi
  log "$1: stopped"
}

case "${1:-ensure}" in
  ensure|start)
    target="${2:-all}"
    if [[ "$target" == "all" ]]; then
      overall=0
      for svc in postgres valkey falkordb qdrant hook; do ensure_one "$svc" || overall=$?; done
      exit "$overall"
    fi
    ensure_one "$target" ;;
  stop)
    target="${2:-all}"
    if [[ "$target" == "all" ]]; then for svc in postgres valkey falkordb qdrant hook; do stop_one "$svc"; done; else stop_one "$target"; fi ;;
  status)
    target="${2:-all}"
    for svc in postgres valkey falkordb qdrant hook; do
      [[ "$target" != "all" && "$target" != "$svc" ]] && continue
      if health "$svc"; then echo "$svc: HEALTHY"; else echo "$svc: DOWN"; fi
    done ;;
  *) echo "usage: $0 {ensure|start|stop|status} [postgres|valkey|falkordb|qdrant|hook|all]" >&2; exit 2 ;;
esac
