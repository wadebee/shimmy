# Shared library

Library modules are sourced by commands and tool runtimes. Keep modules narrow;
do not add tool-specific behavior here.

## Child contexts

- [catalog](catalog/CONTEXT.md)
- [common helpers](common/CONTEXT.md)
- [profiles](profile/CONTEXT.md)
- [runtime](runtime/CONTEXT.md)
- [startup](startup/CONTEXT.md)
- [network information](netinfo/CONTEXT.md)
- [installation lifecycle](install/CONTEXT.md)
- [update lifecycle](update/CONTEXT.md)

The public `commands/netinfo.sh` entrypoint sources the host-network
implementation from `netinfo/`.
