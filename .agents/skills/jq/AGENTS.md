## Scope

This directory contains authoring guidance for the Shimmy jq shim.

## Instructions

- Read `SKILL.md` here before editing the runtime shim.
- Read `../../../CONTRIBUTING.md` for repo-wide contributor guidance.
- Shared repo rules live in `../../../docs/prompt-shimmy-project.md`.
- The runtime file is `../../../shims/jq`.
- Preserve `JQ_IMAGE`, `JQ_IMAGE_PULL`, the `$PWD` mount, and non-interactive `-i` behavior unless the task explicitly changes them.
- Update `../../../scripts/test-shimmy.sh` and `../../../README.md` with any runtime change.
- Keep runnable shell files executable.
