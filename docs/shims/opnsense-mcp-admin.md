# OPNsense MCP Admin Shim

## Upstream

- Source repo README: <https://github.com/floriangrousset/opnsense-mcp-server>
- Shim image: local build from `images/opnsense-mcp-admin/Containerfile`
- Pinned source ref: `eeccd8189dc2d80fd397b2a589b20683ec947266`

## Upstream README Summary

OPNsense MCP Admin is a stdio Model Context Protocol server for managing OPNsense firewalls through AI assistants. Shimmy packages the Grousset implementation as the explicit admin-capable OPNsense option because it exposes broader configuration and management coverage than the read-only Marien shim.

Use `opnsense-mcp-admin` only for explicit configuration changes, approved change-window workflows, or capabilities that `opnsense-mcp-read-only` does not expose. Do not switch to admin just because a read-only call returns an OPNsense privilege error; prompt user to grant the needed read-only privilege instead.

## Top-Level Command Summary

The container entrypoint starts the MCP server directly:

- `opnsense-mcp-admin` - start the admin-capable stdio MCP server through Podman.

The server is meant to be launched by an MCP-compatible client. It requires OPNsense API configuration before it can connect.

Install and configure `opnsense-mcp-admin` only when you need the admin-capable path, and create the new admin Podman secrets below.

## Quick Start Setup

Set the OPNsense API base URL and verify that the host can reach it:

```sh
export OPNSENSE_URL=https://192.168.1.1/api

curl --insecure --silent --show-error --output /dev/null "$OPNSENSE_URL"
```

`OPNSENSE_VERIFY_SSL` defaults to `false`, so Shimmy's preflight uses `curl --insecure` unless you set `OPNSENSE_VERIFY_SSL=true`. If your OPNsense certificate is trusted by the host, set `OPNSENSE_VERIFY_SSL=true` and omit `--insecure` from the manual curl check.

Create Podman secrets for the OPNsense API key and secret:

```sh
printf 'paste your admin api key' | podman secret create opnsense_mcp_admin_api_key -
printf 'paste your admin api secret' | podman secret create opnsense_mcp_admin_api_secret -
```

If Podman reports `no secret with name or id "opnsense_mcp_admin_api_key"` or
`no secret with name or id "opnsense_mcp_admin_api_secret"`, create the missing
secret from a trusted user shell with the matching command above. Do not reuse
the read-only shim secrets for the admin shim.

Run the shim from an MCP client with `OPNSENSE_URL` in the environment. Keep admin credentials separate from read-only credentials so the safer read-only path cannot accidentally inherit broader permissions.

Environment:

- `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE` - override the runtime image. When unset, Shimmy builds a local image from the pinned Grousset source ref.
- `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE_PULL=always` - pull an override image before running.
- `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE_BUILD=always` - rebuild the local source image even when cached.
- `SHIMMY_OPNSENSE_MCP_ADMIN_SOURCE_REF` - override the Grousset git ref used for local builds.
- `SHIMMY_OPNSENSE_MCP_ADMIN_MCP_VERSION` - image build argument for the MCP Python SDK constraint. Default: `mcp[cli]<1.10.0`.
- `SHIMMY_OPNSENSE_MCP_ADMIN_API_KEY` - Podman secret name mounted into the container as `OPNSENSE_API_KEY`. Default: `opnsense_mcp_admin_api_key`.
- `SHIMMY_OPNSENSE_MCP_ADMIN_API_SECRET` - Podman secret name mounted into the container as `OPNSENSE_API_SECRET`. Default: `opnsense_mcp_admin_api_secret`.
- `OPNSENSE_URL` - OPNsense API base URL, including `/api`.
- `OPNSENSE_VERIFY_SSL` - defaults to `false` for self-signed lab certificates. Set `true` only when the host trusts the OPNsense certificate.

Local image build:

- Shimmy builds `localhost/shimmy-opnsense-mcp-admin:<context-hash>-<platform>` from `images/opnsense-mcp-admin/Containerfile`.
- The default source ref is `eeccd8189dc2d80fd397b2a589b20683ec947266` from `floriangrousset/opnsense-mcp-server`.
- The image constrains `mcp[cli]` below `1.10.0` because the current upstream admin code still passes `description=` to `FastMCP(...)`, and newer MCP Python SDK releases reject that argument.
- Use `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE_BUILD=always` to force a rebuild.
- Use `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE` only when you want to run a separately managed image.

Preflight checks:

- `OPNSENSE_URL` must be set and must start with `http://` or `https://`.
- Before starting the container, Shimmy runs a simple curl request against `OPNSENSE_URL`. HTTP authentication failures still prove the endpoint is reachable; DNS, TCP, timeout, and TLS failures stop the shim with guidance.
- When `OPNSENSE_VERIFY_SSL` is unset or `false`, Shimmy passes `--insecure` to the preflight curl check.
- The preflight uses a 10 second connect timeout and 20 second maximum request time to tolerate slower local DNS lookups.
- Shimmy checks that the configured Podman secrets exist before container creation. If either secret is missing, create it with:

```sh
printf 'paste your admin api key' | podman secret create opnsense_mcp_admin_api_key -
printf 'paste your admin api secret' | podman secret create opnsense_mcp_admin_api_secret -
```

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

Selection policy:

1. Prefer `opnsense-mcp-read-only` for inventory, status, diagnostics, inspection, policy review, and any prompt that does not explicitly require a configuration change.
2. Use `opnsense-mcp-admin` only when the user asks for a configuration change, a change-window workflow, or a capability that the read-only library does not expose.
3. If a read-only tool returns an OPNsense privilege error, stop and request the needed read-only privilege. Do not switch to admin as a privilege workaround.
4. Before using admin, state the reason, requested change boundary, and expected rollback or verification path.

MCP stdio smoke test:

```sh
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"shimmy-smoke","version":"0.0.0"}}}'
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
  sleep 20
) | OPNSENSE_URL=https://192.168.1.1/api opnsense-mcp-admin
```

MCP client example:

```json
{
  "mcpServers": {
    "opnsense-admin": {
      "command": "opnsense-mcp-admin",
      "env": {
        "OPNSENSE_URL": "https://192.168.1.1/api"
      }
    }
  }
}
```

Notes:

- Store API key material in Podman secrets, not project files or MCP config JSON.
- Use a dedicated admin OPNsense API user or group, separate from the read-only account.
- Confirm the `curl` preflight succeeds from the same shell or agent environment that will launch the MCP server.
- Treat every admin session as change-capable. Record the intended boundary, approval, verification, and rollback path before changing firewall configuration.

## Quick-Start Prompts

Admin prompts:

- Home labber: "Using the OPNsense MCP admin shim during this approved change window, create the temporary firewall rule we discussed, then verify it is present and describe how to remove it."
- Software dev: "Using the admin shim, add a temporary alias for the integration-test clients. Stop before applying any dependent firewall rule and show the rollback command or UI path."
- Platform engineer: "Using the admin shim, update the requested HAProxy backend during the approved maintenance window, verify OPNsense accepted the change, and list the rollback steps."
