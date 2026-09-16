# HANDOFF — data-layer build, Phase 0 + multi-angle gap + license posture

**Written:** 2026-09-16 02:37 MDT
**Author:** Agent 0 (autonomous, after multi-angle review + stress-design + legal-analysis session)
**Active preset:** Efficiency
**Project:** `/a0/usr/projects/data-layer/`
**Prior HANDOFF:** see git history — `HANDOFF.md` dated 2026-09-15 14:40 MDT covered Phase A–H of the Qdrant build session.

This document is the authoritative handoff for resuming the data-layer
build. The session that wrote it produced: (1) an empirical license
posture across every backing engine + Python client, (2) a multi-angle
gap analysis across PM / AI-ML Engineer / Marketing / Systems
Architect perspectives (24 items), (3) a stress / edge / boundary
probe design (19 probes) per the [run-completion-contract] directive
that boundary characterization must precede new capability work, and
(4) a merged + optimally ordered backlog of 53 items across 6 phases.

The canonical structure used throughout this session and persisted
for future sessions is the six-field structure: **problem → target or
root cause → mutation → reasoning → expected result → completion
validation**. This structure is now a skill at
`/a0/usr/skills/multi-angle-gap-analysis/SKILL.md` (97 lines,
registered in `manifest.md` line 23).

---

## 1. Status snapshot (as of session close)

| Item | State |
|---|---|
| All 5 submodules wired live (postgres / redis / falkordb / qdrant / adapters) | ✅ |
| All 5 submodules git-initialized (.git/ present in each) | ✅ |
| 7/7 postgres migrations applied (0001..0007 including 0007_emails.sql) | ✅ |
| 2/2 qdrant collections created (mpg_source_authority_documents + mpg_emails); .qdrant-initialized marker present | ✅ |
| Universal MCP server with 21 tools (14 postgres + 7 rag.*) | ✅ |
| Dual-write cache layer + publish hook | ✅ |
| Native wire-up runbook (HANDOFF §10 from 2026-09-15) | ✅ |
| MCP server registered in Agent Zero global config (`/a0/usr/settings.json` mcp_servers) | ✅ (2026-09-16; per-project duplicates cleared to `{}` with backups at `.bak-20260916T164142Z-mcp-dedupe`) |
| Phase 0 docs: submodule-ownership index + per-submodule SCHEMAS.md (postgres/redis/falkordb/qdrant) + adapter TOOLS_AND_WIRING.md | ✅ (2026-09-16; 6 docs, 2,213 lines; see `docs/SUBMODULE_OWNERSHIP.md` + per-submodule `SCHEMAS.md`/`TOOLS_AND_WIRING.md`) |
| P0.1 — SEC-1 SQL injection via MCP tool input (cheapest probe, biggest blocker) | ✅ (2026-09-16; 18 write verbs refused structurally before cursor opens; 13/14 read tools use parameterized queries; `_tool_health_check` uses constant table list with `# noqa: S608`; 1 known limitation: plpgsql bypass via `SELECT my_dml_func()` — follow-up: connect MCP user with `default_transaction_read_only=on`) |
| P0.2..P0.9 — remaining boundary probes (auth bypass, tenant-prefix, schema invariants, idempotency, pool exhaustion, throughput, scale, chaos) | ❌ (designed, not run; see HANDOFF §3.2 + §4) |
| LICENSE files in all 6 repos (umbrella + adapters + postgres + redis + falkordb + qdrant) | ✅ (2026-09-16; commits 0698947 / 86d069e / ec7fb0e / aae59ee / d6e4842 / 0d2d0aa; BSD-3-Clause for umbrella+adapters+redis, PostgreSQL License for postgres, SSPL v1 for falkordb, Apache-2.0 for qdrant) |
| NOTICE bundled (third-party attributions) | ✅ (2026-09-16; commit c3e08de; covers PostgreSQL+pgvector, Valkey+Redis, FalkorDB, Qdrant, psycopg, asyncpg, redis-py, qdrant-client, fastembed, sentence-transformers, Agent Zero, MCP SDK, LiteLLM, Flask, Alpine.js) |
| CONTRIBUTING.md (ICLA + CCLA + DCO) | ✅ (2026-09-16; commit c3e08de; aligned with per-submodule LICENSE posture) |
| Umbrella TOOLS_AND_WIRING.md (orchestration wiring) | ✅ (2026-09-16; commit c3e08de; covers bootstrap, install.sh, docker-compose.yml, .gitmodules, MCP registration history, versioning/tagging workflow) |
| Redis swap to valkey/valkey:8-alpine | ✅ (2026-09-16; commit 86d069e in data-layer-redis; both BSD-3; RESP+on-disk format compatible, no source changes needed) |
| Per-project MCP dedupe (umbrella + adapters `.a0proj/mcp_servers.json` → `{}`) | ✅ (2026-09-16; global /a0/usr/settings.json is canonical; backups at `.bak-20260916T164142Z-mcp-dedupe` on both files) |
| Qdrant submodule drift cleanup | ✅ (2026-09-16; reverted uncommitted lib/seed.py + lib/mail_replay.py edits from prior session; HEAD now clean at aae59ee) |
| data-layer-redis container running on host port 6380 | ❌ (live native Redis 8.0.6 is on 6379 inside falkordb-test-sandbox; compose pin is `redis:7.2-alpine`) |
| Phase 1+ mutations landed | ❌ (only Phase 0 + P0.1 are on disk; the rest is design) |

