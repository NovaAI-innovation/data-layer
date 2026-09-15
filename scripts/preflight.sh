#!/usr/bin/env bash
# data-layer/scripts/preflight.sh — dependency pre-check for the data-layer stack.
# Exits 0 if all required tools are present; exits 1 if any are missing.
# Reusable by scripts/install.sh and by human operators.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass=0
fail=0
warn=0

check_cmd() {
  local name="$1" cmd="$2" required="${3:-yes}"
  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver=$("$cmd" --version 2>&1 | head -1 || echo "(version unknown)")
    printf "${GREEN}✓${NC} %-20s %s\n" "$name" "$ver"
    ((pass++)) || true
  else
    if [[ "$required" == "yes" ]]; then
      printf "${RED}✗${NC} %-20s NOT FOUND (required)\n" "$name"
      ((fail++)) || true
    else
      printf "${YELLOW}~${NC} %-20s not found (optional)\n" "$name"
      ((warn++)) || true
    fi
  fi
}

echo "data-layer dependency pre-check"
echo "================================"
echo ""

check_cmd "docker"     docker     yes
check_cmd "git"        git        yes
check_cmd "python3"    python3    yes
check_cmd "openssl"    openssl    yes
check_cmd "psql"       psql       no
check_cmd "redis-cli"  redis-cli  no

# Docker compose plugin — not a standalone binary; check as docker subcommand
printf "  %-20s " "docker compose"
if docker compose version >/dev/null 2>&1; then
  ver=$(docker compose version 2>&1 | head -1)
  printf "${GREEN}✓${NC} %s\n" "$ver"
  ((pass++)) || true
else
  printf "${RED}✗${NC} NOT FOUND (required — install the Docker Compose plugin)\n"
  ((fail++)) || true
fi

# Docker daemon check
printf "  %-20s " "docker daemon"
if docker info >/dev/null 2>&1; then
  printf "${GREEN}✓${NC} running\n"
  ((pass++)) || true
else
  printf "${RED}✗${NC} NOT RUNNING (start Docker and retry)\n"
  ((fail++)) || true
fi

echo ""
echo "--------------------------------"
printf "Results: ${GREEN}%d passed${NC}" "$pass"
if (( fail > 0 )); then printf ", ${RED}%d missing${NC}" "$fail"; fi
if (( warn > 0 )); then printf ", ${YELLOW}%d optional missing${NC}" "$warn"; fi
echo ""

if (( fail > 0 )); then
  echo ""
  printf "${RED}Install missing required tools before proceeding.${NC}\n"
  exit 1
fi

printf "${GREEN}All required tools are present.${NC}\n"
exit 0
