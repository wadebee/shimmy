---
name: shimmy-tool-opnsense-mcp-admin
description: Guidance for using, changing, testing, and troubleshooting the opnsense-mcp-admin shim in this repository, including admin-capable OPNsense MCP routing, change-window approval, rollback guidance, Podman secrets, and supported tool inventory.
---

# OPNsense MCP Admin Shim

Use this skill when working with the opnsense-mcp-admin tool, its tests, its docs, or approved admin-capable OPNsense MCP workflows.

## Files

- Kind metadata: `../../../tools/opnsense-mcp-admin/tool.conf`
- Concrete runtime: `../../../tools/opnsense-mcp-admin/versions/1.0/run.sh`
- User guide: `../../../tools/opnsense-mcp-admin/guide.md`
- Tests: `../../../tools/opnsense-mcp-admin/tests/opnsense-mcp-admin.sh`
- Image context: `../../../tools/opnsense-mcp-admin/versions/1.0/container/Containerfile`
- Repository suite: `../../../tests/test.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `opnsense-mcp-admin` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

For source validation, use `./commands/run-tool.sh opnsense-mcp-admin --preview-shim --help`
or the concrete `tools/opnsense-mcp-admin/versions/1.0/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: local build from `../../../tools/opnsense-mcp-admin/versions/1.0/container/Containerfile`
- Source ref: `eeccd8189dc2d80fd397b2a589b20683ec947266` from `floriangrousset/opnsense-mcp-server`
- Build override: `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE_BUILD=always`
- Source ref override: `SHIMMY_OPNSENSE_MCP_ADMIN_SOURCE_REF`
- MCP SDK build constraint: `SHIMMY_OPNSENSE_MCP_ADMIN_MCP_VERSION`, default `mcp[cli]<1.10.0`
- Pull override for explicit image overrides: `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE_PULL=always`
- Image override: `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE`
- Podman secrets:
  - `SHIMMY_OPNSENSE_MCP_ADMIN_API_KEY`, default `opnsense_mcp_admin_api_key`, mounted as `OPNSENSE_API_KEY`
  - `SHIMMY_OPNSENSE_MCP_ADMIN_API_SECRET`, default `opnsense_mcp_admin_api_secret`, mounted as `OPNSENSE_API_SECRET`
- Required public env: `OPNSENSE_URL`
- URL normalization: accepts a bare hostname, firewall root URL, or `/api` API URL; passes the firewall root URL to upstream because Grousset appends `/api` internally
- SSL preflight default: `OPNSENSE_VERIFY_SSL=false`
- Runtime profile stub: the image writes a no-secret `~/.opnsense-mcp/config.json` default profile from `OPNSENSE_URL` and `OPNSENSE_VERIFY_SSL`
- Runtime mode: stdio-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Routing Rules

1. Prefer `opnsense-mcp-read-only` for inventory, status, diagnostics, inspection, and policy review when a matching read-only tool exists.
2. Use this admin shim only when the user explicitly asks for a configuration change, an approved change-window workflow, or a capability absent from the read-only tool inventory.
3. Do not switch to admin because a read-only call returned HTTP 403. Ask for the needed read-only privilege instead.
4. Before using admin, state the reason, requested change boundary, affected objects, expected verification, and rollback path. Ask for explicit approval/elevation before executing the admin action.
5. Keep admin and read-only Podman secrets separate. Never reuse read-only secret names for admin.

Use this prompt shape before admin changes:

```text
This requires `opnsense-mcp-admin` because <missing read-only capability or requested change>.

Change boundary:
<specific objects, fields, and allowed action>

Verification:
<read-back or status check>

Rollback:
<delete/revert/restore path>

Approve this admin change window before I execute it.
```

## Preflight

The shim should fail before Podman when `OPNSENSE_URL` is unset, contains a URL path other than empty, `/`, or `/api`, `curl` is unavailable, or the normalized firewall root URL does not respond to curl. Bare hostnames are accepted and normalized with `https://`. Full `http://` and `https://` URLs are accepted. When `OPNSENSE_VERIFY_SSL` is unset or `false`, curl uses `--insecure`. Keep current timeouts at `--connect-timeout 10 --max-time 20` unless there is a tested reason to change them.

## Supported Tool Inventory

