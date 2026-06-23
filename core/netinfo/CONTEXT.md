# Host network information

`netinfo.sh` provides the sourceable host-network discovery and rendering
implementation for the public `commands/netinfo.sh` entrypoint. It currently
preserves the command's POSIX behavior while later segments separate its input
validation, CIDR, platform discovery, and output helpers.
