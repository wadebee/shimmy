# Shimmy project guidance

Read root `CONTEXT.md`, then the direct child contexts leading to the module
being changed. Context is local: update the closest `CONTEXT.md` whenever its
directory's architecture, conventions, or child links change.

## Layout

- `commands/` contains the executable management surface.
- `core/` contains reusable POSIX modules.
- `tools/<kind>/tool.conf` defines a tool's default version and selector.
- `tools/<kind>/versions/<major.minor>/run.sh` is the concrete runtime.
- Local builds use that version directory's `container/Containerfile`.
- Tool guides and canonical agent skills live beside the tool.
- `tests/` validates context integrity, metadata dispatch, previews, and clean
  installation behavior.

## Runtime rules

- Keep shell code POSIX-compatible with `#!/bin/sh` and `set -eu`.
- Preserve tool names, profiles, `SHIMMY_*` environment variables, image
  overrides, pull/build options, mounts, credentials, and `--preview-shim`.
- Mount `$PWD` at `/work` unless the tool context documents a reason not to.
- Use `core/runtime/podman.sh` for platform selection and Podman preflight.
- Do not install or provision Podman from Shimmy.

## Tool additions

Add a self-contained `tools/<kind>/` directory with `tool.conf`, a guide,
`CONTEXT.md`, a canonical skill, and one or more version directories containing
`run.sh`, `smoke.conf`, `CONTEXT.md`, and `container/` when locally built. The
catalog discovers this metadata; do not add tool-name case statements to core
or command code.

## Verification

Run `./shimmy test`, inspect shell executable bits, and verify context links.
For a source preview, use `./commands/run-tool.sh <kind> --preview-shim ...`.
