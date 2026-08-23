---
name: shimmy-tool-jq
description: Guidance for using, changing, testing, and troubleshooting the jq shim in this repository, including filter-style stdin behavior and jq image/version expectations.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# jq Shim

Use this skill when working with the jq tool, its tests, its docs, or jq usage through Shimmy.

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
4. Approval scope: `["jq"]` is an acceptable bounded persistent prefix for
   local JSON filtering. Shell redirection or any surrounding mutating command
   remains outside that approval and requires its own authorization.

## Files

- Tool metadata: `tools/jq/tool.conf`
- Concrete runtime: `tools/jq/versions/1.8/run.sh`
- User guide: `tools/jq/guide.md`
- Tests: `tools/jq/tests/jq.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `jq` normally
and inspect the invoking profile with `shimmy profile status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate <name>` command. Running containers
require separate explicit confirmation before adding `--stop-running`. Shimmy's
control plane owns shared and isolated engine lifecycle; a missing recorded
machine is not recreated or adopted. Agents never run direct Podman machine
lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To inspect a named profile, use its
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>`.

For source validation, use `./commands/run-tool.sh jq --preview-shim --version`
or the concrete `tools/jq/versions/1.8/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: `ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91` from version-owned `image.conf`
- Image override: `SHIMMY_JQ_IMAGE`
- Pull override: `SHIMMY_JQ_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work`
- No extra mounts or forwarded env var families
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Keep jq as a filter-style shim with `-i`, not unconditional `-it`.
2. Do not add mounts or env forwarding without a clear jq requirement.
3. Keep exact JSON/filter smoke tests in sync with runtime behavior.
4. Use non-mutating smoke checks such as `jq --version` or filtering a small local JSON file.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh jq --version`
- Filter smoke: run jq against a small local JSON fixture and expect the selected field.
- Pull override smoke keeps `SHIMMY_JQ_IMAGE_PULL=always` plus an explicit `SHIMMY_JQ_IMAGE` override aligned with tests.

## Learning Guidance

- Capture jq-specific lessons here when they affect stdin handling, filter behavior, image tags, or JSON fixture tests.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
