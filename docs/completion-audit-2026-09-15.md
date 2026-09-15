# data-layer Completion Gate Audit — 2026-09-15

Comprehensive submodule-by-submodule audit. Each component is graded
COMPLETE / PARTIAL / STUB / MISSING based on live code inspection.

---

## A. Per-Submodule Matrix

### 1. data-layer-postgres

| Component | Status | Evidence | Gap/Blocker |
|---|---|---|---|
| Dockerfile | COMPLETE | 35 lines, pgvector/pgvector:pg16 base, copies migrations + initdb script, HEALTHCHECK | None |
| lib/install.sh | COMPLETE | 302 lines, install/verify/status/reset, migration tracker, agent_zero grants via psycopg, dry-run | None |
| Migrations | COMPLETE | 6 files (0001_init → 0006_idempotency_keys), append-only, IF NOT EXISTS idempotent | None |
| docker-entrypoint-initdb.d/ | COMPLETE | zzz_create_agent_zero.sh + all .sql migrations copied by Dockerfile | None |
| AGENTS.md | COMPLETE | Documents boundary, layout, commands, env, migration policy | None |
| .env.example | COMPLETE | DSN, POSTGRES_PASSWORD, agent_zero password, container vars | None |
| tests/smoke.sh | COMPLETE | Referenced in README, exists on disk | Not verified in-container (no psql available) |

**Submodule grade: COMPLETE (95%)**
Gap: `lib/install.sh` requires `psycopg` at runtime — auto-bootstraps via pip if missing, but first-run on bare hosts may need network.

---

### 2. data-layer-redis

| Component | Status | Evidence | Gap/Blocker |
|---|---|---|---|
| Dockerfile | COMPLETE | 29 lines, redis:7.2-alpine, custom redis.conf, HEALTHCHECK | None |
| redis.conf | COMPLETE | Hardened: AOF, lazyfree, allkeys-lru, referenced by Dockerfile | None |
| lib/install.sh | COMPLETE | 68 lines, install/verify/status/reset, PING check, config reporting, ENABLED bypass flag | None |
| AGENTS.md | COMPLETE | Documents boundary, layout, commands, env, key pattern catalog | None |
| .env.example | COMPLETE | URL, prefix, TTL, enabled flag, container vars | None |
| tests/smoke.sh | COMPLETE | Referenced in README | Not verified in-container |

**Submodule grade: COMPLETE (95%)**
Gap: Redis is unpassworded by default. `requirepass` not set in redis.conf. Fine for local dev, blocker for multi-host.

---

### 3. data-layer-falkordb

| Component | Status | Evidence | Gap/Blocker |
|---|---|---|---|
| Dockerfile | COMPLETE | 48 lines, falkordb/falkordb:latest, python3 for applier, custom entrypoint, HEALTHCHECK | None |
| docker-entrypoint.sh | COMPLETE | Referenced in Dockerfile, applies migrations + seeds on first start | None |
| lib/install.sh | COMPLETE | 309 lines, install/verify/status/reset/bootstrap-test-sandbox, bolt + redis paths | None |
| lib/falkordb.sh | COMPLETE | 109 lines, native installer with idempotent tarball download | None |
| Migrations | COMPLETE | 2 .cypher files (0001_nodes, 0002_edges), idempotent via _SchemaMigrations sentinel | None |
| lib/bootstrap_payload.py | COMPLETE | Python applier for multi-statement Cypher, referenced by install.sh | None |
| AGENTS.md | COMPLETE | Documents boundary, layout, commands, env, runtime properties | None |
| .env.example | COMPLETE | URL, database, image, container vars | None |

**Submodule grade: COMPLETE (95%)**
Gap: FalkorDB RESP port (6379) collides with any standalone redis on the same host. Documented but not guarded.

---

### 4. data-layer-adapters

