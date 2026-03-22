---
name: shimmy-terraform-shim
description: Guidance for using  the Terraform shim in this repository. Use when changing shims/terraform, its tests, or Terraform-specific mounts and env forwarding behavior.
---

# Terraform Shim

Use this skill when the task makes use of the Terraform cli.

## Files

- Runtime shim: `../../../shims/terraform`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Docs: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Current Behavior

- Default image: `docker.io/hashicorp/terraform:latest`
- Pull override: `TF_IMAGE_PULL=always`
- Runtime mode: interactive via `podman run --rm -it`
- Mounts `$PWD` to `/work`
- Mounts `$HOME/.aws` to `/root/.aws:ro` when present
- Mounts `$HOME/.terraform.d/plugin-cache` to `/root/.terraform.d/plugin-cache` when present
- Forwards `AWS_*` and `TF_VAR_*`

## Change Rules

1. Preserve both optional home-directory mounts unless the task explicitly changes credential or cache handling.
2. Treat `TF_VAR_*` as the current contract; if you change it, update tests and docs deliberately.
3. Keep exact argument tests in sync with runtime behavior.
4. Update README examples and env var documentation whenever defaults or mounts change.
5. Keep the shim executable.
