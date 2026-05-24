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

## Quick Start Setup

Set the OPNsense API base URL and verify that the host can reach it:

```sh
export OPNSENSE_URL=https://192.168.1.1/api

curl --insecure --silent --show-error --output /dev/null "$OPNSENSE_URL"
```

`OPNSENSE_VERIFY_SSL` defaults to `false`, so Shimmy's preflight uses `curl --insecure` unless you set `OPNSENSE_VERIFY_SSL=true`. If your OPNsense certificate is trusted by the host, set `OPNSENSE_VERIFY_SSL=true` and omit `--insecure` from the manual curl check.

Create Podman secrets for the OPNsense API key and secret:

```sh
printf 'paste your api key' | podman secret create opnsense_mcp_api_key -
printf 'paste your api secret' | podman secret create opnsense_mcp_api_secret -
```

Run the shim from an MCP client with `OPNSENSE_URL` in the environment. `OPNSENSE_VERIFY_SSL=false` and `OPNSENSE_ALLOW_WRITES=false` are the defaults, so they only need to be set when overriding that behavior.

Environment:

- `SHIMMY_OPNSENSE_MCP_IMAGE` - override the container image. Default: `docker.io/uhlenheide/opnsense-mcp-server`.
- `SHIMMY_OPNSENSE_MCP_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_OPNSENSE_MCP_API_KEY` - Podman secret name mounted into the container as `OPNSENSE_API_KEY`. Default: `opnsense_mcp_api_key`.
- `SHIMMY_OPNSENSE_MCP_API_SECRET` - Podman secret name mounted into the container as `OPNSENSE_API_SECRET`. Default: `opnsense_mcp_api_secret`.
- `OPNSENSE_URL` - OPNsense API base URL, including `/api`.
- `OPNSENSE_VERIFY_SSL` - defaults to `false` for self-signed lab certificates. Set `true` only when the host trusts the OPNsense certificate.
- `OPNSENSE_ALLOW_WRITES` - defaults to `false` for read-only use. Set `true` only for explicit change windows.

Preflight checks:

- `OPNSENSE_URL` must be set and must start with `http://` or `https://`.
- Before starting the container, Shimmy runs a simple curl request against `OPNSENSE_URL`. HTTP authentication failures still prove the endpoint is reachable; DNS, TCP, timeout, and TLS failures stop the shim with guidance.
- When `OPNSENSE_VERIFY_SSL` is unset or `false`, Shimmy passes `--insecure` to the preflight curl check.
- The preflight uses a 10 second connect timeout and 20 second maximum request time to tolerate slower local DNS lookups.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

Minimum read-only OPNsense API privileges:

| MCP action | OPNsense API endpoint privilege |
|------------|----------------------------------|
| MCP startup/version detection | `GET /api/core/firmware/status` |
| WAN and gateway status | `GET /api/routes/gateway/status` |
| DHCP leases via dnsmasq | `GET /api/dnsmasq/leases/search` |
| DHCP leases via Kea | `GET /api/kea/leases4/search` |
| DHCP leases via ISC DHCP | `GET /api/dhcpv4/leases/searchLease` or `GET /api/dhcpv4/leases/search_lease` |
| DNS resolver stats | `GET /api/unbound/diagnostics/stats` |
| Service list | `POST /api/core/service/search` |
| Config inventory scan | `GET /api/core/backup/download/this` |

Useful optional inventory privileges for `opn_scan_config`:

- `GET /api/core/firmware/info`
- `GET /api/dnsmasq/service/status`
- `GET /api/dnsmasq/settings/get`
- `GET /api/kea/service/status`
- `GET /api/kea/dhcpv4/get`
- `GET /api/dnsmasq/leases/search`
- `GET /api/kea/leases4/search`
- `GET /api/diagnostics/interface/getInterfaceConfig` or `GET /api/diagnostics/interface/get_interface_config`
- `GET /api/diagnostics/interface/getInterfaceNames` or `GET /api/diagnostics/interface/get_interface_names`

Forbidden troubleshooting:

| Error while calling | Usually missing endpoint privilege |
|---------------------|-------------------------------------|
| `Version detection failed: HTTP 403` | `GET /api/core/firmware/status` |
| `opn_gateway_status: Forbidden` | `GET /api/routes/gateway/status` |
| `opn_list_dnsmasq_leases: Forbidden` | `GET /api/dnsmasq/leases/search` |
| `opn_dns_stats: Forbidden` | `GET /api/unbound/diagnostics/stats` |
| `opn_list_services: Forbidden` | `POST /api/core/service/search` |
| `opn_scan_config: Forbidden` | Start with `GET /api/core/backup/download/this`, then add the optional inventory privileges above as needed. |

MCP stdio smoke test:

```sh
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shimmy-smoke","version":"0.0.0"}}}'
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"opn_mcp_info","arguments":{}}}'
  sleep 5
) | OPNSENSE_URL=https://192.168.1.1/api opnsense-mcp-server
```

FastMCP in this image accepts newline-delimited JSON over stdio. Use that format for manual smoke checks instead of `Content-Length` framing.

MCP client example:

```json
{
  "mcpServers": {
    "opnsense": {
      "command": "opnsense-mcp-server",
      "env": {
        "OPNSENSE_URL": "https://192.168.1.1/api"
      }
    }
  }
}
```

Notes:

- Store API key material in Podman secrets, not project files or MCP config JSON.
- Start with a dedicated read-only OPNsense API user.
- Confirm the `curl` preflight succeeds from the same shell or agent environment that will launch the MCP server.
- Leave `OPNSENSE_ALLOW_WRITES=false` unless you intentionally want firewall-changing tools available.
- The upstream documentation references `lucamarien/opnsense-mcp-server`; this Shimmy wrapper uses the actual image `uhlenheide/opnsense-mcp-server`.

## Quick-Start Prompts

Read-only prompts:

- Home labber: "Use the OPNsense MCP server to summarize WAN status, gateway health, DHCP leases, and DNS service status."
- Software dev: "Inspect firewall aliases and NAT rules relevant to the dev subnet, then explain what inbound and outbound access is allowed."
- Platform engineer: "Review VPN, HAProxy, and firewall rule status for production-facing services and list risks or stale entries."

Write-capable prompts:

- Home labber: "With OPNsense writes enabled, propose the exact firewall rule needed to allow this host to reach the NAS on TCP 2049. Wait for confirmation before applying."
- Software dev: "With OPNsense writes enabled, create a temporary alias for the integration-test clients and explain the rollback path before changing rules."
- Platform engineer: "With OPNsense writes enabled during the approved change window, add the requested HAProxy backend update and confirm whether OPNsense accepted the change."
