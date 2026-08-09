# Shimmy project guidance

Read root `CONTEXT.md`, then the direct child contexts leading to the module
being changed. Context is local: update the closest `CONTEXT.md` whenever its
directory's architecture, conventions, or child links change.

## Layout

- `commands/` contains the executable management surface.
- `lib/` contains reusable POSIX modules, including canonical XDG profile-path
  resolution.
- Root `install.sh` bootstraps one profile; the repository contains no runnable
  `shimmy` launcher. Sourcing it initializes the caller; execution is for
  automation. Every bootstrap includes jq and rg, and each installed flat
  profile owns its own `bin/shimmy`.
- `tools/<kind>/tool.conf` defines a tool's default version and selector.
- `tools/<kind>/versions/<major.minor>/run.sh` is the concrete runtime.
- Local builds use that version directory's `container/Containerfile`.
- Tool guides and canonical agent skills live beside the tool.
- `tests/` validates context integrity, metadata dispatch, previews, and clean
  installation behavior.

## Runtime rules

- Keep shell code POSIX-compatible with `#!/bin/sh` and `set -eu`.
- Preserve tool names, supported tool-specific `SHIMMY_*` environment
  variables, image overrides, pull/build options, mounts, credentials, and
  `--preview-shim`.
- Mount `$PWD` at `/work` unless the tool context documents a reason not to.
- Use `lib/runtime/podman.sh` for platform selection and Podman preflight.
- Do not install or provision Podman from Shimmy.

## Tool additions

Add a self-contained `tools/<kind>/` directory with `tool.conf`, a guide,
`CONTEXT.md`, a canonical skill, and one or more version directories containing
`run.sh`, `smoke.conf`, `CONTEXT.md`, and `container/` when locally built. The
catalog discovers this metadata; do not add tool-name case statements to `lib/`
or command code.

## Installed profiles and external integrations

Install profiles below an absolute
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>` root. Installed
commands derive identity from their enclosing profile and do not accept
installation-location or profile-selection overrides. Add non-baseline tools
after onboarding with installed `shimmy install --shim <kind>`. Source a
profile's `shell-init.sh` to select it in an existing shell. Only `default`
owns a persistent startup block; `upstream` never changes startup files.
Canonical sources and packaged plugin skills are unconditional profile payload.
Repository and home agent skills are external state owned by the selected
target manifest and are written or removed only with explicit standalone
`shimmy skills ... --target repo|profile` operations.

## Verification

Run `./tests/test.sh`, inspect shell executable bits, and verify context links.
For a source preview, use `./commands/run-tool.sh <kind> --preview-shim ...`.
