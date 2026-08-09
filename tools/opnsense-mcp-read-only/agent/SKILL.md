---
name: shimmy-tool-opnsense-mcp-read-only
description: Guidance for using, changing, testing, and troubleshooting the opnsense-mcp-read-only shim in this repository, including read-only OPNsense MCP routing, API privileges, Podman secrets, supported tool inventory, and MCP stdio smoke tests.
---

# OPNsense MCP Read-Only Shim

Use this skill when working with the opnsense-mcp-read-only tool, its tests, its docs, or live read-only OPNsense MCP queries.

## Files

- Kind metadata: `../../../tools/opnsense-mcp-read-only/tool.conf`
- Concrete runtime: `../../../tools/opnsense-mcp-read-only/versions/0.4/run.sh`
- User guide: `../../../tools/opnsense-mcp-read-only/guide.md`
- Tests: `../../../tools/opnsense-mcp-read-only/tests/opnsense-mcp-read-only.sh`
- Image context: `../../../tools/opnsense-mcp-read-only/versions/0.4/container/Containerfile`
- Repository suite: `../../../tests/test.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `opnsense-mcp-read-only` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

For source validation, use `./commands/run-tool.sh opnsense-mcp-read-only --preview-shim --help`
or the concrete `tools/opnsense-mcp-read-only/versions/0.4/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: local build from `../../../tools/opnsense-mcp-read-only/versions/0.4/container/Containerfile`
- Source ref: `8ddb99a2a99102abc084b5e605aaba1c05c2ff56` from `lucamarien/opnsense-mcp-server`
- Build override: `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE_BUILD=always`
- Source ref override: `SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF`
- Pull override for explicit image overrides: `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE_PULL=always`
- Image override: `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE`
- Podman secrets:
  - `SHIMMY_OPNSENSE_MCP_READ_ONLY_API_KEY`, default `opnsense_mcp_read_only_api_key`, mounted as `OPNSENSE_API_KEY`
  - `SHIMMY_OPNSENSE_MCP_READ_ONLY_API_SECRET`, default `opnsense_mcp_read_only_api_secret`, mounted as `OPNSENSE_API_SECRET`
- Required public env: `OPNSENSE_URL`
- URL normalization: accepts a bare hostname, firewall root URL, or `/api` API URL; passes the API base URL ending in `/api` to upstream
- Safe defaults: `OPNSENSE_VERIFY_SSL=false`, `OPNSENSE_ALLOW_WRITES=false`
- Runtime mode: stdio-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Routing Rules

1. Prefer this read-only shim for inventory, status, diagnostics, inspection, policy review, and any request that does not explicitly require a configuration change.
2. Use `opnsense-mcp-admin` only when the user asks for a configuration change, an approved change-window workflow, or a capability absent from this inventory.
3. If a read-only MCP call returns an OPNsense privilege error, stop and request the missing read-only privilege. Do not switch to admin as a privilege workaround.
4. Keep active diagnostics such as `opn_ping`, `opn_traceroute`, and `opn_dns_lookup` out of default audits; they may use POST endpoints even when the diagnostic intent is non-mutating.

## Change Rules

1. Keep writes disabled by default. Do not set `OPNSENSE_ALLOW_WRITES=true` in examples unless explicitly discussing a write window.
2. Keep OPNsense API credentials in Podman secrets. Do not put API key material in MCP config JSON, docs examples, or tests.
3. Keep live validation read-only unless the user explicitly asks for a write-capable workflow.
4. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
5. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Preflight

The shim should fail before Podman when `OPNSENSE_URL` is unset, contains a URL path other than empty, `/`, or `/api`, `curl` is unavailable, or the normalized API base URL does not respond to curl. Bare hostnames are accepted and normalized with `https://`. Full `http://` and `https://` URLs are accepted. When `OPNSENSE_VERIFY_SSL` is unset or `false`, curl uses `--insecure`. Keep current timeouts at `--connect-timeout 10 --max-time 20` unless there is a tested reason to change them.

## Supported Tool Inventory

Inventory source: Marien pinned ref `8ddb99a2a99102abc084b5e605aaba1c05c2ff56`, `tests/test_tools/test_registration.py` and `src/opnsense_mcp/tools/*`.

