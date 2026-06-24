# Host network information

`netinfo.sh` orchestrates the sourceable host-network implementation for the
public `commands/netinfo.sh` entrypoint. Focused modules preserve the POSIX
behavior while isolating request handling, IPv4/CIDR logic, platform discovery,
and rendering.

## Files

- `request.sh` parses command inputs and validates explicit host values.
- `cidr.sh` provides IPv4, CIDR, netmask, and line-list helpers.
- `platform.sh` discovers host-network state on Linux and macOS.
- `render.sh` renders manifest and human output.
