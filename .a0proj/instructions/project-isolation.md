# data-layer — project isolation directive

This file is injected into the Agent Zero system prompt when this project
is active. It captures the workspace contract for the data-layer umbrella.

## Workspace

ACTIVE WORKSPACE: `/a0/usr/projects/data-layer`

The workspace is structured as a single umbrella repository with four
placeholder submodule directories. Each submodule directory contains a
README that documents the expected interface contract; the real
implementation lives in a dedicated git repository per submodule.

## Boundary

This project is the orchestrator. It does NOT implement postgres, redis,
falkordb, or framework-adapter logic. Those responsibilities are owned by
the submodule repos:

- `data-layer-postgres` → `github.com/NovaAI-innovation/data-layer-postgres`
- `data-layer-redis` → `github.com/NovaAI-innovation/data-layer-redis`
- `data-layer-falkordb` → `github.com/NovaAI-innovation/data-layer-falkordb`
- `data-layer-adapters` → `github.com/NovaAI-innovation/data-layer-adapters`

## Required workflow

1. Read `README.md`, `docs/architecture.md`, `docs/bootstrap-flow.md`, and `AGENTS.md` before changing anything.
2. State the intended outcome and affected paths before implementation.
3. Keep deployment state separate from source.
4. Use `/opt/venv-a0/bin/python` for Agent Zero framework checks; `/opt/venv/bin/python` for task checks.
5. Never write real secrets to source-controlled files.

## Cross-project communication

Cross-submodule wiring goes through `bootstrap` (which delegates to each
submodule's `lib/install.sh`) and through shared env variables in
`.env.example` / `.a0proj/variables.env`. Do not hard-code paths to other
projects.
