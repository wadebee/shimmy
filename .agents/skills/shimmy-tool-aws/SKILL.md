---
name: shimmy-tool-aws
description: Canonical AWS via Shimmy workflow through the Shimmy runtime. Guidance for using, changing, testing, and troubleshooting the AWS CLI shim in this repository, including AWS credential mounts, AWS env forwarding, and non-mutating AWS CLI smoke checks.
---

# AWS Shim

Use this skill when working with the AWS tool, its tests, its docs, or AWS CLI usage through Shimmy.

## Files

- Kind metadata: `../../../tools/aws/tool.conf`
- Concrete runtime: `../../../tools/aws/versions/2.31/run.sh`
- User guide: `../../../tools/aws/guide.md`
- Tests: `../../../tools/aws/tests/aws.sh`
- Repository suite: `../../../tests/test.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `aws` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

For source validation, use `./commands/run-tool.sh aws --preview-shim --version`
or the concrete `tools/aws/versions/2.31/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: `public.ecr.aws/aws-cli/aws-cli:2.31.21`
- Image override: `SHIMMY_AWS_IMAGE`
- Pull override: `SHIMMY_AWS_IMAGE_PULL=always`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mounts:
  - `$PWD` to `/work`
  - `$HOME/.aws` to `/root/.aws:ro` when present
- Forwarded env: `AWS_*`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Preserve the read-only AWS config mount unless the task explicitly changes credential behavior.
2. Keep `AWS_*` forwarding aligned with AWS CLI native configuration.
3. Keep `SHIMMY_AWS_IMAGE` as the only Shimmy image override.
4. Keep the wrapper minimal and pass `"$@"` directly to the container image.
5. Use non-mutating smoke checks such as `aws --version` or read-only AWS calls such as `aws sts get-caller-identity` when credentials are intentionally available.
6. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
7. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh aws --version`
- Expected output contains `aws-cli/`
- Keep exact argument and mount behavior covered in `../../../tests/test.sh`.

## Learning Guidance

- Capture AWS-specific lessons here when they affect credential discovery, read-only mounts, env forwarding, regions, profiles, SSO, or container image behavior.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
