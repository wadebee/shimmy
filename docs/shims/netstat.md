# Netstat Shim

## Upstream

- BusyBox project page: <https://busybox.net/>
- BusyBox source README: <https://git.busybox.net/busybox/tree/README>
- Latest BusyBox downloads: <https://busybox.net/downloads/>
- Shim image: `docker.io/instrumentisto/nmap:7.98-r2`

## Upstream README Summary

BusyBox combines many standard Unix utilities into a compact executable. This shim uses BusyBox `netstat` from the Nmap container image, so available flags match BusyBox behavior rather than the full GNU net-tools implementation.

## Top-Level Command Summary

netstat is option-oriented rather than subcommand-oriented. Common usage patterns:

- `netstat -rn` - show routing table with numeric addresses.
- `netstat -tuln` - show listening TCP and UDP sockets numerically.
- `netstat -p` - include process information when permissions allow it.
- `netstat --help` - show supported BusyBox options.

## Shimmy Usage

```sh
netstat --help
netstat -rn
SHIMMY_NETSTAT_LAN_VIEW=1 netstat -tuln
```

Environment:

- `NETSTAT_IMAGE` - override the container image.
- `NETSTAT_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_NETSTAT_NETWORK` - pass `--network <value>` to Podman.
- `SHIMMY_NETSTAT_LAN_VIEW=1` - opt into Podman host network visibility.
- `SHIMMY_NETSTAT_HOST_PID=1` - add `--pid host`.
- `SHIMMY_NETSTAT_PRIVILEGED=1` - add `--privileged` as an explicit last-resort opt-in.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

Notes:

- On macOS, `--network host` targets the Podman VM host namespace, not the macOS host's physical network namespace.

## Quick-Start Prompts

- Home labber: "Use `netstat -rn` to show the routing table visible from this containerized tool."
- Software dev: "Use `netstat -tuln` to confirm whether my local dev service is listening on the expected port."
- Platform engineer: "Use the Shimmy netstat LAN opt-in to inspect listening sockets and explain any visibility limits."
