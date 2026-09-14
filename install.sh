#!/usr/bin/env bash
# data-layer/install.sh — convenience wrapper that defaults to 'bootstrap all'.
set -euo pipefail
exec "$(dirname "$0")/bootstrap" all