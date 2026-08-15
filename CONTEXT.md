# Shimmy

Shimmy exposes common CLI tools through small POSIX shell wrappers that run
Podman containers. Read this file first, then the retained `CONTEXT.md` files
on the path to changed code under `commands/`, `lib/`, or `tests/`. Tool and
management-plugin directories deliberately have no context-file hierarchy.

## Architecture

- `commands/` is the public management-command surface.
- `lib/` contains shared catalog, profile, runtime, startup, and networking
  modules.
- `commands/profile.sh` and `lib/profile/activation.sh` own explicit
  profile-bound Podman engine status and activation. Shell initialization owns
  PATH selection only.
- `install.sh` bootstraps one canonical profile with the fixed jq/rg baseline
  and sources its generated `shell-init.sh`; the repository has no runnable
  `shimmy` launcher and does not accept tool selection. Sourcing the installer
  retains shell initialization, while execution remains suitable for
  automation and absolute-path self-update.
- `tools/` owns each tool's metadata, versions, container context, guide, and
  canonical skill.
- `plugins/shimmy/skills/` owns the five canonical control-plane skills.
- `tests/` contains the POSIX test runner and shared test support.

Installed profiles are independent materialized control/runtime trees under
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`. Each owns its
own `bin/shimmy`; no installed control payload is shared between profiles.
Each `tools/` tree contains only manifest-selected tool metadata and concrete
version assets. Canonical skills remain catalog-owned.

## Invariants

- Runtime code is POSIX shell and uses `set -eu`.
- User-facing tool variables use the `SHIMMY_` prefix.
- Tool runs mount `$PWD` at `/work` unless its local context documents why.
- Supported Linux and Darwin hosts select the matching native
  `linux/amd64` or `linux/arm64` image platform; unsupported hosts fail closed.
- Every concrete version owns validated `image.conf` metadata with immutable
  multi-platform defaults.
- Podman is an explicit dependency; do not provision it from Shimmy.
- Darwin profiles map deterministically to pre-existing `shimmy-default` and
  `shimmy-upstream` rootless engines; activation is workload-guarded and
  commits the global default connection last.

## Child contexts

- [commands](commands/CONTEXT.md)
- [shared library](lib/CONTEXT.md)
- [tests](tests/CONTEXT.md)

## Maintaining this tree

The default test suite verifies that every source-bearing directory has a
linked context file and that referenced paths exist. When changing a module,
update only its closest context and its parent link. Periodically ask an LLM:
“Read the CONTEXT tree and verify it is up to date.”
