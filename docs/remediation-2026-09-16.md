# Data-Layer Bootstrap Kit — Master Remediation & Deployment Plan v2

**Date:** 2026-09-16 · **Status:** ACTIVE
**AMENDED 2026-09-17 (principal directive):** compose-first — `docker-compose.yml` is the
canonical deployment (hardened A0 via `deploy/docker-compose.agent-zero.yml`); the native
in-container wire-up is deprecated and its supervisor programs were disabled at user request.
`lib/` is retained as the documented fallback rungs for optional native-mode hosts only.
**Contract:** end of session, this repo is a bootstrap kit that installs all data-centric
services, tooling, and context start-to-finish (optionally installing Agent Zero first),
idempotent and identically repeatable on fresh or minimally drifted deployments, open-ended
for future services/layers and bulk prefabricated agent deployments.

## 0. Root cause being remediated (verified 2026-09-16)

Native wire-up inside the A0 container (dockerd blocked: iptables denied). All services were
launched `nohup`/`--daemonize` with no supervisor; the A0 restart killed valkey/falkordb/qdrant;
postgres survived only by manual restart. Secondary: redis submodule lifecycle is a placeholder;
bootstrap health-wait assumes compose; falkordb had no persistence policy; postgres collation
warning; plugin capture unverified live.

## 1. Port plan — the +1 rule (single source of truth)

Rule: every host-visible port = standard + 1. On collision, escalate deterministically
(+2, +3, …) in stack-composition order. Internal/container ports stay standard.

| Service | Standard | Host (+1) | Internal | Surface |
|---|---|---|---|---|
| postgres | 5432 | **5433** | 5432 | native + compose publish |
| valkey (cache) | 6379 | **6380** | 6379 | native + compose publish |
| falkordb RESP | 6379 | **6381** (6380 taken → +2) | 6379 | native + compose publish |
| falkordb bolt/UI | 7687 | **7688** | 7687 | compose publish |
| falkordb web | 3000 | **3001** | 3000 | compose publish |
| qdrant HTTP | 6333 | **6334** | 6333 | native + compose publish |
| qdrant gRPC | 6334 | **6335** | 6334 | native + compose publish |
| A0 WebUI (hardened compose) | 80 | **81** | 80 | compose publish |
| A0 SSH (hardened compose) | 22 | **23** | 22 | compose publish |

Env-driven overrides (all consumers read these; `.env.example` documents them):
`DATA_LAYER_PG_PORT=5433`, `DATA_LAYER_REDIS_PORT=6380`, `DATA_LAYER_FALKORDB_PORT=6381`,
`DATA_LAYER_QDRANT_HTTP_PORT=6334`, `DATA_LAYER_QDRANT_GRPC_PORT=6335`.
DSN/URLs are derived: `postgresql://…@localhost:5433/postgres`, `redis://localhost:6380/0`,
`redis://localhost:6381`, `http://localhost:6334`.

Uniqueness identity (native + compose): project `data-layer`, supervisor programs
`data-layer-*`, compose project `data-layer`, network `data_layer`, containers `data-layer-*`,
A0 hardened stack `data-layer-agent-zero` on network `data_layer`.

## 2. Phase plan — approach / fallback / fail-stop / gate per phase

### Phase 0 — Preflight & dependencies
- **Objective:** all binaries + dirs present on any fresh container.
- **Approach:** `scripts/preflight.sh` extended with a native mode: check/Install postgres 18 + pgvector (apt), valkey (apt), qdrant (GitHub tarball → `/usr/local/bin`), falkordb.so (image-layer extraction script), jq/curl.
- **Fallback:** per-component skip-with-report when `DATA_LAYER_SKIP_INSTALL=<comp>`; final gate still fails loud if a required binary is missing at start time.
- **Fail-stop:** preflight exit ≠ 0 aborts `install.sh` before any mutation.
- **Gate:** preflight report all-green; artifacts: `/usr/local/bin/qdrant`, `/var/lib/falkordb/bin/falkordb.so`.

### Phase 1 — Port cutover (+1)
- **Objective:** live listeners + all consumers on the +1 port set.
- **Approach (initial):** coordinated cutover — postgresql.conf `port=5433` + cluster restart; .env regenerated; `/a0/usr/settings.json` MCP DSN updated; A0 process env gains `DATA_LAYER_POSTGRES_DSN` (supervisor `run_ui` environment line); compose publishes rewritten.
- **Fallback:** env overrides only (no live cutover) when `DATA_LAYER_PORT_CUTOVER=0` — for drifted hosts where 5432 must stay.
- **Fail-stop:** any port bind conflict during cutover aborts with the conflicting listener named.
- **Gate:** `ss -tlnp` shows exactly 5433/6380/6381/6334; `bootstrap health` green; MCP DSN probe green.

