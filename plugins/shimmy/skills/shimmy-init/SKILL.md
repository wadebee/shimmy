---
name: shimmy-init
description: Initialize and verify Podman readiness for Shimmy-backed tools. Use whenever a Shimmy wrapper fails and the errors mention Podman engine access, podman machine start, podman info, connection refused, operation not permitted, stale sockets, or unreachable Podman services.
---

# Shimmy Init

Use this skill whenever a Shimmy tool fails because Podman may not be ready.

## Goal

Make Shimmy wrappers usable from AI Agent shells by confirming the local Podman engine is reachable. On macOS, the required remediation is often a user-shell step:

```sh
podman machine start
podman info
```

Do not install Podman, initialize a new Podman machine, or run `podman machine start` from an AI Agent shell. If the machine is stopped or unreachable on macOS, instruct the user to run `podman machine start` in a normal shell, then retry verification from the AI Agent.

## When To Use

Use this skill when:

- The agent uses a Shimmy-backed tool such as `rg`, `jq`, `aws`, `terraform`, `go`, `task`, `netcat`, `textual`, or another wrapper installed by Shimmy.
- A Shimmy wrapper exits with an error saying Podman cannot talk to the engine.
- A command fails with Podman socket, lockfile, connection refused, operation not permitted, stale connection, or unreachable service errors.
- Output suggests `podman machine start`, `podman info`, or `podman system connection list`.

## Workflow

1. Confirm the command is likely Shimmy-backed:
   - Prefer `command -v <tool>`.
   - Treat paths under `$HOME/.config/shimmy/shims` or another `shimmy/shims` directory as Shimmy wrappers.
2. Locate Podman:
   - Run `command -v podman`.
   - On macOS, remember the official pkg installer may place it at `/opt/podman/bin/podman`.
3. Verify Podman engine access:
   - Run `podman info`.
   - If it succeeds, retry the original Shimmy command when appropriate.
4. If `podman info` fails on macOS:
   - Run `podman machine list` with escalation if the sandbox blocks socket or machine access.
   - Treat `podman machine start` returning `already running` as confirmation that the machine state is not the blocker, then verify `podman info`.
   - If an existing machine is stopped or Podman reports a refused/stale socket, stop and tell the user to run `podman machine start` in a normal shell outside the AI Agent.
   - After the user reports that startup succeeded, run `podman info` again with escalation if needed.
5. If no Podman machine exists:
   - Stop and ask the user before `podman machine init`.
   - Do not provision Podman implicitly.
6. If `podman info` succeeds but the Shimmy wrapper still fails:
   - Use the tool-specific Shimmy skill when available.
   - Check `command -v <tool>`; if it resolves under `$HOME/.config/shimmy/shims` or another Shimmy install, the AI Agent may need approval for the outer wrapper command even though direct `podman info` works.
   - Run a harmless wrapper smoke check with exact-command escalation, such as `rg --version` with prefix rule `["rg"]`.
   - Remember that AI Agent permissions are evaluated on the outer command (`rg`, `jq`, `terraform`, etc.), not only on the nested `podman` process that the wrapper starts.
   - If later non-escalated wrapper calls still fail in the same session, keep using exact wrapper escalation or ask the user to persist the exact prefix approval.
   - Report whether the failure is from image pull/network, credentials, wrapper behavior, or the underlying tool.

## Escalation Commands

Use narrow escalation requests. Good prefix rules:

- `["podman", "info"]`
- `["podman", "machine", "list"]`
- The exact Shimmy tool prefix, such as `["rg"]`, `["jq"]`, `["terraform"]`, or `["aws"]`

Avoid broad approvals such as `["podman"]`, shell prefixes, or scripting language prefixes.

Use these justifications:

- `podman info`: `Do you want to verify Podman engine access outside the sandbox for Shimmy wrappers?`
- `podman machine list`: `Do you want to inspect local Podman machines outside the sandbox so Shimmy wrappers can be initialized?`
- Shimmy tool retry: `Do you want to allow the <tool> Shimmy wrapper to run Podman outside the sandbox?`

## Reporting

Summarize:

- Whether the requested tool resolved to a Shimmy wrapper.
- Podman path and whether `podman info` succeeded.
- Podman machine state when inspected.
- Any escalation prefix rules requested.
- Whether direct Podman access succeeded but the outer wrapper still needed its own exact-command approval.
- Whether the original Shimmy command succeeded after initialization.

## Safety

- Do not modify repository files, shell profiles, manifests, or installed shims as part of initialization.
- Do not install Podman, start Podman Desktop, start a Podman machine, or initialize a new machine.
- Podman machine startup on macOS should be a user-guidance step because AI Agent shells may not reliably own the user session state needed by Podman socket forwarding.
- Prefer non-mutating smoke checks such as `--version`, `version`, `--help`, or `podman info`.
