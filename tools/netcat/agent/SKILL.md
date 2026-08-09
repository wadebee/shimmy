---
name: shimmy-tool-netcat
description: Guidance for using, changing, testing, and troubleshooting the Netcat/Ncat shim in this repository, including local image build behavior and network debugging safety.
---

# Netcat Shim

Use this skill when working with the Netcat tool, its local image, its tests, its docs, or Netcat/Ncat usage through Shimmy.

## Files

- Kind metadata: `../../../tools/netcat/tool.conf`
- Concrete runtime: `../../../tools/netcat/versions/7.92/run.sh`
- User guide: `../../../tools/netcat/guide.md`
- Tests: `../../../tools/netcat/tests/netcat.sh`
- Image context: `../../../tools/netcat/versions/7.92/container/Containerfile`
- Repository suite: `../../../tests/test.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `netcat` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

For source validation, use `./commands/run-tool.sh netcat --preview-shim --help`
or the concrete `tools/netcat/versions/7.92/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: locally built `localhost/shimmy-netcat-7_92:<context-hash>-<platform>`
- Image override: `SHIMMY_NETCAT_IMAGE`
- Build override: `SHIMMY_NETCAT_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_NETCAT_IMAGE_PULL=always`
- Base image override: `SHIMMY_NETCAT_BASE_IMAGE`
- Default base image: `registry.access.redhat.com/ubi9/ubi-minimal:latest`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work:rw`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep package installation inside `../../../tools/netcat/versions/7.92/container/Containerfile`, not the kind dispatcher.
2. Use `SHIMMY_NETCAT_IMAGE` only as a full runtime image override; local build args apply only to Shimmy-built images.
3. Keep `SHIMMY_NETCAT_IMAGE_PULL=always` scoped to external image overrides.
4. Treat network probes as potentially environment-specific. Prefer `netcat --help` for routine validation.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, local image, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh netcat --help`
- Local build validation may pull or build images; use it only when the task changes image behavior.

## Learning Guidance

- Capture Netcat-specific lessons here when they affect local image builds, base image choice, network probe behavior, stdin, or ncat package behavior.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
