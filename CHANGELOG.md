# Changelog — data-layer

All notable changes to this umbrella repository are documented in this
file. Per-submodule changelogs live in each submodule's own repo
(`data-layer-{postgres,redis,falkordb,qdrant,adapters}/CHANGELOG.md`).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Phase 0 documentation** (umbrella + 4 submodule schema docs + 1
  adapters tools/wiring doc).
  - `docs/SUBMODULE_OWNERSHIP.md` — boundary rules, ownership matrix,
    wiring-route map, audit triggers
  - `data-layer-postgres/SCHEMAS.md` — 13 tables across 7 migrations,
    per-column 5-dimension spec
  - `data-layer-redis/SCHEMAS.md` — 6 dual-write + 7 pure-ephemeral key
    families + RESP command inventory
  - `data-layer-falkordb/SCHEMAS.md` — 5 nodes + 5 edges + cypher
    migrations + derivation contract
  - `data-layer-qdrant/SCHEMAS.md` — both collections
    (mpg_source_authority_documents with 15 fields + mpg_emails with
    13 fields), SOT filters, cross-layer joins
  - `data-layer-adapters/TOOLS_AND_WIRING.md` — all 21 MCP tools + lib
    scripts + framework adapters + dual-write path
- **TOOLS_AND_WIRING.md** (umbrella) — bootstrap dispatcher, install.sh,
  docker-compose.yml, .gitmodules, MCP registration history, versioning
- **NOTICE** — third-party attributions for PostgreSQL+pgvector, Valkey,
  FalkorDB (SSPL v1 warning), Qdrant, fastembed, sentence-transformers,
  Agent Zero, MCP SDK, LiteLLM, Flask, Alpine.js, etc.
- **CONTRIBUTING.md** — ICLA + CCLA templates + DCO sign-off alternative
  + license posture summary + security disclosure policy
- **docs/audits/fastembed-license-compat.md** — license compatibility
  audit of the qdrant embedding pipeline (Apache-2.0 / MIT — PASS)
- **LICENSE files** in all 6 repos (umbrella + 5 submodules)

### Changed

- **Redis swap**: `data-layer-redis/Dockerfile` FROM
  `redis:7.2-alpine` → `valkey/valkey:8-alpine` (active BSD-3 fork;
  RESP + on-disk format compatible, no source changes to redis.conf,
  write_through.py, or redis_publish_hook.py)
- **MCP registration dedupe**: per-project `.a0proj/mcp_servers.json` in
  the umbrella + adapters submodules cleared to `{}` (the global
  `/a0/usr/settings.json` `mcp_servers` is canonical; backups at
  `.bak-20260916T164142Z-mcp-dedupe`)
- `.gitignore` updated to exclude runtime marker files
  (`.qdrant-initialized`, `.service-initialized`, `.application-built`)
- `data-layer/TOOLS_AND_WIRING.md` relocated to umbrella root
  (`/TOOLS_AND_WIRING.md`)
- `docs/architecture.md`, `docs/bootstrap-flow.md`, `docs/README.md`,
  `docs/services/README.md`, `README.md`, `AGENTS.md` refreshed to
  reference the 5th submodule (qdrant) and the new docs structure

### Security

- **P0.1 SEC-1 SQL injection probe** (cheapest probe, biggest blocker
  per HANDOFF §3.2): PASSED
  - 18 write verbs refused structurally before cursor opens
    (`assert_select_only` in `tools/safety.py`)
  - 13 of 14 postgres-backed tools use parameterized queries
    (`cur.execute(sql, params)` with `%s` placeholders)
  - `_tool_health_check` uses module-constant table list with
    `# noqa: S608` (no user input)
  - LIKE escape `_escape_like(q)` defends against `%` / `_` injection
  - `_tool_execute_sql` writes blocked at the verb gate, before any
    cursor opens
- **Known limitation** documented: plpgsql bypass via
  `SELECT my_dml_func()` — follow-up: connect the MCP postgres role with
  `default_transaction_read_only=on` (or `pg_read_only` on PG 16+)

### Fixed

- **qdrant submodule drift cleanup**: reverted uncommitted edits to
  `data-layer-qdrant/lib/seed.py` and `data-layer-qdrant/lib/mail_replay.py`
  from a prior session (HEAD now clean at `aae59ee`)
- **stale `/data-layer-qdrant/` gitignore entries** removed (qdrant is
  now a proper submodule per `.gitmodules`, not a local convenience
  copy)

## [0.0.0] — 2026-09-15

### Added

- **5th submodule wired live**: `data-layer-qdrant` (vector / RAG layer
  with 2 collections `mpg_source_authority_documents` +
  `mpg_emails`; 768-dim cosine; `sentence-transformers/all-mpnet-base-v2`)
- 7/7 postgres migrations applied (0001_init..0007_emails)
- 2/2 qdrant collections created (`.qdrant-initialized` marker present)
- Universal MCP server with 21 tools (14 postgres-backed + 7
  qdrant-backed RAG)
- Dual-write cache layer + redis_publish_hook
- Native wire-up runbook (HANDOFF §10)

### Security

- MCP server exposes reads only; writes (`rag.ingest.point`,
  `rag.ingest.batch`) gated by `MCP_INSTALL_MODE=1`
- Postgres uses scram-sha-256 (not trust) for superuser + agent_zero
  roles; per-table grants via `apply_agent_zero_grants.py`

---

Format reference: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
