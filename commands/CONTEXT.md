# Management commands

These executable entrypoints implement the installed `bin/shimmy` management
surface. The repository `install.sh` bootstrap invokes `install.sh` directly;
there is no repository launcher. Commands parse arguments and orchestrate
shared modules; reusable behavior belongs in `../lib/`.

## Key files

- `install.sh` installs or removes the enclosing canonical profile.
- `dispatch-tool.sh` dispatches a profile-local installed tool command.
- `run-tool.sh` resolves tool metadata and a concrete version.
- `agent-preflight.sh` derives non-mutating approval smoke commands from concrete-version metadata.
- `status.sh` reads enclosing-profile and concrete-version metadata;
  `update.sh`, `skills.sh`, and `netinfo.sh` retain their corresponding public
  capabilities.

Installed commands derive profile identity from their profile root and reject
profile and installation-location selectors. Shared skills are written only
to explicit external targets and are owned by the target manifest.

## Related contexts

- [shared library](../lib/CONTEXT.md)
- [tool metadata](../tools/CONTEXT.md)
- [tests](../tests/CONTEXT.md)
