## Scope

This directory contains authoring guidance for the Shimmy AWS CLI shim.

## Instructions

- Read `SKILL.md` here before editing the runtime shim.
- Shared repo rules live in `../../references/docs/shimmy-project-prompt.md-prompt.md`.
- The runtime file is `../../../shims/aws`.
- Preserve `AWS_IMAGE`, `AWS_IMAGE_PULL`, the `$PWD` mount, the optional `~/.aws` read-only mount, and `AWS_*` forwarding unless the task changes those behaviors on purpose.
- Update `../../../scripts/test-shimmy.sh` and `../../../README.md` with any runtime change.
- Keep runnable shell files executable.
