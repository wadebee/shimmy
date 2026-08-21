# Networking tools

Start with `shimmy admin network` to identify the active profile's host, VM,
and container perspectives. Then use `netcat` for a narrow connectivity probe
or `nmap` for discovery and service inventory.

## Network perspective

```sh
shimmy admin network --format manifest
shimmy admin network --host-lan 192.168.1.0/24
```

The management command is read-only and does not scan. In Crostini and other
nested environments, supply a real host DHCP/DNS name or LAN instead of
assuming the nested shell's interface is the physical LAN.

## Netcat

Use `netcat` when the question is whether a specific host and port are
reachable. The shim runs Ncat, mounts `$PWD` at `/work`, and uses the current
profile's Podman engine.

Examples:

```sh
netcat -vz 198.51.100.25 443
netcat -vz 127.0.0.1 15432
```

`SHIMMY_NETCAT_IMAGE`, `SHIMMY_NETCAT_IMAGE_BUILD=always`,
`SHIMMY_NETCAT_BASE_IMAGE`, and `SHIMMY_NETCAT_IMAGE_PULL=always` control the
version-owned local image. Network targets and listener modes require exact
authorization in agent environments.

## Nmap

Prefer a narrow TCP connect scan for known hosts:

```sh
nmap -sT -Pn -p 80,443 192.168.1.80
SHIMMY_NMAP_NETWORK=appnet nmap -sT -Pn -p 5432 10.88.0.30
```

LAN discovery, capabilities, rootful connections, and privileged execution are
never defaults. They require explicit scope and approval:

```sh
SHIMMY_NMAP_LAN_SCAN=1 nmap -sn -n 192.168.1.0/24
```

On macOS, scans run from the selected Podman machine and may see a different
network than a native host process. Use `SHIMMY_PODMAN_PRIVILEGED=1` only when
the user explicitly authorizes it and the narrower capability-based mode is
insufficient.

## Agent guardrails

- Specify exact hosts, ports, and network perspective.
- Prefer Netcat or a TCP connect scan before subnet discovery.
- Ask before LAN, raw-socket, rootful, or privileged operation.
- Preserve exact commands and distinguish timeout, refusal, DNS, engine, and
  sandbox failures.
- An approved wrapper operation does not authorize unrelated external writes
  or broader scans.