### Phase 2 — Service lifecycle (supervision)
- **Objective:** every service crash-proof + reboot-proof under PID-1 supervisord.
- **Approach:** `lib/install_supervisor_programs.sh` generates `/etc/supervisor/conf.d/data-layer-{postgres,valkey,falkordb,qdrant,hook}.conf` from in-repo templates (unique names, autorestart, startsecs, scoped env incl. ports + DSNs); `supervisorctl reread/update/start`.
- **Fallback:** `lib/service_ctl.sh <svc> start-direct` (nohup/daemonize + pidfile) when supervisorctl unavailable/rejects.
- **Last resort:** fail-out-loud — non-zero exit naming binary/permission/env that blocked each rung; never silent, never half-green.
- **Gate:** `supervisorctl status` all RUNNING; kill-process chaos probe → autorestart within startsecs; full container restart test in Phase 7.

### Phase 3 — Schema & data population with validation phase
- **Objective:** existing data validated at low/no cost; absent data populated idempotently.
- **Approach:** `bootstrap validate` (read-only) runs FIRST: postgres `schema_migrations` vs migrations dir; qdrant collections + point counts (populated ⇒ validated, **not** reseeded); falkordb `:_SchemaMigrations` vs `migrations/*.cypher`; valkey PING. Then `bootstrap all` populates only what validate reports missing, via unchanged per-submodule `lib/install.sh` contracts.
- **Fallback:** per-service populate retry once; then fail-loud with the service's own error.
- **Fail-stop:** any destructive operation (`reset`, `down -v`, drop) requires explicit human invocation — never run inside install/all/up paths.
- **Gate:** validation report persisted to `docs/evidence/validate-<ts>.md`; migrations 7/7; 2 qdrant collections present; graph module loaded.

### Phase 4 — Adapters, MCP, plugin wiring
- **Objective:** single agent-facing surface (21 MCP tools) + writer plugin live on +1 ports.
- **Approach:** settings.json MCP DSN → 5433; publish-hook sidecar program env → 6380 + DSN 5433; plugin DSN env var set in A0 process env.
- **Fallback:** plugin hooks remain best-effort (postgres outage never breaks tool calls) — by design.
- **Gate:** MCP e2e suite full green (`DATA_LAYER_TEST_DSN` → 5433); `tool_executions` row delta > 0 across live probes.

### Phase 5 — Hardened Agent Zero compose file
- **Objective:** the agent itself ships as a hardened, pre-configured container joining the stack.
- **Approach:** `deploy/docker-compose.agent-zero.yml` — service `a0-core` (container `data-layer-agent-zero`), joins `data_layer` network, publishes 81:80 + 23:22, mounts plugins/config/workdir read-only where possible, env-wired to all data services, healthcheck on WebUI, `restart: unless-stopped`, no privileged mode, non-root where feasible.
- **Fallback:** existing non-compose A0 (current container) remains supported; compose file is additive.
- **Gate:** `docker compose -f deploy/docker-compose.agent-zero.yml config` validates; dry-run plan clean.

### Phase 6 — Verification gates & smoke tests
- Gates (all must pass, in order): preflight → supervisor RUNNING ×5 → health probes (pg_isready 5433, PING 6380, PING+graph 6381, /healthz 6334 + 2 collections) → `bootstrap validate` report → MCP e2e green → plugin row delta > 0 → `tests/smoke_test.sh` extended for native+ports.
- **QC agent:** every gate output appended to `docs/evidence/session-2026-09-16.md`; discrepancies block release.

### Phase 7 — Fresh-deployment zero-touch proof (HITL checkpoint)
- **Objective:** prove identical repeatability.
- **Approach:** stop everything, wipe generated supervisor confs, then `./install.sh` on this container as the fresh-deploy stand-in; then (when the user provides a fresh A0) full external run.
- **Fail-stop:** any manual step discovered ⇒ release blocked, back to the owning phase.
- **HITL:** user reviews evidence pack + may request a true fresh-container run before push.

### Phase 8 — Release
- HANDOFF.md §14; commit umbrella (bootstrap, lib/, deploy/, docs/, compose, .env.example) + adapters pointer bump; push all remotes (auth pre-verified).
- **Gate:** `git status` clean; `origin/main` ahead-resolved; evidence pack linked in HANDOFF.

## 3. Cross-cutting contracts

- **Idempotency:** re-running any entry point converges to the same state; no destructive defaults.
- **Fail-out-loud ladder:** supervisor → direct launch → loud failure (exit≠0, named rung).
- **Validation-before-population:** always; populated ⇒ verify + report only.
- **Open-ended extension:** adding service #7 = one submodule + one `SUBMODULES` entry + one supervisor template + one port-plan row (+1 rule) + one validate check; nothing else changes. Layers may be added wholesale (bulk prefabricated agents) by composing additional compose files on the same network.
- **Secrets:** real values only in `.a0proj/secrets.env` / `.env` (untracked); `.env.example` carries placeholders.

## 4. Session execution order (tracked in todo list, project `data-layer`)

1. [x] Diagnosis + approval + todo hygiene (49 stale cancelled)
2. [ ] Plan v2 (this doc) — in_progress
3. [ ] Port cutover + env/settings wiring
4. [ ] Lifecycle tooling (service_ctl, supervisor generator, validate) + bootstrap up/health/validate
5. [ ] Services restored under supervision + all Phase-6 gates
6. [ ] Hardened A0 compose file
7. [ ] Zero-touch fresh-deploy simulation + evidence pack
8. [ ] HANDOFF §14 + commit + push
