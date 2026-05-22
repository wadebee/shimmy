# Terraform Shim

## Upstream

- Source repo README: <https://github.com/hashicorp/terraform/blob/main/README.md>
- Latest release: <https://github.com/hashicorp/terraform/releases/latest>
- Docs: <https://developer.hashicorp.com/terraform/docs>
- Shim image: `docker.io/hashicorp/terraform:latest`

## Upstream README Summary

Terraform is an infrastructure as code tool for safely creating, changing, and versioning infrastructure. The upstream README describes Terraform's declarative configuration model, provider ecosystem, planning workflow, and collaboration model.

## Top-Level Command Summary

- `terraform init` - initialize providers, modules, and backend.
- `terraform validate` - validate configuration syntax and internal consistency.
- `terraform fmt` - rewrite configuration to canonical formatting.
- `terraform plan` - preview changes.
- `terraform apply` - apply planned changes.
- `terraform destroy` - destroy managed infrastructure.
- `terraform output` - read output values.
- `terraform state` - inspect and manipulate state.
- `terraform workspace` - manage workspaces.

## Shimmy Usage

```sh
terraform version
terraform init
terraform plan
```

Environment:

- `TF_IMAGE` - override the container image.
- `TF_IMAGE_PULL=always` - force pulling the configured image.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.aws` -> `/root/.aws` read-only when it exists.
- `~/.terraform.d/plugin-cache` -> `/root/.terraform.d/plugin-cache` when it exists.

Forwarded environment:

- `AWS_*`
- `TF_VAR_*`

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `terraform plan` to show what will change in my home lab DNS stack before I apply it."
- Software dev: "Run `terraform fmt` and `terraform validate`, then summarize any files that changed or validation errors."
- Platform engineer: "Use `terraform plan` output to identify creates, updates, deletes, and high-risk infrastructure changes."
