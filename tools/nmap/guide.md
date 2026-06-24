# Nmap Shim

## Upstream

- Source repo README: <https://github.com/nmap/nmap/blob/master/README.md>
- Latest release downloads: <https://nmap.org/download.html>
- Nmap docs: <https://nmap.org/book/man.html>
- Shim image: `docker.io/instrumentisto/nmap:7.98-r2`

## Upstream README Summary

Nmap is a network discovery and security auditing tool. The upstream project provides host discovery, port scanning, service and version detection, OS detection, scripting through NSE, and related tools such as Ncat.

## Top-Level Command Summary

Nmap is option-oriented rather than subcommand-oriented. Common usage patterns:

- `nmap IPv4` - scan common ports on a target.
- `nmap -sn IPv4_CIDR` - host discovery without port scanning.
- `nmap -sT IPv4` - TCP connect scan.
- `nmap -sV IPv4` - service/version detection.
- `nmap --script NAME IPv4` - run NSE scripts.

## Shimmy Usage

```sh
nmap --version
nmap 198.51.100.10
SHIMMY_NMAP_LAN_SCAN=1 nmap -sn 192.168.1.0/24
```

Environment:

- `SHIMMY_NMAP_IMAGE` - override the container image.
- `SHIMMY_NMAP_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_NMAP_NETWORK` - pass `--network <value>` to Podman.
- `SHIMMY_NMAP_LAN_SCAN=1` - opt into host networking plus raw/network capabilities.
- `SHIMMY_PODMAN_PRIVILEGED=1` - add Podman `--privileged` as an explicit last-resort opt-in.
- `SHIMMY_PODMAN_PRIVILEGED_CONNECTION` - rootful Podman connection used only when `SHIMMY_PODMAN_PRIVILEGED=1`; when unset, Shimmy uses a `<default-connection>-root` companion connection if Podman provides one.
- `SHIMMY_NMAP_PRIVILEGED=1` - pass Nmap `--privileged`.
- `SHIMMY_NMAP_PRIVILEGED=0` - pass Nmap `--unprivileged` for rootless/non-raw probing.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

Notes:

- Containerized scan behavior can differ from host-installed Nmap for raw socket, interface, and host network access.
- On macOS, Podman runs inside a Linux VM, so LAN visibility can differ from native macOS scans.
- On rootless Podman, `nmap -sn` raw host discovery requires explicit approval for `SHIMMY_PODMAN_PRIVILEGED=1`; do not make it a default. Shimmy keeps the normal Podman default connection unchanged and routes only the approved privileged invocation through `SHIMMY_PODMAN_PRIVILEGED_CONNECTION`. If the privileged connection still cannot see the physical LAN, use a native host Nmap or another network perspective. For a known host or narrow subnet where TCP reachability is enough, prefer `nmap -sT -Pn -p PORTS IPv4_OR_CIDR`.

## Quick-Start Prompts

- Home labber: "Use `SHIMMY_NMAP_LAN_SCAN=1 nmap -sn 192.168.1.0/24` to discover active lab clients, including names such as `nas-01` or `printer-01` when the scan output provides them."
- Software dev: "Use `nmap -sT -Pn 127.0.0.1` to verify which ports local integration client `dev-stack` exposes."
- Platform engineer: "Use `nmap -sV 198.51.100.25` against staging client `edge-api-01` and summarize detected services and versions."
