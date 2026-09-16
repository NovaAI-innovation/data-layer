# data-layer

Umbrella repository for the data-layer stack: a framework-agnostic
postgres schema, redis cache, FalkorDB graph, Qdrant vector/RAG layer,
and multi-framework adapter collection. Brings up all five services
with a single command.

## Quick start (Linux / macOS)

```bash
git clone --recurse-submodules https://github.com/NovaAI-innovation/data-layer.git
cd data-layer
bash scripts/install.sh          # one-shot: deps check → build → migrate → verify
```

The installer:
1. Checks host dependencies (docker, git, python3, openssl).
2. Populates git submodules.
3. Generates strong random passwords and writes `.env`.
4. Builds and starts all five services via `docker compose up -d --build`.
5. Waits for healthchecks.
6. Applies database migrations, qdrant collections + seed, and adapter seeds (`bootstrap all`).
7. Verifies all services are reachable (`bootstrap verify`).
8. Prints credentials and next-step commands.

## Quick start (Windows)

```powershell
git clone --recurse-submodules https://github.com/NovaAI-innovation/data-layer.git
cd data-layer
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

Then run migrations from WSL or Git Bash:

```bash
bash bootstrap all
bash bootstrap verify
```

## Layout

```
data-layer/
├── bootstrap                       single dispatcher (init | install | verify | status | help)
├── install.sh                      convenience wrapper (runs bootstrap all)
├── docker-compose.yml              four-service compose file
├── .env.example                    non-secret env template
├── scripts/
│   ├── install.sh                  one-shot Linux/macOS installer
│   ├── install.ps1                 one-shot Windows installer
│   └── preflight.sh                standalone dependency checker
tests/
│   └── smoke_test.sh               cross-submodule verification
docs/
│   ├── architecture.md             submodule relationship diagram
│   ├── bootstrap-flow.md           what happens when bootstrap runs
│   └── services/README.md          per-service overview
data-layer-postgres/                → github.com/NovaAI-innovation/data-layer-postgres
data-layer-redis/                   → github.com/NovaAI-innovation/data-layer-redis
data-layer-falkordb/                → github.com/NovaAI-innovation/data-layer-falkordb
data-layer-qdrant/                  → github.com/NovaAI-innovation/data-layer-qdrant
data-layer-adapters/                → github.com/NovaAI-innovation/data-layer-adapters
```

## Submodule relationship

Each submodule is its own git repository (separate remote). The
umbrella hosts them as siblings on disk and orchestrates via the
`bootstrap` dispatcher.

| Submodule | Owns | Dockerfile |
|---|---|---|
| `data-layer-postgres` | pgvector schema + migrations + agent_zero role (immutable record; SOT) | ✅ |
| `data-layer-redis` | Hardened redis config + tenant-prefix isolation (ephemeral cache) | ✅ |
| `data-layer-falkordb` | FalkorDB server + Cypher graph schema (graph edges) | ✅ |
| `data-layer-qdrant` | Qdrant vector index + 2-collection SOT (source_authority + emails) + bootstrap-gated seed pipeline | ✅ |
| `data-layer-adapters` | Framework adapters (A0, Hermes) + **universal MCP server (21 tools)** + publish hook | ✅ |

## Services (docker compose)

| Service | Host port | Notes |
|---|---|---|
| postgres | 5432 | pgvector/pgvector:pg16, scram-sha-256 auth |
| redis | 6380 | redis:7.2-alpine, AOF, allkeys-lru |
| falkordb | 6379 (RESP), 7687 (Bolt), 3000 (UI) | FalkorDB latest |
| **qdrant** | **6333 (HTTP), 6334 (gRPC)** | **qdrant/qdrant:v1.19.1; vector / RAG layer; 2 collections (mpg_source_authority_documents, mpg_emails); writes gated by `MCP_INSTALL_MODE=1`** |
| adapters | (sidecar) | hook mode by default; **universal MCP server (21 tools: 14 Postgres + 7 Qdrant)** via `docker compose run` |

## Bootstrap commands

```bash
./bootstrap init        # populate git submodules (first clone)
./bootstrap all         # apply migrations + qdrant collections/seed + adapter seeds
./bootstrap verify      # confirm all services are reachable
./bootstrap status      # show per-service state (non-fatal)
./bootstrap postgres    # postgres migrations only
./bootstrap redis       # redis install only
./bootstrap falkordb    # falkordb migrations only
./bootstrap qdrant      # qdrant server + collections + seed (gated by MCP_INSTALL_MODE)
./bootstrap adapters    # adapter install only
./bootstrap seed        # schema + adapter seeds
```

## Environment

Copy `.env.example` to `.env` and set the two required passwords:

- `POSTGRES_PASSWORD` — postgres superuser password
- `DATA_LAYER_AGENT_ZERO_PASSWORD` — agent_zero tenant role password

The one-shot installer generates these automatically. See `.env.example`
for all optional overrides.

## Stopping and resetting

```bash
docker compose down            # stop (data preserved)
docker compose down -v         # stop + DELETE ALL DATA
```

## Security notes

- Postgres uses scram-sha-256. Never commit real passwords.
- Redis is unpassworded by default. Add `requirepass` for non-test use.
- FalkorDB RESP is unauthenticated by default.
- For multi-host exposure, use TLS or a reverse proxy.

## Documentation

| Doc | Purpose |
|---|---|
| `HANDOFF.md` | Session-by-session status log + handoff to next agent |
| `TOOLS_AND_WIRING.md` | Umbrella orchestration: bootstrap, install.sh, docker-compose.yml, .gitmodules, MCP registration, versioning/tagging |
| `NOTICE` | Third-party attributions for every direct dependency (PostgreSQL+pgvector, Valkey+Redis, FalkorDB SSPL v1, Qdrant, fastembed, sentence-transformers, Agent Zero, MCP SDK, LiteLLM, Flask, Alpine.js, etc.) |
| `LICENSE` | Umbrella license (BSD-3-Clause, Casey 2026) |
| `CONTRIBUTING.md` | ICLA + CCLA templates + DCO sign-off alternative + review/security policy |
| `docs/SUBMODULE_OWNERSHIP.md` | Boundary rules + ownership matrix + wiring-route map + audit triggers |
| `docs/architecture.md` | Submodule relationship diagram; cross-layer email → postgres → qdrant flow |
| `docs/bootstrap-flow.md` | What happens when `bootstrap` runs |
| `docs/services/README.md` | Per-service overview + `lib/install.sh` contract |
| `docs/audits/fastembed-license-compat.md` | License compatibility audit of the qdrant embedding pipeline (Apache-2.0 / MIT — all PASS) |
| `docs/completion-audit-2026-09-15.md` | Raw 84% completion audit with per-submodule matrix |
| `data-layer-postgres/SCHEMAS.md` | Per-table, per-column spec for the 13 tables across 7 migrations (5-dimension format) |
| `data-layer-redis/SCHEMAS.md` | Redis key namespace + dual-write families + RESP command inventory |
| `data-layer-falkordb/SCHEMAS.md` | Graph schema (nodes + edges + cypher migrations) |
| `data-layer-qdrant/SCHEMAS.md` | Both qdrant collection payload schemas (5-dimension per field) |
| `data-layer-adapters/TOOLS_AND_WIRING.md` | All 21 MCP tools + lib scripts + framework adapters + dual-write path |

## License posture (per repo)

| Repo | License | Holder |
|---|---|---|
| data-layer (umbrella) | BSD-3-Clause | Casey 2026 |
| data-layer-adapters  | BSD-3-Clause | Casey 2026 |
| data-layer-postgres  | PostgreSQL License | PostgreSQL Global Development Group |
| data-layer-redis     | BSD-3-Clause | Casey + Valkey/Redis lineages |
| data-layer-falkordb  | SSPL v1 (non-OSI; commercial license may be required for service-side use) | FalkorDB project contributors |
| data-layer-qdrant    | Apache License 2.0 | Casey + Qdrant contributors |

## Status

All five submodules are wired and operational. The `bootstrap`
dispatcher applies migrations idempotently; re-runs are no-ops.

Phase 0 docs ✅, P0.1 SQL-injection probe ✅, LICENSE files in all 6
repos ✅, NOTICE + CONTRIBUTING.md ✅, Valkey 8.x swap ✅, MCP dedupe
(global /a0/usr/settings.json is canonical) ✅, qdrant drift cleanup
✅, fastembed license audit ✅ — see HANDOFF.md §1 for the per-row
status with commit hashes and dates.