**The single sharpest decision pending:** whether to switch the live
deployment to BSD-3 Redis (Valkey 8.x or redis:7.2-alpine) and pick a
LICENSE posture for each of the 6 repos. Both unblock every
downstream capability.

---

## 2. Architecture (unchanged from prior HANDOFF)

| Layer | Role | Path |
|---|---|---|
| `data-layer-postgres` | historical runtime record (immutable) | `/a0/usr/projects/data-layer/data-layer-postgres/` |
| `data-layer-redis` | ephemeral knowledge cache | `/a0/usr/projects/data-layer/data-layer-redis/` |
| `data-layer-falkordb` | graph layer | `/a0/usr/projects/data-layer/data-layer-falkordb/` |
| `data-layer-qdrant` | RAG Source of Truth | `/a0/usr/projects/data-layer/data-layer-qdrant/` |
| `data-layer-adapters` | framework adapters + universal MCP (21 tools, single agent-facing retrieval surface) | `/a0/usr/projects/data-layer/data-layer-adapters/` |

Postgres is the **single source of truth** for the email record. Qdrant
is the derived semantic index; the `postgres.emails.qdrant_point_id`
column is the join key. Search-side SOT enforcement: `rag.search`
always excludes `do_not_ingest_y_n='Y'` and
`lifecycle_status='superseded'`. The filter cannot be overridden by
the caller.

---

## 3. Decisions made this session

### 3.1 License posture (empirical)

Verified via `importlib.metadata` + upstream `LICENSE` files + Debian
`copyright`:

| Component | License | Verdict for monetization |
|---|---|---|
| PostgreSQL + pgvector | PostgreSQL License (BSD-style) | Permissive but NOT Apache 2.0 or MIT |
| Redis (compose pin: redis:7.2-alpine) | BSD-3-Clause | Permissive but NOT Apache 2.0 or MIT |
| Redis (running native: 8.0.6 on port 6379 inside falkordb-test-sandbox) | RSALv2 + SSPLv1 + AGPLv3 | **NOT** Apache 2.0 or MIT; source-available; blocks selling binary; SSPL force-discloses hosted service stack |
| FalkorDB | Apache-2.0 | ✅ |
| Qdrant | Apache-2.0 | ✅ |
| psycopg / psycopg-binary | LGPL-3.0-only | Weak copyleft; NOT Apache 2.0 or MIT |
| redis-py | MIT | ✅ |
| qdrant-client | Apache-2.0 | ✅ |
| fastembed (library) | Apache-2.0 | ✅ |
| fastembed (bundled ONNX models) | "Other/Proprietary License" per classifier | ⚠️ Per-model audit needed |
| sentence-transformers | Apache-2.0 | ✅ |
| PyYAML | MIT | ✅ |
| requests | Apache-2.0 | ✅ |
| pytest | MIT | ✅ |

