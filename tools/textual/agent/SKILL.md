---
name: shimmy-tool-textual
description: Guidance for using, changing, testing, and troubleshooting the Textual developer CLI shim in this repository, including local image builds, TTY behavior, and Textual app diagnostics.
---

# Textual Shim

Use this skill when working with the Textual tool, its local image, its tests, its docs, or Textual CLI usage through Shimmy.

## Files

- Kind metadata: `../../../tools/textual/tool.conf`
- Concrete runtime: `../../../tools/textual/versions/8.2/run.sh`
- User guide: `../../../tools/textual/guide.md`
- Tests: `../../../tools/textual/tests/textual.sh`
- Image context: `../../../tools/textual/versions/8.2/container/Containerfile`
- Repository suite: `../../../tests/test.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `textual` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

For source validation, use `./commands/run-tool.sh textual --preview-shim --help`
or the concrete `tools/textual/versions/8.2/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: locally built `localhost/shimmy-textual-8_2:<context-hash>-<platform>`
- Image override: `SHIMMY_TEXTUAL_IMAGE`
- Build override: `SHIMMY_TEXTUAL_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_TEXTUAL_IMAGE_PULL=always`
- Base image override: `SHIMMY_TEXTUAL_BASE_IMAGE`
- Textual version override: `SHIMMY_TEXTUAL_VERSION`
- Default base image: `python:3.13-slim-bookworm`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mount: `$PWD` to `/work:rw`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep package installation inside `../../../tools/textual/versions/8.2/container/Containerfile`, not the kind dispatcher.
2. Preserve TTY detection; Textual apps often need a terminal, while scripted help checks should remain clean.
3. Use `SHIMMY_TEXTUAL_IMAGE` only as a full runtime image override; local build args apply only to Shimmy-built images.
4. Treat `textual run` and `textual serve` as interactive or potentially long-running commands.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, local image, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh textual --help`
- Diagnostics smoke: `./commands/run-tool.sh textual diagnose` when environment details are useful and output size is acceptable.

## Learning Guidance

- Capture Textual-specific lessons here when they affect TTY behavior, local image builds, app execution, browser serving, diagnostics, or Python base image choice.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
