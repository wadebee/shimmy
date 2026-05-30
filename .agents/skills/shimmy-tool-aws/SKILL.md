---
name: shimmy-tool-aws
description: Guidance for using, changing, testing, and troubleshooting the AWS CLI shim in this repository, including AWS credential mounts, AWS env forwarding, and non-mutating AWS CLI smoke checks.
---

# AWS Shim

Use this skill when working with `shims/aws`, its tests, its docs, or AWS CLI usage through Shimmy.

## Files

- Runtime shim: `../../../shims/aws`
- User docs: `../../../docs/shims/aws.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_MODE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: `public.ecr.aws/aws-cli/aws-cli:2.31.21`
- Runtime image override: `AWS_IMAGE`
- Documented/conventional image override: `SHIMMY_AWS_IMAGE`
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
3. Reconcile the `AWS_IMAGE` vs `SHIMMY_AWS_IMAGE` mismatch deliberately before changing AWS image override behavior.
4. Keep the wrapper minimal and pass `"$@"` directly to the container image.
5. Use non-mutating smoke checks such as `aws --version` or read-only AWS calls such as `aws sts get-caller-identity` when credentials are intentionally available.
6. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
7. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/aws --version`
- Expected output contains `aws-cli/`
- Keep exact argument and mount behavior covered in `../../../scripts/test-shimmy.sh`.

## Learning Guidance

- Capture AWS-specific lessons here when they affect credential discovery, read-only mounts, env forwarding, regions, profiles, SSO, or container image behavior.
- Promote reusable Shimmy design lessons to `../shimmy-create/SKILL.md` under `Learning Guidance`.
