# Tool catalog

`catalog.sh` discovers tools from `../../tools/*/tool.conf`; it must not grow a
central list of tool names, versions, or default mappings. Tool metadata is
the source of truth for install validation and each independent profile's
manifest.

Concrete-version lookup helpers resolve the version directory and its required
`image.conf`; schema validation and image lifecycle behavior remain in
`../runtime/image.sh`.

See `CONTRIBUTING.md`, `tools/<kind>/tool.conf`, and each concrete version's
`image.conf` for the metadata contract.
