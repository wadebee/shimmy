---
name: shimmy-aws-shim
description: Guidance for using  the AWS CLI shim in this repository. Use when changing shims/aws, its tests, or AWS-specific shim conventions such as credential mounts and AWS env forwarding.
---

# AWS Shim

Use this skill when the task makes use of the AWS CLI .

## Files

- Runtime shim: `../../../shims/aws`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Docs: `../../../README.md`
- Shared prompt: `../../references/docs/prompt-shimmy-project.md-prompt.md`

## Current Behavior

- Default image: `amazon/aws-cli:2.15.0`
- Pull override: `AWS_IMAGE_PULL=always`
- Runtime mode: interactive via `podman run --rm -it`
- Mounts `$PWD` to `/work`
- Mounts `$HOME/.aws` to `/root/.aws:ro` when present
- Forwards `AWS_*`

## Change Rules

1. Keep the wrapper minimal and pass `"$@"` directly to the container image.
2. Preserve the read-only AWS config mount unless the task explicitly changes credential behavior.
3. Keep exact argument tests in sync with the shim.
4. Update README examples and env var documentation whenever defaults or mounts change.
5. Keep the shim executable.
