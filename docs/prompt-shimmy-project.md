# Shimmy project guidance

Read root `CONTEXT.md`, then the retained child contexts leading to changed
code under `commands/`, `lib/`, or `tests/`. Update the closest retained
context whenever that hierarchy's architecture, conventions, or child links
change. Tool and management-plugin directories do not own context files.

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
- Every concrete version owns `image.conf`, which records external or
  local-build image policy, immutable multi-platform defaults, registry access,
  and both required platforms.
- Local builds use that version directory's `container/Containerfile`.
- Tool guides and canonical tool skills live beside the tool.
- `tests/` validates retained context integrity, metadata dispatch, previews, and clean
  installation behavior.

## Runtime rules

- Keep shell code POSIX-compatible with `#!/bin/sh` and `set -eu`.
- Preserve tool names, supported tool-specific `SHIMMY_*` environment
  variables, image overrides, pull/build options, mounts, credentials, and
  `--preview-shim`.
- Mount `$PWD` at `/work` unless the tool guide or canonical skill documents a
  reason not to.
- Use `lib/runtime/podman.sh` for native OS/architecture platform selection and
  Podman preflight; unsupported or unreadable hosts must fail closed.
- Use `lib/runtime/image.sh` to validate and consume `image.conf`, resolve local
  build inputs, and derive cache identity. Do not duplicate repository-owned
  defaults in runtime shell or Containerfiles.
- Do not install or provision Podman from Shimmy.

## Tool additions

Add a self-contained `tools/<kind>/` directory with `tool.conf`, a guide, a
canonical `SKILL.md`, focused tests, and one or more version directories
containing `run.sh`, `refresh.sh`, `smoke.conf`, `image.conf`, and `container/`
when locally built. The
catalog discovers this metadata; do not add tool-name case statements to `lib/`
or command code.

Choose `external` or `local-build` before implementation. Each concrete
version must own a complete `image.conf`; every repository default and
non-`scratch` base must be an immutable top-level index digest with both
required platforms. Keep mutable publisher tags only as upstream discovery
references. Use the shared image and Podman helpers rather than duplicating
defaults or OS/architecture checks.

Audit companion tools, packages, download URLs, and release archives for both
target architectures. Verify configured indexes explicitly with `shimmy images
verify`, then run the version-owned smoke on native Linux `amd64` and native
Apple Silicon macOS `arm64`; cross-emulation is not acceptance. Digest rotation
is a focused `image.conf` review that must change local cache identity when
applicable and retain the prior digest in git history as rollback evidence.

## Installed profiles and external integrations

Install profiles below an absolute
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>` root. Installed
commands derive identity from their enclosing profile and do not accept
installation-location or profile-selection overrides. Add non-baseline tools
after onboarding with installed `shimmy install --shim <kind>`. Source a
profile's `shell-init.sh` to select it in an existing shell. Only `default`
owns persistent startup blocks for zsh and Bash by default; explicit startup
options may narrow the targets, and `upstream` never changes startup files.
The five-skill management plugin and co-located tool skills are unconditional
profile payload. Repository and home agent skill adapters are external state
owned by the selected target manifest and are written or removed only with explicit standalone
`shimmy skills ... --target repo|profile` operations.

## Verification

Run `./tests/test.sh`, inspect shell executable bits, and verify retained
context links.
For a source preview, use `./commands/run-tool.sh <kind> --preview-shim ...`.
