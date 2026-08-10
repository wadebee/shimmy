---
name: shimmy-tool-terraform
description: Guidance for using, changing, testing, and troubleshooting the Terraform shim in this repository, including AWS credential mounts, plugin-cache mounts, TF_VAR forwarding, and plan-first validation.
---

# Terraform Shim

Use this skill when working with the Terraform tool, its tests, its docs, or Terraform usage through Shimmy.

## Files

- Kind metadata: `tools/terraform/tool.conf`
- Concrete runtime: `tools/terraform/versions/1.15/run.sh`
- User guide: `tools/terraform/guide.md`
- Tests: `tools/terraform/tests/terraform.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `terraform` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

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
