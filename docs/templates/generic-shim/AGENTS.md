## Scope

This template describes one context-first Shimmy tool directory.

## Instructions

- Read this directory's `SKILL.md`, root `CONTEXT.md`, and `tools/CONTEXT.md`.
- Create `tools/<kind>/tool.conf`, `CONTEXT.md`, `guide.md`, and `agent/SKILL.md`.
- Put each concrete runtime at `versions/<major.minor>/run.sh` with a sibling
  `smoke.conf` and `CONTEXT.md`.
- Put local build assets in that version's `container/` directory.
- Keep runtime wrappers POSIX shell, executable, and `SHIMMY_`-prefixed for
  Shimmy-defined environment variables.
