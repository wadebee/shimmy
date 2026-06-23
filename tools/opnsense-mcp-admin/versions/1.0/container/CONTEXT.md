# OPNsense admin MCP image build

`Containerfile` builds the pinned admin MCP server revision. `entrypoint.sh`
writes a permission-restricted runtime config from environment-provided
credentials before starting the server.
