# data-layer-postgres (placeholder)

**Status:** placeholder. Implementation lives in its own repository.

**Upstream:** `github.com/NovaAI-innovation/data-layer-postgres`

This directory is reserved by the `data-layer` umbrella as a wiring slot.
When the upstream repo is cloned here (or linked via `.gitmodules`), it owns:

- `migrations/*.sql` — framework-agnostic postgres schema (identity, agents, sessions, messages, tool_executions, hooks, etc.)
- `lib/install.sh` — idempotent applier (`install | verify | status | reset`)
- `lib/postgres.sh` — postgres cluster installer (apt + cluster init + password sync)
- `docs/schema-abstraction.md` — cross-framework abstraction strategy
- `docs/decisions/` — ADRs (append-only)

## Contract with the umbrella

`bootstrap postgres` will shell-out to `lib/install.sh install` here. The
submodule must:

1. Expose `lib/install.sh` with subcommands: `install`, `verify`, `status`, `reset`.
2. Read its DSN from `$DATA_LAYER_POSTGRES_DSN` (set in `.env.example`).
3. Be idempotent: re-running `install` must be a no-op when already applied.
4. Return non-zero exit on `verify` failure so the umbrella's smoke test catches it.
