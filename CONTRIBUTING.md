# Contributing to data-layer

Thank you for your interest in contributing. This document covers the
contribution workflow, license terms, and the agreement we ask all
contributors to sign.

## 1. Code of Conduct (summary)

Be respectful. Focus on the technical merits. Disagree on ideas, not
people. We expect contributors to follow the spirit of the
[Contributor Covenant](https://www.contributor-covenant.org/) (full
text not embedded here; the canonical reference applies).

## 2. How to submit

1. **Fork** the relevant submodule repository (not the umbrella).
2. **Branch** from `main` with a descriptive name (`fix/...`,
   `feat/...`, `docs/...`).
3. **Commit** with a Conventional Commit prefix (`feat:`, `fix:`,
   `docs:`, `chore:`, `refactor:`, `test:`).
4. **Open a pull request** against `main` of the submodule repo.
5. **Sign** either the Individual CLA (ICLA), the Corporate CLA
   (CCLA), or the Developer Certificate of Origin (DCO — see §5).
6. Wait for review. Maintainers will respond within 5 business days.

## 3. Individual CLA (ICLA) — template

> The individual CLA below is the canonical ICLA. By signing it (via
> the PR comment `I have read and agree to the Individual CLA`) you
> affirm the agreement. The text is intentionally short.

```
INDIVIDUAL CONTRIBUTOR LICENSE AGREEMENT (ICLA)

By submitting a contribution to this project, I agree to the following:

1. **License grant.** I grant the project a non-exclusive, perpetual,
   worldwide, royalty-free, irrevocable license to use, reproduce,
   modify, prepare derivative works of, publicly display, publicly
   perform, sublicense, and distribute my contribution under the
   project license (BSD-3-Clause for umbrella + adapters; PostgreSQL
   License for postgres; BSD-3-Clause for redis; SSPL v1 for
   falkordb; Apache-2.0 for qdrant) and any subsequent license the
   project may adopt.

2. **Originality.** I represent that each contribution is my original
   creation (or that I have sufficient rights to submit it under the
   above terms) and that I have the authority to make the grant in
   clause 1.

3. **Notice obligation.** I will promptly notify the project if I
   become aware that any contribution I submitted infringes a third
   party's rights or was not my original creation.

4. **No warranty.** The contribution is provided "AS IS" without
   warranty of any kind. I have no obligation to provide support,
   maintenance, or updates.

Name: ________________________________
GitHub handle: _______________________
Date: ________________________________
```

## 4. Corporate CLA (CCLA) — template

> Required when the contribution is made on behalf of an employer.
> The employer's authorized representative signs.

```
CORPORATE CONTRIBUTOR LICENSE AGREEMENT (CCLA)

[Company legal name] ("Company") agrees that contributions submitted
by its employees or contractors to this project are subject to the
following:

1. **License grant.** Company grants the project the same license as
   in §3.1 above, on behalf of itself and its authorized contributors.

2. **Authority.** Company represents that it has the authority to
   grant this license and that each authorized contributor has
   assigned to Company sufficient rights in the contribution to make
   the grant.

3. **List of authorized contributors.** Maintained by Company and
   provided on request.

4. **No warranty.** As in §3.4.

Signed: ________________________________
Name: ________________________________
Title: ________________________________
Company: ________________________________
Date: ________________________________
```

## 5. DCO alternative (sign-off your commits)

If you prefer not to sign the ICLA/CCLA, you may instead sign off
every commit using the
[Developer Certificate of Origin](https://developercertificate.org/):

```
Signed-off-by: Your Name <[email protected]>
```

Add the `Signed-off-by:` line via `git commit -s` so the project can
verify your agreement to the DCO terms. The DCO is the lightweight
alternative to the CLA used by many open-source projects.

## 6. License posture (per submodule)

| Repo | License |
|---|---|
| data-layer (umbrella) | BSD-3-Clause |
| data-layer-adapters  | BSD-3-Clause |
| data-layer-postgres  | PostgreSQL License |
| data-layer-redis     | BSD-3-Clause |
| data-layer-falkordb  | SSPL v1 (non-OSI; service-side use may require commercial license) |
| data-layer-qdrant    | Apache License 2.0 |

A NOTICE file at the umbrella root lists the licenses of every direct
dependency (PostgreSQL, Valkey, FalkorDB, Qdrant, fastembed,
sentence-transformers, psycopg, redis-py, asyncpg, qdrant-client,
LiteLLM, MCP SDK, etc.).

## 7. Review expectations

- PR description should reference the relevant issue / HANDOFF section
  / ADR.
- PRs touching schema (migrations/, lib/, mcp/tools/) require a
  maintainer's review.
- PRs touching the umbrella require explicit maintainer sign-off AND
  a submodule pointer refresh (re-pin each submodule if its HEAD
  advanced).

## 8. Security disclosure

If you find a security issue, do NOT open a public GitHub issue.
Contact the maintainer directly via the email listed in the repository
description. Critical CVEs (especially in the P0.x probe space — see
HANDOFF §3.2 / §4) are coordinated privately before public disclosure.

## 9. Endorsement

By signing the ICLA, CCLA, or the DCO sign-off on a commit, you agree
to the contribution terms above. The maintainers welcome your work.

---

Document version: 2026-09-16 (initial generation, concurrent with
Phase 0 docs + LICENSE + Valkey swap + MCP dedupe — umbrella commit
0d2d0aa).