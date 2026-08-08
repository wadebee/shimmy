# Logmine Shim

## Upstream

- Source repo README: <https://github.com/kpfaulkner/gologmine>
- Shim image: local build from `versions/0.1/container/Containerfile`

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
- `SHIMMY_LOGMINE_BASE_IMAGE` - override the Containerfile base image. Default: `golang:1.22`.
- `SHIMMY_LOGMINE_VERSION` - override the gologmine source version. Default: `v0.1`.

Local image behavior:

- Shimmy builds `localhost/shimmy-logmine-0_1:<context-hash>-<platform>` from
  `versions/0.1/container/Containerfile`.

Mounts:

- `$PWD` -> `$PWD` read-write.
- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`
