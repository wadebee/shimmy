# Task Shim

## Upstream

- Source repo README: <https://github.com/go-task/task/blob/main/README.md>
- Latest release: <https://github.com/go-task/task/releases/latest>
- Docs: <https://taskfile.dev/>
- Shim image: local build from `images/task/Containerfile`

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

- `TASK_IMAGE` - override the runtime image entirely.
- `TASK_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `TASK_IMAGE_PULL=always` - force pulling `TASK_IMAGE` when using an override.
- `TASK_BASE_IMAGE` - override the Containerfile base image. Default: `alpine:3.22`.
- `TASK_VERSION` - override the Task release version. Default: `v3.45.5`.

Local image behavior:

- Shimmy builds `localhost/shimmy-task:<context-hash>-<platform>` from `images/task/Containerfile`.

Mounts:

- `$PWD` -> `$PWD` read-write.
- `$PWD` -> `/work` read-write.
- `$HOME` -> `$HOME` read-write when it exists.
- `/tmp` -> `/tmp` read-write when it exists.

Forwarded environment:

- `CONTAINER_HOST` when explicitly set.
- `SHIMMY_HOST_PATH`.
- `HOME` when the home directory mount is enabled.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `task --list` and explain what automation tasks are available for this home lab repo."
- Software dev: "Run the default Taskfile test workflow and summarize the first failing command."
- Platform engineer: "Inspect the Taskfile and identify deployment tasks, required variables, and side effects."
