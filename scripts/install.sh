#!/usr/bin/env bash
# data-layer/scripts/install.sh — one-shot installer for the data-layer stack.
#
# Automates the full installation:
#   1. Check host dependencies (docker, git, python3, openssl)
#   2. Initialize git submodules
#   3. Generate secure random passwords
#   4. Materialize .env from .env.example
#   5. Build and start all services via docker compose
#   6. Apply database migrations and adapter seeds
#   7. Verify all services are reachable
#
# Usage:
#   bash scripts/install.sh            # full install
#   bash scripts/install.sh --dry-run  # show what would happen
#   bash scripts/install.sh --help
#
# Environment overrides:
#   NONINTERACTIVE=1  skip confirmation prompts
#   SKIP_BUILD=1      skip 'docker compose build' (use existing images)
#   SKIP_DOCKER=1     skip all docker steps (services already running)
#   DATA_LAYER_BASE   override repo root

set -euo pipefail

SOURCE="${BASH_SOURCE[0]:-$0}"
SCRIPTS_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

# ── helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { printf "${CYAN}[install]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[install WARN]${NC} %s\n" "$*"; }
fail() { printf "${RED}[install FAIL]${NC} %s\n" "$*" >&2; exit 1; }
ok()   { printf "${GREEN}[install OK]${NC} %s\n" "$*"; }

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h) sed -n '2,17p' "$SOURCE"; exit 0 ;;
    *) fail "unknown argument: $arg" ;;
  esac
done

SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_DOCKER="${SKIP_DOCKER:-0}"

# ── step 1: preflight ────────────────────────────────────────────────
log "Step 1/7 — dependency pre-check"
if [[ -x "$ROOT_DIR/scripts/preflight.sh" ]]; then
  bash "$ROOT_DIR/scripts/preflight.sh" || fail "preflight failed — install missing tools and retry"
else
  warn "preflight.sh not found; skipping"
fi

# ── step 2: submodules ───────────────────────────────────────────────
log "Step 2/7 — initializing git submodules"
if [[ -f "$ROOT_DIR/.gitmodules" ]]; then
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would run: git -C $ROOT_DIR submodule update --init --recursive"
  else
    git -C "$ROOT_DIR" submodule update --init --recursive
    ok "submodules populated"
  fi
else
  warn "no .gitmodules; skipping"
fi

# ── step 3: generate secrets ─────────────────────────────────────────
log "Step 3/7 — generating secrets and materializing .env"

ENV_FILE="$ROOT_DIR/.env"
ENV_EXAMPLE="$ROOT_DIR/.env.example"

# Generate a 32-char alphanumeric password
# shellcheck disable=SC2034
gen_pw() { openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 32; }

PG_PW=""
AZ_PW=""

# Preserve existing values from .env if present
if [[ -f "$ENV_FILE" ]]; then
  log ".env already exists; preserving existing passwords"
  while IFS='=' read -r key val; do
    case "$key" in
      POSTGRES_PASSWORD)                    PG_PW="$val" ;;
      DATA_LAYER_AGENT_ZERO_PASSWORD)      AZ_PW="$val" ;;
    esac
  done < "$ENV_FILE"
fi

if [[ -z "$PG_PW" ]]; then PG_PW=$(gen_pw); log "generated POSTGRES_PASSWORD"; fi
if [[ -z "$AZ_PW" ]]; then AZ_PW=$(gen_pw); log "generated DATA_LAYER_AGENT_ZERO_PASSWORD"; fi

if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] would write .env with generated passwords"
else
  if [[ -f "$ENV_EXAMPLE" ]]; then
    # Materialize .env from .env.example, injecting real secrets
    found_pg=0
    found_az=0
    while IFS= read -r line; do
      case "$line" in
        POSTGRES_PASSWORD=*)
          echo "POSTGRES_PASSWORD=${PG_PW}"
          found_pg=1
          ;;
        DATA_LAYER_AGENT_ZERO_PASSWORD=*)
          echo "DATA_LAYER_AGENT_ZERO_PASSWORD=${AZ_PW}"
          found_az=1
          ;;
        *)
          echo "$line"
          ;;
      esac
    done < "$ENV_EXAMPLE" > "$ENV_FILE"
    # Append if .env.example didn't have the vars
    if (( found_pg == 0 )); then echo "POSTGRES_PASSWORD=${PG_PW}" >> "$ENV_FILE"; fi
    if (( found_az == 0 )); then echo "DATA_LAYER_AGENT_ZERO_PASSWORD=${AZ_PW}" >> "$ENV_FILE"; fi
    chmod 600 "$ENV_FILE"
    ok ".env materialized (mode 600)"
  else
    cat > "$ENV_FILE" <<ENVEOF
