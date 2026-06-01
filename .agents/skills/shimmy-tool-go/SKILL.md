---
name: shimmy-tool-go
description: Guidance for using, changing, testing, and troubleshooting the Go toolchain shim in this repository, including stdin-friendly execution, Go command smoke checks, and platform-aware container behavior.
---

# Go Shim

Use this skill when working with `shims/go`, its tests, its docs, or Go CLI usage through Shimmy.

## Files

- Runtime shim: `../../../shims/go`
- User docs: `../../../docs/shims/go.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_PROFILE_ACTIVE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: `docker.io/library/golang:latest`
- Image override: `SHIMMY_GO_IMAGE`
- Pull override: `SHIMMY_GO_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Entrypoint override: `--entrypoint go`
- Mount: `$PWD` to `/work`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep the shim stdin-friendly so commands such as `go help test` stay clean in scripts.
2. Preserve the `go` entrypoint override unless the image strategy changes deliberately.
3. Avoid adding host cache or module mounts unless the task explicitly accepts the host-coupling tradeoff.
4. Use non-mutating smoke checks such as `go version`, `go help test`, or `go env GOARCH`.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/go version`
- Help smoke: `./shims/go help test`
- Platform smoke: `./shims/go env GOARCH`
- Expected platform output is `amd64` on Linux and `arm64` on macOS.

## Learning Guidance

- Capture Go-specific lessons here when they affect module behavior, cache strategy, entrypoint behavior, platform output, or toolchain image selection.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
