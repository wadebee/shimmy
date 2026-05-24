# OPNsense MCP Server Shim

## Upstream

- Source repo README: <https://github.com/lucamarien/opnsense-mcp-server>
- PyPI package: <https://pypi.org/project/opnsense-mcp-server/>
- Docker image: `docker.io/uhlenheide/opnsense-mcp-server`

## Upstream README Summary

OPNsense MCP Server is a stdio Model Context Protocol server for managing OPNsense firewalls through AI assistants. The upstream package exposes tools across system, firewall, network, DNS, DHCP, VPN, HAProxy, services, diagnostics, and security domains. It is read-only by default; write operations require `OPNSENSE_ALLOW_WRITES=true`.

## Top-Level Command Summary

The container entrypoint starts the MCP server directly:

- `opnsense-mcp-server` - start the stdio MCP server through Podman.

The server is meant to be launched by an MCP-compatible client. It requires OPNsense API configuration before it can connect.

## Shimmy Usage

Create Podman secrets for the OPNsense API key and secret:

```sh
printf 'paste your api key' | podman secret create opnsense_mcp_api_key -
printf 'paste your api secret' | podman secret create opnsense_mcp_api_secret -
```

Run the shim from an MCP client with non-secret settings in the environment:

```sh
OPNSENSE_URL=https://192.168.1.1/api \
OPNSENSE_VERIFY_SSL=false \
OPNSENSE_ALLOW_WRITES=false \
SHIMMY_OPNSENSE_MCP_API_KEY=opnsense_mcp_api_key \
SHIMMY_OPNSENSE_MCP_API_SECRET=opnsense_mcp_api_secret \
opnsense-mcp-server
```

Environment:

- `SHIMMY_OPNSENSE_MCP_IMAGE` - override the container image. Default: `docker.io/uhlenheide/opnsense-mcp-server`.
- `SHIMMY_OPNSENSE_MCP_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_OPNSENSE_MCP_API_KEY` - Podman secret name mounted into the container as `OPNSENSE_API_KEY`.
- `SHIMMY_OPNSENSE_MCP_API_SECRET` - Podman secret name mounted into the container as `OPNSENSE_API_SECRET`.
- `OPNSENSE_URL` - OPNsense API base URL, including `/api`.
- `OPNSENSE_VERIFY_SSL` - set `false` for self-signed lab certificates.
- `OPNSENSE_ALLOW_WRITES` - keep `false` for read-only use; set `true` only for explicit change windows.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

MCP client example:

```json
{
  "mcpServers": {
    "opnsense": {
      "command": "opnsense-mcp-server",
      "env": {
        "OPNSENSE_URL": "https://192.168.1.1/api",
        "OPNSENSE_VERIFY_SSL": "false",
        "OPNSENSE_ALLOW_WRITES": "false",
        "SHIMMY_OPNSENSE_MCP_API_KEY": "opnsense_mcp_api_key",
        "SHIMMY_OPNSENSE_MCP_API_SECRET": "opnsense_mcp_api_secret"
      }
    }
  }
}
```

Notes:

- Store API key material in Podman secrets, not project files or MCP config JSON.
- Start with a dedicated read-only OPNsense API user.
- Leave `OPNSENSE_ALLOW_WRITES=false` unless you intentionally want firewall-changing tools available.
- The upstream documentation references `lucamarien/opnsense-mcp-server`; this Shimmy wrapper uses the actual image `uhlenheide/opnsense-mcp-server`.

## Quick-Start Prompts

Read-only prompts:

- Home labber: "Use the OPNsense MCP server to summarize WAN status, gateway health, DHCP leases, and DNS service status. Do not make changes."
- Software dev: "Inspect firewall aliases and NAT rules relevant to the dev subnet, then explain what inbound and outbound access is allowed. Read-only only."
- Platform engineer: "Review VPN, HAProxy, and firewall rule status for production-facing services and list risks or stale entries. Do not modify OPNsense."

Write-capable prompts:

- Home labber: "With OPNsense writes enabled, propose the exact firewall rule needed to allow this host to reach the NAS on TCP 2049. Wait for confirmation before applying."
- Software dev: "With OPNsense writes enabled, create a temporary alias for the integration-test clients and explain the rollback path before changing rules."
- Platform engineer: "With OPNsense writes enabled during the approved change window, add the requested HAProxy backend update and confirm whether OPNsense accepted the change."
