# OPNsense admin MCP image build

`Containerfile` receives the configured Python base through its required build
argument and builds the pinned admin MCP server revision. `entrypoint.sh`
writes a permission-restricted runtime config before starting the server.
