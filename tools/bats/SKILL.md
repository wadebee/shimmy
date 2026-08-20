---
name: shimmy-tool-bats
description: Guidance for using, changing, testing, and troubleshooting the Bats Shimmy tool, including shell-test execution, interactive I/O, and image/version expectations.
---

# Bats Shim

Use this skill when working with the Bats tool, its tests, its docs, or Bats usage through Shimmy.

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
4. Approval scope: require the exact Bats command. Do not persist a broad
   `bats` prefix because test execution can run arbitrary shell code from the
   mounted project and may modify local files.

## Files

- Tool metadata: `tools/bats/tool.conf`
- Concrete runtime: `tools/bats/versions/1.14/run.sh`
- Image metadata: `tools/bats/versions/1.14/image.conf`
- User guide: `tools/bats/guide.md`
- Tests: `tools/bats/tests/bats.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

Install this opt-in tool with `shimmy install --shim bats`. When the installed
profile is selected on `PATH`, invoke `bats` normally and inspect the invoking
profile with `shimmy status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate --dry-run`, then request approval
for the exact `"$profile_root/bin/shimmy" profile activate` command. Require
separate confirmation before adding `--stop-running`. The user provisions any
missing Podman machine in a normal shell; agents do not create, replace,
rename, adopt, start, or delete machines.

After activation, source `"$profile_root/shell-init.sh"` to select PATH. AI
Agent calls do not retain earlier sourcing, so use the absolute profile
dispatcher or source `shell-init.sh` in the same command. For source
validation, use `./commands/run-tool.sh bats --preview-shim --version` or the
concrete `tools/bats/versions/1.14/run.sh` runtime.

## Current Behavior

- Public command: `bats`.
- Default image: `docker.io/bats/bats@sha256:5322b877351fda0cc435de8c6116de7d0a2ec79d7c680132a0ef329a633bc66f`.
- Image override: `SHIMMY_BATS_IMAGE`.
- Pull override: `SHIMMY_BATS_IMAGE_PULL=always`.
- Runtime mode: stdin is always open; `-t` is added only when stdin and stdout are terminals.
- Mount: `$PWD` to `/work` read-write, with `/work` as the working directory.
- State: no host home, credentials, or extra configuration directories are mounted.
- Platform: the shared Podman helper selects native `linux/amd64` or `linux/arm64`.

## Safety Rules

1. Treat any Bats run as execution of project shell code with read-write access to the mounted working tree.
2. Require exact-command approval for installed execution because `bats` can run arbitrary test helpers and fixture setup.
3. Do not add host home, credential, or cache mounts without a separate reviewed design.
4. Keep the runtime stdin-friendly and allocate a TTY only when both stdin and stdout are terminals.
5. Use non-mutating smoke checks such as `bats --version` for runtime validation.
6. If the Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.

## Validation

- Preview: `./commands/run-tool.sh bats --preview-shim --version`
- Direct smoke: `./commands/run-tool.sh bats --version`
- Image verification: `./commands/images.sh verify --shim bats --public-only`
- Focused preview contract: run `test_tools_bats_run` through `./tests/test.sh`
- Full suite: `./tests/test.sh`

Native feature acceptance requires the version-owned smoke on Linux `amd64`
and Apple Silicon macOS `arm64`; previews and cross-emulation do not replace
either host result. Do not generate or edit `.agents/skills/` adapters as part
of tool changes.
