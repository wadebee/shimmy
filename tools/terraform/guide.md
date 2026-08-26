# Terraform Shim

## Upstream

- Source repo README: <https://github.com/hashicorp/terraform/blob/main/README.md>
- Latest release: <https://github.com/hashicorp/terraform/releases/latest>
- Docs: <https://developer.hashicorp.com/terraform/docs>
- Shim image: `docker.io/hashicorp/terraform@sha256:adae45661e45d3c88beef071ee1277b4621cea73517aae7f0844657c8e85f641` from `versions/1.15/image.conf`

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

- `SHIMMY_TF_IMAGE` - override the container image.
- `SHIMMY_TF_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_HOST_CA_BUNDLE` - mount one absolute, readable host CA bundle
  read-only and set `SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem`.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.aws` -> `/root/.aws` read-only when it exists.
- `~/.terraform.d/plugin-cache` -> `/root/.terraform.d/plugin-cache` when it exists.
- `SHIMMY_HOST_CA_BUNDLE` -> `/tmp/shimmy-host-ca-bundle.pem` read-only
  when configured.

Forwarded environment:

- `AWS_*`
- `TF_VAR_*`

`SSL_CERT_FILE` changes the Go system-root file used by Terraform core and
inherited provider processes. It can replace the normal public roots, so use a
combined public and corporate bundle when both are required. Provider-specific
CA configuration can still take precedence.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `terraform plan` to show what will change in my home lab DNS stack before I apply it."
- Software dev: "Run `terraform fmt` and `terraform validate`, then summarize any files that changed or validation errors."
- Platform engineer: "Use `terraform plan` output to identify creates, updates, deletes, and high-risk infrastructure changes."
