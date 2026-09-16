# data-layer bootstrap flow

This doc describes what happens when `data-layer/bootstrap` runs.

## Entry points

- `./bootstrap` — full dispatcher (`init | install | verify | status | help`)
- `./install.sh` — convenience wrapper that runs `bootstrap all`
- `bash scripts/install.sh` — one-shot installer (deps + docker + migrate + verify)

## Subcommand behaviour

### `bootstrap init`

1. `git -C "$DATA_LAYER_BASE" submodule update --init --recursive`
2. Reports success.

Run once after cloning. Idempotent — re-runs are no-ops if submodules
are already populated.

### `bootstrap all`

1. Delegates to each submodule's `lib/install.sh install`:
   - `data-layer-postgres` → applies SQL migrations + creates agent_zero role/db/grants
   - `data-layer-redis` → reports config (no-op; server is managed by docker)
   - `data-layer-falkordb` → applies Cypher migrations
   - `data-layer-qdrant` → creates 2 collections (mpg_source_authority_documents, mpg_emails) + seeds (gated by MCP_INSTALL_MODE=1)
2. Runs `data-layer-adapters/bootstrap seed` → applies per-adapter seed rows.

Re-runs are no-ops: postgres tracks applied versions in `schema_migrations`,
falkordb tracks in `:_SchemaMigrations`, qdrant collections are idempotent (apply_migrations.py skips existing), and seeds use `INSERT ... ON CONFLICT`.

### `bootstrap <component>`

Same as above but scoped to one submodule. Useful for surgical installs.

```bash
./bootstrap postgres          # apply postgres migrations only
./bootstrap redis             # redis config only
./bootstrap falkordb          # falkordb migrations only
./bootstrap adapters          # adapter install only
```

### `bootstrap seed`

1. Postgres migrations (FK dependency — schema must exist first).
2. Adapter seeds (framework-specific rows).

### `bootstrap verify`

Runs `lib/install.sh verify` on each submodule:
- postgres: checks 10 business tables + uuid-ossp/vector extensions + HNSW index + agent_zero role
- redis: PING + CONFIG GET for bind/protected-mode/requirepass
- falkordb: checks node labels (Project, Agent, Session, Message, Tool)
- adapters: delegates to per-adapter verify

### `bootstrap status`

Informational — prints per-submodule state. Tolerant of per-service
failures (does not abort if one service is down).

### `bootstrap help`

Prints usage block.

## Environment

`DATA_LAYER_BASE` defaults to the directory containing `bootstrap`.
Override only when symlinking the dispatcher elsewhere.

Per-submodule DSN / URL env vars live in `.env.example` / `.a0proj/variables.env`.
Real secrets live in `.a0proj/secrets.env` (mode 0600, not committed) or
the local `.env` file (git-ignored).
