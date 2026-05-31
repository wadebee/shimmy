---
name: shimmy-tool-terraform
description: Guidance for using, changing, testing, and troubleshooting the Terraform shim in this repository, including AWS credential mounts, plugin-cache mounts, TF_VAR forwarding, and plan-first validation.
---

# Terraform Shim

Use this skill when working with `shims/terraform`, its tests, its docs, or Terraform usage through Shimmy.

## Files

- Runtime shim: `../../../shims/terraform`
- User docs: `../../../docs/shims/terraform.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_PROFILE_ACTIVE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: `docker.io/hashicorp/terraform:latest`
- Image override: `SHIMMY_TF_IMAGE`
- Pull override: `SHIMMY_TF_IMAGE_PULL=always`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mounts:
  - `$PWD` to `/work`
  - `$HOME/.aws` to `/root/.aws:ro` when present
  - `$HOME/.terraform.d/plugin-cache` to `/root/.terraform.d/plugin-cache` when present
- Forwarded env: `AWS_*`, `TF_VAR_*`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Preserve the optional AWS and Terraform plugin-cache mounts unless the task explicitly changes credential or cache behavior.
2. Treat `TF_VAR_*` forwarding as the current contract; update docs and tests deliberately if it changes.
3. Prefer `terraform fmt`, `terraform validate`, and `terraform plan` before any apply-style workflow.
4. Do not run `terraform apply` or `terraform destroy` unless the user explicitly asks for that operation and the plan has been reviewed.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/terraform version`
- Low-risk workflow checks: `terraform fmt -check`, `terraform validate`, and `terraform plan` when project context supports them.

## Learning Guidance

- Capture Terraform-specific lessons here when they affect credential mounts, plugin caching, provider behavior, env forwarding, state safety, or apply/destroy approval boundaries.
- Promote reusable Shimmy design lessons to `../shimmy-create/SKILL.md` under `Learning Guidance`.
