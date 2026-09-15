#!/usr/bin/env bash
# data-layer/tests/smoke_test.sh — cross-submodule smoke test.
#
# Delegates to each submodule's verify path via the umbrella bootstrap.
# Aggregates pass/fail into a table; exits non-zero if any submodule fails.
#
# Usage:
#   bash tests/smoke_test.sh           # check all 4 submodules
#   bash tests/smoke_test.sh --fast    # skip adapter wait (faster)
#
# Timeout per component: 30s
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
BOOTSTRAP="$ROOT/bootstrap"
TIMEOUT=30
FAST=0

[[ "${1:-}" == "--fast" ]] && FAST=1

if [[ ! -x "$BOOTSTRAP" ]]; then
  echo "[smoke_test FAIL] bootstrap not found at $BOOTSTRAP" >&2
  exit 2
fi

declare -A RESULTS
TOTAL=0
PASSED=0
FAILED=0

run_check() {
  local name="$1" subdir="$2" sub="${3:-verify}"
  TOTAL=$((TOTAL + 1))
  echo "[smoke_test] checking $name..."
  if [[ ! -d "$ROOT/$subdir" ]]; then
    echo "  FAIL: submodule dir missing: $subdir"
    RESULTS[$name]="MISSING"
    FAILED=$((FAILED + 1))
    return 1
  fi
  if [[ ! -x "$ROOT/$subdir/lib/install.sh" ]]; then
    echo "  FAIL: install.sh missing in $subdir/lib"
    RESULTS[$name]="NO_INSTALL"
    FAILED=$((FAILED + 1))
    return 1
  fi
  if timeout "$TIMEOUT" bash -c "cd '$ROOT/$subdir' && bash lib/install.sh '$sub'" >/tmp/smoke_$name.out 2>&1; then
    echo "  PASS"
    RESULTS[$name]="PASS"
    PASSED=$((PASSED + 1))
    return 0
  else
    echo "  FAIL: see /tmp/smoke_$name.out"
    RESULTS[$name]="FAIL"
    FAILED=$((FAILED + 1))
    return 1
  fi
}

# Service-level checks
run_check "postgres"  "data-layer-postgres"  "verify"
run_check "redis"     "data-layer-redis"     "verify"
run_check "falkordb"  "data-layer-falkordb"  "verify"

# Adapter collection check
TOTAL=$((TOTAL + 1))
echo "[smoke_test] checking adapters..."
if [[ -x "$ROOT/data-layer-adapters/bootstrap" ]]; then
  if timeout "$TIMEOUT" bash -c "cd '$ROOT/data-layer-adapters' && bash bootstrap verify" >/tmp/smoke_adapters.out 2>&1; then
    echo "  PASS"
    RESULTS[adapters]="PASS"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL"
    RESULTS[adapters]="FAIL"
    FAILED=$((FAILED + 1))
  fi
else
  echo "  SKIP: adapters bootstrap not found"
  RESULTS[adapters]="SKIP"
fi

# Compose health (skip if docker unavailable or --fast)
TOTAL=$((TOTAL + 1))
if [[ $FAST -eq 0 ]] && command -v docker >/dev/null 2>&1; then
  echo "[smoke_test] checking compose health..."
  if (cd "$ROOT" && timeout "$TIMEOUT" docker compose ps --format json 2>/dev/null | \
      python3 -c 'import sys,json
data = sys.stdin.read().strip()
if not data:
    print("NO_COMPOSE"); sys.exit(2)
lines = [l for l in data.split("\n") if l.strip()]
services = [json.loads(l) for l in lines]
unhealthy = [s for s in services if s.get("Health", "") != "healthy"]
if unhealthy:
    for s in unhealthy: print(s.get("Name", "?"), s.get("Health", "?"))
    sys.exit(1)
print("OK")' >/tmp/smoke_compose.out 2>&1); then
    echo "  PASS"
    RESULTS[compose]="PASS"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL or not running"
    RESULTS[compose]="FAIL"
    FAILED=$((FAILED + 1))
  fi
else
  echo "[smoke_test] compose check skipped (--fast or no docker)"
  RESULTS[compose]="SKIP"
fi

# Summary table
echo ""
echo "=== data-layer smoke test results ==="
printf "  %-12s %s\n" "COMPONENT" "STATUS"
printf "  %-12s %s\n" "----------" "-------"
for name in postgres redis falkordb adapters compose; do
  printf "  %-12s %s\n" "$name" "${RESULTS[$name]:-SKIP}"
done
echo ""
echo "Totals: $PASSED passed / $FAILED failed / $TOTAL total"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