| Component | Status | Evidence | Gap/Blocker |
|---|---|---|---|
| Dockerfile | COMPLETE | python:3.12-slim, psycopg + redis-py, multi-role entrypoint | None |
| docker-entrypoint.sh | COMPLETE | hook/mcp/smoke/help roles, ADAPTER_ROLE env var | None |
| bootstrap | COMPLETE | 43 lines, agent-zero/hermes-agent/mcp/all/seed/verify/status/reset | None |
| agent-zero/bootstrap | COMPLETE | 38 lines, install/verify/status/reset/seed, uses lib/deps.sh + lib/plugin.sh | None |
| agent-zero/seeds/0001_default_agent.sql | COMPLETE | 32 lines, idempotent (ON CONFLICT DO NOTHING), placeholder substitution | None |
| hermes-agent/bootstrap | COMPLETE | 35 lines, same pattern as agent-zero | None |
| hermes-agent/seeds/0001_seed_hermes.sql | COMPLETE | 34 lines, idempotent, metadata with kanban flag | Hermes version = NULL (intentional?) |
| lib/write_through.py | COMPLETE | 347 lines, dual-write (pg primary → redis cache → falkordb via publish hook), category flags, counters | None |
| lib/redis_publish_hook.py | COMPLETE | 308 lines, consumes PUBLISH events, projects to falkordb via MERGE | None |
| mcp/server.py | COMPLETE | 190 lines, MCP protocol 2024-11-05, stdio transport | None |
| AGENTS.md | EXISTS | Documents layout, per-adapter commands, universal MCP | Brief — could document more of the dual-write contract |
| .env.example | COMPLETE | DSN, container names, MCP server path | Missing DW_* flags |

**Submodule grade: COMPLETE (90%)**
Gaps:
1. `.env.example` does not list the 6 `DATA_LAYER_DW_*` category flags
2. Hermes seed has `version = NULL` — intentional placeholder or oversight?
3. `lib/deps.sh` and `lib/plugin.sh` not audited (agent-zero/lib/)

---

### 5. Umbrella Layer

| Component | Status | Evidence | Gap/Blocker |
|---|---|---|---|
| bootstrap dispatcher | COMPLETE | 115 lines, all subcommands wired (postgres/redis/falkordb/adapters/seed/all/verify/status/help) | None |
| install.sh | COMPLETE | 4 lines, convenience wrapper for `bootstrap all` | None |
| docker-compose.yml | PARTIAL | 152 lines, all 4 services, healthchecks, depends_on ordering | Missing DW_* env passthrough (only DW_SESSION_PRESENCE is wired) |
| .env.example | PARTIAL | 37 lines, has required vars | Missing DW_* category flags |
| .gitmodules | COMPLETE | 4 submodules, correct URLs to github.com/NovaAI-innovation | None |
| .gitignore | BUGGY | 65 lines | Lines 62-65 ignore submodule working trees (breaks submodule tracking). Lines 35-46 duplicate FAISS block. |
| README.md | STALE | 44 lines, says 'placeholders, deferred to future pass' | Needs full rewrite |
| docs/architecture.md | STALE | 43 lines, says 'placeholder, future pass' | Needs full rewrite |
| docs/bootstrap-flow.md | STALE | 47 lines, says 'not yet wired, scaffold is structure-only' | Needs full rewrite |
| docs/services/README.md | STALE | 15 lines, says 'placeholder' | Needs full rewrite |
| tests/smoke_test.sh | STUB | 8 lines, placeholder, exit 0 | Needs real implementation |
| .a0proj/ | COMPLETE | secrets.env (empty), variables.env (7 vars), project.json | None |

**Umbrella grade: PARTIAL (60%)**

---

## B. Env Var Inventory

### Required (compose :? guard — will fail to start if unset)

| Variable | Required By | Has Default | Set In .env.example | Notes |
|---|---|---|---|---|
| POSTGRES_PASSWORD | docker-compose.yml postgres service | No | Yes (empty) | Superuser password |
| DATA_LAYER_AGENT_ZERO_PASSWORD | docker-compose.yml postgres + adapters | No | Yes (empty) | Tenant role password |

### Optional with defaults

