---
name: shimmy-tool-gdrive
description: Guidance for using, changing, testing, and troubleshooting the gdrive MCP server shim in this repository, including local image builds from isaacphi/mcp-gdrive and OAuth credential mounts.
---

# gdrive Shim

Use this skill when working with the gdrive tool, its local image, its tests, its docs, or Google Drive MCP usage through Shimmy.

## AI Agent Evidence Order

1. If the installed wrapper's safe outer-command prefix is already approved,
   run the actual requested operation with escalation on the first attempt. Do
   not first run a sandboxed Podman call or a version smoke.
2. Treat a sandbox-only unreachable, unknown, socket-denied, or
   `operation not permitted` result as `unverified from the sandbox`, not as an
   inactive profile. Retry the same wrapper operation through
   `shimmy-escalation` before profile inspection or fallback.
3. Use `shimmy-init` only if the escalated wrapper still proves a
   profile-affinity, engine, connection, or registry-projection failure. Never
   activate a profile automatically from sandbox-only evidence.
4. Approval scope: require the exact wrapper startup, including its credential
   and callback configuration. Wrapper approval authorizes MCP server startup,
   not Google Drive or Sheets writes; authorize those operations separately.

## Files

- Tool metadata: `tools/gdrive/tool.conf`
- Concrete runtime: `tools/gdrive/versions/0.2/run.sh`
- User guide: `tools/gdrive/guide.md`
- Tests: `tools/gdrive/tests/gdrive.sh`
- Image context: `tools/gdrive/versions/0.2/container/Containerfile`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `gdrive` normally
and inspect the invoking profile with `shimmy status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate` command. Running containers
require separate explicit confirmation before adding `--stop-running`. A missing
machine must be provisioned by the user in a normal shell with the exact
`podman machine init shimmy-<profile>` guidance; agents never run direct Podman
machine lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To test `upstream`, use the
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream`.

For source validation, use `./commands/run-tool.sh gdrive --preview-shim --help`
or the concrete `tools/gdrive/versions/0.2/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: locally built `localhost/shimmy-gdrive-0_2:<image-input-hash>-<platform>` from version-owned `image.conf`, `container/`, and `isaacphi/mcp-gdrive`
- Source ref: `SHIMMY_GDRIVE_SOURCE_REF`, default `5a94bdcb751975f9f6552d261da35314baf89c43`
- Image override: `SHIMMY_GDRIVE_IMAGE`
- Build override: `SHIMMY_GDRIVE_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_GDRIVE_IMAGE_PULL=always`
- OAuth callback port override: `SHIMMY_GDRIVE_AUTH_PORT`, default `3000`
- Base image override: `SHIMMY_GDRIVE_BASE_IMAGE`
- Default base: `docker.io/library/node@sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32`
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
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Keep OAuth credentials in a host directory mounted through `GDRIVE_CREDS_DIR`; do not bake credentials into the image.
2. Keep package installation and source checkout in `tools/gdrive/versions/0.2/container/Containerfile`, not the tool dispatcher.
3. Use `SHIMMY_GDRIVE_IMAGE` only as a full runtime image override; local build args apply only to Shimmy-built images.
4. Keep `--help` wrapper-level so smoke tests do not start browser OAuth.
5. Preserve first-time auth port publishing unless upstream stops using a localhost browser callback.
6. Update the runtime shim, local image, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh gdrive --help`
- Rebuild smoke: `SHIMMY_GDRIVE_IMAGE_BUILD=always ./commands/run-tool.sh gdrive --help`
- Configuration preflight: run `./commands/run-tool.sh gdrive` without `CLIENT_ID`, `CLIENT_SECRET`, or `GDRIVE_CREDS_DIR` and expect an early error.
- Full MCP validation requires Google OAuth credentials and should use read/search operations unless the user explicitly asks to test Sheets writes.

## Learning Guidance

- `isaacphi/mcp-gdrive` starts OAuth during server startup when no saved token exists, so wrapper help must not enter the upstream Node entrypoint.
- `isaacphi/mcp-gdrive` currently has no release tags. Keep the default local build pinned to a commit SHA and expose `SHIMMY_GDRIVE_SOURCE_REF` for deliberate source upgrades.
- A plain `npm ci` runs the package `prepare` script, which invokes TypeScript and can exceed the default Podman VM memory limit. Because upstream commits `dist/`, prefer `npm ci --omit=dev --ignore-scripts` and copy the committed `dist/` into the runtime image.
- First-time OAuth needs the upstream localhost callback reachable from the host browser. Publish `127.0.0.1:${SHIMMY_GDRIVE_AUTH_PORT:-3000}:3000` only when `.gdrive-server-credentials.json` is absent; normal MCP stdio runs should not publish a port.
