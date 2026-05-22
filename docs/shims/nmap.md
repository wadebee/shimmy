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

- `nmap TARGET` - scan common ports on a target.
- `nmap -sn CIDR` - host discovery without port scanning.
- `nmap -sT TARGET` - TCP connect scan.
- `nmap -sV TARGET` - service/version detection.
- `nmap --script NAME TARGET` - run NSE scripts.

## Shimmy Usage

```sh
nmap --version
nmap scanme.nmap.org
SHIMMY_NMAP_LAN_SCAN=1 nmap -sn 192.168.1.0/24
```

Environment:

- `NMAP_IMAGE` - override the container image.
- `NMAP_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_NMAP_NETWORK` - pass `--network <value>` to Podman.
- `SHIMMY_NMAP_LAN_SCAN=1` - opt into host networking plus raw/network capabilities.
- `SHIMMY_NMAP_PRIVILEGED=1` - add `--privileged` as an explicit last-resort opt-in.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

Notes:

- Containerized scan behavior can differ from host-installed Nmap for raw socket, interface, and host network access.
- On macOS, Podman runs inside a Linux VM, so LAN visibility can differ from native macOS scans.

## Quick-Start Prompts

- Home labber: "Use `nmap` to discover which hosts are up on my lab subnet and summarize likely device roles."
- Software dev: "Use `nmap -sT -Pn` to verify which ports my local integration stack exposes."
- Platform engineer: "Use `nmap -sV` against a staging endpoint and summarize detected services and versions."