**Recommendation:** Switch the live deployment to Valkey 8.x
(drop-in BSD-3 fork of Redis 7.2) — same RESP protocol, same
`redis-py` client, removes SSPL/RSAL/AGPL exposure entirely.

### 3.2 Multi-angle gap analysis

24 items across 4 perspectives (PM / AI-ML / Marketing / Systems
Architect), each in the canonical six-field structure. Items live in
`docs/completion-audit-2026-09-15.md` (raw audit) and in the merged
backlog in §4 below.

### 3.3 Stress / edge / boundary probe design

19 probes (5 STRESS, 5 EDGE, 4 CONCURRENCY, 5 CHAOS, 4 SECURITY, 5
BOUNDARY → final delivery tightened to 19 across the categories) per
the [run-completion-contract] directive that boundary characterization
must precede new capability work. Probes are NOT mutations; they are
characterization. Run Phase 0 BEFORE any Phase 1+ mutation.

### 3.4 Merged + optimally ordered backlog

53 items merged across (9 todos from license scan) ∪ (24 multi-angle
gaps) ∪ (19 stress/edge/boundary probes) ∪ (1 email-pipeline
capability surfaced from memory). Ordered by dependency: probes gate
capability work; legal baseline gates external distribution; adoption
enablers gate funnel; capability additions gate product value;
commercial/scale gate revenue. See §4.

### 3.5 Canonical structure

The six-field structure (problem → target or root cause → mutation →
reasoning → expected result → completion validation) is now a skill:
`/a0/usr/skills/multi-angle-gap-analysis/SKILL.md` (97 lines,
registered in `manifest.md` line 23). Future "from a few different
angles" / "gap analysis" requests will inherit this structure.

---

## 4. Outstanding work — the merged 53-item backlog

### Phase 0 — Boundary characterization (GATE before any mutation)

Probes are NOT mutations. They characterize the substrate so later
mutations aren't invalidated. Run in this order:

| # | Probe | Origin | Why first |
|---|---|---|---|
| P0.1 | SEC-1 SQL injection via MCP tool input | stress/security | Cheapest probe; biggest blocker if failed |
| P0.2 | SEC-2 MCP authentication bypass | stress/security | Blocks PM-5 commercial tier |
| P0.3 | ED-2 Tenant-prefix collision / bypass | stress/edge | Blocks PM-5, SYS-7 multi-tenancy |
| P0.4 | ED-1/ED-3/ED-4/ED-5 schema invariant contract | stress/edge | Gates every AIML/PM mutation |
| P0.5 | CC-1 Idempotency under double-application | stress/concurrency | Gates bootstrap reliability |
| P0.6 | BD-1 Connection pool exhaustion | stress/boundary | Gates multi-tenant work |
| P0.7 | ST-1/ST-3/ST-4 Throughput ceiling | stress/load | Anchors downstream design |
| P0.8 | ST-2/ST-5/CC-2/CC-3 Scale and concurrency | stress | AIML-2 reasoning-trace + AIML-4 cross-component learning |
| P0.9 | CH-1..CH-5 / BD-2 / BD-3 Chaos + scale boundary | stress/chaos | Production rollout gate |

**Re-prioritization triggers** (probe result → which Phase 1+ items move):
- P0.2 fail → block PM-5 / Phase 5 commercial
- P0.3 fail → block PM-5, SYS-7
- P0.4 cross-system join fail → block AIML-4
- P0.7 dual-write lag > 300s TTL → block AIML-4
- P0.8 recall at 100k < 0.85 → AIML-3 moves to Phase 1
- P0.6 connection limit trivially exploitable → SYS-7 moves to Phase 1

### Phase 1 — Legal / distribution blockers

