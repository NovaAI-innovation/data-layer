# data-layer architecture

The data-layer umbrella orchestrates five service-level submodules.
Each submodule is its own git repository with its own remote, Dockerfile,
`lib/install.sh`, and migration files.

```
data-layer (umbrella)
├── bootstrap                       single dispatcher (init|install|verify|status|help)
├── install.sh                      convenience wrapper (runs bootstrap all)
├── docker-compose.yml              five-service compose file
├── scripts/                        one-shot installers + preflight
├── tests/                          cross-submodule smoke test
├── docs/                           architecture + bootstrap-flow + services overview
data-layer-postgres/                its own repo — postgres schema + migrations (the SOT)
data-layer-redis/                   its own repo — redis cache + tenant isolation (ephemeral)
data-layer-falkordb/                its own repo — falkordb graph + Cypher migrations
data-layer-qdrant/                  its own repo — vector / RAG layer (semantic index)
data-layer-adapters/                its own repo — framework adapters + universal MCP server
```

## Ownership map

| Submodule | Owns | Does NOT own |
|---|---|---|
| `data-layer-postgres` | Framework-agnostic postgres schema + migration applier + cluster installer + agent_zero role | Agent Zero plugin, framework adapters, Redis/FalkorDB/Qdrant |
| `data-layer-redis` | Framework-agnostic redis cache layer + tenant isolation + bounded payloads | Schema, postgres/falkordb/qdrant, framework adapters |
| `data-layer-falkordb` | Framework-agnostic falkordb graph layer + node/edge schema | Cache, postgres, qdrant, framework adapters |
| `data-layer-qdrant` | Vector index (Qdrant) + collection migrations + bootstrap-driven seed pipeline + 2-collection SOT model (mpg_source_authority_documents + mpg_emails) | Postgres schema, framework adapters |
| `data-layer-adapters` | Framework adapters collection (A0 + Hermes) + **universal MCP server** (21 tools, zero write tools by default; gated `rag.ingest.*` writes) + redis_publish_hook sidecar | Service-level storage backends |

## Dependency rules

- Components are siblings — no cross-component dependency at the git level.
- Submodules communicate only at runtime via DSN / URL env variables.
- The umbrella is the only thing that imports / orchestrates the five.
- Framework adapters consume service DSNs through `data-layer-adapters`.
- The **single agent-facing retrieval surface** is the universal MCP server
  in `data-layer-adapters/mcp/`. It owns 14 Postgres-backed tools + 7
  Qdrant-backed RAG tools. Zero write tools are exposed to the agent
  without `MCP_INSTALL_MODE=1`.

## Bootstrap ordering

The dispatcher follows this ordering:

1. `init` — `git submodule update --init --recursive` (first-clone only)
2. `data-layer-postgres` install (cluster + schema + applier)
3. `data-layer-redis` install (server + tenant prefix)
4. `data-layer-falkordb` install (server + graph bootstrap)
5. `data-layer-qdrant` install (Qdrant server + collection migrations + seed; gated by `MCP_INSTALL_MODE=1` for the seed step)
6. `data-layer-adapters` seed (per-adapter framework seeds)
7. `bootstrap verify` — reachability check across all five.

The ordering reflects the data-flow graph: postgres is the immutable
historical record; redis is the ephemeral cache; falkordb is the graph;
qdrant is the derived semantic index; adapters are the universal
agent-facing surface that talks to all of them.

## Cross-layer data flow: email → postgres → qdrant

The canonical end-to-end flow that motivates this architecture:

```
[ IMAP / Gmail / SMTP ]
        │
        ▼
   postgres.emails        (immutable historical record; 0007_emails.sql)
        │
        ├── qdrant.mpg_emails          (derived semantic index; payload carries
        │                               message_id, from, to, subject, body, lifecycle)
        │
        └── falkordb (future)          (graph edges: thread_id, in_reply_to,
                                        sender→recipient)
        │
        ▼
   MCP tools:
     - read path:  rag.search on mpg_emails (always-on)
                   history.retrieve across messages + tool_executions
     - write path: rag.ingest.point / rag.ingest.batch (gated)
                   bootstrap seed writes here, never the agent
```

Key invariants:

* Postgres is the **single source of truth** for the email record.
  Qdrant is a derived index; if qdrant is rebuilt from scratch, the
  seed script reads the postgres rows and re-embeds.
* The postgres `qdrant_point_id` column is the join key.
  `qdrant_ingested_y_n` (`Y|N|SUPERSEDED|DO_NOT_INGEST`) is the
  ingestion gate. `DO_NOT_INGEST` rows are kept in postgres for
  audit but never sent to qdrant.
* Search-side SOT enforcement: `rag.search` ALWAYS excludes
  `do_not_ingest_y_n='Y'` and `lifecycle_status='superseded'`. The
  filter cannot be overridden by the caller.

## Docker compose architecture

```
docker compose up -d --build
    ├── postgres   ← pgvector/pgvector:pg16
    ├── redis      ← redis:7.2-alpine
    ├── falkordb   ← falkordb/falkordb:latest
    ├── qdrant     ← qdrant/qdrant:v1.19.1   (NEW: 5th service)
    └── adapters   ← python:3.12-slim (universal MCP + hook sidecar)
                        depends_on: postgres, redis, falkordb, qdrant (all healthy)
```

Services communicate over the `data_layer` bridge network. The adapters
service uses compose-provided hostnames (`postgres`, `redis`, `falkordb`,
`qdrant`) to reach the four backend services. The universal MCP server
inside `data-layer-adapters` exposes 21 tools (14 Postgres + 7 Qdrant)
on stdio and is the single surface the agent ever touches.
