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

Use the privilege `Name` values shown in `System | Groups | Edit Group | Privileges`.
Add `System: Deny config write` to the read-only group so the account cannot
change saved configuration even if broader page privileges are added later.

| Scope | OPNsense privilege `Name` | MCP tools or prompts covered |
|-------|----------------------------|------------------------------|
| Smoke-test baseline | `System: Firmware` | `opn_system_status`; API version/style detection |
| Smoke-test baseline | `Status: Services` | `opn_list_services`; service status checks |
| Smoke-test baseline | `System: Gateways` | `opn_gateway_status`; WAN and gateway health |
| Home lab read-only prompt | `Services: Dnsmasq DNS/DHCP: Settings` | `opn_list_dnsmasq_leases`, `opn_list_dnsmasq_ranges`; dnsmasq DHCP/DNS installs |
| Home lab read-only prompt | `Services: DHCP: Kea(v4)` | `opn_list_kea_leases`; Kea DHCPv4 installs |
| Home lab read-only prompt | `Services: ISC DHCPv4: Leases` | `opn_list_dhcp_leases`; legacy ISC DHCPv4 installs |
| Home lab read-only prompt | `Services: Unbound` | `opn_dns_stats`; Unbound resolver data |
| Software dev read-only prompt | `Firewall: Aliases` | `opn_list_firewall_aliases`; alias inventory |
| Software dev read-only prompt | `Firewall: NAT: Destination NAT` | `opn_list_nat_rules`; MVC port-forward rules |
| Software dev read-only prompt | `Firewall: Rules [new]` | `opn_list_firewall_rules`; MVC firewall automation rules |
| Software dev read-only prompt | `Diagnostics: Configuration History` | `opn_scan_config`, `opn_get_config_section`, `opn_download_config`; legacy GUI firewall and NAT config inventory |
| Platform engineer read-only prompt | `Services: HAProxy` | `opn_haproxy_status`; HAProxy status and read-only resource searches |
| Platform engineer read-only prompt | `Status: OpenVPN` | `opn_openvpn_status`; OpenVPN sessions and routes |
| Platform engineer read-only prompt | `VPN: OpenVPN: Instances` | `opn_openvpn_status`; OpenVPN instance inventory |
| Platform engineer read-only prompt | `Status: IPsec` | `opn_ipsec_status`; IPsec phase 1 and phase 2 sessions |
| Platform engineer read-only prompt | `Status: IPsec: SPD` | `opn_ipsec_status`; IPsec service status |
| Platform engineer read-only prompt | `VPN: WireGuard: Status` | `opn_wireguard_status`; WireGuard tunnel status |
| Optional diagnostics | `Diagnostics: ARP Table` | `opn_arp_table`; IPv4 neighbor inventory |
| Optional diagnostics | `Diagnostics: NDP Table` | `opn_ndp_table`; IPv6 neighbor inventory |
| Optional diagnostics | `Diagnostics: Netstat` | `opn_interface_stats`; interface counters |
| Optional diagnostics | `Diagnostics: Show States` | `opn_pf_states`; state table inspection |
| Optional diagnostics | `Diagnostics: Logs: Firewall: Live View` | `opn_firewall_log`; recent firewall log entries |
| Optional diagnostics | `Diagnostics: Ping` | `opn_ping`; active ping diagnostic |
| Optional diagnostics | `Diagnostics: Traceroute` | `opn_traceroute`; active traceroute diagnostic |
| Optional diagnostics | `Interfaces: Diagnostics: DNS Lookup` | `opn_dns_lookup`; active DNS lookup diagnostic |

The read-only prompt examples below do not all need every optional diagnostic
privilege. Grant the optional rows only when the assistant should be allowed to
run those diagnostics. Some OPNsense versions and plugins expose overlapping
privileges; the names above come from the OPNsense privilege list at
`/api/auth/priv/search` and correspond to the UI `Name` column.

MCP stdio smoke test:

```sh
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shimmy-smoke","version":"0.0.0"}}}'
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"opn_mcp_info","arguments":{}}}'
  printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"opn_system_status","arguments":{}}}'
  printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"opn_list_services","arguments":{}}}'
  printf '%s\n' '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"opn_gateway_status","arguments":{}}}'
  sleep 20
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

- Home labber: "Use the OPNsense MCP server to summarize WAN and dnsmasq status, then show detailed DHCP leases."
- Software dev: "Show my current host IP/subnet and inspect firewall aliases, interface assignments and rules that apply toit. Summarize effective inbound / outbound access and port forwards. Show floating rules and highlight externally exposed services."
- Platform engineer: "Review VPN, HAProxy, and firewall rule status for production-facing services and list risks or stale entries."

Write-capable prompts:

- Home labber: "With OPNsense writes enabled, propose the exact firewall rule needed to allow this host to reach the NAS on TCP 2049. Wait for confirmation before applying."
- Software dev: "With OPNsense writes enabled, create a temporary alias for the integration-test clients and explain the rollback path before changing rules."
- Platform engineer: "With OPNsense writes enabled during the approved change window, add the requested HAProxy backend update and confirm whether OPNsense accepted the change."
