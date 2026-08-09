# Tests

`test.sh` is the canonical POSIX test runner and `support.sh` provides shared
assertions, scenarios, and cleanup. `profile-smoke.sh` parses installed-profile
test requests and runs the selected profile's non-mutating smoke commands.
Tests use live Podman only for non-mutating commands; preview rendering is
preferred where it proves the same behavior.

`context-tree.sh` validates the repository's hierarchical context links. Every
source-bearing directory below `agent/`, `commands/`, `lib/`, `tools/`, and
`tests/` must have a linked `CONTEXT.md`; this includes canonical skills,
test modules, and local container contexts.

## Child contexts

- [shared-library behavior](core/CONTEXT.md)
- [management commands](commands/CONTEXT.md)
