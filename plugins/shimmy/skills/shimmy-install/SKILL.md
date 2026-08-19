---
name: shimmy-install
description: Install, update, validate, initialize shells for, or remove Shimmy profiles. Use for Shimmy lifecycle work, bootstrap-time profile selection, disposable XDG installation validation, external startup or skills integration, and manifest-based state inspection.
---

# Shimmy Installation Lifecycle

## Source of truth

- For first-time checkout installation, read `BOOTSTRAP.md`, use the public
  `./bootstrap.sh` checkout bootstrap, and use `./tests/test.sh` for repository
  validation. There is no repository `shimmy` launcher.
- In an installed environment, use the desired profile's absolute
  `bin/shimmy` launcher or its `shimmy` command after sourcing `shell-init.sh`.
- Inspect the invoking profile with `shimmy status --format manifest`.
- Profile manifests are authoritative for installed tools and concrete
  versions. Do not edit manifests directly when a Shimmy command supports the
  action.

## Profiles

Shimmy provides independent `default` and `upstream` profiles below
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`. Require
`XDG_CONFIG_HOME` to be absolute when it is non-empty.

- `default` is the normal external-user profile.
- `upstream` is intended for maintainers; its catalog resolves the recorded
  source checkout, while installed tools execute from profile-local
  materialized assets.
- Only `./bootstrap.sh` accepts `--profile default|upstream`. An installed
  launcher manages only its enclosing profile and rejects profile selection.
- Use `SHIMMY_UPSTREAM_CHECKOUT_DIR` only to select the absolute checkout
  recorded while bootstrapping `upstream`; it never relocates installed state.

Each profile records one fixed named-catalog binding. `upstream` resolves a
validated live Git checkout on every catalog-aware invocation, while `default`
resolves a Shimmy-owned immutable generation. Valid upstream edits are visible
on the next command. Default changes only after clean committed publication,
and existing profile materializations remain unchanged until explicit update.

## Lifecycle commands

```sh
. ./bootstrap.sh
SHIMMY_UPSTREAM_CHECKOUT_DIR=/absolute/checkout
export SHIMMY_UPSTREAM_CHECKOUT_DIR
. ./bootstrap.sh --profile upstream
shimmy install --shim task
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/bin/shimmy" status --format manifest
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/bin/shimmy" update --shim jq
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/bin/shimmy" uninstall
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/bin/shimmy" catalog publish
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/bin/shimmy" catalog rollback
```

For disposable validation, set an absolute temporary `XDG_CONFIG_HOME` and use
fresh-default-bootstrap `--no-startup`. Do not add an installation-directory
override.

Every repository bootstrap includes jq and rg. Add any other tool afterward
through the installed `shimmy install --shim <tool>` command; it installs the
tool dispatcher and its default concrete version. Use `--shim
<tool>@<major.minor>` for a non-default version.

`--activate` is a human checkout-bootstrap convenience for an explicit
post-commit engine transition. It may switch or restart an idle Darwin VM,
never supplies `--stop-running`, and retains the installed profile if
activation fails. Do not use `. ./bootstrap.sh --activate` as an AI Agent
shortcut: it does not authorize an AI Agent to combine installation, status,
dry-run, activation approval, or workload acknowledgement. Follow the separate
absolute-launcher workflow below.

Catalog-dependent install, update, status, image, and skill operations validate
the registry and exact schema before mutation. Already-materialized tools do
not require the catalog to run. Recover a moved upstream checkout with explicit
`shimmy catalog rebind --checkout <absolute-path>` and recover default with
`shimmy catalog rollback` when a retained valid generation exists.

The root rename from `install.sh` to `bootstrap.sh` is a hard compatibility
break. Before adopting the renamed checkout, use the old installed control
plane to run `shimmy uninstall --global`, then reinstall with `. ./bootstrap.sh`.
Do not attempt an in-place self-update or add a forwarding entrypoint.

## Profile activation

After installing or updating a target profile, activate it before recommending
shell selection or tool use:

```sh
profile_root=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default
"$profile_root/bin/shimmy" profile status
"$profile_root/bin/shimmy" profile activate --dry-run
"$profile_root/bin/shimmy" profile activate
```

Use the target profile's validated absolute launcher even when another profile
is selected on `PATH`. Run status and dry-run first. Request approval only for
the exact absolute `bin/shimmy profile activate` command. If the workload guard
lists running containers, stop and obtain separate explicit confirmation before
adding `--stop-running`.

Never provision, delete, rename, or adopt a Podman machine. If the expected
machine is missing, repeat Shimmy's exact `podman machine init
shimmy-<profile>` guidance, including its same-path volume form when shown, for
the user to run in a normal shell. If an older installed profile lacks `profile
activate`, stop and guide the user to update or reinstall it; do not run direct
Podman machine lifecycle commands as a fallback.

Profile activation also selects strict registry redirects. Skopeo and
`shimmy images verify` mount only a valid current invoking-profile policy;
profiles with no activation omit it, while prepared, stale, mismatched, or
damaged active state must be corrected through `shimmy profile` rather than
bypassed.

## Shell initialization and startup

Sourcing the repository bootstrap installs the profile and sources its
generated `shell-init.sh` in the caller. Executing it performs the same install
for automation, but initialization ends with that process.

```sh
. "${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh"
```

After successful activation, users can switch their current shell by sourcing
the desired profile's absolute `shell-init.sh`.
Only `default` may manage persistent startup blocks. Fresh bootstrap records
one normalized shell from `--shell <name>` or `$SHELL`. Managed policy resolves
that shell's conventional paths once. When a sourced bootstrap identifies a
running Bash or Zsh that differs from the managed startup shell, bootstrap warns
with both values and requires confirmation before mutation. Align them by
running bootstrap from the configured shell or selecting the running shell with
`--shell` during fresh creation. Executed automation remains non-interactive.
Fresh-bootstrap `--no-startup` records manual policy with no owned files. Later
bootstraps and installed lifecycle operations inherit the manifest state.
`shimmy update --repair-startup` repairs only the exact recorded paths and is a
no-op for manual policy. Changing policy requires uninstalling and recreating
the default profile; `upstream` never changes shell startup files. Installed
`shimmy install` accepts only repeatable `--shim` selection, and installed
launchers derive profile identity from their enclosing root rather than a
`--profile` option.

For a manual policy with a nonstandard startup chain, add the generated
`shell-init.sh` source block to the chosen interactive or login startup file.
Require non-empty `XDG_CONFIG_HOME` to be absolute. The block selects PATH only;
Bash users must not apply it globally through `BASH_ENV`.

AI Agent tool calls do not retain a sourcing operation performed in an earlier
tool call. For a later management or tool command, use the absolute target
dispatcher or source `shell-init.sh` and invoke the command within the same
shell command. Sourcing selects PATH only and never activates an engine.

## Shared skills

The canonical five-skill management plugin and co-located tool skills remain
in the invoking profile's named catalog; they are not copied into the profile.
Install or update agent skill adapters in a repository or home agent profile
only when the user explicitly selects that target through standalone `shimmy
skills` commands. Shimmy stages the complete adapter set and validates the
catalog again before changing the target. The target's
`.shimmy-skills-manifest.txt` owns those entries; no profile manifest owns the
target. Profile and catalog install, update, and uninstall never implicitly
refresh or remove it. Target-owned uninstall remains available if the catalog
is unavailable:

```sh
shimmy skills update --target <repo|profile>
shimmy skills uninstall --target <repo|profile>
```

Ordinary `shimmy uninstall` removes only the invoking profile and preserves
sibling profiles and shared catalogs. It cleans an exact Linux activation or
Darwin projection itself; manual `profile redirect remove --all --detach` is
recovery/debugging functionality, not a prerequisite. Darwin cleanup restores
the initial machine/default state and may need to stop a running machine. Run
uninstall without `--stop-running` first; if it lists workloads and refuses,
obtain explicit confirmation before retrying with that acknowledgement.
Explicit `shimmy uninstall --global` detaches every owned profile before
removing all valid manifest-owned profiles and registry-owned catalogs while
preserving bound checkouts and these external exports; it refuses unrecognized
shared state.

## Podman and validation

Podman is an explicit dependency. Do not provision it. Run `podman info` only
when appropriate; if a Shimmy wrapper is sandbox-blocked despite direct Podman
access, use the exact-wrapper approval workflow before any fallback.

Validate with status, an XDG-isolated disposable profile install, and
non-mutating tool smokes. Earlier layouts must be removed with the Shimmy
version that created them and reinstalled; do not migrate their manifests.
