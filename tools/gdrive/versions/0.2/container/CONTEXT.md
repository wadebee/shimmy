# Google Drive MCP image build

`Containerfile` receives the configured Node base through its required build
argument, builds the pinned `isaacphi/mcp-gdrive` revision with production
dependencies, and exposes the MCP stdio entrypoint.
