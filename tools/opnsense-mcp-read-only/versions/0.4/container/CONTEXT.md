# OPNsense read-only MCP image build

`Containerfile` builds and installs the pinned read-only MCP server wheel, then
uses `opnsense-mcp` as the stdio entrypoint.
