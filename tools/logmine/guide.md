# Logmine Shim

## Upstream

- Source repo README: <https://github.com/kpfaulkner/gologmine>
- Shim image: local build from `versions/0.1/image.conf` and `container/`

## Top-Level Command Summary

- `logmine --help` - show usage.

## Shimmy Usage

```sh
logmine --help
```

Environment:

- `SHIMMY_LOGMINE_IMAGE` - override the runtime image entirely.
- `SHIMMY_LOGMINE_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `SHIMMY_LOGMINE_IMAGE_PULL=always` - force pulling `SHIMMY_LOGMINE_IMAGE` when using an override.
- `SHIMMY_LOGMINE_BASE_IMAGE` - override the configured base image. Default: `docker.io/library/golang@sha256:1cf6c45ba39db9fd6db16922041d074a63c935556a05c5ccb62d181034df7f02`.
- `SHIMMY_LOGMINE_VERSION` - override the gologmine source version. Default: `v0.1`.

Local image behavior:

- Shimmy builds `localhost/shimmy-logmine-0_1:<image-input-hash>-<platform>`
  from the version's `image.conf`, effective build arguments, and `container/`.

Mounts:

- `$PWD` -> `$PWD` read-write.
- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`
