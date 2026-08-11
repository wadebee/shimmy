---
name: shimmy-tool-jq
description: Guidance for using, changing, testing, and troubleshooting the jq shim in this repository, including filter-style stdin behavior and jq image/version expectations.
---

# jq Shim

Use this skill when working with the jq tool, its tests, its docs, or jq usage through Shimmy.

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
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

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
