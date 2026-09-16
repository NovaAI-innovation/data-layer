# data-layer/docs

Documentation for the data-layer umbrella.

## Submodule relationships + wiring

- `architecture.md` — submodule relationship and ownership map
- `bootstrap-flow.md` — what happens when `bootstrap` runs end-to-end
- `services/README.md` — per-service overview + `lib/install.sh` contract
- `SUBMODULE_OWNERSHIP.md` — boundary rules + ownership matrix + wiring-route map + audit triggers

## Phase 0 docs (completed 2026-09-16)

- `audits/fastembed-license-compat.md` — license compatibility audit of the qdrant embedding pipeline (Apache-2.0 / MIT — all PASS)
- `completion-audit-2026-09-15.md` — raw 84% completion audit with per-submodule matrix

## Top-level artifacts (umbrella root)

- `../HANDOFF.md` — session-by-session status log + handoff to next agent
- `../TOOLS_AND_WIRING.md` — umbrella orchestration doc
- `../NOTICE` — third-party attributions
- `../LICENSE` — BSD-3-Clause
- `../CONTRIBUTING.md` — ICLA + CCLA templates + DCO sign-off alternative + review/security policy
- `../AGENTS.md` — agent contract for the umbrella
- `../README.md` — quick start + layout + services table + status

## Per-submodule docs (in each submodule repo)

- `data-layer-postgres/SCHEMAS.md` — 13 tables across 7 migrations, 5-dimension per column
- `data-layer-redis/SCHEMAS.md` — 6 dual-write + 7 pure-ephemeral key families + RESP command inventory
- `data-layer-falkordb/SCHEMAS.md` — 5 nodes + 5 edges + 2 cypher migrations + derivation contract
- `data-layer-qdrant/SCHEMAS.md` — 2 collections (mpg_source_authority_documents with 15 fields, mpg_emails with 13 fields) + SOT filters + cross-layer joins
- `data-layer-adapters/TOOLS_AND_WIRING.md` — all 21 MCP tools + lib scripts + framework adapters + dual-write path + MCP registration history
