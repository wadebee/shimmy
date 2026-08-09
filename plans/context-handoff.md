# Context-first migration handoff

The context-first Shimmy migration described by
[`context_remaining.md`](context_remaining.md) is complete. This document is
the copy-ready prompt for a fresh agent session that needs to review, extend,
or verify that work without replaying it.

## Prompt

```text
Continue Shimmy work from plans/context_remaining.md.

The context-first migration is complete. Do not reimplement its completed
segments. First read AGENTS.md, CONTRIBUTING.md, root CONTEXT.md, and the
relevant child-context path for any file you change.

Validate the current worktree before making changes. Use the source-checkout
suite directly:

  ./tests/test.sh

Use exact-approved, non-mutating Shimmy wrapper commands for any live Podman
check. Do not pull or build an image without explicit user authority. Preserve
the POSIX-shell architecture, version-local tool behavior, SHIMMY_-prefixed
variables, generic catalog dispatch, and context-tree links.

Treat plans/context_remaining.md as the completed migration record. New work
must be a separately scoped plan. For future work involving multi-platform
base images, begin with plans/multi-architecture-manifest.md.
```

## Completed acceptance evidence

- Context links and source-bearing directories validate through
  `./tests/context-tree.sh`.
- The source suite passes through `./tests/test.sh` without dispatching through
  an installed profile.
- All 16 tool kinds own test coverage, and all 18 concrete versions have a
  live non-mutating smoke result.
- OC 4.18, 4.20, and 4.22 use Red Hat multi-architecture manifest-list
  digests and a cross-version `oc --help` smoke command.

## Boundaries for future work

- The user's normal Shimmy install may use a legacy layout; do not mutate it.
  Use an absolute disposable `XDG_CONFIG_HOME` for tests.
- Local image builds and remote image pulls mutate Podman state. Request
  authority before refreshing images, even if a previous session did so.
- The read-only `.agents/` tree is a compatibility adapter. Canonical skills
  are under `agent/` and `tools/<kind>/agent/`.
