## Scope

This directory contains authoring guidance for the Shimmy ripgrep shim.

## Instructions

- Read `SKILL.md` here before editing the runtime shim.
- Shared repo rules live in `../../references/docs/shimmy-project-prompt.md-prompt.md`.
- The runtime file is `../../../shims/rg`.
- Preserve `RG_IMAGE`, `RG_IMAGE_PULL`, the `$PWD` mount, and non-interactive `-i` behavior unless the task explicitly changes them.
- Reconcile the current image mismatch between `../../../shims/rg` and `../../../scripts/test-shimmy.sh` explicitly if you touch ripgrep defaults.
- Update `../../../scripts/test-shimmy.sh` and `../../../README.md` with any runtime change.
- Keep runnable shell files executable.
