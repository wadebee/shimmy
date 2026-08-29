# Skopeo Shim

## Upstream

- Source repo README: <https://github.com/podman-container-tools/skopeo>
- Latest release: <https://github.com/podman-container-tools/skopeo/releases/latest>
- Selected release: <https://github.com/podman-container-tools/skopeo/releases/tag/v1.22.2>
- Installation docs: <https://github.com/podman-container-tools/skopeo/blob/main/install.md>
- Selected image catalog: <https://catalog.redhat.com/en/software/containers/ubi9/skopeo/61959869ce09ff98ccc36338>
- Shim image: `registry.access.redhat.com/ubi9/skopeo@sha256:577a988b42ae430f0f9d99bae5232b517ceaea6a7b884ec443fe8e636528e291` from `versions/1.22/image.conf` (contains Skopeo 1.22.2)

## Upstream README Summary

Skopeo is a command-line utility for inspecting, copying, deleting, and syncing
container images across registries, local directories, OCI layouts, container
archives, and related storage mechanisms. It performs most operations without
root privileges and without requiring a local container daemon.

## Top-Level Command Summary

- `skopeo inspect` - inspect image metadata before pulling an image.
- `skopeo copy` - copy images between registries, archives, directories, and OCI layouts.
- `skopeo delete` - delete an image from a repository.
- `skopeo sync` - sync images from one registry or source into another destination.
- `skopeo login` - authenticate to a registry.
- `skopeo logout` - remove registry authentication.

## Shimmy Usage

```sh
skopeo --version
skopeo inspect docker://registry.fedoraproject.org/fedora:latest
skopeo copy docker://quay.io/skopeo/stable dir:skopeo-image
```

Environment:

- `SHIMMY_SKOPEO_IMAGE` - override the container image.
- `SHIMMY_SKOPEO_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_SKOPEO_AUTH_SECRET` - mount a Podman secret containing a registry `auth.json`.
- `SHIMMY_HOST_CA_BUNDLE` - mount one absolute, readable host CA bundle
  read-only and set `SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem`.

Image runtime:

- The selected Red Hat UBI 9 image has no configured entrypoint and defaults
  to `/bin/bash`. The shim explicitly sets `/usr/bin/skopeo` as the container
  entrypoint before forwarding command arguments.
- The image runs with its effective root container user through the invoking
  user's rootless Podman engine. The shim adds no capabilities or privileged
  mode.
- `SHIMMY_SKOPEO_IMAGE` overrides must also provide `/usr/bin/skopeo`.

Mounts:

- `$PWD` -> `/work` read-write.
- The active invoking profile's valid, current `registries.conf` ->
  `/etc/containers/registries.conf.d/shimmy-profile.conf` read-only. A valid
  profile with no Shimmy activation omits this mount; mismatched, damaged,
  stale, unsafe, connection-overridden, or registry-overridden installed state
  fails closed.
- `SHIMMY_SKOPEO_AUTH_SECRET` -> `/run/secrets/skopeo-auth.json` read-only when set.
- `SHIMMY_HOST_CA_BUNDLE` -> `/tmp/shimmy-host-ca-bundle.pem` read-only
  when configured.

Forwarded environment:

- When `SHIMMY_SKOPEO_AUTH_SECRET` is set, the container receives `REGISTRY_AUTH_FILE=/run/secrets/skopeo-auth.json`.

Authentication:

The default shim does not mount host registry credentials. For private registry
access, create a Podman secret containing a `containers-auth.json` compatible
file and set `SHIMMY_SKOPEO_AUTH_SECRET` to that secret name:

```sh
auth_tmp=$(mktemp)
printf '{}\n' > "$auth_tmp"
podman login --authfile="$auth_tmp" registry.example.com
podman secret create registry-example-auth "$auth_tmp"
rm "$auth_tmp"

SHIMMY_SKOPEO_AUTH_SECRET=registry-example-auth \
  skopeo inspect docker://registry.example.com/project/image:tag
```

Registry redirects use containers/image `prefix`/replacement `location`
semantics. The logical `docker://` reference remains unchanged and there is no
configured upstream fallback. `shimmy catalog verify` uses this same runtime,
so it inherits the active profile policy automatically.

The policy mount does not provide credentials, install a corporate CA, or
change signature policy. Keep using the explicit auth secret above.
`SHIMMY_HOST_CA_BUNDLE` supplies one exact host file through Go's
`SSL_CERT_FILE` system-root discovery; it does not mount host trust directories
or weaken TLS verification. This setting can replace the normal public roots,
so provide a combined public and corporate bundle when both are required.
Registry-specific `certs.d` configuration and Skopeo's `--cert-dir` setting can
still take precedence.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `skopeo inspect` to compare the digests for these two image tags."
- Software dev: "Use `skopeo copy` to export this image into an OCI layout under the current directory."
- Platform engineer: "Use `skopeo sync` to mirror this public repository into an internal registry."