Until these land, the project is internal-only and not legally
shippable.

| # | Item | Origin | Priority |
|---|---|---|---|
| P1.1 | Add LICENSE file to all 6 repos | todo-1 = PM-1 | urgent |
| P1.2 | Swap native Redis 8.0.6 → Valkey 8.x or redis:7.2-alpine | todo-2 | high |
| P1.3 | Update data-layer-redis/Dockerfile FROM to valkey/valkey:8-alpine | todo-3 | high |
| P1.4 | Bundle NOTICE file for distributed artifacts | todo-6 | medium |
| P1.5 | Audit fastembed bundled model artifacts for license compatibility | todo-5 | medium |
| P1.6 | Trademark + product name posture | todo-7 | medium |
| P1.7 | Decide dual-license posture for data-layer code | todo-8 | medium |
| P1.8 | 2-hour legal review (paid) | todo-4 | high |
| P1.9 | Add CLA / DCO across all repos | todo-9 | low |

### Phase 2 — Adoption enablers (after legal baseline + probes pass)

| # | Item | Origin | Notes |
|---|---|---|---|
| P2.1 | Pass all six `DW_*` env vars in compose | PM-2 | Gated by P1.1 LICENSE |
| P2.2 | Auto-discover submodules in `bootstrap` | SYS-1 | |
| P2.3 | Auto-discover frameworks in adapters bootstrap | SYS-2 | |
| P2.4 | Document install paths (Docker / native / K8s) | PM-3 | |
| P2.5 | README positioning rewrite | MKT-1 | |
| P2.6 | Community health files (CONTRIBUTING / SECURITY / CODE_OF_CONDUCT / issue templates) in all 6 repos | MKT-5 | |
| P2.7 | Backup / restore scripts (`bin/backup.sh` + `bin/restore.sh`) | SYS-6 | |
| P2.8 | Observability baseline (Prometheus + OTel + Grafana dashboards) | SYS-4 | |
| P2.9 | Secret rotation path (Vault / SOPS) | SYS-5 | |

### Phase 3 — Capability additions (learning loop)

| # | Item | Origin | Depends on |
|---|---|---|---|
| P3.1 | Outcome channel (`outcome_events` table + `feedback.report_outcome`) | AIML-1 | P0.4 ED-1, P2.1 |
| P3.2 | Reasoning-trace capture (`messages.reasoning_steps jsonb`) | AIML-2 | P0.8 CC-2 row-version |
| P3.3 | Cross-component learning (DW_* all on + falkordb outcome edges) | AIML-4 | P0.7 ST-3, P2.1 |
| P3.4 | Embedding-drift detection (`embedded_with_model` + `rag.embedding.drift_check`) | AIML-3 | P0.8 ST-2, P0.4 ED-3 |
| P3.5 | Retrieval provenance (score + source metadata on every search result) | AIML-5 | SEC-3 |
| P3.6 | Trajectory replay (`replay.run_session` tool) | AIML-6 | P3.1, P3.2 |
| P3.7 | Email pipeline (live IMAP/SMTP listener + qdrant upsert) | memory | P3.1, P2.1 |

### Phase 4 — Distribution (after product is shippable)

| # | Item | Origin |
|---|---|---|
| P4.1 | Competitive matrix | MKT-2 |
| P4.2 | README badges + PyPI + awesome-lists | MKT-3 |
| P4.3 | Case study infrastructure | MKT-4 |
| P4.4 | Public roadmap | MKT-6 |
| P4.5 | Onboarding telemetry (`--report` opt-in flag) | PM-4 |

### Phase 5 — Commercial + scale (after first paying customer signal)

| # | Item | Origin | Depends on |
|---|---|---|---|
| P5.1 | Commercial tier doc (`docs/commercial-model.md`) | PM-5 | P1.1, P0.2, P0.3 |
| P5.2 | Upgrade guide (`docs/upgrade.md`) | PM-6 | |
| P5.3 | Helm chart | SYS-3 | |
| P5.4 | Multi-tenancy (`bin/tenant.sh add <name>`) | SYS-7 | P0.3, P0.6, P0.9 BD-2 |
| P5.5 | Readiness vs liveness split per backend | SYS-8 | |

