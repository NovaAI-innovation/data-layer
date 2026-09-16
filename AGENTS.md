# AGENTS.md — data-layer

Agent contract for the data-layer umbrella project.

## Scope and ownership

This project is the umbrella (orchestrator) for the data-layer stack.
It owns the single bootstrap entry point and the relationship between the
five service-level projects (the fifth, data-layer-qdrant, was added
2026-09-15). It does NOT own any of the service-level implementation
itself; those live in dedicated submodule repos:

- `data-layer-postgres/` — pgvector schema + 7 migrations (0001..0007_emails) + immutable SOT for runtime history. See `./data-layer-postgres/README.md` and `./data-layer-postgres/SCHEMAS.md`.
- `data-layer-redis/` — BSD-3 cache layer (Valkey 8.x); ephemeral presence/idempotency/lock primitives; dual-write mirror of postgres. See `./data-layer-redis/README.md` and `./data-layer-redis/SCHEMAS.md`.
- `data-layer-falkordb/` — Graph layer (nodes + edges + Cypher); SSPL v1. See `./data-layer-falkordb/README.md` and `./data-layer-falkordb/SCHEMAS.md`.
- `data-layer-qdrant/` — Vector/RAG layer (2 collections: mpg_source_authority_documents, mpg_emails); Apache-2.0. See `./data-layer-qdrant/README.md` and `./data-layer-qdrant/SCHEMAS.md`.
- `data-layer-adapters/` — Universal MCP server (21 tools) + framework adapters (agent-zero, hermes-agent) + dual-write hook. See `./data-layer-adapters/README.md` and `./data-layer-adapters/TOOLS_AND_WIRING.md`.

## Isolation and security

Keep plans, scripts, docs, and evidence inside this workspace.
Do not write real secrets to source-controlled files; use `.env.example`
for placeholders. Do not modify files in `/a0`, other projects, global
plugins, system services, or live databases unless the user explicitly
requests the integration and the side effect is reported.

## Required workflow

Before consequential changes, read `README.md`, `docs/architecture.md`,
`docs/bootstrap-flow.md`, `AGENTS.md`, and `.a0proj/instructions/project-isolation.md`.
State the intended outcome and affected paths before implementation.
Keep deployment state separate from source.

## Runtime boundary

Use `/opt/venv-a0/bin/python` for Agent Zero framework and plugin-hook
checks. Use `/opt/venv/bin/python` for task or user-code checks. Do not
treat one runtime as proof of the other.

## Canonical references

- `bootstrap` — single dispatcher (install | verify | status | reset | seed | help)
- `install.sh` — one-shot installer wrapper
- `docker-compose.yml` — single compose file bringing up all 5 services
- `.gitmodules` — five submodule registrations (one per service)
- `HANDOFF.md` — session-by-session handoff log + §1 status snapshot
- `TOOLS_AND_WIRING.md` — umbrella orchestration doc
- `NOTICE` — third-party attributions
- `CONTRIBUTING.md` — ICLA + CCLA + DCO templates + review/security policy
- `LICENSE` — umbrella BSD-3-Clause
- `docs/SUBMODULE_OWNERSHIP.md` — boundary rules + ownership matrix + wiring-route map
- `docs/architecture.md` — submodule relationships
- `docs/bootstrap-flow.md` — what happens when `bootstrap` runs
- `docs/services/README.md` — per-service overview + `lib/install.sh` contract
- `docs/audits/fastembed-license-compat.md` — license compatibility audit (Apache-2.0/MIT, PASS)
- `data-layer-{postgres,redis,falkordb,qdrant}/SCHEMAS.md` — per-submodule schema spec (5-dimension per column)
- `data-layer-adapters/TOOLS_AND_WIRING.md` — every MCP tool + lib script + framework adapter