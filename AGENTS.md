## Scope

This repository packages and makes common CLI tools available to your shell as small wrappers that call `podman run`.

## Personality

Drop all affect, be objective, succinct and provide practical advice.

Question requests that materially differ from your training of best practices by:
1. Searching the web for information added after your knowledge cutoff using your search tools. Synthesize any such responses explicitly citing your sources.
2. Challenging the user to adopt a different approach that more closely aligns with standards.

## Project Map

- Read `CONTEXT.md` and every child context on the path to a changed file.
- Tool runtime, metadata, guides, and concrete versions live in `tools/<kind>/`.
- Shared modules live in `core/`.
- Management entrypoints live in `commands/`.
- Behavioral tests live in `tests/`.
- Contributor guidance lives in `CONTRIBUTING.md`.
- The reusable project prompt lives in `docs/prompt-shimmy-project.md`.

## Available Shim Skills

- Generic shim template: `docs/templates/generic-shim/`
- AWS tool: `tools/aws/`
- jq tool: `tools/jq/`
- ripgrep tool: `tools/rg/`
- Terraform tool: `tools/terraform/`

## Working Rules

- Read `CONTRIBUTING.md` before making repo changes.
- Follow the naming conventions in `CONTRIBUTING.md` for files, functions, and variables.
- Keep runtime shims as small POSIX shell wrappers with `#!/bin/sh` and `set -eu`.
- Do not propose or implement Go, Rust, Python, or other language rewrites for Shimmy core behavior or runtime shims unless the user explicitly asks to leave the POSIX shell architecture.
- Mount `$PWD` to `/work` unless the shim has a documented reason not to.
- Use `SHIMMY_{TOOL_PREFIX}_IMAGE` for image override and `SHIMMY_{TOOL_PREFIX}_IMAGE_PULL=always` for pull policy.
- Use Shimmy's shared Podman helper for runtime platform selection instead of hardcoding per-shim OS or architecture checks.
- Any Shimmy-defined user-facing environment variable must use the `SHIMMY_` prefix, including image overrides, pull or build flags, opt-in behavior switches, and secret-name selectors.
- Update shim helper code, install script, tests, and README together when behavior changes.
- Treat Podman as an explicit dependency. Do not add Shimmy-side installation or provisioning steps for it.
- On macOS, remember the official Podman pkg installer may place the binary at `/opt/podman/bin/podman`. If automation cannot find `podman`, check that `/opt/podman/bin` is on `PATH`.
- When testing containers, use live Podman and non-mutating cli calls (eg: version or --help) to validate execution  
- Ensure runnable shell files keep executable bits.
- It is important that you use Shimmy tools when available. This requires Podman to be running.
- If a Shimmy-backed tool exists for a task and the wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, do not silently fall back to host tools for the same capability. Use the `shimmy-escalation` workflow and request approval for the exact outer wrapper command prefix. For search or listing work, if `rg` is available as a Shimmy shim and fails, request approval for the needed `rg` wrapper prefix before using alternatives such as `find`, `grep`, or host-installed search tools. Use a non-shim fallback only after the user explicitly approves it, preferably with the phrase `fallback approved`.
- For activated installed shims, invoke the normal tool name such as `rg` or `jq`; do not call the resolved installed shim path. For source previews, use `./commands/run-tool.sh <tool> --preview-shim ...` or the concrete version runtime named by that tool's context.
- When running repo commands, invoke them directly with `exec_command` `login=false` unless profile or startup-file behavior is explicitly under test. Do not use `bash -lc` or login shells for Shimmy commands unless needed.
- In AI Agent environments, approvals are evaluated on the outer command. If `podman info` succeeds but a Shimmy-backed tool still reports Podman-unreachable or sandbox-permission symptoms, use the `shimmy-escalation` workflow before asking the user for a Podman remediation plan. For availability smoke checks, request approval for the exact dry-run command prefix such as `["rg","--version"]`, `["jq","--version"]`, or `["./commands/run-tool.sh","rg","--version"]`; approval for `["podman", "info"]` alone does not approve nested Podman access through a wrapper.