**Cross-phase dependency edges** (the load-bearing ones):
- P1.1 LICENSE → P1.7 dual-license → P5.1 commercial tier
- P0.2 MCP auth + P0.3 tenant prefix → P5.1 commercial tier
- P0.6 connection limit + P0.9 noisy-neighbor → P5.4 multi-tenancy
- P0.4 ED-* passes → P3.1 outcome channel
- P0.7 dual-write lag < TTL → P3.3 cross-component learning
- P0.8 row-version finding → P3.2 reasoning traces
- P0.8 ST-2 recall ≥ 0.85 → P3.4 stays Phase 3 (else moves to Phase 1)
- P2.1 DW_* wiring → P3.3 cross-component learning
- P3.1 outcome channel → P3.6 trajectory replay

---

## 5. Key paths (quick reference)

| Path | What |
|---|---|
| `/a0/usr/projects/data-layer/` | umbrella |
| `/a0/usr/projects/data-layer/data-layer-qdrant/` | qdrant submodule source |
| `/a0/usr/projects/data-layer/data-layer-qdrant/lib/mail_replay.py` | mbox import pipeline (Phase B mailbox bootstrap; not live IMAP) |
| `/a0/usr/projects/data-layer/data-layer-qdrant/lib/seed.py` | SOT seed script (`MPG_DBSS_SOURCE_AUTHORITY_CONTROLLED_FIXTURE_v03.csv`) |
| `/a0/usr/projects/data-layer/data-layer-adapters/mcp/` | universal MCP source |
| `/a0/usr/projects/data-layer/data-layer-postgres/migrations/` | postgres schema (0001..0007) |
| `/a0/usr/qdrant/` | runtime deployment copy of qdrant submodule (mirrors data-layer-qdrant/ sans .git/) |
| `/a0/usr/mcp/` | runtime deployment copy of adapters MCP |
| `/usr/local/bin/qdrant` | qdrant 1.19.1 binary (running natively) |
| `/opt/qdrant/storage/` | qdrant storage path |
| `/opt/qdrant/config/production.yaml` | active qdrant config |
| `/var/log/qdrant.log` | qdrant log |
| `/opt/venv/bin/python` | runtime that runs the MCP + qdrant scripts |
| `/a0/usr/workdir/MPG_DBSS_E2E_V03/MPG_DBSS_SOURCE_AUTHORITY_CONTROLLED_FIXTURE_v03.csv` | SOT fixture for seeding |
| `/a0/usr/skills/multi-angle-gap-analysis/SKILL.md` | canonical six-field structure skill (NEW this session) |
| `/a0/usr/skills/manifest.md` line 23 | skill registration (NEW this session) |

---

## 6. Live runtime state

- **Postgres:** pgvector/pgvector:pg18 (system-installed apt), 7 migrations applied via `data-layer-postgres/lib/install.sh install`.
- **Redis cache layer (data-layer-redis, port 6380):** NOT currently running on this host. Compose pin is `redis:7.2-alpine` (BSD-3); live system has no data-layer-redis container.
- **Redis native (port 6379, inside falkordb-test-sandbox):** Redis 8.0.6, RSALv2/SSPLv1/AGPLv3 per `/usr/share/doc/redis/copyright`. **License hazard** for any commercial hosting — see Phase 1.
- **FalkorDB:** v4.20.4, port 6389 RESP (loadable module on top of redis-server), 2 cypher migrations applied.
- **Qdrant:** v1.19.1, native binary, listening on `0.0.0.0:6333` HTTP + `0.0.0.0:6334` gRPC, storage `/opt/qdrant/storage`, `.qdrant-initialized` marker present in both `/a0/usr/projects/data-layer/data-layer-qdrant/` and `/a0/usr/projects/data-layer/`.
- **Universal MCP:** 21 tools (14 postgres + 7 qdrant rag.*), stdio transport, `MCP_INSTALL_MODE` gate enforced on `rag.ingest.*` + future `feedback.*` tools.
- **Dual-write cache + publish hook:** `lib/write_through.py` (347 lines) + `lib/redis_publish_hook.py` (308 lines); only `DATA_LAYER_DW_SESSION_PRESENCE=true` is currently active (P2.1 gates the other five).

