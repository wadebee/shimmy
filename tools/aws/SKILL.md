---
name: shimmy-tool-aws
description: Guidance for using, changing, testing, and troubleshooting the AWS CLI shim in this repository, including AWS credential mounts, AWS env forwarding, and non-mutating AWS CLI smoke checks.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# AWS Shim

Use this skill when working with the AWS tool, its tests, its docs, or AWS CLI usage through Shimmy.

## AI Agent Evidence Order

1. If the installed wrapper's safe outer-command prefix is already approved,
   run the actual requested operation with escalation on the first attempt. Do
   not first run a sandboxed Podman call or a version smoke.
2. Treat a sandbox-only unreachable, unknown, socket-denied, or
   `operation not permitted` result as `unverified from the sandbox`, not as an
   inactive profile. Retry the same wrapper operation through
   `shimmy-escalation` before profile inspection or fallback.
3. Use `shimmy-init` only if the escalated wrapper still proves a
   profile-affinity, engine, connection, or registry-projection failure. Never
   activate a profile automatically from sandbox-only evidence.
4. Approval scope: require the exact non-mutating AWS command. Do not persist a
   broad `aws` prefix because the wrapper forwards credentials and AWS commands
   can mutate remote resources.

## Files

- Tool metadata: `tools/aws/tool.conf`
- Concrete runtime: `tools/aws/versions/2.31/run.sh`
- User guide: `tools/aws/guide.md`
- Tests: `tools/aws/tests/aws.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `aws` normally
and inspect the invoking profile with `shimmy profile status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate <name>` command. Running containers
require separate explicit confirmation before adding `--stop-running`. Shimmy's
control plane owns shared and isolated engine lifecycle; a missing recorded
machine is not recreated or adopted. Agents never run direct Podman machine
lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To inspect a named profile, use its
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>`.

For source validation, use `./commands/run-tool.sh aws --preview-shim --version`
or the concrete `tools/aws/versions/2.31/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: `public.ecr.aws/aws-cli/aws-cli@sha256:40033dc921634b1073094712ea8237869bc857cd7ddc2571896ec9b14ef97ae8` from version-owned `image.conf`
- Image override: `SHIMMY_AWS_IMAGE`
- Pull override: `SHIMMY_AWS_IMAGE_PULL=always`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mounts:
  - `$PWD` to `/work`
  - `$HOME/.aws` to `/root/.aws:ro` when present
- Forwarded env: `AWS_*`
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

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
- Keep exact argument and mount behavior covered in `tests/test.sh`.

## Learning Guidance

- Capture AWS-specific lessons here when they affect credential discovery, read-only mounts, env forwarding, regions, profiles, SSO, or container image behavior.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
