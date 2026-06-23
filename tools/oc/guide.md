# OpenShift CLI (oc) Multi-Version Shim

## Overview

The `oc` shim is the user-facing kind dispatcher for several concrete
OpenShift CLI version shims. When no selector is set, `oc` dispatches to the
catalog default version `oc_4_20`.

Supported minor tracks (initial set):

- `4.18` → `oc_4_18`
- `4.20` → `oc_4_20`
- `4.22` → `oc_4_22`

Future 5.x tracks can be added without changing the selector variable name.

## Commands

- `oc` - dispatcher that reads optional `SHIMMY_OC_VERSION` and execs the matching `oc_4_xx` shim.
- `oc_4_18`, `oc_4_20`, `oc_4_22` – version-specific shims that run a locally built `ose-cli` image for the corresponding minor track.

## Version Selection

Shimmy uses a version-agnostic selector:

- `SHIMMY_OC_VERSION` - optional, value is `major.minor` (for example, `4.18`, `4.20`, `4.22`).

Dispatcher behavior:

- If `SHIMMY_OC_VERSION` is unset or empty, `oc` uses the default `4.20` selector and execs `oc_4_20`.
- If `SHIMMY_OC_VERSION` is set to an unsupported value, `oc` prints an error listing the supported values and exits non-zero.
- For supported values, `oc` resolves the matching versioned shim in the same directory and `exec`s it.

Example:

```sh
oc version
SHIMMY_OC_VERSION=4.18 oc version
oc get pods -A
```

## Images, Local Builds, and Environment

Each minor track has its own image environment variables and local-build behavior:

- `oc_4_18`
  - `SHIMMY_OC_4_18_IMAGE` – optional override. When set, the shim runs this image directly.
  - `SHIMMY_OC_4_18_IMAGE_BUILD` – `auto` (default) or `always` when building the local image.
  - `SHIMMY_OC_4_18_BASE_IMAGE` – optional base image override for local builds.
- `oc_4_20`
  - `SHIMMY_OC_4_20_IMAGE` – optional override.
  - `SHIMMY_OC_4_20_IMAGE_BUILD` – `auto` (default) or `always`.
  - `SHIMMY_OC_4_20_BASE_IMAGE` – optional base image override for local builds.
- `oc_4_22`
  - `SHIMMY_OC_4_22_IMAGE` – optional override.
  - `SHIMMY_OC_4_22_IMAGE_BUILD` – `auto` (default) or `always`.
  - `SHIMMY_OC_4_22_BASE_IMAGE` – optional base image override for local builds.

When `SHIMMY_OC_4_xx_IMAGE` is **not** set, Shimmy uses a local image built from the corresponding version-local `container/Containerfile` context:

- `versions/4.18/container/Containerfile`
- `versions/4.20/container/Containerfile`
- `versions/4.22/container/Containerfile`

Each Containerfile uses an unqualified base image short name so that Podman can resolve it via `/etc/containers/registries.conf`. For example, `versions/4.20/container/Containerfile` defaults to:

- `ARG SHIMMY_OC_4_20_BASE_IMAGE=openshift4/ose-cli:4.20`

You can override the base image used for local builds by setting the corresponding `SHIMMY_OC_4_xx_BASE_IMAGE` environment variable; the versioned shim passes it to Podman as a `--build-arg`. If a local image for the same build context was already cached, set the matching `SHIMMY_OC_4_xx_IMAGE_BUILD=always` once to force a rebuild with the new base image. You can also customize your Podman `registries.conf` to control how the short name is resolved.

Runtime behavior for each versioned shim:

- Uses Shimmy's shared Podman helper for platform selection (`linux/amd64` on Linux, `linux/arm64` on macOS).
- Mounts `$PWD` to `/work` and sets `-w /work`.
- Adds `-it` only when stdin and stdout are terminals.
- Forwards `KUBECONFIG` into the container when it is set in the host environment.

Note: The shim does **not** automatically mount `$HOME/.kube`. Ensure that any paths referenced by `KUBECONFIG` are reachable inside the container (for example, under the current working directory or via your own volume mounts).

## Preview Mode

All versioned shims support Shimmy's `--preview-shim` behavior via the shared Podman helper:

```sh
oc --preview-shim version
SHIMMY_OC_VERSION=4.18 oc --preview-shim version
```

With `--preview-shim`, Shimmy prints the shell-quoted `podman run` command and exits without contacting the Podman engine, pulling images, or starting a container.

## Smoke Tests

The dispatcher and each versioned shim have corresponding config files used by `shimmy test`:

- `tool.conf`
- `versions/4.18/smoke.conf`
- `versions/4.20/smoke.conf`
- `versions/4.22/smoke.conf`

The dispatcher config uses preview mode and a non-secret selector pinned to the default track, so installed smoke tests can validate dispatch without contacting Podman:

- `smoke_env=SHIMMY_OC_VERSION=4.20`
- `smoke_arg=--preview-shim`
- `smoke_arg=version`

The versioned configs use a single-token smoke command:

- `smoke_arg=version`

Examples:

```sh
./shimmy install --shim oc
./shimmy install --shim oc@4.18
./shimmy test --shim oc
./shimmy test --shim oc_4_20
./shimmy test --shim oc_4_18
./shimmy test --shim oc_4_22
```

## Installation and Profiles

The oc shims are wired into Shimmy's catalog and installer:

- Supported kind: `oc`.
- Supported concrete versions: `oc_4_18`, `oc_4_20`, and `oc_4_22`.
- Default version: `oc_4_20`.
- `shimmy install --shim oc` installs the `oc` dispatcher and default `oc_4_20`.
- `shimmy install --shim oc@4.18` installs the `oc` dispatcher, default `oc_4_20`, and selected `oc_4_18`.

Examples:

```sh
# Install upstream profile and the default oc 4.20
./shimmy install --profile upstream --shim oc

# Install the 4.18 selector as an additional concrete version
./shimmy install --profile upstream --shim oc@4.18

# In an activated upstream shell, unset selector uses 4.20
eval "$(./shimmy activate --profile upstream)"
oc version
SHIMMY_OC_VERSION=4.18 oc version
```

`shimmy status` reports `oc` as an installed kind, the default version, and each installed version label. `shimmy update --shim oc --build` refreshes the dispatcher and installed `oc_4_xx` local images for the selected profile. `shimmy update --shim oc@4.18 --build` refreshes only the selected concrete version plus the required dispatcher.

## Extending to New Tracks

To add a new minor track in the future (for example, `5.1`):

- Add a version directory such as `versions/5.1/` with its local-build configuration and `SHIMMY_OC_5_1_IMAGE` / `SHIMMY_OC_5_1_IMAGE_BUILD` env vars.
- Add `versions/5.1/smoke.conf` with `shim_name=oc_5_1` and `smoke_arg=version`.
- Extend the `oc` dispatcher to map `SHIMMY_OC_VERSION=5.1` to `oc_5_1`.
- Update the catalog kind metadata, status, and update scripts to include the new concrete version.
- Update `tool.conf` only if the metadata default or dispatcher smoke version should change.
