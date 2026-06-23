# Tests

`test.sh` is the canonical POSIX test runner and `support.sh` provides shared
assertions, scenarios, and cleanup. Tests use live Podman only for
non-mutating commands; preview rendering is preferred where it proves the
same behavior.

`context-tree.sh` validates the repository's hierarchical context links.
