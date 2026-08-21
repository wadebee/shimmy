# Host network information

`netinfo.sh` orchestrates the sourceable host-network implementation behind
installed `shimmy admin network`. Focused modules preserve POSIX behavior while
isolating request handling, IPv4/CIDR logic, platform discovery, and rendering.

## Files

- `request.sh` parses command inputs and validates explicit host values.
- `cidr.sh` provides IPv4, CIDR, netmask, and line-list helpers.
- `platform.sh` discovers host-network state on Linux and macOS.
- `render.sh` renders manifest and human output.