Inventory source: Grousset pinned ref `eeccd8189dc2d80fd397b2a589b20683ec947266`, `src/opnsense_mcp/domains/*` FastMCP `@mcp.tool(name="...")` registrations. The wrapper notes 166 tools total; the compact inventory below lists exact names useful for routing.

- Connection and API discovery: `configure_opnsense_connection`, `get_api_endpoints`, `exec_api_call`
- System and firmware: `get_system_status`, `get_system_health`, `get_system_routes`, `restart_service`, `backup_config`, `list_plugins`, `install_plugin`, `perform_firewall_audit`
- Interfaces and gateways: `get_interfaces`, `get_dhcp_leases`, `get_interface_details`, `reload_interface`, `export_interface_config`; VLAN `list_vlan_interfaces`, `get_vlan_interface`, `create_vlan_interface`, `update_vlan_interface`, `delete_vlan_interface`; bridge `list_bridge_interfaces`, `get_bridge_interface`, `create_bridge_interface`, `update_bridge_interface`, `delete_bridge_interface`; LAGG `list_lagg_interfaces`, `get_lagg_interface`, `create_lagg_interface`, `update_lagg_interface`, `delete_lagg_interface`; VIP `list_virtual_ips`, `get_virtual_ip`, `create_virtual_ip`, `update_virtual_ip`, `delete_virtual_ip`, `get_unused_vhid`
- Firewall rules, aliases, NAT, states, and logs: `firewall_get_rules`, `firewall_add_rule`, `firewall_delete_rule`, `firewall_toggle_rule`, `get_firewall_aliases`, `add_to_alias`, `delete_from_alias`, `get_firewall_logs`, `nat_list_outbound_rules`, `nat_add_outbound_rule`, `nat_delete_outbound_rule`, `nat_toggle_outbound_rule`, `nat_list_one_to_one_rules`, `nat_add_one_to_one_rule`, `nat_delete_one_to_one_rule`, `nat_get_port_forward_info`
- DNS, DHCP, leases, and resolver data: DHCP `dhcp_list_servers`, `dhcp_get_server`, `dhcp_set_server`, `dhcp_restart_service`, `dhcp_list_static_mappings`, `dhcp_get_static_mapping`, `dhcp_add_static_mapping`, `dhcp_update_static_mapping`, `dhcp_delete_static_mapping`, `dhcp_get_leases`, `dhcp_search_leases`, `dhcp_get_lease_statistics`; Unbound `dns_resolver_get_settings`, `dns_resolver_set_settings`, `dns_resolver_restart_service`, `dns_resolver_list_host_overrides`, `dns_resolver_get_host_override`, `dns_resolver_add_host_override`, `dns_resolver_update_host_override`, `dns_resolver_delete_host_override`, `dns_resolver_list_domain_overrides`, `dns_resolver_add_domain_override`; dnsmasq `dns_forwarder_get_settings`, `dns_forwarder_set_settings`, `dns_forwarder_list_hosts`, `dns_forwarder_add_host`, `dns_forwarder_restart_service`
- VPN: `get_vpn_connections`
- Services and plugins: `list_plugins`, `install_plugin`
- Diagnostics, logs, and monitoring: `get_firewall_logs`, `get_system_logs`, `get_service_logs`, `search_logs`, `export_logs`, `get_log_statistics`, `clear_logs`, `configure_logging`, `analyze_security_events`, `generate_log_report`
- Configuration backup, history, and apply/revert behavior: `backup_config`, `traffic_shaper_reconfigure`, `dhcp_restart_service`, `dns_resolver_restart_service`, `dns_forwarder_restart_service`, `restart_service`
- Admin-only create/update/delete actions: firewall add/delete/toggle, NAT add/delete/toggle, alias add/delete, DHCP set/add/update/delete, DNS set/add/update/delete, interface/VLAN/bridge/LAGG/VIP create/update/delete, user/group/privilege create/update/delete/assign/revoke/reset/bulk/template, certificate/ACME create/import/sign/revoke/delete, logging clear/configure, traffic shaper create/update/delete/toggle helpers, plugin install, custom `exec_api_call`
- Certificates and ACME: CA `list_certificate_authorities`, `get_certificate_authority`, `create_certificate_authority`, `delete_certificate_authority`, `export_certificate_authority`; cert `list_certificates`, `get_certificate`, `import_certificate`, `delete_certificate`, `export_certificate`; CSR `list_certificate_signing_requests`, `get_certificate_signing_request`, `create_certificate_signing_request`, `delete_certificate_signing_request`; ACME `list_acme_accounts`, `get_acme_account`, `create_acme_account`, `delete_acme_account`, `list_acme_certificates`, `get_acme_certificate`, `create_acme_certificate`, `sign_acme_certificate`, `revoke_acme_certificate`, `delete_acme_certificate`; analysis `analyze_certificate_expiration`, `validate_certificate_chain`, `get_certificate_usage`
- Users, groups, and privileges: `list_users`, `get_user`, `create_user`, `update_user`, `delete_user`, `toggle_user`, `list_groups`, `get_group`, `create_group`, `update_group`, `delete_group`, `add_user_to_group`, `remove_user_from_group`, `list_privileges`, `get_user_effective_privileges`, `assign_privilege_to_user`, `revoke_privilege_from_user`, `list_auth_servers`, `test_user_authentication`, `create_admin_user`, `create_readonly_user`, `reset_user_password`, `bulk_user_creation`, `setup_user_group_template`
- Traffic shaping: `traffic_shaper_get_status`, `traffic_shaper_reconfigure`, `traffic_shaper_get_settings`, pipe tools `traffic_shaper_list_pipes`, `traffic_shaper_get_pipe`, `traffic_shaper_create_pipe`, `traffic_shaper_update_pipe`, `traffic_shaper_delete_pipe`, `traffic_shaper_toggle_pipe`; queue tools `traffic_shaper_list_queues`, `traffic_shaper_get_queue`, `traffic_shaper_create_queue`, `traffic_shaper_update_queue`, `traffic_shaper_delete_queue`, `traffic_shaper_toggle_queue`; rule tools `traffic_shaper_list_rules`, `traffic_shaper_get_rule`, `traffic_shaper_create_rule`, `traffic_shaper_update_rule`, `traffic_shaper_delete_rule`, `traffic_shaper_toggle_rule`; helpers `traffic_shaper_limit_user_bandwidth`, `traffic_shaper_prioritize_voip`, `traffic_shaper_setup_gaming_priority`, `traffic_shaper_create_guest_limits`

