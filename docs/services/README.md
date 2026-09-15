# data-layer services overview

Each of the five submodules is a fully wired service with its own
git repository, Dockerfile, `lib/install.sh`, and migration files.
See the README inside each submodule for the full contract.

| Submodule | README in this repo | Upstream repo |
|---|---|---|
| `data-layer-postgres/` | [README](./../../data-layer-postgres/README.md) | `github.com/NovaAI-innovation/data-layer-postgres` |
| `data-layer-redis/` | [README](./../../data-layer-redis/README.md) | `github.com/NovaAI-innovation/data-layer-redis` |
| `data-layer-falkordb/` | [README](./../../data-layer-falkordb/README.md) | `github.com/NovaAI-innovation/data-layer-falkordb` |
| `data-layer-qdrant/` | [README](./../../data-layer-qdrant/README.md) | `github.com/NovaAI-innovation/data-layer-qdrant` |
| `data-layer-adapters/` | [README](./../../data-layer-adapters/README.md) | `github.com/NovaAI-innovation/data-layer-adapters` |

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
