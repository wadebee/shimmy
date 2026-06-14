---
name: shimmy-tool-opnsense-mcp
description: Guidance for using, changing, testing, and troubleshooting the OPNsense MCP read-only shim in this repository, including OPNsense API privileges, Podman secrets, read-only live checks, and MCP stdio smoke tests.
---

# OPNsense MCP Read-Only Shim

Use this skill when working with `shims/opnsense-mcp-read-only`, its tests, its docs, or live read-only OPNsense MCP queries.

## Files

- Runtime shim: `../../../shims/opnsense-mcp-read-only`
- User docs: `../../../docs/shims/opnsense-mcp-read-only.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_PROFILE_ACTIVE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: local build from `../../../images/opnsense-mcp-read-only/Containerfile`
- Build override: `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE_BUILD=always`
- Source ref override: `SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF`
- Pull override for explicit image overrides: `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE_PULL=always`
- Image override: `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE`
- Podman secrets:
  - `SHIMMY_OPNSENSE_MCP_READ_ONLY_API_KEY`, default `opnsense_mcp_read_only_api_key`, mounted as `OPNSENSE_API_KEY`
  - `SHIMMY_OPNSENSE_MCP_READ_ONLY_API_SECRET`, default `opnsense_mcp_read_only_api_secret`, mounted as `OPNSENSE_API_SECRET`
- Required upstream env: `OPNSENSE_URL`
- Safe defaults:
  - `OPNSENSE_VERIFY_SSL=false`
  - `OPNSENSE_ALLOW_WRITES=false`
- Runtime mode: stdio-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep writes disabled by default. Do not set `OPNSENSE_ALLOW_WRITES=true` in examples unless explicitly discussing a write window.
2. Keep OPNsense API credentials in Podman secrets. Do not put API key material in MCP config JSON, docs examples, or tests.
3. Keep live validation read-only unless the user explicitly asks for a write-capable workflow.
4. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
5. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Preflight

The shim should fail before Podman when:

- `OPNSENSE_URL` is unset
- `OPNSENSE_URL` does not start with `http://` or `https://`
- `curl` is unavailable
- the URL does not respond to curl

When `OPNSENSE_VERIFY_SSL` is unset or `false`, curl uses `--insecure`. Keep the timeout long enough for local DNS: current values are `--connect-timeout 10 --max-time 20`.

## Live MCP Smoke

Use newline-delimited JSON for manual FastMCP stdio checks:

Avoid `Content-Length` framing for ad hoc smoke tests against this image; it produced parser errors during manual checks.

## Status Summary Pattern

For read-only network summaries, query tools separately or keep output small:

- `opn_gateway_status`
- `opn_list_dnsmasq_leases`, `opn_list_kea_leases`, or `opn_list_dhcp_leases`
- `opn_dns_stats`
- `opn_list_services`
- `opn_mcp_info`

If combined output is large, rerun individual tools and summarize locally from `structuredContent`.

## Missing OPNsense API Privileges

When an OPNsense MCP call returns HTTP 403 or another authorization error:

1. Stop. Do not try alternate endpoints, remove safety flags, enable writes, or work around the missing privilege.
2. Identify the failed MCP tool and the likely OPNsense privilege `Name` from `../../../docs/shims/opnsense-mcp-read-only.md` when possible.
3. Ask the user to update the API user's group privileges before retrying.
4. Tell the user to add the privilege in OPNsense at `System | Access | Groups | Edit Group | Privileges`.
5. Include the security impact of the requested privilege:
   - If the privilege is status, diagnostics, lease, alias, NAT, rule, service, VPN, or configuration-inspection oriented, say it preserves the intended read-only posture while `System: Deny config write` remains enabled.
   - If the operation requires removing `System: Deny config write`, setting `OPNSENSE_ALLOW_WRITES=true`, or granting write-capable privileges, say it breaches the read-only boundary and should only happen during an explicit change window.
6. After the user confirms the privilege has been added, retry the same operation once. If it still fails, stop and report the remaining error.

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

## Learning Guidance

- Capture OPNsense MCP-specific lessons here when they affect API privileges, secret handling, stdio framing, read-only defaults, write-window safeguards, or live smoke checks.
- In AI Agent VM/container shells, local host network commands may expose only loopback, an internal resolver, or sandbox-only routes. For "current host" firewall summaries, infer the real VM host from OPNsense leases, ARP output, and PF states instead of assuming the shell's local IP is the host IP.
- `opn_arp_table` and `opn_ndp_table` may fail at the MCP/FastMCP serialization layer when the upstream tool returns a bare list instead of a dict. Useful ARP/NDP rows can still appear in the error payload; inspect that text before treating the query as a total failure.
- Use `opn_pf_states` to distinguish configured policy from active traffic. If an alias such as `server_proxmox` points to one address but live PF states only show another host on the subnet, report that distinction explicitly.
- For firewall policy summaries, query legacy config sections as well as MVC list tools. `opn_list_firewall_rules` can return empty while legacy GUI rules exist under `opn_get_config_section("filter")`; `opn_list_nat_rules` can show generated rules while NAT mode or legacy NAT details are under `opn_get_config_section("nat")`.
- Keep active diagnostics such as `opn_ping` and `opn_dns_lookup` out of the default read-only audit path. They may use POST endpoints that OPNsense denies when the API user has `System: Deny config write`, even though the diagnostic intent is non-mutating.
- When summarizing effective access, separate configuration from runtime evidence: aliases and rules describe intended policy, leases and ARP describe known neighbors, and PF states describe current traffic.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
