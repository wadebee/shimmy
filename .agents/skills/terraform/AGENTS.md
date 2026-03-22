## Scope

This directory contains authoring guidance for the Shimmy Terraform shim.

## Instructions

- Read `SKILL.md` here before editing the runtime shim.
- Read `../../../CONTRIBUTING.md` for repo-wide contributor guidance.
- Shared repo rules live in `../../references/docs/prompt-shimmy-project.md-prompt.md`.
- The runtime file is `../../../shims/terraform`.
- Preserve `TF_IMAGE`, `TF_IMAGE_PULL`, the `$PWD` mount, the optional AWS and plugin-cache mounts, and the current env forwarding behavior unless the task explicitly changes them.
- Update `../../../scripts/test-shimmy.sh` and `../../../README.md` with any runtime change.
- Keep runnable shell files executable.