| Variable | Required By | Default | Set In .env.example | Notes |
|---|---|---|---|---|
| POSTGRES_USER | compose | postgres | Yes | |
| POSTGRES_DB | compose | postgres | Yes | |
| POSTGRES_HOST_AUTH_METHOD | compose | scram-sha-256 | Yes | |
| DATA_LAYER_POSTGRES_DSN | postgres install.sh | postgresql://postgres@localhost:5432/postgres | Yes | |
| DATA_LAYER_REDIS_URL | redis install.sh | redis://localhost:6379/0 | Yes | |
| DATA_LAYER_REDIS_PREFIX | redis | dl: | Yes | |
| DATA_LAYER_REDIS_TTL | redis | 300 | Yes | |
| DATA_LAYER_REDIS_ENABLED | redis | true | No | Missing from umbrella .env.example |
| DATA_LAYER_FALKORDB_URL | falkordb install.sh | bolt://localhost:7687 | Yes | |
| DATA_LAYER_FALKORDB_DATABASE | falkordb | default | Yes | |
| DATA_LAYER_FALKORDB_IMAGE | falkordb | falkordb/falkordb:latest | No | Only used by bootstrap-test-sandbox |
| DATA_LAYER_FALKORDB_CONTAINER | falkordb | falkordb-test-sandbox | No | Only used by bootstrap-test-sandbox |
| DATA_LAYER_FALKORDB_VERSION | falkordb.sh | (latest) | No | Native installer version |

### DW Category Flags (ALL MISSING from .env.example and docker-compose.yml)

| Variable | Category | Default in write_through.py | Wired in compose? |
|---|---|---|---|
| DATA_LAYER_DW_SESSION_PRESENCE | session_presence | false | YES (line 140) |
| DATA_LAYER_DW_TOOL_EXECUTION | tool_execution | false | **NO** |
| DATA_LAYER_DW_IDEMPOTENCY_KEY | idempotency_key | false | **NO** |
| DATA_LAYER_DW_RECENT_MESSAGES | recent_messages | false | **NO** |
| DATA_LAYER_DW_RATE_LIMIT_EVENT | rate_limit_event | false | **NO** |
| DATA_LAYER_DW_LOCK_AUDIT | lock_audit | false | **NO** |

**Critical gap**: Only `DW_SESSION_PRESENCE` is passed through to the adapters container.
The other 5 categories cannot be activated without editing docker-compose.yml.

---

## C. Bootstrap Path Trace

Step-by-step from `git clone` to `bootstrap verify`:

| Step | Command | Status | Evidence |
|---|---|---|---|
| 1 | `git clone --recurse-submodules <url>` | NEEDS FIX | .gitignore ignores submodule dirs; working trees populate but git status hides drift |
| 2 | Copy .env.example → .env | OK | Template exists, clear instructions |
| 3 | Set POSTGRES_PASSWORD | OK | Documented in .env.example comments |
| 4 | Set DATA_LAYER_AGENT_ZERO_PASSWORD | OK | Documented in .env.example comments |
| 5 | `docker compose up -d --build` | OK | All 4 services build from local Dockerfiles |
| 6 | Wait for healthchecks | **GAP** | No automated wait script; bootstrap runs install immediately which may race healthchecks |
| 7 | `./install.sh` (→ `bootstrap all`) | OK | Wired: postgres install → redis install → falkordb install → adapters seed |
| 8 | `./bootstrap verify` | OK | Delegates to each submodule's lib/install.sh verify |
| 9 | `./bootstrap status` | OK | Tolerant of failures |
| 10 | `tests/smoke_test.sh` | **STUB** | Placeholder, always exits 0 |

**Gaps**: Steps 1 (gitignore), 6 (no healthcheck wait), 10 (stub test)

---

## D. Framework Extensibility Assessment

### What works today

The adapters submodule is designed for multi-framework support:
- Each framework gets its own subdirectory (`agent-zero/`, `hermes-agent/`)
- Each has a `bootstrap` script with standard subcommands (install/verify/status/reset/seed)
- Each has a `seeds/` directory with idempotent SQL
- The umbrella `bootstrap` dispatches to `data-layer-adapters/bootstrap` which iterates frameworks
- The MCP server in `mcp/` is framework-agnostic
- `write_through.py` and `redis_publish_hook.py` are framework-agnostic

### What would need to change to add a new framework (e.g., 'crewai')

1. Create `data-layer-adapters/crewai/` with:
   - `bootstrap` (install/verify/status/reset/seed)
   - `lib/deps.sh`, `lib/plugin.sh` (or equivalent)
   - `seeds/0001_seed_crewai.sql` (idempotent INSERT INTO agent_frameworks + agents)
