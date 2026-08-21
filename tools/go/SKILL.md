---
name: shimmy-tool-go
description: Guidance for using, changing, testing, and troubleshooting the Go toolchain shim in this repository, including stdin-friendly execution, Go command smoke checks, and platform-aware container behavior.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Go Shim

Use this skill when working with the Go tool, its tests, its docs, or Go CLI usage through Shimmy.

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
4. Approval scope: require the exact Go command. Do not persist a broad `go`
   prefix because builds, generators, tests, module downloads, and formatting
   can execute code, access the network, or modify the project.

## Files

- Tool metadata: `tools/go/tool.conf`
- Concrete runtime: `tools/go/versions/1.26/run.sh`
- User guide: `tools/go/guide.md`
- Tests: `tools/go/tests/go.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `go` normally
and inspect the invoking profile with `shimmy profile status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate <name>` command. Running containers
require separate explicit confirmation before adding `--stop-running`. A missing
machine must be provisioned by the user in a normal shell with the exact
`podman machine init shimmy-<profile>` guidance; agents never run direct Podman
machine lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To inspect a named profile, use its
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>`.

For source validation, use `./commands/run-tool.sh go --preview-shim version`
or the concrete `tools/go/versions/1.26/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: `docker.io/library/golang@sha256:f96cc555eb8db430159a3aa6797cd5bae561945b7b0fe7d0e284c63a3b291609` from version-owned `image.conf`
- Image override: `SHIMMY_GO_IMAGE`
- Pull override: `SHIMMY_GO_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Entrypoint override: `--entrypoint go`
- Mount: `$PWD` to `/work`
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Keep the shim stdin-friendly so commands such as `go help test` stay clean in scripts.
2. Preserve the `go` entrypoint override unless the image strategy changes deliberately.
3. Avoid adding host cache or module mounts unless the task explicitly accepts the host-coupling tradeoff.
4. Use non-mutating smoke checks such as `go version`, `go help test`, or `go env GOARCH`.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh go version`
- Help smoke: `./commands/run-tool.sh go help test`
- Platform smoke: `./commands/run-tool.sh go env GOARCH`
- Expected platform output is `amd64` on Linux and `arm64` on macOS.

## Learning Guidance

- Capture Go-specific lessons here when they affect module behavior, cache strategy, entrypoint behavior, platform output, or toolchain image selection.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
