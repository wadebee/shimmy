# Netcat Shim

## Upstream

- Ncat project page: <https://nmap.org/ncat/>
- Nmap source repo README: <https://github.com/nmap/nmap/blob/master/README.md>
- Latest Nmap/Ncat downloads: <https://nmap.org/download.html>
- Shim image: local build from `images/netcat/Containerfile`

## Upstream README Summary

This shim provides Ncat, the Nmap project's modern Netcat-compatible tool. Ncat reads and writes data across networks, supports TCP and UDP, and is useful for debugging services, testing connectivity, proxying traffic, and simple client/server workflows.

## Top-Level Command Summary

Ncat is option-oriented rather than subcommand-oriented. Common usage patterns:

- `netcat HOST PORT` - open a TCP connection.
- `netcat -l PORT` - listen for inbound connections.
- `netcat -u HOST PORT` - use UDP.
- `netcat --ssl HOST PORT` - connect with TLS.
- `netcat --send-only` or `--recv-only` - constrain data direction.

## Shimmy Usage

```sh
netcat --help
netcat example.com 443
```

Environment:

- `NETCAT_IMAGE` - override the runtime image entirely.
- `NETCAT_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `NETCAT_IMAGE_PULL=always` - force pulling `NETCAT_IMAGE` when using an override.
- `NETCAT_BASE_IMAGE` - override the Containerfile base image. Default: `registry.access.redhat.com/ubi9/ubi-minimal:latest`.

Local image behavior:

- Shimmy builds `localhost/shimmy-netcat:<context-hash>-<platform>` from `images/netcat/Containerfile`.
- The image installs the `nmap-ncat` package.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `netcat` to check whether my NAS is accepting TCP connections on port 445."
- Software dev: "Use `netcat` to send a raw HTTP request to my local service and show the response headers."
- Platform engineer: "Use `netcat` to verify whether a service port is reachable from inside this project environment."
