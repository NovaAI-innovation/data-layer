# data-layer-falkordb (placeholder)

**Status:** placeholder. Implementation lives in its own repository.

**Upstream:** `github.com/NovaAI-innovation/data-layer-falkordb`

This directory is reserved by the `data-layer` umbrella as a wiring slot.
When the upstream repo is cloned here (or linked via `.gitmodules`), it owns:

- `lib/install.sh` — idempotent applier (`install | verify | status | reset`)
- `lib/falkordb.sh` — falkordb server install + graph bootstrap
- `docs/graph-schema.md` — node/edge schema and identity rules
- `docs/decisions/` — ADRs (append-only)

## Contract with the umbrella

`bootstrap falkordb` will shell-out to `lib/install.sh install` here. The
submodule must:

1. Expose `lib/install.sh` with subcommands: `install`, `verify`, `status`, `reset`.
2. Read its URL from `$DATA_LAYER_FALKORDB_URL` and database name from `$DATA_LAYER_FALKORDB_DATABASE` (set in `.env.example`).
3. Be idempotent: re-running `install` must be a no-op when already applied.
4. Return non-zero exit on `verify` failure so the umbrella's smoke test catches it.
