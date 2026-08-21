# Shared library

Library modules are sourced by commands and tool runtimes. Keep modules narrow;
do not add tool-specific behavior here.

`profile/profile.sh` is the canonical XDG path resolver. It maps an absolute
`XDG_CONFIG_HOME`, or the `$HOME/.config` fallback, to independent arbitrary-
name profiles below `shimmy/profiles/<profile>` and validates schema-2 runtime
identity.

## Child contexts

- [catalog](catalog/CONTEXT.md)
- [AI-skill bundles](ai-skill/CONTEXT.md)
- [common helpers](common/CONTEXT.md)
- [profiles](profile/CONTEXT.md)
- [profile-local shims](shim/CONTEXT.md)
- [registry redirects](registries/CONTEXT.md)
- [runtime](runtime/CONTEXT.md)
- [startup](startup/CONTEXT.md)
- [network information](netinfo/CONTEXT.md)
- [installation lifecycle](install/CONTEXT.md)
- [update lifecycle](update/CONTEXT.md)
- [image verification](images/CONTEXT.md)

The installed `admin network` route sources the host-network implementation
from `netinfo/`.
