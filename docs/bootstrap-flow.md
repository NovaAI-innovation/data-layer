# data-layer bootstrap flow

This doc describes what happens when `data-layer/bootstrap` runs end-to-end.
The flow is **not yet wired** — this scaffold is structure-only — but the
contract is defined here so the wiring pass is mechanical.

## Entry points

- `./bootstrap` — full dispatcher (`install | verify | status | help`)
- `./install.sh` — convenience wrapper that runs `bootstrap all`

## Subcommand behaviour (planned)

### `bootstrap all`

1. `git -C "$DATA_LAYER_BASE" submodule update --init --recursive` — ensure submodules are present.
2. Delegate to each submodule's `lib/install.sh install`:
   - `data-layer-postgres` → installs postgres cluster + applies schema migrations
   - `data-layer-redis` → installs/configures redis with tenant prefixes
   - `data-layer-falkordb` → installs/configures falkordb and bootstraps the graph
   - `data-layer-adapters` → invokes per-adapter installer (currently A0)
3. Run `tests/smoke_test.sh` to verify each component is reachable.

### `bootstrap <component>`

Same as above but scoped to one submodule. Useful for surgical installs.

### `bootstrap verify`

Reads each submodule's `lib/install.sh verify` to confirm reachability
(postgres connection, redis ping, falkordb health, adapter tool listing).

### `bootstrap status`

Prints each submodule's current state (installed? running? last verify?).

### `bootstrap help`

Prints the usage block.

## Environment

`DATA_LAYER_BASE` defaults to the directory containing `bootstrap`. Override
only when symlinking the dispatcher elsewhere.

Per-submodule DSN / URL env vars live in `.env.example` / `.a0proj/variables.env`.
Real secrets live in `.a0proj/secrets.env` (mode 0600, not committed).
