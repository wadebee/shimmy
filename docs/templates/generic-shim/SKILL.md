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
- `<image-strategy>` as `remote-image` or `local-build`

## Read First

1. Read `../../../CONTRIBUTING.md` and `../../../docs/prompt-shimmy-project.md`.
2. Inspect the closest existing runtime shim under `../../../shims/`.
3. Inspect the closest existing shim skill under `../../../.agents/skills/` when a tool already has authoring guidance.
4. Reuse existing conventions instead of inventing a new wrapper shape.

## Required Outputs

- `../../../shims/<shim-name>`
- `../../../shims/<shim-name>.conf`
- `../../../lib/repo/shimmy-catalog.sh`
- `../../../scripts/status-shimmy.sh`
- `../../../scripts/update-shimmy.sh`
- `../../../scripts/test-shimmy.sh`
- `../../../README.md`
- `../../../docs/shims/<shim-name>.md`
- `../../../.agents/skills/shimmy-tool-<shim-name>/SKILL.md` when the shim is new or materially changed
- `../../../.agents/skills/.shimmy-skills-manifest.txt` after installing or updating the tool skill

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

Use repeated `smoke_arg=` lines when the smoke command needs more than one argument. `shimmy test` does not shell-split a single `smoke_arg=` value. Use `smoke_env=KEY=value` only for non-secret selector or test-mode variables needed by the smoke command. The smoke command must be non-mutating and must belong to the shim config rather than `scripts/test-shimmy.sh`.

## Design Rules

- Keep the wrapper linear and readable; avoid helper functions unless the shim genuinely needs them.
- Mount home-directory state only when the tool needs config, credentials, or caches.
- Prefer wildcard env forwarding such as `-e AWS_*` when the underlying CLI already depends on a family of env vars.
- Preserve transparent CLI behavior by passing `"$@"` unchanged.
- Support `--preview-shim` as a global Shimmy flag through the shared Podman helper.
- Use `SHIMMY_` for every Shimmy-defined user-facing environment variable; reserve non-`SHIMMY_` env vars for upstream-defined pass-through configuration.
- Choose a pinned image unless there is a strong reason to use `latest`.
- Decide whether the shim uses a remote image or a local build context before implementation; do not silently switch an existing shim's strategy.
- For local-build shims, add `images/<shim-name>/Containerfile`, use `shimmy_local_image_ensure`, pass documented base/source override env vars as `--build-arg` values, describe status local refs, and add update `--build` behavior.
- Treat Podman as an explicit dependency. On macOS, remember the official pkg installer may place it at `/opt/podman/bin/podman`.
- Use the shared Podman helper's platform resolver; do not hardcode per-shim platform logic.

## Change Checklist

1. Add the shim to the supported shim catalog in `lib/repo/shimmy-catalog.sh`.
2. Add a shim config with a non-mutating smoke command in `shims/<shim-name>.conf`.
3. Use one `smoke_arg=` line per argv item and `smoke_env=KEY=value` only for non-secret selector variables.
4. Add status image/dispatcher description logic in `scripts/status-shimmy.sh`.
5. Add update pull/build refresh logic in `scripts/update-shimmy.sh` when the shim supports image pull or local build refresh.
6. Add live Podman-backed or preview-based tests in `scripts/test-shimmy.sh`, including installed smoke config coverage when applicable.
7. Document the tool in `README.md` and `docs/shims/<shim-name>.md`.
8. Keep executable bits on runnable shell files.
9. If the tool is new or materially changed, add a shim-specific skill folder under `../../../.agents/skills/` and install it into the repo skills manifest.
10. For multi-version dispatchers, add dispatcher and versioned shims/configs, selector `smoke_env`, companion install behavior, selector error tests, preview tests, status/update tests, and docs for adding new tracks.
11. Run `git diff --check`, inspect `git diff --summary`, and finish with an `rg` or `git grep` surface scan across docs, shims, scripts, catalog, and skills.