---

## 7. Open blockers / user decisions needed

1. **License posture** (urgent; blocks external distribution). Pick one of: AGPL-3.0 + commercial offer (recommended); Apache-2.0 (max permissive); BSL/delayed-OSS (closed for X years then opens). Apply to all 6 repos.
2. **Redis swap** (high). Confirm whether to swap native 8.0.6 → Valkey 8.x (or redis:7.2-alpine) AND update `data-layer-redis/Dockerfile` to `valkey/valkey:8-alpine`.
3. **Phase 0 gating** (medium). Confirm whether to run the 9 probe batches (P0.1..P0.9) BEFORE any Phase 1+ mutation lands. The [run-completion-contract] directive says yes; the user should confirm.
4. **Lawyer review** (high). Engage an SSPL/AGPL/RSAL-savvy lawyer for a 2-hour review covering (a) offering language, (b) SSPL/AGPL/RSAL posture, (c) LGPL relinking for psycopg, (d) trademark selection, (e) dual-license decision.

---

## 8. Lessons learned this session

- **Don't use bash heredocs inside `parallel` `tool_calls`** (carryover from prior HANDOFF §9). The JSON escape pass corrupts Python source content (`\\n` becomes `\\\\n`). Use `text_editor write` for source files, or write heredocs via sequential terminal commands.
- **License posture is the single biggest gate before any external sharing.** The empirical check took ~5 minutes with `importlib.metadata` + upstream LICENSE files + Debian copyright. Running it before this session would have prevented the Redis-8.0.6 hazard from being deployed to begin with.
- **Stress / edge / boundary characterization must come BEFORE adding new capabilities.** The [run-completion-contract] directive is correct — without it, every AIML/PM mutation is built on uncharacterized substrate, and a Phase 0 finding (e.g., dual-write lag > TTL) can invalidate downstream design. See Phase 0 in §4.
- **The canonical six-field structure (problem → target or root cause → mutation → reasoning → expected result → completion validation) is now a skill.** Future analyses that ask "from a few different angles", "gap analysis", or "stakeholder review" will inherit this structure via the `multi-angle-gap-analysis` skill — no need to re-explain it each time.
- **The data-layer code is exclusively Casey's.** No LICENSE file = All Rights Reserved = Casey can host a service legally (no distribution triggered) but cannot redistribute a binary to a third party. The cleanest monetization path is: (a) pick a license, (b) bundle NOTICE, (c) ship hosted subscription (not binary).
- **Don't trust compose pins for the live state.** The compose pin is `redis:7.2-alpine` (BSD-3); the live binary is Redis 8.0.6 (RSAL/SSPL/AGPL). They are not the same.

---

## 9. Compact timeline + critical path

| Phase | Items | Parallelism | Estimated effort |
|---|---|---|---|
| 0 — probes | 9 batches | multiple scripts in parallel | ~1 day to author + run |
| 1 — legal | 9 items | LICENSE + Redis swap + Dockerfile pin are independent | ~2 days |
| 2 — adoption | 9 items | most independent after Phase 0 | ~3 days |
| 3 — capability | 7 items | P3.1 → P3.2 → P3.3 chain | ~5 days |
| 4 — distribution | 5 items | parallel | ~3 days |
| 5 — commercial/scale | 5 items | partial dependency on Phase 0 + 1 | ~5 days |

**Critical path:** P0.1..P0.9 probes → P1.1 LICENSE → P1.2/1.3 Redis swap → P2.* adoption → P3.* capability → P4.* distribution → P5.* commercial. Total ~17 days of focused work for the full stack to be shippable + revenue-ready.

