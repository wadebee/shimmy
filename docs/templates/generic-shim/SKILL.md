---
name: shimmy-generic-shim-template
description: Template for creating or updating a Shimmy-style CLI shim that wraps a tool in Podman. Use when adding a new shim or cloning an existing pattern in this repository.
---

# Generic Shim Template

Use this as the starting point for a new shim skill or as a checklist for a one-off shim addition.

## Replace These Tokens

- `<shim-name>`
- `<tool_prefix>` for env vars such as `SHIMMY_<TOOL_PREFIX>_IMAGE`
- `<default-image>`
- `<interactive-flag>` as `-i` or `-it`
- `<extra-mounts>`
- `<env-forwarding>`

## Read First

1. Read `../../../CONTRIBUTING.md` and `../../../docs/prompt-shimmy-project.md`.
2. Inspect the closest existing runtime shim under `../../../shims/`.
3. Inspect the closest existing shim skill under `../../../.agents/skills/` when a tool already has authoring guidance.
4. Reuse existing conventions instead of inventing a new wrapper shape.

## Required Outputs

- `../../../shims/<shim-name>`
- `../../../shims/<shim-name>.conf`
- `../../../scripts/install-shimmy.sh`
- `../../../scripts/test-shimmy.sh`
- `../../../README.md`

## Runtime Pattern

```sh
#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
SHIMMY_PODMAN_HELPER_FILE=$SCRIPT_DIR/../lib/shims/shimmy-podman.sh

SHIMMY_<TOOL_PREFIX>_IMAGE=${SHIMMY_<TOOL_PREFIX>_IMAGE:-<default-image>}
SHIMMY_<TOOL_PREFIX>_IMAGE_PULL=${SHIMMY_<TOOL_PREFIX>_IMAGE_PULL:-}
SHIMMY_<TOOL_PREFIX>_PULL_ARG=

if [ ! -f "$SHIMMY_PODMAN_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_PODMAN_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/shims/shimmy-podman.sh
. "$SHIMMY_PODMAN_HELPER_FILE"

shimmy_podman_preflight_or_preview_require "the <shim-name> shim" "$@"

if [ "$SHIMMY_<TOOL_PREFIX>_IMAGE_PULL" = "always" ]; then
  SHIMMY_<TOOL_PREFIX>_PULL_ARG=--pull=always
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm --platform "$SHIMMY_PODMAN_PLATFORM" <interactive-flag> ${SHIMMY_<TOOL_PREFIX>_PULL_ARG:+"$SHIMMY_<TOOL_PREFIX>_PULL_ARG"} -v "$PWD:/work" -w /work "$SHIMMY_<TOOL_PREFIX>_IMAGE" "$@"
```

## Shim Config Pattern

```text
shim_config_version=1
shim_name=<shim-name>
smoke_arg=<non-mutating-arg>
```

Use repeated `smoke_arg=` lines when the smoke command needs more than one argument. The smoke command must be non-mutating and must belong to the shim config rather than `scripts/test-shimmy.sh`.

## Design Rules

- Keep the wrapper linear and readable; avoid helper functions unless the shim genuinely needs them.
- Mount home-directory state only when the tool needs config, credentials, or caches.
- Prefer wildcard env forwarding such as `-e AWS_*` when the underlying CLI already depends on a family of env vars.
- Preserve transparent CLI behavior by passing `"$@"` unchanged.
- Support `--preview-shim` as a global Shimmy flag through the shared Podman helper.
- Use `SHIMMY_` for every Shimmy-defined user-facing environment variable; reserve non-`SHIMMY_` env vars for upstream-defined pass-through configuration.
- Choose a pinned image unless there is a strong reason to use `latest`.
- Treat Podman as an explicit dependency. On macOS, remember the official pkg installer may place it at `/opt/podman/bin/podman`.
- Use the shared Podman helper's platform resolver; do not hardcode per-shim platform logic.

## Change Checklist

1. Add the shim to the supported shim catalog in `lib/repo/shimmy-catalog.sh`.
2. Add a shim config with a non-mutating smoke command in `shims/<shim-name>.conf`.
3. Add live Podman-backed tests in `scripts/test-shimmy.sh`.
4. Document the tool in `README.md`.
5. Keep executable bits on runnable shell files.
6. If the tool differs materially from existing shims, add a shim-specific skill folder under `../../../.agents/skills/`.
