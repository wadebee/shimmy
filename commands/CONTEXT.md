# Management commands

These executable entrypoints implement the `shimmy` management surface. They
parse command arguments and orchestrate shared modules; reusable behavior
belongs in `../lib/`.

## Key files

- `install.sh` manages profile installation and removal.
- `dispatch-tool.sh` dispatches stable installed tool commands to profiles.
- `run-tool.sh` resolves tool metadata and a concrete version.
- `agent-preflight.sh` derives non-mutating approval smoke commands from concrete-version metadata.
- `status.sh` reads concrete-version status metadata; `update.sh`, `skills.sh`,
  `activate.sh`, and `netinfo.sh` retain their corresponding public capabilities.

## Related contexts

- [shared library](../lib/CONTEXT.md)
- [tool metadata](../tools/CONTEXT.md)
- [tests](../tests/CONTEXT.md)
