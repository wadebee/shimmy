# Management commands

These executable entrypoints implement the `shimmy` management surface. They
parse command arguments and orchestrate shared modules; reusable behavior
belongs in `../core/`.

## Key files

- `install.sh` manages profile installation and removal.
- `dispatch-tool.sh` dispatches stable installed tool commands to profiles.
- `run-tool.sh` resolves tool metadata and a concrete version.
- `status.sh`, `update.sh`, `skills.sh`, `activate.sh`, and `netinfo.sh` retain
  their corresponding public capabilities.

## Related contexts

- [shared core](../core/CONTEXT.md)
- [tool metadata](../tools/CONTEXT.md)
- [tests](../tests/CONTEXT.md)
