# Tests

`test.sh` is the canonical POSIX test runner and `support.sh` provides shared
assertions, scenarios, and cleanup. `profile-smoke.sh` parses installed-profile
test requests and runs the enclosing profile's non-mutating smoke commands.
Smoke output capture preserves the wrapped command's exit status so engine or
tool failures cannot be reported as passes.
Tests use live Podman only for non-mutating commands; preview rendering is
preferred where it proves the same behavior. The default suite validates image
metadata offline and previews every concrete runtime across the supported
Linux/Darwin and amd64/arm64 host matrix.

Installation scenarios isolate state with absolute disposable `HOME` and
`XDG_CONFIG_HOME` values. They do not use a Shimmy installation-directory or
installed profile-selection override. The runner creates pristine default and
upstream profiles once per session; scenarios that do not need to exercise the
bootstrap itself clone those fixtures using APFS copy-on-write when available
and a recursive copy fallback elsewhere. Clones relocate the generated
`shell-init.sh` path and default implementation runtime roots before use. The
immutable committed source repository used by self-update scenarios is also
created once per session. Onboarding coverage sources the root
bootstrap to initialize PATH and executes it separately to verify automation
semantics.

`context-tree.sh` validates the repository's hierarchical context links. Every
source-bearing directory below `agent/`, `commands/`, `lib/`, `tools/`, and
`tests/` must have a linked `CONTEXT.md`; this includes canonical skills,
test modules, and local container contexts. The generated `.agents/`
compatibility adapter and all of its descendants are explicitly excluded.

## Child contexts

- [shared-library behavior](lib/CONTEXT.md)
- [management commands](commands/CONTEXT.md)
