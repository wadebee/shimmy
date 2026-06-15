# OpenShift CLI (oc) Shim

## Upstream

- Source repo README: <https://github.com/openshift/oc/blob/master/README.md>
- Official docs: <https://docs.openshift.com/>
- Shim images:
  - 4.18: `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.18`
  - 4.20: `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.20`
  - 4.22: `docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.22`

## Upstream README Summary

The OpenShift CLI (`oc`) exposes commands for managing and interacting with OpenShift clusters. It is built on top of `kubectl` and adds features specifically designed for OpenShift.

## Top-Level Command Summary

Common examples:

- `oc login` - log in to an OpenShift cluster.
- `oc project` - view or change the current active OpenShift project.
- `oc get pods` - list pods in the active namespace.
- `oc status` - show a high-level overview of the current project.

## Shimmy Usage

Set `SHIMMY_OC_VERSION` (e.g., `4.18`, `4.20`, or `4.22`) to select which minor version track of the CLI is active at runtime.

```sh
export SHIMMY_OC_VERSION=4.20
oc version --client
oc get pods
```

Environment:

- `SHIMMY_OC_VERSION` - **required** major.minor version identifier (e.g., `4.18`, `4.20`, `4.22`).
- `SHIMMY_OC_4_18_IMAGE`, `SHIMMY_OC_4_20_IMAGE`, `SHIMMY_OC_4_22_IMAGE` - override the container images.
- `SHIMMY_OC_4_18_IMAGE_PULL`, `SHIMMY_OC_4_20_IMAGE_PULL`, `SHIMMY_OC_4_22_IMAGE_PULL` - set to `always` to force pulling.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.kube` -> `/root/.kube` read-only when it exists.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `oc status` to show the state of my active OpenShift project and list any warnings or suggestions."
- Software dev: "Use `oc get pods` to list all running pods in the current namespace."
- Platform engineer: "Use `oc project` to switch the active context to `my-project`."
