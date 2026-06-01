# gdrive Shim

## Upstream

- Source repo README: <https://github.com/isaacphi/mcp-gdrive/blob/master/README.md>
- Latest release: <https://github.com/isaacphi/mcp-gdrive/releases/latest>
- Manual: <https://github.com/isaacphi/mcp-gdrive#readme>
- Shim image: `docker.io/mcp/gdrive:latest`

## Upstream README Summary

gdrive is an MCP (Model Context Protocol) server for interacting with Google Drive and Google Sheets. It allows AI assistants and other MCP clients to perform operations on Google Drive files and Sheets spreadsheets through a standardized interface.

## Top-Level Command Summary

The container entrypoint starts the MCP server directly:

- `gdrive` - start the stdio MCP server through Podman.

The server is meant to be launched by an MCP-compatible client. It requires Google Cloud OAuth credentials before it can connect.

## Shimmy Usage

```sh
# Run gdrive in auth mode to set up credentials
gdrive auth

# Run gdrive as an MCP server (default mode)
gdrive
```

Environment:

- `SHIMMY_GDRIVE_IMAGE` - override the container image.
- `SHIMMY_GDRIVE_IMAGE_PULL=always` - force pulling the configured image.
- `GDRIVE_CREDS_DIR` - directory for OAuth credentials (defaults to user config)
- `CLIENT_ID` - OAuth Client ID from Google Cloud
- `CLIENT_SECRET` - OAuth Client Secret from Google Cloud

Mounts:

- `$PWD` -> `/work` read-write.
- For OAuth credentials: `-v /path/to/gcp-oauth.keys.json:/gcp-oauth.keys.json`
- For credential storage: `-v mcp-gdrive:/gdrive-server` (as shown in Docker Hub examples)

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `gdrive` to list all files in my Google Drive folder."
- Software dev: "Use `gdrive` to read data from a Google Sheet for my application."
- Platform engineer: "Use `gdrive` to backup configuration files to Google Drive."