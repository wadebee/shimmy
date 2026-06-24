# gdrive Shim

## Upstream

- Source repo README: <https://github.com/isaacphi/mcp-gdrive/blob/master/README.md>
- Current source ref: `5a94bdcb751975f9f6552d261da35314baf89c43`
- Manual: <https://github.com/isaacphi/mcp-gdrive#readme>
- Shim image: locally built `localhost/shimmy-gdrive-0_2:<context-hash>-<platform>` from `versions/0.2/container/Containerfile` and `isaacphi/mcp-gdrive`

## Upstream README Summary

gdrive is an MCP (Model Context Protocol) server for interacting with Google Drive and Google Sheets. It allows AI assistants and other MCP clients to perform operations on Google Drive files and Sheets spreadsheets through a standardized interface.

## Top-Level Command Summary

The container entrypoint starts the MCP server directly:

- `gdrive` - start the stdio MCP server through Podman.

The server is meant to be launched by an MCP-compatible client. It requires Google Cloud OAuth credentials before it can connect.

## Shimmy Usage

```sh
# First-time setup
mkdir -p "$HOME/.config/mcp-gdrive"
# Place your OAuth desktop-client JSON at:
# "$HOME/.config/mcp-gdrive/gcp-oauth.keys.json"

# Start the MCP server; first run opens the upstream browser auth flow
CLIENT_ID=... \
CLIENT_SECRET=... \
GDRIVE_CREDS_DIR="$HOME/.config/mcp-gdrive" \
gdrive
```

Environment:

- `CLIENT_ID` - OAuth Client ID from Google Cloud.
- `CLIENT_SECRET` - OAuth Client Secret from Google Cloud.
- `GDRIVE_CREDS_DIR` - host directory containing `gcp-oauth.keys.json` and storing `.gdrive-server-credentials.json`.
- `SHIMMY_GDRIVE_IMAGE` - override the runtime image instead of using the local source-built image.
- `SHIMMY_GDRIVE_IMAGE_PULL=always` - force pulling the configured override image.
- `SHIMMY_GDRIVE_IMAGE_BUILD=always` - rebuild the local source-built image.
- `SHIMMY_GDRIVE_AUTH_PORT` - host OAuth callback port for first-time auth; defaults to `3000`.
- `SHIMMY_GDRIVE_BASE_IMAGE` - override the Node base image for local builds.
- `SHIMMY_GDRIVE_SOURCE_REF` - override the `isaacphi/mcp-gdrive` git ref used for local builds.

Mounts:

- `$PWD` -> `/work` read-write.
- `GDRIVE_CREDS_DIR` -> same path in the container, read-write.

Ports:

- When `.gdrive-server-credentials.json` is missing, Shimmy publishes `127.0.0.1:${SHIMMY_GDRIVE_AUTH_PORT:-3000}:3000` for the upstream browser OAuth callback.
- Once credentials exist, no port is published for normal MCP stdio use.

Preflight:

- `CLIENT_ID`, `CLIENT_SECRET`, and `GDRIVE_CREDS_DIR` are required.
- `GDRIVE_CREDS_DIR` must exist.
- `GDRIVE_CREDS_DIR` must contain either `gcp-oauth.keys.json` for first-time auth or `.gdrive-server-credentials.json` for an already-authenticated setup.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `gdrive` to list all files in my Google Drive folder."
- Software dev: "Use `gdrive` to read data from a Google Sheet for my application."
- Platform engineer: "Use `gdrive` to backup configuration files to Google Drive."
