---
name: shimmy-tool-terraform
description: Guidance for using, changing, testing, and troubleshooting the Terraform shim in this repository, including AWS credential mounts, plugin-cache mounts, TF_VAR forwarding, and plan-first validation.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Terraform Shim

Use this skill when working with the Terraform tool, its tests, its docs, or Terraform usage through Shimmy.

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
4. Approval scope: require the exact Terraform command and arguments. Keep
   `fmt`, `validate`, and reviewed `plan` approvals separate from any explicit
   `apply` or `destroy` authorization; never persist a broad prefix.

## Files

- Tool metadata: `tools/terraform/tool.conf`
- Concrete runtime: `tools/terraform/versions/1.15/run.sh`
- User guide: `tools/terraform/guide.md`
- Tests: `tools/terraform/tests/terraform.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `terraform` normally
and inspect the invoking profile with `shimmy profile status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate <name>` command. Running containers
require separate explicit confirmation before adding `--stop-running`. A missing
machine must be provisioned by the user in a normal shell with the exact
`podman machine init shimmy-<profile>` guidance; agents never run direct Podman
machine lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To inspect a named profile, use its
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>`.

For source validation, use `./commands/run-tool.sh terraform --preview-shim version`
or the concrete `tools/terraform/versions/1.15/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: `docker.io/hashicorp/terraform@sha256:adae45661e45d3c88beef071ee1277b4621cea73517aae7f0844657c8e85f641` from version-owned `image.conf`
- Image override: `SHIMMY_TF_IMAGE`
- Pull override: `SHIMMY_TF_IMAGE_PULL=always`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mounts:
  - `$PWD` to `/work`
  - `$HOME/.aws` to `/root/.aws:ro` when present
  - `$HOME/.terraform.d/plugin-cache` to `/root/.terraform.d/plugin-cache` when present
- Forwarded env: `AWS_*`, `TF_VAR_*`
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Preserve the optional AWS and Terraform plugin-cache mounts unless the task explicitly changes credential or cache behavior.
2. Treat `TF_VAR_*` forwarding as the current contract; update docs and tests deliberately if it changes.
3. Prefer `terraform fmt`, `terraform validate`, and `terraform plan` before any apply-style workflow.
4. Do not run `terraform apply` or `terraform destroy` unless the user explicitly asks for that operation and the plan has been reviewed.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh terraform version`
- Low-risk workflow checks: `terraform fmt -check`, `terraform validate`, and `terraform plan` when project context supports them.

## Learning Guidance

- Capture Terraform-specific lessons here when they affect credential mounts, plugin caching, provider behavior, env forwarding, state safety, or apply/destroy approval boundaries.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
