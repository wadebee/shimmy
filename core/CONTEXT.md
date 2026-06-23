# Shared core

Core modules are sourced by commands and tool runtimes. Keep modules narrow;
do not add tool-specific behavior here.

## Child contexts

- [catalog](catalog/CONTEXT.md)
- [common helpers](common/CONTEXT.md)
- [profiles](profile/CONTEXT.md)
- [runtime](runtime/CONTEXT.md)
- [startup](startup/CONTEXT.md)

`netinfo` remains invoked through `commands/netinfo.sh` until its host-probing
functions are split into sourceable modules.