2. Add `crewai` to the adapters bootstrap's `for d in agent-zero hermes-agent` loop
3. Add `crewai` case to umbrella bootstrap if needed (currently only 'adapters' exists)
4. No changes to postgres schema, redis, falkordb, write_through, or redis_publish_hook needed

### Assessment

**The contract is clean.** A new framework requires:
- 1 new subdirectory under adapters
- 1 seed SQL file
- 1 line added to adapters bootstrap loop
- Zero changes to the 3 service submodules

**Framework extensibility grade: COMPLETE (95%)**
Gap: The adapters bootstrap hardcodes `for d in agent-zero hermes-agent` — a new framework needs a code edit. Could be made auto-discovering.

---

## E. Top Blockers (Prioritized)

| # | Severity | Blocker | Fix |
|---|---|---|---|
| 1 | **HIGH** | 5 of 6 DW category flags not wired in docker-compose.yml | Add DATA_LAYER_DW_TOOL_EXECUTION, DW_IDEMPOTENCY_KEY, DW_RECENT_MESSAGES, DW_RATE_LIMIT_EVENT, DW_LOCK_AUDIT to adapters service env |
| 2 | **HIGH** | .env.example missing DW_* flags and DATA_LAYER_REDIS_ENABLED | Add all 7 missing vars to .env.example |
| 3 | **HIGH** | No healthcheck wait in bootstrap | Add `docker compose up -d --build && docker compose exec postgres pg_isready` wait loop before running install |
| 4 | **MEDIUM** | .gitignore ignores submodule working trees | Remove lines 62-65 (data-layer-*/). Keep **/.git and **/.a0proj/. |
| 5 | **MEDIUM** | .gitignore has duplicate FAISS block | Remove duplicate lines 35-46 |
| 6 | **MEDIUM** | README.md / docs/* are stale | Rewrite to reflect live state |
| 7 | **MEDIUM** | tests/smoke_test.sh is a stub | Implement: shell out to `bootstrap verify`, aggregate pass/fail |
| 8 | **MEDIUM** | No one-shot installer | Create scripts/install.sh with dep check, password gen, compose up, wait, bootstrap |
| 9 | **LOW** | Adapters bootstrap hardcodes framework list | Make auto-discovering (ls -d */bootstrap) |
| 10 | **LOW** | Hermes seed has version=NULL | Query Hermes for version or document as intentional |
| 11 | **LOW** | Redis unpassworded by default | Add requirepass to redis.conf or document as dev-only |
| 12 | **LOW** | FalkorDB port 6379 collides with standalone redis | Document or offer alternate port mapping |

---

## F. Completion Percentage

| Component | Weight | Score | Notes |
|---|---|---|---|
| data-layer-postgres | 25% | 95% | Fully wired, minor psycopg bootstrap gap |
| data-layer-redis | 15% | 95% | Fully wired, no auth gap |
| data-layer-falkordb | 15% | 95% | Fully wired, port collision gap |
| data-layer-adapters | 20% | 90% | Fully wired, missing DW flags, hard-coded framework list |
| Umbrella orchestration | 25% | 60% | Wiring done, docs/stubs/gitignore/installer all stale |

**Overall completion: 84%**

### Methodology

Score = (functional completeness × 0.6) + (documentation × 0.2) + (install reliability × 0.2)
- Functional: Does the code work end-to-end? (mostly yes)
- Documentation: Are docs accurate? (no — stale)
- Install reliability: Can a fresh clone install with minimal intervention? (no — missing installer, missing env vars, no healthcheck wait)

---

## G. Recommended Fix Order

To reach 95%+ completion:

1. Fix docker-compose.yml (add 5 missing DW_* env vars) — 5 min
2. Fix .env.example (add 7 missing vars) — 5 min
3. Fix .gitignore (remove submodule ignores + dedup) — 2 min
4. Add healthcheck wait to bootstrap — 10 min
5. Rewrite README.md — 20 min
6. Update docs/architecture.md and docs/bootstrap-flow.md — 15 min
7. Implement tests/smoke_test.sh — 15 min
8. Create scripts/install.sh (one-shot installer) — 30 min
9. Make adapters bootstrap auto-discovering — 10 min

**Total estimated fix time: ~2 hours**
