---
name: shimmy-tool-gdrive
description: Guidance for using, changing, testing, and troubleshooting the gdrive MCP server shim in this repository, including local image builds from isaacphi/mcp-gdrive and OAuth credential mounts.
---

# gdrive Shim

Use this skill when working with `shims/gdrive`, its local image, its tests, its docs, or Google Drive MCP usage through Shimmy.

## Files

- Kind dispatcher: `../../../shims/gdrive`
- Version shim: `../../../shims/gdrive_0_2`
- Local image: `../../../images/gdrive_0_2/Containerfile`
- User docs: `../../../docs/shims/gdrive.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `gdrive --help` and inspect the invoking profile with `shimmy status --format manifest`. To validate `upstream`, first activate its absolute `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/bin/shimmy` launcher, then run `gdrive --help` without a profile selector. Use repo-local paths such as `./shims/gdrive` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: locally built `localhost/shimmy-gdrive-0_2:<context-hash>-<platform>` from `isaacphi/mcp-gdrive`
- Source ref: `SHIMMY_GDRIVE_SOURCE_REF`, default `5a94bdcb751975f9f6552d261da35314baf89c43`
- Image override: `SHIMMY_GDRIVE_IMAGE`
- Build override: `SHIMMY_GDRIVE_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_GDRIVE_IMAGE_PULL=always`
- OAuth callback port override: `SHIMMY_GDRIVE_AUTH_PORT`, default `3000`
- Base image override: `SHIMMY_GDRIVE_BASE_IMAGE`
- Required upstream env: `CLIENT_ID`, `CLIENT_SECRET`, `GDRIVE_CREDS_DIR`
- Runtime mode: stdio-friendly via `podman run --rm -i`
- Mounts:
  - `$PWD` to `/work:rw`
  - `GDRIVE_CREDS_DIR` to the same container path, read-write
- Port publishing:
  - `127.0.0.1:${SHIMMY_GDRIVE_AUTH_PORT:-3000}:3000` when `.gdrive-server-credentials.json` is missing
  - no published ports after credentials exist
- Forwarded env:
  - `CLIENT_ID`
  - `CLIENT_SECRET`
  - `GDRIVE_CREDS_DIR`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep OAuth credentials in a host directory mounted through `GDRIVE_CREDS_DIR`; do not bake credentials into the image.
2. Keep package installation and source checkout in `../../../images/gdrive_0_2/Containerfile`, not the kind dispatcher.
3. Use `SHIMMY_GDRIVE_IMAGE` only as a full runtime image override; local build args apply only to Shimmy-built images.
4. Keep `--help` wrapper-level so smoke tests do not start browser OAuth.
5. Preserve first-time auth port publishing unless upstream stops using a localhost browser callback.
6. Update the runtime shim, local image, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/gdrive --help`
- Rebuild smoke: `SHIMMY_GDRIVE_IMAGE_BUILD=always ./shims/gdrive --help`
- Configuration preflight: run `./shims/gdrive` without `CLIENT_ID`, `CLIENT_SECRET`, or `GDRIVE_CREDS_DIR` and expect an early error.
- Full MCP validation requires Google OAuth credentials and should use read/search operations unless the user explicitly asks to test Sheets writes.

## Learning Guidance

- `isaacphi/mcp-gdrive` starts OAuth during server startup when no saved token exists, so wrapper help must not enter the upstream Node entrypoint.
- `isaacphi/mcp-gdrive` currently has no release tags. Keep the default local build pinned to a commit SHA and expose `SHIMMY_GDRIVE_SOURCE_REF` for deliberate source upgrades.
- A plain `npm ci` runs the package `prepare` script, which invokes TypeScript and can exceed the default Podman VM memory limit. Because upstream commits `dist/`, prefer `npm ci --omit=dev --ignore-scripts` and copy the committed `dist/` into the runtime image.
- First-time OAuth needs the upstream localhost callback reachable from the host browser. Publish `127.0.0.1:${SHIMMY_GDRIVE_AUTH_PORT:-3000}:3000` only when `.gdrive-server-credentials.json` is absent; normal MCP stdio runs should not publish a port.
