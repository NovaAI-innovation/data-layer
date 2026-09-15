# data-layer architecture

The data-layer umbrella orchestrates four service-level submodules.
Each submodule is its own git repository with its own remote, Dockerfile,
`lib/install.sh`, and migration files.

```
data-layer (umbrella)
├── bootstrap                       single dispatcher (init|install|verify|status|help)
├── install.sh                      convenience wrapper (runs bootstrap all)
├── docker-compose.yml              four-service compose file
├── scripts/                        one-shot installers + preflight
├── tests/                          cross-submodule smoke test
├── docs/                           architecture + bootstrap-flow + services overview
data-layer-postgres/                its own repo — postgres schema + migrations
data-layer-redis/                   its own repo — redis cache + tenant isolation
data-layer-falkordb/                its own repo — falkordb graph + Cypher migrations
data-layer-adapters/                its own repo — framework adapters + MCP + publish hook
```

## Ownership map

| Submodule | Owns | Does NOT own |
|---|---|---|
| `data-layer-postgres` | Framework-agnostic postgres schema + migration applier + cluster installer + agent_zero role | Agent Zero plugin, framework adapters, Redis/FalkorDB |
| `data-layer-redis` | Framework-agnostic redis cache layer + tenant isolation + bounded payloads | Schema, postgres/falkordb, framework adapters |
| `data-layer-falkordb` | Framework-agnostic falkordb graph layer + node/edge schema | Cache, postgres, framework adapters |
| `data-layer-adapters` | Framework adapters collection (A0 + Hermes) + universal MCP server + redis_publish_hook sidecar | Service-level storage backends |

## Dependency rules

- Components are siblings — no cross-component dependency at the git level.
- Submodules communicate only at runtime via DSN / URL env variables.
- The umbrella is the only thing that imports / orchestrates the four.
- Framework adapters consume service DSNs through `data-layer-adapters`.

## Bootstrap ordering

The dispatcher follows this ordering:

1. `init` — `git submodule update --init --recursive` (first-clone only)
2. `data-layer-postgres` install (cluster + schema + applier)
3. `data-layer-redis` install (server + tenant prefix)
4. `data-layer-falkordb` install (server + graph bootstrap)
5. `data-layer-adapters` seed (per-adapter framework seeds)
6. `bootstrap verify` — reachability check across all four.

## Docker compose architecture

```
docker compose up -d --build
    ├── postgres   ← pgvector/pgvector:pg16
    ├── redis      ← redis:7.2-alpine
    ├── falkordb   ← falkordb/falkordb:latest
    └── adapters   ← python:3.12-slim (hook sidecar)
                        depends_on: postgres, redis, falkordb (healthy)
```

Services communicate over the `data_layer` bridge network. The adapters
service uses compose-provided hostnames (`postgres`, `redis`, `falkordb`)
to reach the three backend services.
