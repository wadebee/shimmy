# POSIX Rewrite Architecture

This document defines the target architecture and coding rules for the `posix-rewrite` branch.

It is the checkpoint document for the first rewrite iteration and should guide all proof-of-concept work that follows.

## Goals

- Rebuild Shimmy as a POSIX-shell-first codebase.
- Preserve the user-facing capabilities that remain in scope.
- Prefer simpler designs over mechanism parity with the Bash implementation.
- Optimize for first-time installation and easy onboarding.
- Keep runtime shims small and readable.

## In Scope

- Repo control surface via `shimmy`
- `install`, `uninstall`, `status`, `update`, `test`, and `shellenv`
- Install manifests and install-path tracking
- `eval "$(shimmy shellenv)"` activation
- Remote-image shims
- Local-build shims except `tessl`
- Podman-backed smoke tests
- Onboarding helpers for common POSIX-oriented shell environments

## Out Of Scope

- `.envrc` and direnv compatibility
- `tessl` shim and its container image support
- Backward compatibility with Bash-specific implementation details
- Preserving current code logic if a better POSIX design exists

## Capability Targets

The rewrite should reproduce these capabilities in a new POSIX-friendly design:

- Install shimmy-managed assets into user-scoped locations
- Support copy and symlink install modes
- Track the active install using a manifest file
- Support explicit install paths via `SHIMMY_INSTALL_DIR`, `SHIMMY_SHIM_DIR`, `SHIMMY_IMAGES_DIR`, and `SHIMMY_SHIM_LIB_DIR`
- Print activation code with `shimmy shellenv`
- Report install state and installed shim image references
- Refresh an existing install from repo state
- Run smoke tests against Podman-backed shims
- Support remote-image shims: `aws`, `jq`, `rg`, `terraform`
- Support local-build shims: `netcat`, `task`, `textual`
- Support `<PREFIX>_IMAGE` and `<PREFIX>_IMAGE_PULL=always`
- Build local images from checked-in `Containerfile` contexts
- Rebuild and prune local images during update when requested
- Mount working directory and tool-specific state into containers
- Forward required environment variables
- Honor `LOG_LEVEL`

## Design Principles

- Target `/bin/sh` compatibility first.
- Treat `dash -n` as the first parser gate.
- Avoid Bash-only syntax entirely.
- Avoid clever shell patterns when a simpler linear script will do.
- Prefer data files and simple line-oriented text over shell metaprogramming.
- Prefer one-directional control flow over source-time side effects.
- Keep install-time behavior idempotent.
- Avoid editing user rc files in the initial foundation.
- Add onboarding helpers only after `shellenv` is stable.
- Treat Podman as an explicit dependency. Shimmy should fail clearly when it is missing, not try to install it.

## POSIX Coding Rules

- Use `#!/bin/sh` for runnable shell files unless a file is intentionally not executable.
- Use `set -eu` by default.
- Do not use `pipefail`.
- Use `.` instead of `source`.
- Do not use `[[ ... ]]`.
- Do not use arrays.
- Do not use `local`.
- Do not use `function`.
- Do not use `select`, `mapfile`, namerefs, process substitution, here-strings, or `BASH_SOURCE`.
- Use POSIX-safe function names with a `shimmy_` prefix.
- Prefer `case` and `[ ... ]` for conditionals.
- Prefer `set --` for argument accumulation when a command needs dynamic options.
- Prefer newline-delimited records over shell-escaped list serialization.
- Quote all variable expansions unless unquoted expansion is explicitly required.
- Use `printf` instead of `echo` for non-trivial output.

## Utility Portability Rules

- Avoid GNU-only command flags when a portable alternative is reasonable.
- Prefer `cp -R` over `cp -a` when metadata preservation is not essential.
- Avoid `find -printf`.
- Avoid relying on `readlink` for core behavior.
- Treat content hashing helpers as implementation details that may use available system tools, but keep fallback behavior explicit.

## Proposed Runtime Shape

### `shimmy`

- Thin POSIX entrypoint
- Dispatches subcommands to scripts in `scripts/`
- Provides `shellenv`
- Does not support sourced-script detection as a core feature

### `scripts/`

- `install-shimmy.sh`
- `status-shimmy.sh`
- `update-shimmy.sh`
- `test-shimmy.sh`

These remain the repo lifecycle entrypoints, but are reimplemented as POSIX shell scripts.

### `lib/`

- `lib/repo/` remains the home for repo-lifecycle helpers
- `lib/shims/` remains the home for installed runtime shim helpers

Helper libraries should expose only POSIX-safe function names and avoid dynamic shell tricks.

### `shims/`

- One executable per tool
- Remote-image shims stay very small
- Local-build shims may source a minimal helper library for image resolution

## Activation Model

### Primary path

The primary onboarding path is:

```sh
eval "$(shimmy shellenv)"
```

### Persistent setup

Persistent shell setup is not part of the initial foundation.

Instead, the documentation will show users how to add a single activation line to their preferred shell config. After the core rewrite is stable, helper functions and onboarding guidance can be added for the most common POSIX-oriented environments.

## Manifest Model

The manifest is the source of truth for the current install.

The rewrite should keep it simple:

- line-oriented key-value format
- one value per line
- repeated keys allowed for repeated values such as installed shims
- easy to parse with `sed`, `grep`, and shell loops

The implementation should avoid array-name indirection or `eval`-driven serialization.

## Proof Of Concept Scope

The first implementation checkpoint should include:

- new POSIX-safe helper naming conventions
- a POSIX `shimmy` entrypoint
- a POSIX `shellenv` implementation
- a minimal POSIX install flow
- one simple remote-image shim, expected to be `jq`
- minimal `/bin/sh` validation and one Podman smoke test

## Checkpoint Questions

Before expanding beyond the proof of concept, confirm:

- the new helper naming convention is acceptable
- the manifest format is simple enough
- `eval "$(shimmy shellenv)"` is the preferred onboarding path
- rc-file editing remains deferred
- the proof-of-concept shim shape is good enough to replicate
