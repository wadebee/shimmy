---
name: shimmy-tool-go
description: Guidance for using, changing, testing, and troubleshooting the Go toolchain shim in this repository, including stdin-friendly execution, Go command smoke checks, and platform-aware container behavior.
---

# Go Shim

Use this skill when working with the Go tool, its tests, its docs, or Go CLI usage through Shimmy.

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
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

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
