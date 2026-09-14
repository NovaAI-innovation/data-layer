# data-layer

Reference scaffold for the data-layer umbrella repository.

This tree is **structure-only**. The four submodules (`data-layer-postgres`,
`data-layer-redis`, `data-layer-falkordb`, `data-layer-adapters`) are
**placeholders** — each contains only a README that points to its dedicated
repository, where the real implementation lives or will live.

## Layout

```
data-layer/
├── bootstrap                  single dispatcher (install | verify | status | help)
├── install.sh                 convenience wrapper (defaults to 'bootstrap all')
├── .a0proj/                   Agent Zero project metadata
├── docs/                      architecture + bootstrap-flow docs
├── tests/                     smoke tests scaffold
├── data-layer-postgres/       placeholder — see ./data-layer-postgres/README.md
├── data-layer-redis/          placeholder — see ./data-layer-redis/README.md
├── data-layer-falkordb/       placeholder — see ./data-layer-falkordb/README.md
└── data-layer-adapters/       placeholder — see ./data-layer-adapters/README.md
```

## Submodule relationship

Each submodule is its own git repository (separate remote). This umbrella
hosts them as siblings on disk; submodules are wired via shell-out from
`data-layer/bootstrap`.

| Submodule | Owns | Lives at |
|---|---|---|
| `data-layer-postgres` | Framework-agnostic postgres schema + applier | `github.com/NovaAI-innovation/data-layer-postgres` |
| `data-layer-redis` | Framework-agnostic redis cache layer | `github.com/NovaAI-innovation/data-layer-redis` |
| `data-layer-falkordb` | Framework-agnostic falkordb graph layer | `github.com/NovaAI-innovation/data-layer-falkordb` |
| `data-layer-adapters` | Multi-framework adapter collection (currently A0) | `github.com/NovaAI-innovation/data-layer-adapters` |

## Status

This scaffold was created 2026-09-14 as a **reference for relationship planning**.
Service implementation, bootstrap wiring, and `.gitmodules` activation are
deferred to a future pass. The placeholder READMEs in each submodule
document the expected interface contract so implementation can proceed in
parallel against a stable shape.