POSTGRES_PASSWORD=${PG_PW}
DATA_LAYER_AGENT_ZERO_PASSWORD=${AZ_PW}
DATA_LAYER_BASE=${ROOT_DIR}
ENVEOF
    chmod 600 "$ENV_FILE"
    ok ".env created (minimal, mode 600)"
  fi
fi

# ── step 4: docker compose up ────────────────────────────────────────
if [[ "$SKIP_DOCKER" == "1" ]]; then
  log "Step 4/7 — SKIP_DOCKER=1; skipping"
elif [[ "$SKIP_BUILD" == "1" ]]; then
  log "Step 4/7 — SKIP_BUILD=1; starting existing containers"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would run: docker compose up -d"
  else
    (cd "$ROOT_DIR" && docker compose up -d)
    ok "containers started"
  fi
else
  log "Step 4/7 — docker compose up -d --build"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would run: docker compose up -d --build"
  else
    (cd "$ROOT_DIR" && docker compose up -d --build)
    ok "containers built and started"
  fi
fi

# ── step 5: wait for healthchecks ────────────────────────────────────
if [[ "$SKIP_DOCKER" == "1" ]]; then
  log "Step 5/7 — SKIP_DOCKER=1; skipping healthcheck wait"
else
  log "Step 5/7 — waiting for service healthchecks (up to 90s)"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[dry-run] would wait for healthchecks"
  else
    elapsed=0
    max_wait=90
    while (( elapsed < max_wait )); do
      healthy=$(cd "$ROOT_DIR" && docker compose ps 2>/dev/null | grep -c "healthy" || true)
      if (( healthy >= 3 )); then
        ok "services healthy ($healthy/4)"
        break
      fi
      sleep 5
      ((elapsed+=5)) || true
      printf "  waiting... (%ds, %d healthy)\n" "$elapsed" "$healthy"
    done
    if (( elapsed >= max_wait )); then
      warn "healthcheck timeout after ${max_wait}s — continuing"
    fi
  fi
fi

# ── step 6: bootstrap all ────────────────────────────────────────────
log "Step 6/7 — running bootstrap (migrations + seeds)"
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] would run: $ROOT_DIR/bootstrap all"
else
  bash "$ROOT_DIR/bootstrap" all
  ok "bootstrap complete"
fi

# ── step 7: verify ───────────────────────────────────────────────────
log "Step 7/7 — verifying installation"
if [[ "$DRY_RUN" == "1" ]]; then
  log "[dry-run] would run: $ROOT_DIR/bootstrap verify"
else
  if bash "$ROOT_DIR/bootstrap" verify; then
    ok "all verifications passed"
  else
    warn "some verifications failed — check output above"
  fi
fi

# ── summary ──────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  data-layer stack — installation complete"
echo "============================================================"
echo ""
echo "  Services:"
echo "    postgres   →  localhost:5432  (user: postgres)"
echo "    redis      →  localhost:6380"
echo "    falkordb   →  localhost:6379 (RESP) / 7687 (Bolt) / 3000 (UI)"
echo "    adapters   →  sidecar (no host port; MCP via docker compose run)"
echo ""
echo "  Credentials (saved in .env):"
echo "    POSTGRES_PASSWORD              = $PG_PW"
echo "    DATA_LAYER_AGENT_ZERO_PASSWORD = $AZ_PW"
echo ""
echo "  Next steps:"
echo "    source .env              # load env vars into shell"
echo "    ./bootstrap status       # check service state"
echo "    ./bootstrap verify       # re-verify reachability"
echo "    docs/architecture.md     # read the architecture"
echo ""
echo "  Stop:    docker compose down"
echo "  Reset:   docker compose down -v   (DROPS ALL DATA)"
echo "============================================================"
