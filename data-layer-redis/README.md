# data-layer-redis (placeholder)

**Status:** placeholder. Implementation lives in its own repository.

**Upstream:** `github.com/NovaAI-innovation/data-layer-redis`

This directory is reserved by the `data-layer` umbrella as a wiring slot.
When the upstream repo is cloned here (or linked via `.gitmodules`), it owns:

- `lib/install.sh` — idempotent applier (`install | verify | status | reset`)
- `lib/redis.sh` — redis server install + tenant-prefix key setup
- `docs/cache-abstraction.md` — bounded read-through contract
- `docs/decisions/` — ADRs (append-only)

## Contract with the umbrella

`bootstrap redis` will shell-out to `lib/install.sh install` here. The
submodule must:

1. Expose `lib/install.sh` with subcommands: `install`, `verify`, `status`, `reset`.
2. Read its URL from `$DATA_LAYER_REDIS_URL` (set in `.env.example`).
3. Be idempotent: re-running `install` must be a no-op when already applied.
4. Return non-zero exit on `verify` failure so the umbrella's smoke test catches it.
