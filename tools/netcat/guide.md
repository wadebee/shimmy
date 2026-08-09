# Netcat Shim

## Upstream

- Ncat project page: <https://nmap.org/ncat/>
- Nmap source repo README: <https://github.com/nmap/nmap/blob/master/README.md>
- Latest Nmap/Ncat downloads: <https://nmap.org/download.html>
- Shim image: local build from `versions/7.92/image.conf` and `container/`

## Upstream README Summary

This shim provides Ncat, the Nmap project's modern Netcat-compatible tool. Ncat reads and writes data across networks, supports TCP and UDP, and is useful for debugging services, testing connectivity, proxying traffic, and simple client/server workflows.

## Top-Level Command Summary

Ncat is option-oriented. Common usage patterns:

- `netcat IPv4 PORT` - open a TCP connection.
- `netcat -l PORT` - listen for inbound connections.
- `netcat -u IPv4 PORT` - use UDP.
- `netcat --ssl IPv4 PORT` - connect with TLS.
- `netcat --send-only` or `--recv-only` - constrain data direction.

## Shimmy Usage

```sh
netcat --help
netcat 198.51.100.10 443
```

Environment:

- `SHIMMY_NETCAT_IMAGE` - override the runtime image entirely.
- `SHIMMY_NETCAT_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `SHIMMY_NETCAT_IMAGE_PULL=always` - force pulling `SHIMMY_NETCAT_IMAGE` when using an override.
- `SHIMMY_NETCAT_BASE_IMAGE` - override the configured base image. Default: `registry.access.redhat.com/ubi9/ubi-minimal@sha256:dd334afa72444fa46238fcf9e6bd399245adf746378735348cf84b9dfdca38f1`.

Local image behavior:

- Shimmy builds `localhost/shimmy-netcat-7_92:<image-input-hash>-<platform>` from the version's `image.conf` and `container/` inputs.
- The image installs the `nmap-ncat` package.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `netcat 192.168.1.20 445` to check whether NAS client `nas-01` is accepting SMB connections."
- Software dev: "Use `netcat 127.0.0.1 8080` to send a raw HTTP request to local API client `api-dev` and show the response headers."
- Platform engineer: "Use `netcat 198.51.100.25 443` to verify whether service client `edge-api-01` is reachable from inside this project environment."
