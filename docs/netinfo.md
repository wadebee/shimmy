# Shimmy Netinfo

`shimmy netinfo` prints the current shell's network perspective on Linux and
macOS. It is a local diagnostic command, not a Podman-backed shim, because the
first question is usually what the shell VM, container, or host can see before
another container is started. From a source checkout, run it as `./shimmy
netinfo`; after installation, activated shells can run `shimmy netinfo` from any
directory.

## Usage

```sh
shimmy netinfo
shimmy netinfo --target 192.168.1.1
shimmy netinfo --host-name chromebook --host-prefix 24
shimmy netinfo --host-ip 192.168.1.2 --host-prefix 24
shimmy netinfo --host-lan 192.168.1.0/24
shimmy netinfo --format manifest
```

Options:

- `--target <host-or-ip>` adds a route perspective target. Repeatable. The
  default is `1.1.1.1`.
- `--host-name <name>` resolves a host-side DHCP/DNS name with the system
  resolver.
- `--host-ip <ipv4>` provides the host-side IPv4 address explicitly.
- `--host-prefix <bits>` derives a host-side LAN CIDR from `--host-name` or
  `--host-ip`.
- `--host-lan <cidr>` provides the host-side LAN CIDR explicitly.
- `--format human|manifest` controls output format.

## Crostini

Crostini usually places the Linux shell behind a ChromeOS-managed NAT layer.
The shell-visible address is commonly in a VM/container-side range such as
`100.115.92.0/24`. That address is useful for understanding the shell
perspective, but it is not the Chromebook's Wi-Fi or Ethernet LAN address.

Crostini shells also commonly return `penguin` from `hostname`. That is the
Linux container hostname, not the Chromebook's DHCP/DNS name. Do not pass
`$(hostname)` to `--host-name` in Crostini.

Preferred Crostini flow:

```sh
shimmy netinfo
shimmy netinfo --host-name <chromebook-router-dns-name> --host-prefix 24
```

Use the Chromebook's router/DNS name, DHCP reservation name, or another local
DNS name that resolves to the Chromebook's LAN address. If the network does not
register that name, use an explicit value:

```sh
shimmy netinfo --host-ip 192.168.1.42 --host-prefix 24
shimmy netinfo --host-lan 192.168.1.0/24
```

`netinfo` does not scan the LAN by default. It reports `host_lan=unknown` until
the host-side LAN is supplied or can be derived from a resolved host IP plus a
prefix. It intentionally does not promote Crostini shell interface addresses to
host-side LAN values.

## macOS and Other VM Hosts

The same host identity model works for Proxmox guests, macOS Podman VMs, and
other nested environments. On macOS hosts, `netinfo` uses native tools such as
`ifconfig`, `netstat`, `route`, and `arp` rather than Linux `iproute2`. When the
shell appears to be the real host, `netinfo` can infer `host_ipv4` and
`host_lan` from the default route interface. In VM or container-like
environments, it keeps host-side values unknown until you provide them. Use a
DNS name when the network maintains one:

```sh
shimmy netinfo --host-name dev-vm-01.home.arpa --host-prefix 24
```

If DNS is not available or not stable, pass the LAN explicitly:

```sh
shimmy netinfo --host-lan 10.10.20.0/24
```

## Manifest Output

Use `--format manifest` for automation:

```text
perspective=shell
environment=crostini_probable
shell_hostname=penguin
host_name=chromebook-home
host_name_resolution=resolved
host_ipv4=192.168.1.42
host_lan=192.168.1.0/24
host_resolution_confidence=high
route_target=1.1.1.1 via 100.115.92.1 dev eth0 src 100.115.92.205
```
