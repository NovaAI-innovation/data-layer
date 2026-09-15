# data-layer

Umbrella repository for the data-layer stack: a framework-agnostic
postgres schema, redis cache, FalkorDB graph, and multi-framework
adapter collection. Brings up all four services with a single command.

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
4. Builds and starts all four services via `docker compose up -d --build`.
5. Waits for healthchecks.
6. Applies database migrations and adapter seeds (`bootstrap all`).
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
data-layer-adapters/                → github.com/NovaAI-innovation/data-layer-adapters
```

## Submodule relationship

Each submodule is its own git repository (separate remote). The
umbrella hosts them as siblings on disk and orchestrates via the
`bootstrap` dispatcher.

| Submodule | Owns | Dockerfile |
|---|---|---|
| `data-layer-postgres` | pgvector schema + migrations + agent_zero role | ✅ |
| `data-layer-redis` | Hardened redis config + tenant-prefix isolation | ✅ |
| `data-layer-falkordb` | FalkorDB server + Cypher graph schema | ✅ |
| `data-layer-adapters` | Framework adapters (A0, Hermes) + MCP server + publish hook | ✅ |

## Services (docker compose)

| Service | Host port | Notes |
|---|---|---|
| postgres | 5432 | pgvector/pgvector:pg16, scram-sha-256 auth |
| redis | 6380 | redis:7.2-alpine, AOF, allkeys-lru |
| falkordb | 6379 (RESP), 7687 (Bolt), 3000 (UI) | FalkorDB latest |
| adapters | (sidecar) | hook mode by default; MCP via `docker compose run` |

## Bootstrap commands

```bash
./bootstrap init        # populate git submodules (first clone)
./bootstrap all         # apply migrations + adapter seeds
./bootstrap verify      # confirm all services are reachable
./bootstrap status      # show per-service state (non-fatal)
./bootstrap postgres    # postgres migrations only
./bootstrap redis       # redis install only
./bootstrap falkordb    # falkordb migrations only
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

## Status

All four submodules are wired and operational. The `bootstrap`
dispatcher applies migrations idempotently; re-runs are no-ops.
