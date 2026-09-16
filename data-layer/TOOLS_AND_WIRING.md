# data-layer — TOOLS_AND_WIRING.md (umbrella orchestration)

This document covers the orchestration tooling that lives at the umbrella
level — the code that wires the five submodules together but does not
own any service-level implementation (per the boundary rule #3 in
`docs/SUBMODULE_OWNERSHIP.md`). For per-submodule details, see each
submodule's `SCHEMAS.md` (postgres, redis, falkordb, qdrant) or
`TOOLS_AND_WIRING.md` (data-layer-adapters).

## 1. The bootstrap dispatcher (`./bootstrap`)

Single entry point for install / verify / status / reset / seed /
help. Subcommands:

| Subcommand | Behavior |
|---|---|
| `install`  | applies all pending service-level installs (delegates to each submodule's `lib/install.sh`) |
| `verify`   | confirms every service is reachable and its schema is at the expected migration version |
| `status`   | prints current state (applied migration versions, container health, vector counts) |
| `reset`    | drops schema/data (DESTRUCTIVE; requires explicit confirmation) |
| `seed`     | runs seed SQL for each framework adapter (inserts default agent rows, framework rows, etc.) |
| `help`     | usage screen |

The dispatcher shells out to each submodule; no cross-submodule
imports happen here. See `docs/bootstrap-flow.md` for the dependency
graph (postgres → redis → falkordb → qdrant → adapters).

## 2. One-shot installer (`./install.sh`)

Convenience wrapper over `bootstrap install` plus a preflight check.
Located at the umbrella root; calls `scripts/preflight.sh` (deps:
docker, docker compose, git, python3, openssl) before any work, then
generates 32-char random passwords for POSTGRES_PASSWORD and
DATA_LAYER_AGENT_ZERO_PASSWORD, materializes `.env` from `.env.example`
with passwords filled, waits for all 4 service healthchecks, runs
`bootstrap install`, and prints a summary with service URLs + the
generated passwords.

## 3. docker-compose.yml

Single compose file bringing up four services in dependency order:
postgres → redis → falkordb → qdrant → adapters. The `adapters`
service uses `depends_on: { … condition: service_healthy }` for every
backend. Healthcheck intervals are 10s with 3s timeout and 5 retries.

Port mapping notes (host:container):
- postgres:  5432:5432  (scram-sha-256)
- redis:     6380:6379  (host 6380 to avoid colliding with falkordb 6379)
- falkordb:  6379:6379 / 7687:7687 / 3000:3000
- qdrant:    6333:6333 (HTTP) / 6334:6334 (gRPC)
- adapters:  no host port (publish hook is a sidecar; MCP runs on stdio via `docker compose run --rm adapters mcp`)

The redis image pin was swapped from `redis:7.2-alpine` to
`valkey/valkey:8-alpine` on 2026-09-16 to use the active BSD-3 fork
(see `data-layer-redis/LICENSE`). The RESP protocol and on-disk
format are wire- and storage-compatible; redis.conf + write_through.py
+ redis_publish_hook.py require no source changes.

## 4. .gitmodules — submodule wiring

Five submodules registered, each pointing at its own GitHub repo:

| Submodule | URL |
|---|---|
| data-layer-postgres  | github.com/NovaAI-innovation/data-layer-postgres |
| data-layer-redis     | github.com/NovaAI-innovation/data-layer-redis |
| data-layer-falkordb  | github.com/NovaAI-innovation/data-layer-falkordb |
| data-layer-qdrant    | github.com/NovaAI-innovation/data-layer-qdrant |
| data-layer-adapters  | github.com/NovaAI-innovation/data-layer-adapters |

Fresh clones run `git submodule update --init` to materialize each
working tree. Each submodule owns its own VERSION / migration
history; the umbrella tracks only the pointer (gitlink mode 160000).

## 5. MCP registration — global + per-project dedupe

The az-retrieval-mcp server is the universal MCP that exposes 21 tools
(14 postgres-backed + 7 qdrant-backed RAG). It is registered in three
places that have been progressively consolidated:

1. **Global Agent Zero config** (`/a0/usr/settings.json` `mcp_servers`)
   — the canonical registration. Set on 2026-09-16. Spawns
   `python3 /a0/usr/mcp/server.py` with `DATA_LAYER_POSTGRES_DSN` env.

2. **Per-project umbrella config**
   (`/a0/usr/projects/data-layer/.a0proj/mcp_servers.json`) — cleared
   to `{}` on 2026-09-16 since it duplicated the global registration.
   Backup: `.bak-20260916T164142Z-mcp-dedupe` (249 bytes).

3. **Per-project adapters submodule config**
   (`data-layer-adapters/.a0proj/mcp_servers.json`) — also cleared
   to `{}`. Same backup pattern.

The three other submodules (postgres, redis, falkordb) always had
empty `{}` mcp_servers.json files.

After the dedupe: only one az-retrieval-mcp spawn path is active per
session load (the global one). The connected stdio server lives at
`/a0/usr/mcp/server.py` (deployed from `data-layer-adapters/mcp/server.py`;
source vs deployed are content-identical, verified 2026-09-16).

## 6. Versioning + tagging

Tag conventions: `v<major>.<minor>.<patch>` (semver).

| Tag | When |
|---|---|
| (none yet) | — |

Tag + ship workflow (for after Wire-up E is unblocked):
1. Confirm all 6 submodule commit hashes are at HEAD on origin
2. Confirm umbrella working tree is clean (no uncommitted / untracked source)
3. `git tag v0.1.0`
4. `git push --tags origin main` (after explicit user authorization)

## 7. Per-submodule cross-references

| Submodule | Tools/wiring doc | Schemas doc |
|---|---|---|
| `data-layer-postgres/` | (no TOOLS doc; pure schema) | `SCHEMAS.md` |
| `data-layer-redis/` | (no TOOLS doc; pure schema) | `SCHEMAS.md` |
| `data-layer-falkordb/` | (no TOOLS doc; pure schema) | `SCHEMAS.md` |
| `data-layer-qdrant/` | (no TOOLS doc; pure schema) | `SCHEMAS.md` |
| `data-layer-adapters/` | `TOOLS_AND_WIRING.md` (533 lines; all 21 MCP tools + lib scripts + framework adapters + dual-write) | (n/a) |

## 8. See also

- `docs/SUBMODULE_OWNERSHIP.md` — boundary rules + ownership matrix
- `docs/architecture.md` — relationship diagram
- `docs/bootstrap-flow.md` — dependency order + per-step behavior
- `docs/services/README.md` — per-service interface contract
- `HANDOFF.md` — session-by-session handoff log
- `LICENSE` + submodule `LICENSE` files — license posture
- `NOTICE` — third-party attributions
- `CONTRIBUTING.md` — contributor license + DCO process