Use read-only first when a matching tool exists. Use admin only for missing read-only coverage or explicit configuration changes.

## Admin Safety

- Treat `exec_api_call` as power-user tooling. Use a dedicated tool first when available; if using `exec_api_call`, define the exact method and endpoint and avoid destructive HTTP methods unless the user approved them.
- Treat `restart_service`, `reload_interface`, DNS/DHCP restarts, and traffic-shaper reconfigure as operational changes even when configuration is not edited.
- Prefer read-back verification through the least privileged matching tool after every admin action.
- Do not put API key material in MCP config JSON, docs examples, shell history, or tests.
- If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.

## Lessons Learned

- Use one public `OPNSENSE_URL` contract across both OPNsense MCP shims.
- Admin upstream expects the firewall root URL and appends `/api` internally.
- Read-only upstream expects the API base URL including `/api`.
- Admin upstream requires a config profile metadata file even when credentials load from env, so Shimmy provides a no-secret runtime stub.
- Manual stdio smoke for these images should use newline-delimited JSON unless testing a specific framing change.
- If direct tool calls fail after connection, distinguish shim connectivity from upstream endpoint bugs. For example, `get_system_status` may fail on `/core/system/info` while `exec_api_call` to `/core/firmware/status` proves auth/API connectivity.
- In sandboxed AI Agent runs, `firewall.home.arpa` or other local DNS names may fail before Podman during shim curl preflight even when they work from the user's normal host shell. Treat `curl: (6) Could not resolve host` as a host-network/DNS sandbox symptom first, not an OPNsense or shim failure.
- When local DNS fails in the sandbox, rerun the exact `opnsense-mcp-admin` wrapper command with escalation instead of falling back to host curl or bypassing the shim. Example prefix: `["env", "OPNSENSE_URL=http://firewall.home.arpa/", "OPNSENSE_VERIFY_SSL=false", "./commands/run-tool.sh opnsense-mcp-admin"]`.
- For connectivity smoke, use `configure_opnsense_connection` first, then `exec_api_call` with `GET /core/firmware/status`. A `200 OK` there proves URL normalization, credentials, auth, and OPNsense API reachability.
- Interrupting a manual stdio MCP smoke with Ctrl-C can print a Python `KeyboardInterrupt` traceback. That is normal cleanup noise after a successful smoke, not a connectivity failure.
