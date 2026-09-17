#!/usr/bin/env bash
# data-layer/lib/validate.sh — READ-ONLY validation phase over existing data.
#
# NOTE 2026-09-17: compose-first deployments should prefer the profile-gated
# `validate` service in docker-compose.yml (docker compose --profile validate
# up validate). This script remains for native-mode hosts; it auto-detects
# ports from the environment, so it also works against compose-published
# +1 ports when DATA_LAYER_*_PORT variables are set accordingly.
#
# Runs before any population step (bootstrap validate / bootstrap all first pass).
# Populated components are verified + reported (NEVER reseeded); missing pieces are
# reported for population. Evidence is persisted under docs/evidence/ for HITL/QC.
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
EVIDENCE_DIR="$DATA_LAYER_BASE/docs/evidence"
mkdir -p "$EVIDENCE_DIR"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT="$EVIDENCE_DIR/validate-$(date -u +%Y%m%dT%H%M%SZ).md"

pass=0; warn=0; fail=0
say()      { printf '%s\n' "$*" | tee -a "$OUT"; }
chk_pass() { say "  PASS  $*"; pass=$((pass+1)); }
chk_warn() { say "  WARN  $*"; warn=$((warn+1)); }
chk_fail() { say "  FAIL  $*"; fail=$((fail+1)); }

say "# data-layer validation report"
say ""
say "- **UTC:** $TS"
say "- **Mode:** read-only (no mutation, no reseed)"
say ""

# ---------------- postgres ----------------
say "## postgres :$PG_PORT"
if pg_isready -h 127.0.0.1 -p "$PG_PORT" -q 2>/dev/null; then
  chk_pass "accepting connections"
  applied=$(psql "postgresql://postgres@localhost:$PG_PORT/postgres" -Atc "SELECT count(*) FROM schema_migrations" 2>/dev/null || echo 0)
  on_disk=$(ls "$DATA_LAYER_BASE"/data-layer-postgres/migrations/*.sql 2>/dev/null | wc -l)
  if [[ "$applied" == "$on_disk" ]]; then
    chk_pass "migrations applied=$applied == on-disk=$on_disk"
  else
    chk_fail "migrations applied=$applied != on-disk=$on_disk"
  fi
  agents=$(psql "postgresql://postgres@localhost:$PG_PORT/postgres" -Atc "SELECT count(*) FROM agents" 2>/dev/null || echo ERR)
  tools=$(psql "postgresql://postgres@localhost:$PG_PORT/postgres" -Atc "SELECT count(*) FROM tool_executions" 2>/dev/null || echo ERR)
  say "  INFO  rows: agents=$agents tool_executions=$tools"
else
  chk_fail "postgres not accepting connections on $PG_PORT"
fi
say ""

# ---------------- valkey ----------------
say "## valkey :$REDIS_PORT"
if redis-cli -p "$REDIS_PORT" PING 2>/dev/null | grep -q PONG; then
  chk_pass "PING -> PONG (ephemeral cache online)"
else
  chk_fail "PING failed"
fi
say ""

# ---------------- falkordb ----------------
say "## falkordb :$FALKORDB_PORT"
if redis-cli -p "$FALKORDB_PORT" PING 2>/dev/null | grep -q PONG; then
  chk_pass "PING -> PONG"
  if redis-cli -p "$FALKORDB_PORT" MODULE LIST 2>/dev/null | grep -qi graph; then
    chk_pass "graph module loaded"
    mig=$(redis-cli -p "$FALKORDB_PORT" GRAPH.QUERY data_layer "MATCH (n:_SchemaMigrations) RETURN n.version ORDER BY n.version DESC LIMIT 1" 2>/dev/null | grep -oE '[0-9]{4}_[a-z_]+' | head -1)
    last_file=$(ls "$DATA_LAYER_BASE"/data-layer-falkordb/migrations/*.cypher 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.cypher//' | sort | tail -1)
    if [[ -n "$mig" && "$mig" == "$last_file" ]]; then
      chk_pass "cypher migrations applied=$mig == on-disk=$last_file"
    elif [[ -z "$mig" && -z "$last_file" ]]; then
      chk_pass "no cypher migrations on either side (clean slate)"
    else
      chk_fail "cypher migrations applied=${mig:-none} != on-disk=${last_file:-none}"
    fi
  else
    chk_fail "graph module NOT loaded"
  fi
else
  chk_fail "PING failed"
fi
say ""

# ---------------- qdrant ----------------
say "## qdrant :$QDRANT_HTTP_PORT"
if curl -fsS "http://127.0.0.1:$QDRANT_HTTP_PORT/healthz" >/dev/null 2>&1; then
  chk_pass "healthz ok"
  for coll in mpg_source_authority_documents mpg_emails; do
    pts=$(curl -fsS "http://127.0.0.1:$QDRANT_HTTP_PORT/collections/$coll" 2>/dev/null | grep -o '"points_count":[0-9]*' | cut -d: -f2)
    if [[ -n "$pts" ]]; then
      if [[ "$pts" -gt 0 ]]; then
        chk_pass "$coll populated (points=$pts) — validated, NOT reseeded"
      else
        chk_warn "$coll exists but empty (points=0) — eligible for seed"
      fi
    else
      chk_fail "$coll MISSING — eligible for creation"
    fi
  done
else
  chk_fail "healthz failed"
fi
say ""

# ---------------- summary ----------------
say "## summary"
say ""
say "- PASS: $pass  WARN: $warn  FAIL: $fail"
if [[ "$fail" -eq 0 ]]; then
  say "- **verdict: VALID** (existing data consistent)"
else
  say "- **verdict: REMEDIATION REQUIRED** (see FAIL lines)"
fi
echo "$OUT"
[[ "$fail" -eq 0 ]]
