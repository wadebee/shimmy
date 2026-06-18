# Netcat Shim

## Upstream

- Ncat project page: <https://nmap.org/ncat/>
- Nmap source repo README: <https://github.com/nmap/nmap/blob/master/README.md>
- Latest Nmap/Ncat downloads: <https://nmap.org/download.html>
- Shim image: local build from `images/netcat_7_92/Containerfile`

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
- `SHIMMY_NETCAT_BASE_IMAGE` - override the Containerfile base image. Default: `registry.access.redhat.com/ubi9/ubi-minimal:latest`.

Local image behavior:

- Shimmy builds `localhost/shimmy-netcat-7_92:<context-hash>-<platform>` from `images/netcat_7_92/Containerfile`.
- The image installs the `nmap-ncat` package.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `netcat 192.168.1.20 445` to check whether NAS client `nas-01` is accepting SMB connections."
- Software dev: "Use `netcat 127.0.0.1 8080` to send a raw HTTP request to local API client `api-dev` and show the response headers."
- Platform engineer: "Use `netcat 198.51.100.25 443` to verify whether service client `edge-api-01` is reachable from inside this project environment."
