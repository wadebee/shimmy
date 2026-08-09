# Shimmy

Shimmy exposes common CLI tools through small POSIX shell wrappers that run Podman containers. Read this file first, then the `CONTEXT.md` files on the path to the code being changed.

## Architecture

- `commands/` is the public management-command surface.
- `lib/` contains shared catalog, profile, runtime, startup, and networking
  modules.
- `tools/` owns each tool's metadata, versions, container context, guide, and
  agent guidance.
- `tests/` contains the POSIX test runner and shared test support.

## Invariants

- Runtime code is POSIX shell and uses `set -eu`.
- User-facing tool variables use the `SHIMMY_` prefix.
- Tool runs mount `$PWD` at `/work` unless its local context documents why.
- Podman is an explicit dependency; do not provision it from Shimmy.

## Child contexts

- [commands](commands/CONTEXT.md)
- [shared library](lib/CONTEXT.md)
- [tools](tools/CONTEXT.md)
- [tests](tests/CONTEXT.md)
- [agent guidance](agent/CONTEXT.md)

## Maintaining this tree

The default test suite verifies that every source-bearing directory has a
linked context file and that referenced paths exist. When changing a module,
update only its closest context and its parent link. Periodically ask an LLM:
“Read the CONTEXT tree and verify it is up to date.”
