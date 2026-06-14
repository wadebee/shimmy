# OPNsense MCP Read-Only/Admin Split Plan

## Goal

Split Shimmy's current OPNsense MCP support into two explicit shims:

- `opnsense-mcp-read-only` for the Marien implementation, preferred for normal
  inspection and read-only workflows.
- `opnsense-mcp-admin` for the Grousset implementation, reserved for explicit
  configuration changes or capabilities missing from the read-only library.

Remove the existing `opnsense-mcp-server` command, container and supporting code entirely. Do not keep a
compatibility alias.

## Upstreams

- Marien read-only/safe model: <https://github.com/lucamarien/opnsense-mcp-server>
- Grousset high-capability/admin model: <https://github.com/floriangrousset/opnsense-mcp-server>

The Marien library is the safety-first default: read-only by default, hardened
guardrails, rollback/safety behavior, and API-level blocked actions. The
Grousset library is the high-capability admin option with broader management
coverage and should be treated as change-window tooling.

## Assumptions

- `opnsense-mcp-server` is removed from supported shims, podman image and secrets, docs, tests, skills,
  and installer-visible command names.
- Existing users must create new Podman secrets for each new shim; old
  `opnsense_mcp_api_key` and `opnsense_mcp_api_secret` names are not reused.
- `opnsense-mcp-read-only` must stop depending on the current upstream Marien
  container image because it is stale and no newer upstream container exists.
  Build a Shimmy-managed local image from a pinned Marien source ref instead.
- `opnsense-mcp-admin` should prefer a published multi-arch image only if one
  is documented and suitable. Otherwise build a Shimmy-managed local image from
  a pinned Grousset source ref.
- Both shims keep `OPNSENSE_URL`, `OPNSENSE_VERIFY_SSL`, and OPNsense API
  upstream env behavior unless upstream-specific docs require a different name.

## Naming

Runtime shims:

- `shims/opnsense-mcp-read-only`
- `shims/opnsense-mcp-admin`

Shim config:

- `shims/opnsense-mcp-read-only.conf`
- `shims/opnsense-mcp-admin.conf`

Docs:

- `docs/shims/opnsense-mcp-read-only.md`
- `docs/shims/opnsense-mcp-admin.md`

Agent skills:

- `.agents/skills/shimmy-tool-opnsense-mcp-read-only/SKILL.md`
- `.agents/skills/shimmy-tool-opnsense-mcp-admin/SKILL.md`

## Credential Separation

Read-only shim env and secret defaults:

- `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE`
- `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE_PULL=always`
- `SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF`
- `SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE_BUILD=always`
- `SHIMMY_OPNSENSE_MCP_READ_ONLY_API_KEY`
  - default Podman secret: `opnsense_mcp_read_only_api_key`
  - mounted as `OPNSENSE_API_KEY`
- `SHIMMY_OPNSENSE_MCP_READ_ONLY_API_SECRET`
  - default Podman secret: `opnsense_mcp_read_only_api_secret`
  - mounted as `OPNSENSE_API_SECRET`

Admin shim env and secret defaults:

- `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE`
- `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE_PULL=always`
- `SHIMMY_OPNSENSE_MCP_ADMIN_API_KEY`
  - default Podman secret: `opnsense_mcp_admin_api_key`
  - mounted as `OPNSENSE_API_KEY`
- `SHIMMY_OPNSENSE_MCP_ADMIN_API_SECRET`
  - default Podman secret: `opnsense_mcp_admin_api_secret`
  - mounted as `OPNSENSE_API_SECRET`

If `opnsense-mcp-admin` uses a local source build, also add:

- `SHIMMY_OPNSENSE_MCP_ADMIN_SOURCE_REF`
- `SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE_BUILD=always`

## Selection Policy

Document and encode this guidance in README, shim docs, and agent skills:
1. Prefer `opnsense-mcp-read-only` for inventory, status, diagnostics,
   inspection, policy review, and any prompt that does not explicitly require a
   configuration change.
2. Use `opnsense-mcp-admin` only when the user asks for a configuration change,
   a change-window workflow, or a capability that the read-only library does not
   expose.
3. If a read-only tool returns an OPNsense privilege error, stop and request the
   needed read-only privilege. Do not switch to admin as a privilege workaround.
4. If admin is needed, state the reason, the requested change boundary, and the
   expected rollback or verification path before using it.
5. See Section 7 for Supported Tool Inventories and make use of this localized list when selecting the appropriate opnsense mcp library

## Implementation Workstreams

### 1. Rename Current Read-Only Shim

- Move `shims/opnsense-mcp-server` to `shims/opnsense-mcp-read-only`.
- Move `shims/opnsense-mcp-server.conf` to
  `shims/opnsense-mcp-read-only.conf`.
- Update shell function names and user-facing messages from
  `opnsense-mcp-server` to `opnsense-mcp-read-only`.
- Rename env vars from `SHIMMY_OPNSENSE_MCP_*` to
  `SHIMMY_OPNSENSE_MCP_READ_ONLY_*`.
- Rename default Podman secrets to the read-only names.
- Add `images/opnsense-mcp-read-only/Containerfile` and rebuild the Marien
  implementation as a Shimmy-managed local image from a pinned source ref.
- Use Shimmy's shared custom-image helper for the read-only image build.
- Preserve POSIX shell, `set -eu`, shared Podman helper use, `$PWD:/work`,
  `--preview-shim`, URL validation, SSL preflight behavior, and stdio-friendly
  `-i` runtime mode.

### 2. Add Admin Shim

