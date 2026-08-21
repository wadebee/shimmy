# Shimmy network inspection

`shimmy admin network` reports the active profile's host, Podman machine, and
container network perspectives. It is read-only and is available only through
an installed profile launcher.

## Usage

```sh
shimmy admin network
shimmy admin network --target 192.168.1.1
shimmy admin network --host-name chromebook --host-prefix 24
shimmy admin network --host-ip 192.168.1.2 --host-prefix 24
shimmy admin network --host-lan 192.168.1.0/24
shimmy admin network --format manifest
```

- `--target <host-or-ip>` adds a route target and may be repeated. The default
  is `1.1.1.1`.
- `--host-name <name>` resolves a host-side DHCP or DNS name.
- `--host-ip <ipv4>` supplies the host-side address explicitly.
- `--host-prefix <bits>` derives a LAN from `--host-name` or `--host-ip`.
- `--host-lan <cidr>` supplies the LAN directly.
- `--format human|manifest` selects output; human is the default.

## Nested hosts

Crostini, Podman machines, and other VMs often expose only a NAT-side address.
That address describes the shell or VM, not the physical host's LAN identity.
In Crostini, `penguin` is normally the Linux container hostname, not the
Chromebook's router name. Supply the Chromebook's DHCP/DNS name or an explicit
host address or LAN:

```sh
shimmy admin network --host-name chromebook-home --host-prefix 24
shimmy admin network --host-lan 192.168.1.0/24
```

The command does not scan a LAN. It keeps uncertain host-side values unknown
instead of promoting nested-interface addresses. Use the manifest format when
another command needs stable key/value evidence.
