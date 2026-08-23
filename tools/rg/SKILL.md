---
name: shimmy-tool-rg
description: Guidance for using, changing, testing, and troubleshooting the ripgrep shim in this repository, including stdin-friendly search behavior and rg image/version expectations.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# ripgrep Shim

Use this skill when working with the ripgrep tool, its tests, its docs, or ripgrep usage through Shimmy.

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
4. Approval scope: `["rg"]` is an acceptable bounded persistent prefix for
   read-only repository search and listing. Shell redirection or any
   surrounding mutating command requires its own authorization.

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
and inspect the invoking profile with `shimmy profile status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate <name>` command. Running containers
require separate explicit confirmation before adding `--stop-running`. Shimmy's
control plane owns shared and isolated engine lifecycle; a missing recorded
machine is not recreated or adopted. Agents never run direct Podman machine
lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To inspect a named profile, use its
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>`.

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
5. If the `rg` Shimmy wrapper is sandbox-blocked, retry the same search through
   the `shimmy-escalation` workflow before inspecting profile activation or
   using `find`, `grep`, or host-installed search tools. Use `shimmy-init` only
   if the escalated wrapper call still proves a profile or engine failure.
6. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh rg --version`
- Search/list smoke: `./commands/run-tool.sh rg --files`
- For repeated read-only installed searches, `["rg"]` is a bounded persistent
  approval prefix. Keep smoke-only and repo-local approvals scoped to their
  exact commands, such as `["rg","--version"]` or
  `["./commands/run-tool.sh","rg","--version"]`.

## Learning Guidance

- Capture ripgrep-specific lessons here when they affect search/list behavior, ignore-file handling, image tags, stdin, or AI Agent search fallback policy.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
