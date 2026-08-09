---
name: shimmy-tool-task
description: Guidance for using, changing, testing, and troubleshooting the Task shim in this repository, including local image builds, host path behavior, home/tmp mounts, and Podman socket forwarding for nested workflows.
---

# Task Shim

Use this skill when working with the Task tool, its local image, its tests, its docs, or Taskfile usage through Shimmy.

## Files

- Kind metadata: `../../../tools/task/tool.conf`
- Concrete runtime: `../../../tools/task/versions/3.45/run.sh`
- User guide: `../../../tools/task/guide.md`
- Tests: `../../../tools/task/tests/task.sh`
- Image context: `../../../tools/task/versions/3.45/container/Containerfile`
- Repository suite: `../../../tests/test.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `task` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

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

## Change Rules

1. Preserve the `$PWD` to `$PWD` mount and working directory behavior; Taskfiles often expect host-relative paths.
2. Treat `$HOME`, `/tmp`, and `CONTAINER_HOST` forwarding as deliberate host-coupling. Keep tests and docs aligned if changed.
3. Keep package installation inside `../../../tools/task/versions/3.45/container/Containerfile`, not the kind dispatcher.
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
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
