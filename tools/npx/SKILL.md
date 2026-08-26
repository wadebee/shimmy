---
name: shimmy-tool-npx
description: Guidance for using, changing, testing, and troubleshooting the npx Shimmy tool, including package-execution safety, ephemeral npm state, interactive I/O, and the observational node-llama-cpp GPU diagnostic.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# npx Shim

Use this skill when working with the npx tool, its tests, its documentation, or
npm package execution through Shimmy.

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
4. Approval scope: require the exact package name, pinned version, npx options,
   and arguments. Never persist a broad `npx` prefix because packages execute
   arbitrary code with network and read-write project access.

## Files

- Tool metadata: `tools/npx/tool.conf`
- Concrete runtime: `tools/npx/versions/24.18/run.sh`
- Image metadata: `tools/npx/versions/24.18/image.conf`
- User guide: `tools/npx/guide.md`
- Tests: `tools/npx/tests/npx.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`

## Installed Workflow

Install this opt-in tool with `shimmy shim add npx` for a tracking default or
`shimmy shim add npx@24.18` for an explicitly pinned first default. When the
installed profile is selected on `PATH`, invoke `npx` normally and inspect the
invoking profile with `shimmy profile status --format manifest` and
`shimmy shim list --format manifest`.

Catalog publication changes registry authority without mutating profile pins.
`shimmy profile sync` explicitly adopts registry current, while
`shimmy shim sync npx` uses only the invoking profile's existing catalog pin.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact `"$profile_root/bin/shimmy" profile activate <name>` command. Require
separate confirmation before adding `--stop-running`. Shimmy's control plane
owns shared and isolated engine lifecycle. Agents do not directly create,
replace, rename, adopt, start, or delete machines.

After activation, source `"$profile_root/shell-init.sh"` to select PATH. AI
Agent calls do not retain earlier sourcing, so use the absolute profile
dispatcher or source `shell-init.sh` in the same command. For source
validation, use `./commands/run-tool.sh npx --preview-shim --version` or the
concrete `tools/npx/versions/24.18/run.sh` runtime.

## Current Behavior

- Public command: `npx` only; the image's `node` and `npm` commands are not exposed as shims.
- Default image: `docker.io/library/node@sha256:5711a0d445a1af54af9589066c646df387d1831a608226f4cd694fc59e745059`.
- Image override: `SHIMMY_NPX_IMAGE`.
- Pull override: `SHIMMY_NPX_IMAGE_PULL=always`.
- Runtime mode: stdin is always open; `-t` is added only when stdin and stdout are terminals.
- Entrypoint override: `--entrypoint npx`.
- Mount: `$PWD` to `/work` read-write, with `/work` as the working directory.
- Host CA mapping: configured host-only `SHIMMY_HOST_CA_BUNDLE` is mounted at
  `/tmp/shimmy-host-ca-bundle.pem:ro` and exposed as `NODE_EXTRA_CA_CERTS`.
- State: host home, npm credentials, npm configuration, and persistent caches are not mounted.
- Platform: the shared Podman helper selects native `linux/amd64` or `linux/arm64`.

## Safety Rules

1. Treat every package executed by npx as arbitrary code with network access and read-write access to the current directory.
2. Review package names, pin package versions for repeatability, and avoid sensitive working directories.
3. Do not inject `--yes`; preserve npx's confirmation boundary. Use `--yes` only when the user explicitly intends it.
4. Do not mount host `HOME`, `~/.npm`, npm credentials, or persistent package caches without a separate reviewed design.
5. If host-created `node_modules` contains native macOS artifacts incompatible with Linux, use a clean directory or container-compatible dependencies; do not hide or rewrite project resolution.
6. Keep `npx --yes node-llama-cpp@3.19.1 inspect gpu` observational. The generic image does not provide `/dev/dri`, LibKrun, or patched Mesa/Vulkan support and makes no GPU-acceleration promise.
7. If the Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
8. Preserve Node's additive host CA behavior: `NODE_EXTRA_CA_CERTS` extends
   built-in roots and is read at process startup. Package code that explicitly
   supplies a TLS `ca` option can override it. Keep `SHIMMY_HOST_CA_BUNDLE`
   host-only and do not parse or merge the supplied PEM file.

## Validation

- Preview: `./commands/run-tool.sh npx --preview-shim --version`
- Direct smoke: `./commands/run-tool.sh npx --version`
- Image verification: `shimmy catalog verify --tool npx@24.18 --public-only`
- Focused preview contract: run `test_tools_npx_run` through `./tests/test.sh`
- Full suite: `./tests/test.sh`
- Observational package execution: `./commands/run-tool.sh npx --yes node-llama-cpp@3.19.1 inspect gpu`

Native feature acceptance requires the version-owned smoke on Linux `amd64`
and Apple Silicon macOS `arm64`; previews and cross-emulation do not replace
either host result. Do not generate or edit `.agents/skills/` adapters as part
of tool changes.
