## Scope

This repository packages and makes common CLI tools available to your shell as small wrappers that call `podman run`.

## Execution Model

Always operate in PLAN -> REVIEW -> ACT mode:

- Always produce a plan first.
  - The one exception is if the prompt is a question or a request for information that only requires non-mutating actions such as search.
- When planning:
  - If uncertain, ask clarifying questions instead of guessing.
  - Identify risks, assumptions, and best practices you embrace.
  - Revise the plan if feedback is provided.
- When planning is complete, request user approval to execute the plan, using the harness approval button when available.
- NEVER ACT without user approval.
- Do not deviate from an approved plan without re-review.
- If the user explicitly says to implement, fix, run, or proceed, that counts as plan approval so you may ACT; however, you may NEVER modify files immediately.
- Before acting, read this `AGENTS.md` and follow this execution model.
- After approval, proceed through implementation, verification, and summary.

## Project Map

- Runtime shims live in `shims/`.
- Shared repo helpers live in `lib/repo/`.
- Installed shim helper libraries live in `lib/shims/`.
- Installation logic lives in `scripts/install-shimmy.sh`.
- Behavioral tests live in `scripts/test-shimmy.sh`.
- Contributor guidance lives in `CONTRIBUTING.md`.
- The reusable project prompt lives in `docs/prompt-shimmy-project.md`.

## Available Shim Skills

- Generic shim template: `docs/templates/generic-shim/`
- AWS shim: `shims/aws/`
- jq shim: `shims/jq/`
- ripgrep shim: `shims/rg/`
- Terraform shim: `shims/terraform/`

## Working Rules

- Read `CONTRIBUTING.md` before making repo changes.
- Follow the naming conventions in `CONTRIBUTING.md` for files, functions, and variables.
- Keep runtime shims as small POSIX shell wrappers with `#!/bin/sh` and `set -eu`.
- Mount `$PWD` to `/work` unless the shim has a documented reason not to.
- Use `<PREFIX>_IMAGE` for image override and `<PREFIX>_IMAGE_PULL=always` for pull policy.
- Use Shimmy's shared Podman helper for runtime platform selection instead of hardcoding per-shim OS or architecture checks.
- Any Shimmy-defined variable exported into the user's shell must use the `SHIMMY_` prefix.
- Update shim helper code, install script, tests, and README together when behavior changes.
- Treat Podman as an explicit dependency. Do not add Shimmy-side installation or provisioning steps for it.
- On macOS, remember the official Podman pkg installer may place the binary at `/opt/podman/bin/podman`. If automation cannot find `podman`, check that `/opt/podman/bin` is on `PATH`.
- When testing containers, use live Podman and non-mutating cli calls (eg: version or --help) to validate execution  
- Ensure runnable shell files keep executable bits.
- It is important that you use Shimmy tools when available. This requires Podman to be running.
- If a Shimmy-backed tool exists for a task and the wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, do not silently fall back to host tools for the same capability. Use the `shimmy-escalation` workflow and request approval for the exact outer wrapper command prefix. For search or listing work, if `rg` is available as a Shimmy shim and fails, request approval for the needed `rg` wrapper prefix before using alternatives such as `find`, `grep`, or host-installed search tools. Use a non-shim fallback only after the user explicitly approves it, preferably with the phrase `fallback approved`.
- When running repo commands, invoke them directly with `exec_command` `login=false` unless profile or startup-file behavior is explicitly under test. Do not use `bash -lc` or login shells for Shimmy commands unless needed.
- In AI Agent environments, approvals are evaluated on the outer command. If `podman info` succeeds but a Shimmy-backed tool still reports Podman-unreachable or sandbox-permission symptoms, use the `shimmy-escalation` workflow before asking the user for a Podman remediation plan. For availability smoke checks, request approval for the exact dry-run command prefix such as `["rg","--version"]`, `["jq","--version"]`, or `["./shims/rg","--version"]`; approval for `["podman", "info"]` alone does not approve nested Podman access through a wrapper.
