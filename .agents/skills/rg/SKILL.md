---
name: shimmy-rg-shim
description: Guidance for using  the ripgrep shim in this repository. Use when changing shims/rg, its tests, or ripgrep-specific image and stdin behavior.
---

# ripgrep Shim

Use this skill when the task makes use of the ripgrep cli.

## Files

- Runtime shim: `../../../shims/rg`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Docs: `../../../README.md`
- Shared prompt: `../../references/docs/prompt-shimmy-project.md-prompt.md`

## Current Behavior

- Default image in the shim: `docker.io/vszl/ripgrep:latest`
- Pull override: `RG_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mounts `$PWD` to `/work`
- Does not add extra mounts
- Does not forward extra env var families

## Change Rules

1. Reconcile the image mismatch deliberately before changing ripgrep defaults.
2. Keep ripgrep as a filter-style shim with `-i`, not `-it`, unless the task explicitly changes terminal behavior.
3. Keep exact argument tests in sync with runtime behavior.
4. Update README examples and image documentation whenever defaults change.
5. Keep the shim executable.
