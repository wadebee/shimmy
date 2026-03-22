---
name: shimmy-jq-shim
description: Guidance for using  the jq shim in this repository. Use when changing shims/jq, its tests, or jq-specific image and stdin behavior.
---

# jq Shim

Use this skill when the task makes use of the jq cli.

## Files

- Runtime shim: `../../../shims/jq`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Docs: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../references/docs/prompt-shimmy-project.md-prompt.md`

## Current Behavior

- Default image: `docker.io/stedolan/jq:latest`
- Pull override: `JQ_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mounts `$PWD` to `/work`
- Does not add extra mounts
- Does not forward extra env var families

## Change Rules

1. Keep jq as a filter-style shim with `-i`, not `-it`, unless the task explicitly changes terminal behavior.
2. Keep the runtime wrapper minimal; do not add mounts or env forwarding without a clear tool requirement.
3. Keep exact argument tests in sync with runtime behavior.
4. Update README examples and image documentation whenever defaults change.
5. Keep the shim executable.
