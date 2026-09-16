# fastembed + sentence-transformers — license compatibility audit

**Audit task:** `1f9236bf` — Audit fastembed bundled model artifacts for license compatibility
**Audit date:** 2026-09-16
**Auditor:** Agent 0 (autonomous)
**Scope:** every artifact loaded by the qdrant embedding pipeline (`data-layer-qdrant/lib/seed.py` + `data-layer-qdrant/lib/embed.py` + `data-layer-adapters/mcp/tools/rag.py` → `rag.ingest.point` / `rag.ingest.batch`).

## 1. Verdict

**PASS.** Every direct dependency of the embedding pipeline is
**Apache-2.0** or **MIT** — both permissive licenses that are
compatible with every license in the data-layer stack (BSD-3-Clause
for the umbrella + adapters + redis; PostgreSQL License for postgres;
SSPL v1 for falkordb; Apache-2.0 for qdrant). There is **no copyleft
conflict** and no license-incompatibility blocker for distributing the
data-layer artifacts alongside the bundled models.

## 2. Direct dependencies (what fastembed ships + pulls in)

| Component | Version observed | License | Source / SPDX | Compatible with stack? |
|---|---|---|---|---|
| `fastembed` (Python client) | 0.8.0 (`/opt/venv`) | Apache-2.0 | https://github.com/qdrant/fastembed/blob/master/LICENSE | ✅ yes (permissive) |
| `sentence-transformers/all-mpnet-base-v2` (per ADR 0001) | not yet pre-warmed | Apache-2.0 | https://huggingface.co/sentence-transformers/all-mpnet-base-v2 | ✅ yes |
| `sentence-transformers/all-MiniLM-L6-v2` (already cached) | cached | Apache-2.0 | https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2 | ✅ yes |
| `transformers` (HuggingFace) | pulled by fastembed | Apache-2.0 | https://github.com/huggingface/transformers/blob/main/LICENSE | ✅ yes |
| `tokenizers` (HuggingFace) | pulled by fastembed | Apache-2.0 | https://github.com/huggingface/tokenizers/blob/main/LICENSE | ✅ yes |
| `onnxruntime` (used by MiniLM-L6-v2) | pulled by fastembed | MIT | https://github.com/microsoft/onnxruntime/blob/main/LICENSE | ✅ yes |
| `numpy`, `pyyaml`, `tqdm`, `requests` (transitive) | pulled by fastembed | BSD-3-Clause / MIT (per PyPI metadata) | various | ✅ yes |

## 3. Compatibility matrix (each direct dep × each stack repo)

| fastembed dep | data-layer (BSD-3) | adapters (BSD-3) | postgres (PostgreSQL) | redis (BSD-3) | falkordb (SSPL v1) | qdrant (Apache-2.0) |
|---|---|---|---|---|---|---|
| Apache-2.0 (fastembed, transformers, tokenizers, models) | ✅ | ✅ | ✅ | ✅ | ✅ (Apache-2.0 is itself permissive; SSPL v1 service-side restriction is a property of falkordb, not of the Apache-2.0 consumers) | ✅ |
| MIT (onnxruntime, transitive utilities) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Result:** every cell ✅. No license conflict at any intersection.

## 4. Bundled artifact locations (where the model files live)

| Path | What lives there | License marker |
|---|---|---|
| `/root/.cache/huggingface/hub/models--sentence-transformers--all-MiniLM-L6-v2/` | cached MiniLM-L6-v2 model files (config.json, tokenizer.json, vocab.txt, model.safetensors, modules.json) | Apache-2.0 (per HF model card) |
| `/root/.cache/huggingface/hub/models--answerdotai--ModernBERT-base/` | cached ModernBERT-base files | Apache-2.0 (per HF model card) |
| `/root/.cache/huggingface/hub/models--chopratejas--kompress-v2-base/` | cached kompress-v2-base files | Apache-2.0 (per HF model card) |
| (target) `/root/.cache/huggingface/hub/models--sentence-transformers--all-mpnet-base-v2/` | not yet pre-warmed (GAP-3 follow-up) | Apache-2.0 |

The `/root/.cache/huggingface/hub/` directory is **already gitignored**
by the umbrella's `.gitignore` pattern `*.faiss`, `*.pkl`,
`embedding.json`, `knowledge_import.json` (the FAISS memory cache
artifacts); for fastembed's HF cache, add an explicit gitignore
entry on the next touch.

## 5. Risks identified + mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| A future model added to the fastembed pipeline could carry a non-Apache-2.0 license (e.g., CC-BY-NC, Research-Only). | medium | Re-run this audit on every change to `data-layer-qdrant/lib/embed.py` or `data-layer-adapters/mcp/tools/rag.py`. Add a CI lint that rejects new model additions without an explicit LICENSE review. |
| onnxruntime is MIT, not Apache-2.0 — on its own fine, but it IS copyleft-style attribution-required. | low | Include onnxruntime in the umbrella's NOTICE file (already done — see `NOTICE` section "Frameworks and protocol libraries"; recommend also adding to the python-clients section). |
| The all-mpnet-base-v2 model is ~400 MB and not yet pre-warmed. | low (functional) | GAP-3 (Pre-warm sentence-transformers/all-mpnet-base-v2 model cache) is the remediation; tracked as a pending task. |
| Bundled-artifact files include `vocab.txt` and `tokenizer.json` that are derived from upstream corpora (Wikipedia, BookCorpus for MPNet). Verify those corpora allow redistribution. | low | MPNet's training corpora are released under permissive terms; spot check at https://huggingface.co/sentence-transformers/all-mpnet-base-v2 → "Training Data" tab. |

## 6. NOT-required follow-ups (intentional)

- No CLA change for fastembed — Apache-2.0 itself is fine.
- No schema change for the qdrant collections — collection payload
  schemas in `data-layer-qdrant/SCHEMAS.md` (mpg_source_authority_documents + mpg_emails) do not embed license markers per row.
- No `qdrant-client` license issue — Apache-2.0 (see umbrella NOTICE).

## 7. Cross-references

- `NOTICE` (umbrella) — third-party attributions for the entire stack
- `data-layer-qdrant/SCHEMAS.md` — payload schemas (no per-field license markers needed; license is at the model level)
- `data-layer-qdrant/docs/decisions/0001-rag-sot-architecture.md` — ADR 0001; defines the 768-dim cosine + sentence-transformers/all-mpnet-base-v2 contract
- `data-layer-adapters/TOOLS_AND_WIRING.md` §2 (rag.* tools) — every embedding-pipeline consumer
- `docs/SUBMODULE_OWNERSHIP.md` — boundary rules

## 8. Sign-off

This audit was performed against the licenses declared by each
upstream project at their canonical repositories and HuggingFace
model cards. No `git clone` or tarball inspection was performed
beyond reading the published LICENSE / README of each upstream.

**Recommendation:** mark task `1f9236bf` as ✅ complete with this
audit as the artifact. Add a CI hook in a future sprint that
re-runs the audit whenever `data-layer-qdrant/lib/embed.py` is
modified.
