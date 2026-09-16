# Submodule Ownership & Boundaries

**Last reconciled:** 2026-09-16 (this doc is the authoritative index for the
submodule-boundary audit described in HANDOFF §1.1).

This document is the umbrella's master map of who-owns-what across the
five submodules. Each submodule ships its own detailed docs:

- **`data-layer-postgres/SCHEMAS.md`** — table-by-table, column-by-column schema spec.
- **`data-layer-redis/SCHEMAS.md`** — key namespace + TTL contract.
- **`data-layer-falkordb/SCHEMAS.md`** — node labels, edge types, properties.
- **`data-layer-qdrant/SCHEMAS.md`** — collection payload schemas (2 collections).
- **`data-layer-adapters/TOOLS_AND_WIRING.md`** — every CLI tool, MCP tool, lib script, and its wiring route.
- **`data-layer/TOOLS_AND_WIRING.md`** (umbrella) — orchestration wiring (bootstrap, install.sh, docker-compose, MCP registration).

## Boundary rules (binding across all submodules)

1. **No cross-submodule imports.** A submodule never imports code or SQL from a sibling submodule. The only allowed cross-submodule call is the umbrella orchestrator shelling out via `bash <submodule>/lib/install.sh <subcommand>` or via the network protocol defined in the contract (postgres DSN, redis RESP, falkordb bolt, qdrant HTTP, MCP JSON-RPC).
2. **No shared mutable state between submodules.** The only state a submodule may expose is via its own service (port, schema, key namespace, or HTTP API).
3. **Umbrella does not own service-level logic.** The umbrella repo orchestrates only — install, verify, status, reset, dispatch — and never implements migrations, queries, or schema.
4. **MCP exposes reads; writes go through bootstrap scripts.** Every write into any submodule is gated by a `<submodule>/lib/install.sh` or `<submodule>/bootstrap` subcommand. The MCP in `data-layer-adapters/mcp/` is read-only by default; `rag.ingest.*` are the only writes and are gated by `MCP_INSTALL_MODE=1`.

## Per-submodule ownership matrix

| Submodule | Owns | Does NOT own |
|---|---|---|
| **`data-layer-postgres`** | All PostgreSQL schemas and migrations (`migrations/0001_*.sql` … `migrations/0007_emails.sql`); DDL, DCL, seed SQL; the source of truth for runtime history (sessions, messages, tool_executions, idempotency_keys, session_heartbeats, agents, projects, emails). | Vector storage (→ qdrant); ephemeral cache (→ redis); graph nodes/edges (→ falkordb); framework-specific adapter code (→ adapters). |
| **`data-layer-redis`** | Redis key namespace + TTL policy; dual-write cache layer for postgres; presence/idempotency/lock primitives; the RESP interface contract. | Persistent storage (→ postgres); semantic search (→ qdrant); graph (→ falkordb); agent framework code (→ adapters). |
| **`data-layer-falkordb`** | Graph layer: nodes (e.g., `Session`, `Agent`, `Project`, `Tool`, `Email`) and edges (e.g., `INVOKED`, `BELONGS_TO`, `REFERENCES`); Cypher migrations in `migrations/`; bolt protocol. | Tabular history (→ postgres); ephemeral cache (→ redis); vector search (→ qdrant); adapter logic (→ adapters). |
| **`data-layer-qdrant`** | Vector store for the RAG SOT layer; the two collections (`mpg_source_authority_documents`, `mpg_emails`); the embedding pipeline contract (`sentence-transformers/all-mpnet-base-v2`, 768-dim cosine); the HTTP API + allowlist gate. | Tabular data (→ postgres); graph (→ falkordb); framework code (→ adapters). |
| **`data-layer-adapters`** | The universal MCP server (`mcp/server.py`) exposing 21 tools (14 postgres-backed + 7 Qdrant-backed RAG); framework adapters (e.g., `agent-zero/`, `hermes-agent/`) that seed the postgres framework tables; the dual-write hook (`lib/redis_publish_hook.py`, `lib/write_through.py`); the safety/registry/`_registry.py` of MCP tools. | Schema definitions (→ postgres); vector storage (→ qdrant); graph (→ falkordb); cache (→ redis). |
| **`data-layer` (umbrella)** | Orchestration only: `bootstrap` dispatcher, `install.sh`, `docker-compose.yml`, `.gitmodules`, MCP registration (`umbrella/.a0proj/mcp_servers.json` + global A0 registration at `/a0/usr/settings.json` mcp_servers), this documentation index, HANDOFF.md. | Any service-level implementation. |

## Wiring route map (who calls whom)

```
  Agent Zero
       │
       ▼
  /a0/usr/mcp/server.py  (data-layer-adapters/mcp/server.py, deployed)
       │
       ├── 14 postgres-backed tools ──►  data-layer-postgres (DSN)
       │
       └── 7 rag.* tools ────────────►  data-layer-qdrant (HTTP)
                                         │
                                         └─ embedding derivation ←── data-layer-postgres (emails table)

  Dual-write path (writes):
  data-layer-adapters/lib/write_through.py
       │
       ▼
  data-layer-postgres (durable)
       │
       └─► data-layer-redis (cache layer, via redis_publish_hook.py)

  Graph derivation (read):
  data-layer-falkordb
       ▲
       └─ populated from data-layer-postgres via bootstrap migrations

  Orchestration (writes/installs/seed):
  data-layer/bootstrap
       │
       ├─► data-layer-postgres/bootstrap
       ├─► data-layer-redis/bootstrap
       ├─► data-layer-falkordb/bootstrap
       ├─► data-layer-qdrant/bootstrap
       └─► data-layer-adapters/bootstrap (delegates to each framework subdir)
```

## Audit triggers (what changes require re-reading this doc)

- Adding a new submodule (append to the matrix; add wiring arrows).
- Adding a new write path through any submodule (update the dual-write diagram).
- Promoting a `rag.ingest.*` write to runtime (move from MCP_INSTALL_MODE-gated to always-on) — REQUIRES a re-spec of the boundary rule #4.
- Cross-submodule data flow change (e.g., qdrant now derives from falkordb instead of postgres).

## See also

- `docs/architecture.md` — relationship diagram (one level up from this matrix).
- `docs/services/README.md` — per-service interface contract (`install | verify | status | reset`).
- `HANDOFF.md` §1.1 — the boundary-audit entry point that triggered this doc.
