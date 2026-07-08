# Skopeo Shim

## Upstream

- Source repo README: <https://github.com/containers/skopeo>
- Latest release: <https://github.com/containers/skopeo/releases/latest>
- Installation docs: <https://github.com/containers/skopeo/blob/main/install.md>
- Container image docs: <https://github.com/containers/image_build/tree/main/skopeo>
- Shim image: `quay.io/skopeo/stable:latest` (currently reports Skopeo 1.22.2)

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

Mounts:

- `$PWD` -> `/work` read-write.
- `SHIMMY_SKOPEO_AUTH_SECRET` -> `/run/secrets/skopeo-auth.json` read-only when set.

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

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `skopeo inspect` to compare the digests for these two image tags."
- Software dev: "Use `skopeo copy` to export this image into an OCI layout under the current directory."
- Platform engineer: "Use `skopeo sync` to mirror this public repository into an internal registry."
