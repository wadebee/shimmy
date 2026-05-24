---
name: shimmy-tool-opnsense-mcp
description: Guidance for using, changing, testing, and troubleshooting the OPNsense MCP server shim in this repository, including OPNsense API privileges, Podman secrets, read-only live checks, and MCP stdio smoke tests.
---

# OPNsense MCP Shim

Use this skill when working with `shims/opnsense-mcp-server`, its tests, its docs, or live read-only OPNsense MCP queries.

## Files

- Runtime shim: `../../../shims/opnsense-mcp-server`
- User docs: `../../../docs/shims/opnsense-mcp-server.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Current Behavior

- Default image: `docker.io/uhlenheide/opnsense-mcp-server`
- Pull override: `SHIMMY_OPNSENSE_MCP_IMAGE_PULL=always`
- Image override: `SHIMMY_OPNSENSE_MCP_IMAGE`
- Podman secrets:
  - `SHIMMY_OPNSENSE_MCP_API_KEY`, default `opnsense_mcp_api_key`, mounted as `OPNSENSE_API_KEY`
  - `SHIMMY_OPNSENSE_MCP_API_SECRET`, default `opnsense_mcp_api_secret`, mounted as `OPNSENSE_API_SECRET`
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

## Learning Guidance

- Capture OPNsense MCP-specific lessons here when they affect API privileges, secret handling, stdio framing, read-only defaults, write-window safeguards, or live smoke checks.
- Promote reusable Shimmy design lessons to `../shimmy-create/SKILL.md` under `Learning Guidance`.
