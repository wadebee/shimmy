---
name: shimmy-tool-textual
description: Guidance for using, changing, testing, and troubleshooting the Textual developer CLI shim in this repository, including local image builds, TTY behavior, and Textual app diagnostics.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Textual Shim

Use this skill when working with the Textual tool, its local image, its tests, its docs, or Textual CLI usage through Shimmy.

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
4. Approval scope: require the exact Textual command and application target.
   Do not persist a broad prefix because `run` and `serve` execute project code
   and may start long-running or network-accessible services.

## Files

- Tool metadata: `tools/textual/tool.conf`
- Concrete runtime: `tools/textual/versions/8.2/run.sh`
- User guide: `tools/textual/guide.md`
- Tests: `tools/textual/tests/textual.sh`
- Image context: `tools/textual/versions/8.2/container/Containerfile`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `textual` normally
and inspect the invoking profile with `shimmy profile status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate <name> --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate <name>` command. Running containers
require separate explicit confirmation before adding `--stop-running`. A missing
machine must be provisioned by the user in a normal shell with the exact
`podman machine init shimmy-<profile>` guidance; agents never run direct Podman
machine lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To inspect a named profile, use its
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>`.

For source validation, use `./commands/run-tool.sh textual --preview-shim --help`
or the concrete `tools/textual/versions/8.2/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: locally built `localhost/shimmy-textual-8_2:<image-input-hash>-<platform>` from version-owned `image.conf` and `container/`
- Image override: `SHIMMY_TEXTUAL_IMAGE`
- Build override: `SHIMMY_TEXTUAL_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_TEXTUAL_IMAGE_PULL=always`
- Base image override: `SHIMMY_TEXTUAL_BASE_IMAGE`
- Textual version override: `SHIMMY_TEXTUAL_VERSION`
- Default base image: `docker.io/library/python@sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mount: `$PWD` to `/work:rw`
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Keep package installation inside `tools/textual/versions/8.2/container/Containerfile`, not the tool dispatcher.
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
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