- Add `shims/opnsense-mcp-admin` as a separate wrapper.
- Confirm Grousset runtime command, upstream env names, package manager, and
  container entrypoint from the upstream repository.
- Check for a suitable published image and supported platforms
  (`linux/amd64` and `linux/arm64`).
- If no suitable image is documented, add
  `images/opnsense-mcp-admin/Containerfile` and build a local image from a
  pinned Grousset source ref using Shimmy's shared custom-image helper.
- Use separate admin image, pull/build, and Podman secret env vars.
- Keep URL preflight and Podman preflight before container startup.
- Add admin-specific help text that warns it is change-capable tooling.

### 3. Installer And Catalog

- Update `lib/repo/shimmy-catalog.sh` supported shim list.
- Remove `opnsense-mcp-server` from supported shim names.
- Add `opnsense-mcp-read-only` and `opnsense-mcp-admin`.
- Keep default installed shims unchanged unless product policy changes later.
- Update `scripts/install-shimmy.sh` behavior where shim names, copied assets,
  or skills depend on the catalog.
- Add migration notes explaining that existing installed profiles must install
  the new shim names and create new secrets.

### 4. Tests

- Rename existing OPNsense preflight tests to target
  `opnsense-mcp-read-only`.
- Add matching admin preflight tests for required `OPNSENSE_URL`, invalid URL,
  unreachable URL, SSL default, and secret selector wiring.
- Assert old `opnsense-mcp-server` is no longer supported by install/status
  flows.
- Update installed-shim tests to install and validate the new names.
- Add local image build tests for read-only and admin local image contexts.
- Keep tests non-mutating. Use `--help`, `--preview-shim`, URL preflight
  failures, and file-content assertions unless an approved live smoke is needed.

### 5. Documentation

- Replace `docs/shims/opnsense-mcp-server.md` with
  `docs/shims/opnsense-mcp-read-only.md`.
- Add `docs/shims/opnsense-mcp-admin.md`.
- Update `README.md` Included Shims table alphabetically.
- Document separate Podman secret creation commands for each shim.
- Document the Shimmy-created Marien image rebuild for
  `opnsense-mcp-read-only`, including source ref, rebuild trigger, and image
  override behavior.
- Document MCP client examples using explicit command names.
- Include selection policy in both OPNsense docs and README.
- Call out that `opnsense-mcp-server` was intentionally removed and is not an
  alias.

### 6. Agent Skills

- Replace `.agents/skills/shimmy-tool-opnsense-mcp` with explicit read-only and
  admin skill directories.
- Preserve relevant OPNsense lessons from the current skill in the read-only
  skill, then add admin-specific change-window and privilege guidance.
- Install/update the generated skills with
  `./shimmy skills install --target repo shimmy-tool-opnsense-mcp-read-only`
  and
  `./shimmy skills install --target repo shimmy-tool-opnsense-mcp-admin`.
- Update plugin skills if the packaged Shimmy plugin is expected to carry these
  tool skills.

### 7. Supported Tool Inventories In Skills

Add compact supported-tool inventories to each OPNsense agent skill so future
agents can route OPNsense prompts with fewer tokens.

Requirements:

- Include exact MCP tool names where useful for routing.
- Organize by capability area, not as a single long unstructured dump.
- Keep the inventory compact enough for skill loading.
- Include a routing note in both skills:
  - prefer read-only when a matching tool exists;
  - use admin only for missing read-only coverage or explicit configuration
    changes.
- Source the inventories from upstream code or machine-readable metadata during
  implementation when feasible. Avoid hand-copying stale lists if the upstream
  exposes tool registration in a parseable form.
- Verification should confirm each skill contains a tool inventory and that the
  inventories distinguish overlapping read-only/admin capabilities.

Suggested inventory sections:

- System and firmware
- Interfaces and gateways
- Firewall rules, aliases, NAT, states, and logs
- DNS, DHCP, leases, and resolver data
- VPN
- Services and plugins
- Diagnostics
- Configuration backup, history, and apply/revert behavior
- Admin-only create/update/delete actions

## Risks

- The read-only and admin upstreams may not publish maintained multi-arch
  images. Mitigate by using pinned local builds and documenting source refs.
- Tool counts and exact tool names may drift upstream. Mitigate by deriving the
  agent skill inventories from upstream code during implementation where
  practical, and documenting the source commit/ref used.
- Removing `opnsense-mcp-server` is a breaking change. Backwards compatibility / migration notes is not required.
- Sharing credentials between read-only and admin would defeat the split.
  Mitigate with separate default Podman secret names and tests for secret
  selector wiring.
- Switching from read-only to admin on privilege errors would weaken the safety
  model. Mitigate with explicit skill guidance and docs. 
- Switching from read-only to admin should always include a user-prompt alerting to risks and requesting explicit approval/elevation

## Verification Plan

- Run POSIX parse checks over new and renamed shell scripts.
- Run targeted `scripts/test-shimmy.sh` checks for catalog/install/profile
  behavior and OPNsense shim preflight behavior.
- Run full `./scripts/test-shimmy.sh` before completion if feasible.
- Run non-mutating Podman smoke checks:
  - `./shims/opnsense-mcp-read-only --help`
  - `./shims/opnsense-mcp-read-only --preview-shim`
  - `./shims/opnsense-mcp-admin --help`
  - `./shims/opnsense-mcp-admin --preview-shim`
- Verify both local image build paths with non-mutating smoke commands after
  obtaining any required Podman approval.
- Confirm executable bits are preserved for runtime shims.
- Confirm README, docs, tests, installer, catalog, and agent skills do not
  retain stale `opnsense-mcp-server` command references except in migration
  notes.
