## Compact Restart Brief

Read this entire document as a "restart context" for the `posix-rewrite`.

The following user approved decisions have not yet been captured in the 'Current checklist status:'   
- Remove symlink install mode from the target design.
- Use a single fixed install layout under one install root.
- Default the install root to `~/.config/shimmy`.
- Keep install root configurable through `--install-dir`.
- Remove exported `SHIMMY_INSTALL_DIR`, `SHIMMY_SHIM_DIR`, `SHIMMY_IMAGES_DIR`, and `SHIMMY_SHIM_LIB_DIR` from the target runtime model.
- Rename the activation command from `shellenv` to `activate`.
- Make `activate` primarily responsible for PATH activation.
- Treat Podman as an explicit dependency. Shimmy must not install it.
- Final macOS usage must not require users to prepend `/opt/podman/bin` manually.
- If Shimmy ever exports user-shell variables again, they must use the `SHIMMY_` prefix.

Implementation note:
- Your first action should update the `Current checklist status` list below to integrate the new decisions above.
- Then update the status of each checklist item to see if they require rework
- Prioritize the checklist to maximize chances of a successful conversion by you in a later session.
- A prior proof of concept already exists on this branch using `shellenv`, explicit `SHIMMY_*` exports, and copy/symlink installer support.
- That proof of concept successfully validated the POSIX direction and live Podman tests for the jq shim so doesn't need to be reimplemented. Simply validate.
- The next implementation phase should adapt that proof of concept to the newly approved `activate` and single-root design rather than treating the earlier POC interface as final.
- Lets iterate over checklist items. Create a checkpoint at each item and confirm with me your approach and any optional decisions you would like clarity on. Once we are in agreement, update this rewrite doc as appropriate to create a decision log.

### Current checklist status:

- `done` Create and switch to `posix-rewrite`
  `thinking: medium`
- `done` Inventory current capabilities
  `thinking: medium`
- `done` Define out-of-scope items
  `thinking: medium`
- `done` Establish the new POSIX architecture and coding rules
  `thinking: high`
- `done` Build proof-of-concept `shimmy` entrypoint in POSIX shell
  `thinking: medium`
- `done` Rework the proof-of-concept activation flow to `eval "$(shimmy activate)"`
  `thinking: medium`
- `done` Rework the proof-of-concept install flow for the approved single-root layout
  `thinking: high`
- `to-do` Add onboarding-helper checklist item for common POSIX shell environments
  `thinking: medium`
- `done` Port one simple remote-image shim as the reference implementation
  `thinking: medium`
- `done` Add minimal `/bin/sh` validation and smoke tests for the proof of concept
  `thinking: medium`
- `done` Checkpoint and confirm approach before expanding the pattern
  `thinking: high`
- `done` Update contributor and project docs to match the approved `activate` plus single-root pattern
  `thinking: medium`
- `to-do` Expand the rewrite to the remaining in-scope shims and lifecycle commands
  `thinking: high`
- `to-do` Add secondary onboarding features, including optional rc-file helpers
  `thinking: medium`

### Restart checkpoint decision log

- The branch already validated the core POSIX direction with a repo-root `shimmy` launcher, a live `jq` reference shim, and live Podman smoke tests.
- That proof of concept is not the final interface because it still reflects the superseded `shellenv`, exported `SHIMMY_*` path variables, and copy-or-symlink installer design.
- The current restart work first replaced `shellenv` with `activate`, collapsed installs to a single root-derived layout, and removed the exported Shimmy path variables from activation output.
- The fixed install root remains `~/.config/shimmy`, with `--install-dir` retained as the explicit override.
- `activate` should own PATH activation for installed shims and should also cover the macOS pkg-installed Podman path when needed so users do not have to prepend `/opt/podman/bin` manually.
- The foundation now includes POSIX `install`, `activate`, `status`, `update`, and `test` flows built around the single-root manifest model.
- The next priority is the remaining runtime shim expansion work, especially the in-scope remote-image and local-build shims that still rely on older Bash-era helpers.

Next-session priority adjustments:

- Current git-branch is posix-rewrite
- continue with medium thinking unless otherwise requested
- Use the new `activate` and single-root model as the baseline for the remaining shim ports.
- Port the remaining in-scope runtime shims off Bash-era helpers and conventions.
- Update shared shim helper libraries as needed so local-build shims no longer depend on exported Shimmy path variables.
- Keep validating with `/bin/sh` parser checks and live Podman smoke tests as each shim group moves over.

# POSIX Rewrite Architecture

This document defines the target architecture and coding rules for the `posix-rewrite` branch.

It is the checkpoint document for the first rewrite iteration and should guide all proof-of-concept work that follows.

## Goals

- Rebuild Shimmy as a POSIX-shell-first codebase.
- Preserve the user-facing capabilities that remain in scope.
- Prefer simpler designs over mechanism parity with the Bash implementation.
- Optimize for first-time installation and easy onboarding.
- Keep runtime shims small and readable yet flexible with option handling and shell-agnostic integration and conventions.

## In Scope

- Repo control surface via `shimmy`
- `install`, `uninstall`, `status`, `update`, `test`, and `activate` commands
- Install manifests and install-path tracking
- Remote-image shims
- Local-build shims except `tessl`
- Live Podman-backed smoke tests (no fakes)
- Simple installation and activation helpers for common POSIX-oriented shell environments

## Out Of Scope

- `.envrc` and direnv compatibility
- `tessl` shim and its container image support
- Backward compatibility with Bash-specific implementation details
- Preserving current code logic if a better POSIX design exists

## Capability Targets

The rewrite should reproduce these capabilities in a new POSIX-friendly design:

- Default to a single fixed install layout rooted at `~/.config/shimmy`
- Install shimmy-managed assets into install root-derived paths
- Support explicit install and admin roots via `--install-dir`
- Track the active install using a manifest file
- Avoid exporting Shimmy-managed path variables into the user shell by default
- Refresh existing install state with `shimmy activate` and optionally switch to new root with `--install-dir`
- Report install state and installed shim image references for active install root with `shimmy status` command
- Run smoke tests against Podman-backed shims with `shimmy test` command
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
- Separate installer and admin configuration from runtime shell activation.
- Add onboarding helpers only after `activate` is stable.
- Treat Podman as an explicit dependency. Shimmy should fail clearly when it is missing, not try to install it.
- Final macOS usage should not require users to manually prepend `/opt/podman/bin`.

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
- Provides `activate`
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
eval "$(shimmy install)"
```

`activate` should primarily be a PATH activator. Its default output should make installed shims discoverable without exporting Shimmy-managed internal path variables into the user shell.

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
- a POSIX `activate` implementation
- a minimal POSIX install flow
- one simple remote-image shim, expected to be `jq`
- minimal `/bin/sh` validation and one Podman smoke test

## Checkpoint Questions

Before expanding beyond the proof of concept, confirm:

- new conventions are acceptable
- implementation formats are simple enough
- `eval "$(shimmy activate)"` or other simple onboarding path has been implemented without exporting Shimmy-managed path variables
- the proof-of-concept shim shape is good enough to replicate
