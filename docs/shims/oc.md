# OpenShift oc Multi-Version Shim

## Upstream

- Upstream docs: https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html
- Shim images:
  - `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.18`
  - `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.20`
  - `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.22`

Each tag is a floating minor tag that tracks the latest patch release for that minor.

## Shimmy Usage

The primary entrypoint is the dispatcher shim:

```sh
export SHIMMY_OC_VERSION=4.20
oc version
```

- `SHIMMY_OC_VERSION` selects the OpenShift CLI minor track at runtime.
- Supported values in this repo:
  - `4.18`
  - `4.20`
  - `4.22`

The dispatcher maps `SHIMMY_OC_VERSION` to a version-specific shim:

- `4.18` -> `oc_4_18`
- `4.20` -> `oc_4_20`
- `4.22` -> `oc_4_22`

Each version-specific shim is also callable directly:

```sh
oc_4_20 version
```

## Environment

Dispatcher selector:

- `SHIMMY_OC_VERSION` (required for `oc`):
  - Value is `major.minor` (for example, `4.18`, `4.20`, `4.22`).
  - Future 5.x tracks can be added without changing the env var name.

Per-track image configuration:

- `SHIMMY_OC_4_18_IMAGE` – override `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.18`.
- `SHIMMY_OC_4_20_IMAGE` – override `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.20`.
- `SHIMMY_OC_4_22_IMAGE` – override `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.22`.

Pull policy (per track):

- `SHIMMY_OC_4_18_IMAGE_PULL=always` – force image pull for the 4.18 shim.
- `SHIMMY_OC_4_20_IMAGE_PULL=always`.
- `SHIMMY_OC_4_22_IMAGE_PULL=always`.

## Mounts

Each version-specific shim uses the shared Podman helper and mounts:

- `$PWD` -> `/work` read-write.
- `~/.kube` -> `/root/.kube` read-only when it exists.

Runtime platform:

- Linux -> `linux/amd64`.
- macOS -> `linux/arm64`.

## Smoke Tests

Shim config files for `shimmy test`:

- `oc_4_18.conf` – `smoke_arg=version`.
- `oc_4_20.conf` – `smoke_arg=version`.
- `oc_4_22.conf` – `smoke_arg=version`.

These smoke tests are client-only and validate that the CLI starts without requiring
cluster access.
