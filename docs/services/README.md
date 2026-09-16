# data-layer services overview

Each of the five submodules is a fully wired service with its own
git repository, Dockerfile, `lib/install.sh`, migration files,
LICENSE, and a 5-dimension schema doc (`SCHEMAS.md` for postgres/redis/falkordb/qdrant; `TOOLS_AND_WIRING.md` for adapters). See the README inside each submodule for the full contract.

| Submodule | README in this repo | Schema/tools doc | Upstream repo | License |
|---|---|---|---|---|
| `data-layer-postgres/` | [README](./../../data-layer-postgres/README.md) | [SCHEMAS.md](./../../data-layer-postgres/SCHEMAS.md) | `github.com/NovaAI-innovation/data-layer-postgres` | PostgreSQL License |
| `data-layer-redis/` | [README](./../../data-layer-redis/README.md) | [SCHEMAS.md](./../../data-layer-redis/SCHEMAS.md) | `github.com/NovaAI-innovation/data-layer-redis` | BSD-3-Clause |
| `data-layer-falkordb/` | [README](./../../data-layer-falkordb/README.md) | [SCHEMAS.md](./../../data-layer-falkordb/SCHEMAS.md) | `github.com/NovaAI-innovation/data-layer-falkordb` | SSPL v1 (non-OSI) |
| `data-layer-qdrant/` | [README](./../../data-layer-qdrant/README.md) | [SCHEMAS.md](./../../data-layer-qdrant/SCHEMAS.md) | `github.com/NovaAI-innovation/data-layer-qdrant` | Apache License 2.0 |
| `data-layer-adapters/` | [README](./../../data-layer-adapters/README.md) | [TOOLS_AND_WIRING.md](./../../data-layer-adapters/TOOLS_AND_WIRING.md) | `github.com/NovaAI-innovation/data-layer-adapters` | BSD-3-Clause |

## Per-submodule interface contract

Each submodule ships a `lib/install.sh` with these subcommands:

| Subcommand | Purpose |
|---|---|
| `install` | Apply pending migrations / config (idempotent) |
| `verify` | Confirm the service is reachable and schema is correct |
| `status` | Print current state (applied versions, key counts, etc.) |
| `reset` | Drop schema / data (destructive — use with caution) |

The umbrella `bootstrap` dispatcher shells out to these scripts;
no cross-submodule imports exist.

## Docker images

All five services are built from Dockerfiles in their submodule
directories. The umbrella `docker-compose.yml` references them
via `build: ./data-layer-<name>` and brings them up in dependency
order (postgres → redis → falkordb → qdrant → adapters).