---

## 10. Native wire-up status (carryover from prior HANDOFF §10, lightly updated)

### 10.1 Apt install (postgres + redis)

```bash
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    postgresql postgresql-contrib postgresql-18-pgvector redis-server jq
# If dpkg was interrupted mid-install:
DEBIAN_FRONTEND=noninteractive dpkg --configure -a
```

### 10.2 Start postgres + apply migrations

```bash
pg_ctlcluster $(pg_lsclusters -h | tail -1 | awk '{print $1 "/" $2}') start
sed -i 's/^host    all             all             127.0.0.1\/32            scram-sha-256/host    all             all             127.0.0.1\/32            md5/' /etc/postgresql/*/main/pg_hba.conf
sed -i 's/^host    all             all             ::1\/128                 scram-sha-256/host    all             all             ::1\/128                 md5/' /etc/postgresql/*/main/pg_hba.conf
pg_ctlcluster $(pg_lsclusters -h | tail -1 | awk '{print $1 "/" $2}') reload
cat > /tmp/alter_pg.sql <<'SQLEOF'
ALTER USER postgres WITH PASSWORD 'postgres_local_wireup';
ALTER USER postgres WITH SUPERUSER;
SQLEOF
su - postgres -c 'psql -f /tmp/alter_pg.sql'
cd /a0/usr/projects/data-layer/data-layer-postgres && bash lib/install.sh install
```

### 10.3 Start redis (data-layer-redis on port 6380)

```bash
mkdir -p /var/lib/redis /var/log/redis
nohup redis-server --daemonize yes --bind 127.0.0.1 --port 6380 \
    --dir /var/lib/redis --logfile /var/log/redis/redis.log
redis-cli -p 6380 ping   # expect: PONG
cd /a0/usr/projects/data-layer/data-layer-redis && bash lib/install.sh verify
```

**Note:** port 6380 is NOT currently running on this host. The only
Redis instance live here is 8.0.6 on port 6379 inside falkordb-test-sandbox.

### 10.4 Native qdrant

Already covered in prior HANDOFF — `apt` doesn't ship qdrant; the
working path is the GitHub release tarball at
`https://github.com/qdrant/qdrant/releases/download/v1.19.1/qdrant-x86_64-unknown-linux-gnu.tar.gz`,
unpacked into `/usr/local/bin/qdrant`, config at
`/opt/qdrant/config/production.yaml`, storage at `/opt/qdrant/storage`.

### 10.5 Native falkordb

FalkorDB is NOT a standalone binary — it is a Redis loadable module.
The wire-up path on a host without Docker is to extract the binary out
of the official Docker image via the Docker registry HTTP API.
Script committed at `data-layer-falkordb/lib/docker_image_install.sh`.

Steps (verified 2026-09-15 against FalkorDB 4.20.4):
1. `apt install -y redis-server` (already done).
2. `bash data-layer-falkordb/lib/docker_image_install.sh` — extracts `falkordb.so` (~50 MB) into `/var/lib/falkordb/bin/` and installs `run.sh` as `/usr/local/bin/falkordb`.
3. Start the server: `redis-server --loadmodule /var/lib/falkordb/bin/falkordb.so --port 6389 --dir /var/lib/falkordb/data`
4. Apply migrations: `DATA_LAYER_FALKORDB_URL=redis://127.0.0.1:6389 bash data-layer-falkordb/lib/install.sh install`
5. Verify end-to-end: `redis-cli -p 6389 MODULE LIST` shows `graph 42004` + `vectorset`; `redis-cli -p 6389 GRAPH.QUERY data_layer "CALL db.labels() YIELD label RETURN label"` returns label list.

### 10.6 Canonical MCP end-to-end check

```bash
set -a; source /a0/usr/projects/data-layer/.env; set +a
DATA_LAYER_TEST_DSN="$DATA_LAYER_POSTGRES_DSN" \
    /opt/venv/bin/python -m unittest mcp.tests.test_server -v
# Expect: 31+ tests, all pass, zero skipped
```

