# data-layer services overview

Each of the four submodules has a placeholder directory in this repo.
See the README inside each placeholder for the implementation contract
and the upstream repository URL.

| Submodule | README in this repo | Upstream repo |
|---|---|---|
| `data-layer-postgres/` | [README](./../../data-layer-postgres/README.md) | `github.com/NovaAI-innovation/data-layer-postgres` |
| `data-layer-redis/` | [README](./../../data-layer-redis/README.md) | `github.com/NovaAI-innovation/data-layer-redis` |
| `data-layer-falkordb/` | [README](./../../data-layer-falkordb/README.md) | `github.com/NovaAI-innovation/data-layer-falkordb` |
| `data-layer-adapters/` | [README](./../../data-layer-adapters/README.md) | `github.com/NovaAI-innovation/data-layer-adapters` |

Each upstream repo ships its own `lib/install.sh` (install | verify | status | reset)
that the umbrella `bootstrap` will eventually shell-out to.
