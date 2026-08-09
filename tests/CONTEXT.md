# Tests

`test.sh` is the canonical POSIX test runner and `support.sh` provides shared
assertions, scenarios, and cleanup. `profile-smoke.sh` parses installed-profile
test requests and runs the enclosing profile's non-mutating smoke commands.
Tests use live Podman only for non-mutating commands; preview rendering is
preferred where it proves the same behavior.

Installation scenarios isolate state with absolute disposable `HOME` and
`XDG_CONFIG_HOME` values. They do not use a Shimmy installation-directory or
installed profile-selection override. Onboarding coverage sources the root
bootstrap to initialize PATH and executes it separately to verify automation
semantics.

`context-tree.sh` validates the repository's hierarchical context links. Every
source-bearing directory below `agent/`, `commands/`, `lib/`, `tools/`, and
`tests/` must have a linked `CONTEXT.md`; this includes canonical skills,
test modules, and local container contexts.

## Child contexts

- [shared-library behavior](lib/CONTEXT.md)
- [management commands](commands/CONTEXT.md)
