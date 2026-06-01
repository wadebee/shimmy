---
name: shimmy-tool-textual
description: Guidance for using, changing, testing, and troubleshooting the Textual developer CLI shim in this repository, including local image builds, TTY behavior, and Textual app diagnostics.
---

# Textual Shim

Use this skill when working with `shims/textual`, its local image, its tests, its docs, or Textual CLI usage through Shimmy.

## Files

- Runtime shim: `../../../shims/textual`
- Local image: `../../../images/textual/Containerfile`
- User docs: `../../../docs/shims/textual.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_PROFILE_ACTIVE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: locally built `localhost/shimmy-textual:<context-hash>-<platform>`
- Image override: `SHIMMY_TEXTUAL_IMAGE`
- Build override: `SHIMMY_TEXTUAL_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_TEXTUAL_IMAGE_PULL=always`
- Base image override: `TEXTUAL_BASE_IMAGE`
- Default base image: `python:3.13-slim-bookworm`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mount: `$PWD` to `/work:rw`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep package installation inside `../../../images/textual/Containerfile`, not the runtime shim.
2. Preserve TTY detection; Textual apps often need a terminal, while scripted help checks should remain clean.
3. Use `SHIMMY_TEXTUAL_IMAGE` only as a full runtime image override; local build args apply only to Shimmy-built images.
4. Treat `textual run` and `textual serve` as interactive or potentially long-running commands.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, local image, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/textual --help`
- Diagnostics smoke: `./shims/textual diagnose` when environment details are useful and output size is acceptable.

## Learning Guidance

- Capture Textual-specific lessons here when they affect TTY behavior, local image builds, app execution, browser serving, diagnostics, or Python base image choice.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
