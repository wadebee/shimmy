---
name: shimmy-tool-netcat
description: Guidance for using, changing, testing, and troubleshooting the Netcat/Ncat shim in this repository, including local image build behavior and network debugging safety.
---

# Netcat Shim

Use this skill when working with `shims/netcat`, its local image, its tests, its docs, or Netcat/Ncat usage through Shimmy.

## Files

- Runtime shim: `../../../shims/netcat`
- Local image: `../../../images/netcat/Containerfile`
- User docs: `../../../docs/shims/netcat.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Current Behavior

- Default image: locally built `localhost/shimmy-netcat:<context-hash>-<platform>`
- Image override: `SHIMMY_NETCAT_IMAGE`
- Build override: `SHIMMY_NETCAT_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_NETCAT_IMAGE_PULL=always`
- Base image override: `SHIMMY_NETCAT_BASE_IMAGE`
- Default base image: `registry.access.redhat.com/ubi9/ubi-minimal:latest`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work:rw`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep package installation inside `../../../images/netcat/Containerfile`, not the runtime shim.
2. Use `SHIMMY_NETCAT_IMAGE` only as a full runtime image override; local build args apply only to Shimmy-built images.
3. Keep `SHIMMY_NETCAT_IMAGE_PULL=always` scoped to external image overrides.
4. Treat network probes as potentially environment-specific. Prefer `netcat --help` for routine validation.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, local image, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/netcat --help`
- Local build validation may pull or build images; use it only when the task changes image behavior.

## Learning Guidance

- Capture Netcat-specific lessons here when they affect local image builds, base image choice, network probe behavior, stdin, or ncat package behavior.
- Promote reusable Shimmy design lessons to `../shimmy-create/SKILL.md` under `Learning Guidance`.
