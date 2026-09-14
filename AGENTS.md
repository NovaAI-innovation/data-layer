# AGENTS.md — data-layer

Agent contract for the data-layer umbrella project.

## Scope and ownership

This project is the umbrella (orchestrator) for the data-layer stack.
It owns the single bootstrap entry point and the relationship between the
four service-level projects. It does NOT own any of the service-level
implementation itself; those live in dedicated submodule repos:

- `data-layer-postgres/` — see ./data-layer-postgres/README.md
- `data-layer-redis/` — see ./data-layer-redis/README.md
- `data-layer-falkordb/` — see ./data-layer-falkordb/README.md
- `data-layer-adapters/` — see ./data-layer-adapters/README.md

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

- `bootstrap` — single dispatcher (install | verify | status | help)
- `docs/architecture.md` — submodule relationships
- `docs/bootstrap-flow.md` — what happens when `bootstrap` runs
- `docs/services/README.md` — high-level overview of each service