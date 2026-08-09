# Tool catalog

`catalog.sh` discovers tools from `../../tools/*/tool.conf`; it must not grow a
central list of tool names, versions, or default mappings. Tool metadata is
the source of truth for install validation and each independent profile's
manifest.

See [tools](../../tools/CONTEXT.md) for the metadata contract.
