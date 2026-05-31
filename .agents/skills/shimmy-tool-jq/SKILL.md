---
name: shimmy-tool-jq
description: Guidance for using, changing, testing, and troubleshooting the jq shim in this repository, including filter-style stdin behavior and jq image/version expectations.
---

# jq Shim

Use this skill when working with `shims/jq`, its tests, its docs, or jq usage through Shimmy.

## Files

- Runtime shim: `../../../shims/jq`
- User docs: `../../../docs/shims/jq.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_PROFILE_ACTIVE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: `ghcr.io/jqlang/jq:1.8.1`
- Image override: `SHIMMY_JQ_IMAGE`
- Pull override: `SHIMMY_JQ_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work`
- No extra mounts or forwarded env var families
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Keep jq as a filter-style shim with `-i`, not unconditional `-it`.
2. Do not add mounts or env forwarding without a clear jq requirement.
3. Keep exact JSON/filter smoke tests in sync with runtime behavior.
4. Use non-mutating smoke checks such as `jq --version` or filtering a small local JSON file.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/jq --version`
- Filter smoke: run jq against a small local JSON fixture and expect the selected field.
- Pull override smoke keeps `SHIMMY_JQ_IMAGE_PULL=always SHIMMY_JQ_IMAGE=ghcr.io/jqlang/jq:1.8.1` aligned with tests.

## Learning Guidance

- Capture jq-specific lessons here when they affect stdin handling, filter behavior, image tags, or JSON fixture tests.
- Promote reusable Shimmy design lessons to `../shimmy-create/SKILL.md` under `Learning Guidance`.
