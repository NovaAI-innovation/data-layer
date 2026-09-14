# data-layer architecture

The data-layer umbrella orchestrates four service-level submodules.
Each submodule is its own git repository with its own remote.

```
data-layer (umbrella)
├── bootstrap                       single dispatcher
├── install.sh                      convenience wrapper
├── docs/                           architecture + bootstrap-flow + services overview
├── tests/                          smoke tests scaffold
├── data-layer-postgres/            placeholder → its own repo
├── data-layer-redis/               placeholder → its own repo
├── data-layer-falkordb/            placeholder → its own repo
└── data-layer-adapters/            placeholder → its own repo
```

## Ownership map

| Submodule | Owns | Does NOT own |
|---|---|---|
| `data-layer-postgres` | Framework-agnostic postgres schema + migration applier + cluster installer | Agent Zero plugin, framework adapters, Redis/FalkorDB |
| `data-layer-redis` | Framework-agnostic redis cache layer + tenant isolation + bounded payloads | Schema, postgres/falkordb, framework adapters |
| `data-layer-falkordb` | Framework-agnostic falkordb graph layer + node/edge schema | Cache, postgres, framework adapters |
| `data-layer-adapters` | Framework adapters collection (currently A0 only) | Service-level storage backends |

## Dependency rules

- Components are siblings — no cross-component dependency at the git level.
- Submodules communicate only at runtime via DSN / URL env variables.
- The umbrella is the only thing that imports / orchestrates the four.
- Framework adapters consume service DSNs through `data-layer-adapters`.

## Bootstrap ordering (future pass)

The dispatcher will follow this ordering once wired:

1. `git submodule update --init --recursive` (if `.gitmodules` exists)
2. `data-layer-postgres` install (cluster + schema + applier)
3. `data-layer-redis` install (server + tenant prefix)
4. `data-layer-falkordb` install (server + graph bootstrap)
5. `data-layer-adapters` install (per-adapter glue)
6. Final smoke across all four.
