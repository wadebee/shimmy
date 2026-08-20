---
name: shimmy-tool-task
description: Guidance for using, changing, testing, and troubleshooting the Task shim in this repository, including local image builds, host path behavior, home/tmp mounts, and Podman socket forwarding for nested workflows.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Task Shim

Use this skill when working with the Task tool, its local image, its tests, its docs, or Taskfile usage through Shimmy.

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
4. Approval scope: require the exact Task command and task names. Do not
   persist a broad `task` prefix because Taskfiles execute arbitrary commands
   with broad read-write host mounts and optional Podman socket access.

## Files

- Tool metadata: `tools/task/tool.conf`
- Concrete runtime: `tools/task/versions/3.45/run.sh`
- User guide: `tools/task/guide.md`
- Tests: `tools/task/tests/task.sh`
- Image context: `tools/task/versions/3.45/container/Containerfile`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `task` normally
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

For source validation, use `./commands/run-tool.sh task --preview-shim --version`
or the concrete `tools/task/versions/3.45/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: locally built `localhost/shimmy-task-3_45:<image-input-hash>-<platform>` from version-owned `image.conf` and `container/`
- Image override: `SHIMMY_TASK_IMAGE`
- Build override: `SHIMMY_TASK_IMAGE_BUILD=always`
- Pull override for image overrides: `SHIMMY_TASK_IMAGE_PULL=always`
- Base image override: `SHIMMY_TASK_BASE_IMAGE`
- Default base: `docker.io/library/alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce`
- Task version override: `SHIMMY_TASK_VERSION`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mounts:
  - `$PWD` to `$PWD:rw`
  - `$PWD` to `/work:rw`
  - `$HOME` to `$HOME:rw` when present
  - `/tmp` to `/tmp:rw` when present
  - `CONTAINER_HOST` Unix socket when explicitly set and present
- Forwarded env:
  - `HOME` when the home mount is enabled
  - `SHIMMY_HOST_PATH=$PATH`
  - `CONTAINER_HOST` when explicitly set
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

A non-empty `CONTAINER_HOST` or `CONTAINER_CONNECTION` masks Podman's selected
connection and blocks deterministic profile activation. Use `profile status`
to identify only the masking variable name, never print its value, and ask the
user to unset it before activation. Restore `CONTAINER_HOST` afterward only
when the Task invocation intentionally needs that socket forwarded for a
nested container workflow.

## Change Rules

1. Preserve the `$PWD` to `$PWD` mount and working directory behavior; Taskfiles often expect host-relative paths.
2. Treat `$HOME`, `/tmp`, and `CONTAINER_HOST` forwarding as deliberate host-coupling. Keep tests and docs aligned if changed.
3. Keep package installation inside `tools/task/versions/3.45/container/Containerfile`, not the tool dispatcher.
4. Use `SHIMMY_TASK_IMAGE` only as a full runtime image override; local build args apply only to Shimmy-built images.
5. Use non-mutating smoke checks such as `task --version` or `task --list`.
6. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
7. Update the runtime shim, local image, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./commands/run-tool.sh task --version`
- Installed smoke: install the task shim and run the installed wrapper with `--version`.
- For Taskfile behavior changes, prefer `task --list` before running tasks with side effects.

## Learning Guidance

- Capture Task-specific lessons here when they affect host path expectations, nested Podman access, home/tmp mounts, image builds, or Taskfile side-effect safety.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
