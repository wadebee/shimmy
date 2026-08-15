---
name: shimmy-tool-rg
description: Guidance for using, changing, testing, and troubleshooting the ripgrep shim in this repository, including stdin-friendly search behavior and rg image/version expectations.
---

# ripgrep Shim

Use this skill when working with the ripgrep tool, its tests, its docs, or ripgrep usage through Shimmy.

## Files

- Tool metadata: `tools/rg/tool.conf`
- Concrete runtime: `tools/rg/versions/15.1/run.sh`
- User guide: `tools/rg/guide.md`
- Tests: `tools/rg/tests/rg.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `rg` normally
and inspect the invoking profile with `shimmy status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate` command. Running containers
require separate explicit confirmation before adding `--stop-running`. A missing
machine must be provisioned by the user in a normal shell with the exact
`podman machine init shimmy-<profile>` guidance; agents never run direct Podman
machine lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To test `upstream`, use the
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream`.

For source validation, use `./commands/run-tool.sh rg --preview-shim --version`
or the concrete `tools/rg/versions/15.1/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: `docker.io/vszl/ripgrep@sha256:3e12f460f714b3c4ab27f4dbad8b7eda7b8184050c46c15f95eb0f2f53b5818c` from version-owned `image.conf`
- Image override: `SHIMMY_RG_IMAGE`
- Pull override: `SHIMMY_RG_IMAGE_PULL=always`
- Runtime mode: stdin-friendly via `podman run --rm -i`
- Mount: `$PWD` to `/work`
- No extra mounts or forwarded env var families
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Keep ripgrep as a filter/search-style shim with `-i`, not unconditional `-it`.
2. Do not add mounts or env forwarding without a clear ripgrep requirement.
3. Reconcile runtime, docs, README, and tests deliberately if changing the image or tag strategy.
4. Use non-mutating smoke checks such as `rg --version` or `rg --files`.
5. If the `rg` Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using `find`, `grep`, or host-installed search tools.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh rg --version`
- Search/list smoke: `./commands/run-tool.sh rg --files`
- Keep AI Agent approvals scoped to the exact dry-run wrapper prefix such as `["rg","--version"]` or `["./commands/run-tool.sh rg","--version"]`.

## Learning Guidance

- Capture ripgrep-specific lessons here when they affect search/list behavior, ignore-file handling, image tags, stdin, or AI Agent search fallback policy.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