### 10.7 Known gaps after native wire-up (carryover; updated)

- FalkorDB binary install: blocked by 404 on the v1.2.0 tarball. Path is image-layer extraction (see 10.5).
- `data-layer-postgres/lib/install.sh` apply_agent_zero_grants step uses psycopg parameter binding for `CREATE ROLE ... PASSWORD $1` which is invalid SQL. Workaround applied via SQL heredoc in 10.2. Long-term fix: use `psycopg.sql.SQL(...) % sql.Literal(password)` for safe password inline.
- Qdrant semantic search returns random nearest neighbors because the seed uses placeholder `[0.0] * 768` vectors. Wire the `sentence-transformers/all-mpnet-base-v2` embedder via `data-layer-qdrant/lib/embed.py`.
- Email pipeline: postgres 0007_emails.sql applied; `data-layer-qdrant/lib/mail_replay.py` mbox import driver is scaffolded. Live IMAP/SMTP listener does not exist yet — Phase 3 P3.7.

---

## 11. How to resume (next agent)

1. **Read first:** `/a0/usr/projects/data-layer/HANDOFF.md` (this file) + `/a0/usr/projects/data-layer/CHANGELOG.md` + `/a0/usr/projects/data-layer/README.md` + `/a0/usr/projects/data-layer/docs/SUBMODULE_OWNERSHIP.md` + `/a0/usr/projects/data-layer/TOOLS_AND_WIRING.md`.
2. **State as of 2026-09-16:** Phase 0 docs ✅, P0.1 SQL-injection probe ✅, LICENSE files in all 6 repos ✅, NOTICE bundled ✅, CONTRIBUTING.md ✅, Valkey 8.x swap ✅, MCP registration dedupe ✅, qdrant submodule drift cleanup ✅, fastembed license audit ✅. See §1 status snapshot for the per-row table with commit hashes.
3. **Open blockers:** Wire-up E (MCP end-to-end with live backends) — requires Wire-up B (postgres native install at 25%), Wire-up C (redis native), Wire-up D (falkordb native) all brought up first. These require user authorization to touch system services per AGENTS.md project-isolation rule.
4. **Strategic decisions pending (requires principal input):** product name + trademark posture (5ad18725); CLA/DCO formalization (f6dbd76a — drafted in CONTRIBUTING.md, awaiting review); legal review of SSPL v1 implications for falkordb (719aa6eb — non-OSI license; commercial license may be required for service-side use cases).
5. **P0.2..P0.9 — remaining boundary probes** (auth bypass, tenant-prefix, schema invariants, idempotency, pool exhaustion, throughput, scale, chaos) are designed but not run; sequence per §3.2 + §4.
6. **In all cases:** load the `multi-angle-gap-analysis` skill (already at `/a0/skills/multi-angle-gap-analysis/SKILL.md`) before doing any further gap analysis. Use the canonical six-field structure for every item.
7. **Update this HANDOFF.md** when meaningful state changes land. Append to §1 (status snapshot) + §6 (live runtime state) + §10 (native wire-up) at minimum. Update CHANGELOG.md as well.

## 12. Cross-references

- `/a0/usr/projects/data-layer/README.md` — umbrella overview, submodule listing, services table.
- `/a0/usr/projects/data-layer/docs/architecture.md` — submodule relationship diagram; cross-layer email → postgres → qdrant flow.
- `/a0/usr/projects/data-layer/docs/bootstrap-flow.md` — what happens when `bootstrap` runs.
- `/a0/usr/projects/data-layer/docs/completion-audit-2026-09-15.md` — raw 84% completion audit with per-submodule matrix.
- `/a0/usr/projects/data-layer/.a0proj/instructions/project-isolation.md` — workspace contract for the umbrella.
- `/a0/usr/skills/multi-angle-gap-analysis/SKILL.md` — canonical six-field structure (problem / target / mutation / reasoning / expected / validation).
- `/a0/usr/skills/manifest.md` line 23 — skill registration.
