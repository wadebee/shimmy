# Task Shim

## Upstream

- Source repo README: <https://github.com/go-task/task/blob/main/README.md>
- Latest release: <https://github.com/go-task/task/releases/latest>
- Docs: <https://taskfile.dev/>
- Shim image: local build from `versions/3.45/image.conf` and `container/`

## Upstream README Summary

Task is a task runner and build tool configured with `Taskfile.yml`. The upstream README positions Task as a simpler, cross-platform alternative to Make, with shell commands, dependencies, variables, includes, and reusable task definitions.

## Top-Level Command Summary

- `task` - run the default task or named tasks.
- `task --list` - list available tasks.
- `task --summary TASK` - show details for a task.
- `task --watch TASK` - rerun when files change.
- `task --init` - create a starter Taskfile.
- `task --version` - show version information.

## Shimmy Usage

```sh
task --version
task --list
task test
```

Environment:

- `SHIMMY_TASK_IMAGE` - override the runtime image entirely.
- `SHIMMY_TASK_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `SHIMMY_TASK_IMAGE_PULL=always` - force pulling `SHIMMY_TASK_IMAGE` when using an override.
- `SHIMMY_TASK_BASE_IMAGE` - override the configured base image. Default: `docker.io/library/alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce`.
- `SHIMMY_TASK_VERSION` - override the Task release version. Default: `v3.45.5`.

Local image behavior:

- Shimmy builds `localhost/shimmy-task-3_45:<image-input-hash>-<platform>` from the version's `image.conf`, effective build arguments, and `container/`.

Mounts:

- `$PWD` -> `$PWD` read-write.
- `$PWD` -> `/work` read-write.
- `$HOME` -> `$HOME` read-write when it exists.
- `/tmp` -> `/tmp` read-write when it exists.

Forwarded environment:

- `CONTAINER_HOST` when explicitly set.
- `SHIMMY_HOST_PATH`.
- `HOME` when the home directory mount is enabled.

`CONTAINER_HOST` and `CONTAINER_CONNECTION` also override Podman's selected
connection, so any non-empty value blocks deterministic `shimmy profile
activate`. Inspect `shimmy profile status`; it reports only the masking variable
name and never its value. Unset the conflicting variable before activation.
After activation, set `CONTAINER_HOST` again only when a Taskfile intentionally
needs that explicit socket forwarded into nested container workflows. Do not
print either variable's contents while troubleshooting.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `task --list` and explain what automation tasks are available for this home lab repo."
- Software dev: "Run the default Taskfile test workflow and summarize the first failing command."
- Platform engineer: "Inspect the Taskfile and identify deployment tasks, required variables, and side effects."