- System and firmware: `opn_system_status`, `opn_list_services`, `opn_gateway_status`, `opn_download_config`, `opn_scan_config`, `opn_get_config_section`, `opn_mcp_info`
- Interfaces and gateways: `opn_interface_stats`, `opn_arp_table`, `opn_ndp_table`, `opn_ipv6_status`, `opn_list_static_routes`
- Firewall rules, aliases, NAT, states, and logs: read `opn_list_firewall_rules`, `opn_list_firewall_aliases`, `opn_list_nat_rules`, `opn_list_firewall_categories`, `opn_firewall_log`, `opn_pf_states`; write-capable but disabled by default `opn_add_firewall_rule`, `opn_update_firewall_rule`, `opn_delete_firewall_rule`, `opn_toggle_firewall_rule`, `opn_add_alias`, `opn_update_alias`, `opn_delete_alias`, `opn_toggle_alias`, `opn_add_nat_rule`, `opn_update_nat_rule`, `opn_delete_nat_rule`, `opn_add_firewall_category`, `opn_delete_firewall_category`, `opn_set_rule_categories`, `opn_add_icmpv6_rules`, `opn_confirm_changes`
- DNS, DHCP, leases, and resolver data: read `opn_list_dns_overrides`, `opn_list_dns_forwards`, `opn_dns_stats`, `opn_list_dhcp_leases`, `opn_list_kea_leases`, `opn_list_dnsmasq_leases`, `opn_list_dnsmasq_ranges`, `opn_list_dnsbl`, `opn_get_dnsbl`; write-capable but disabled by default `opn_reconfigure_unbound`, `opn_add_dns_override`, `opn_update_dns_override`, `opn_delete_dns_override`, `opn_set_dnsbl`, `opn_add_dnsbl_allowlist`, `opn_remove_dnsbl_allowlist`, `opn_update_dnsbl`, `opn_add_dnsmasq_range`, `opn_update_dnsmasq_range`, `opn_delete_dnsmasq_range`, `opn_reconfigure_dnsmasq`
- VPN: `opn_wireguard_status`, `opn_ipsec_status`, `opn_openvpn_status`
- Services and plugins: read `opn_haproxy_status`, `opn_haproxy_search`, `opn_haproxy_get`, `opn_haproxy_configtest`, `opn_list_acme_certs`, `opn_list_cron_jobs`, `opn_crowdsec_status`, `opn_crowdsec_alerts`, `opn_list_ddns_accounts`, `opn_mdns_repeater_status`; write-capable but disabled by default `opn_reconfigure_haproxy`, `opn_haproxy_add`, `opn_haproxy_update`, `opn_haproxy_delete`, `opn_add_ddns_account`, `opn_update_ddns_account`, `opn_delete_ddns_account`, `opn_reconfigure_ddclient`, `opn_configure_mdns_repeater`
- Diagnostics and security: `opn_ping`, `opn_traceroute`, `opn_dns_lookup`, `opn_security_audit`

Use read-only tools first when a matching tool exists. Use admin only for missing coverage or explicit configuration changes.

## Missing OPNsense API Privileges

When an OPNsense MCP call returns HTTP 403 or another authorization error:

1. Stop. Do not try alternate endpoints, remove safety flags, enable writes, or work around the missing privilege.
2. Identify the failed MCP tool and likely OPNsense privilege `Name` from `../../../tools/opnsense-mcp-read-only/guide.md` when possible.
3. Ask the user to update the API user's group privileges at `System | Access | Groups | Edit Group | Privileges`.
4. Include the security impact: read-oriented privileges preserve the read-only posture while `System: Deny config write` remains enabled; write-capable privileges breach that boundary and need an explicit change window.
5. After the user confirms the privilege has been added, retry the same operation once. If it still fails, stop and report the remaining error.

Use this prompt shape:

```text
OPNsense returned 403 for `<mcp_tool_name>`.

Likely missing privilege:
`<OPNsense privilege Name>`

To grant it, update the API user's group in OPNsense:
`System | Access | Groups | Edit Group | Privileges`

Security impact:
<Briefly explain whether this preserves the read-only boundary with
`System: Deny config write`, or whether it breaches the read-only boundary.>

After you add the privilege, approve and I will retry the same operation once.
```

## Live MCP Smoke

Use newline-delimited JSON for manual FastMCP stdio checks. Avoid `Content-Length` framing for ad hoc smoke tests against this image; it produced parser errors during manual checks.

For read-only network summaries, query tools separately or keep output small: `opn_gateway_status`, one lease tool such as `opn_list_dnsmasq_leases`, `opn_dns_stats`, `opn_list_services`, and `opn_mcp_info`.

## Learning Guidance

- In AI Agent VM/container shells, local host network commands may expose only loopback, an internal resolver, or sandbox-only routes. For "current host" firewall summaries, infer the real VM host from OPNsense leases, ARP output, and PF states instead of assuming the shell's local IP is the host IP.
- `opn_arp_table` and `opn_ndp_table` may fail at the MCP/FastMCP serialization layer when upstream returns a bare list instead of a dict. Useful ARP/NDP rows can still appear in the error payload; inspect that text before treating the query as a total failure.
- Use `opn_pf_states` to distinguish configured policy from active traffic.
- For firewall policy summaries, query legacy config sections as well as MVC list tools. `opn_list_firewall_rules` can return empty while legacy GUI rules exist under `opn_get_config_section("filter")`; `opn_list_nat_rules` can show generated rules while NAT mode or legacy NAT details are under `opn_get_config_section("nat")`.
- When summarizing effective access, separate configuration from runtime evidence: aliases and rules describe intended policy, leases and ARP describe known neighbors, and PF states describe current traffic.
