---
name: shimmy-generic-shim-template
description: Template for creating or updating a Shimmy-style CLI shim that wraps a tool in Podman. Use when adding a new shim or cloning an existing pattern in this repository.
---

# Generic Shim Template

Use this as the starting point for a new shim skill or as a checklist for a one-off shim addition.

## Replace These Tokens

- `<shim-name>`
- `<prefix>` for env vars such as `<PREFIX>_IMAGE`
- `<default-image>`
- `<interactive-flag>` as `-i` or `-it`
- `<extra-mounts>`
- `<env-forwarding>`

## Read First

1. Read `../../references/docs/shimmy-project-prompt.md-prompt.md`.
2. Inspect the closest existing runtime shim under `../../../shims/`.
3. Inspect the closest existing shim skill under `../../shims/` when a tool already has authoring guidance.
4. Reuse existing conventions instead of inventing a new wrapper shape.

## Required Outputs

- `../../../shims/<shim-name>`
- `../../../scripts/install-shimmy.sh`
- `../../../scripts/test-shimmy.sh`
- `../../../README.md`

## Runtime Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

<PREFIX>_IMAGE=${<PREFIX>_IMAGE:-<default-image>}

MOUNTS=( -v "$PWD":/work -w /work )
ENV_VARS=()
PODMAN_OPTS=()

# Add tool-specific mounts here.

if [ "${<PREFIX>_IMAGE_PULL:-}" = "always" ]; then
  PODMAN_OPTS+=( --pull=always )
fi

exec podman run --rm <interactive-flag> "${PODMAN_OPTS[@]}" "${MOUNTS[@]}" "${ENV_VARS[@]}" "$<PREFIX>_IMAGE" "$@"
```

## Design Rules

- Keep the wrapper linear and readable; avoid helper functions unless the shim genuinely needs them.
- Mount home-directory state only when the tool needs config, credentials, or caches.
- Prefer wildcard env forwarding such as `-e AWS_*` when the underlying CLI already depends on a family of env vars.
- Preserve transparent CLI behavior by passing `"$@"` unchanged.
- Choose a pinned image unless there is a strong reason to use `latest`.

## Change Checklist

1. Add the shim to the fixed install list in `scripts/install-shimmy.sh`.
2. Add exact argv tests in `scripts/test-shimmy.sh`.
3. Document the tool in `README.md`.
4. Keep executable bits on runnable shell files.
5. If the tool differs materially from existing shims, add a shim-specific skill folder under `../../shims/`.
