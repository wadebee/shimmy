# OPNsense read-only MCP image build

`Containerfile` receives the configured Python base through its required build
argument, builds the pinned read-only MCP server wheel, and uses
`opnsense-mcp` as the stdio entrypoint.
