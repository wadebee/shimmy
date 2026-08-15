---
name: shimmy-init
description: Initialize and verify Podman readiness for Shimmy-backed tools. Use whenever a Shimmy wrapper reports an inactive profile, engine mismatch, Podman access failure, connection refusal, operation-not-permitted error, stale socket, or unreachable service.
---

# Shimmy Init

Use this skill whenever a Shimmy tool fails because its profile-bound Podman
engine may not be active or reachable.

## Goal

Make Shimmy wrappers usable from an AI Agent shell through the installed
profile's activation control plane. On macOS, `default` requires the
pre-existing `shimmy-default` machine and `upstream` requires the pre-existing
`shimmy-upstream` machine. Only the exact absolute profile-local launcher may
activate that deterministic engine.

Do not install Podman or directly provision, start, stop, restart, delete,
rename, or adopt a Podman machine. Do not request a broad Podman, shell, or
scripting-language approval.

## Workflow

1. Resolve the selected installed profile:
   - Prefer the profile containing the resolved `shimmy` or tool command.
   - Require the canonical absolute root
     `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<default|upstream>`.
   - Set `profile_root` to that validated absolute path and use
     `"$profile_root/bin/shimmy"` for every management check. Do not activate a
     sibling profile through the currently selected launcher.
2. Check control-plane support:
   - Run `"$profile_root/bin/shimmy" profile --help`.
   - If the installed profile lacks `profile activate`, stop and give
     user-shell guidance to update or reinstall that profile. Do not replace
     the missing control plane with direct `podman machine` lifecycle commands.
3. Inspect without mutation:
   - Run `"$profile_root/bin/shimmy" profile status`.
   - Run `"$profile_root/bin/shimmy" profile activate --dry-run`.
   - Use narrow escalation for these exact absolute commands if the AI Agent
     sandbox blocks inspection.
   - Never print values of `CONTAINER_CONNECTION` or `CONTAINER_HOST`; identify
     only the masking variable name and ask the user to unset it.
4. Handle a missing deterministic machine:
   - Stop without attempting activation.
   - Repeat the command emitted by Shimmy for the user to run in a normal
     shell: `podman machine init shimmy-<profile>`.
   - If Shimmy reports that the configuration home is outside `HOME`, also
     repeat its exact same-path volume form:
     `podman machine init --volume <absolute-config-home>:<absolute-config-home> shimmy-<profile>`.
   - State that Shimmy never adopts, renames, migrates, or removes
     `podman-machine-default`.
5. Activate only after status and dry-run succeed:
   - Request approval for the exact absolute command
     `"$profile_root/bin/shimmy" profile activate`.
   - Use the exact prefix equivalent
     `["<profile-root>/bin/shimmy","profile","activate"]`; never request
     `["shimmy"]`, `["podman"]`, a shell prefix, or a wildcard path.
   - Explain any machine that the dry run will stop and start. On macOS only
     one Podman-managed VM can run, so switching profiles can interrupt
     workloads hosted by another VM.
6. If activation reports running containers:
   - Stop and report the displayed workload names or IDs.
   - Obtain separate explicit user confirmation to interrupt those workloads.
   - Only after that confirmation, request and run the exact absolute command
     `"$profile_root/bin/shimmy" profile activate --stop-running` with the exact
     prefix equivalent including `--stop-running`.
   - Treat `--stop-running` as acknowledgement, not a promise that interrupted
     containers will resume during rollback.
7. Verify the result:
   - Run `"$profile_root/bin/shimmy" profile status` and `podman info`.
   - If direct Podman access succeeds but a wrapper remains sandbox-blocked,
     delegate its exact non-mutating smoke approval to `shimmy-escalation`.
   - For a tool call in a separate AI Agent command, invoke the absolute
     profile dispatcher or source `"$profile_root/shell-init.sh"` in that same
     command. A sourcing operation in one agent tool call does not change PATH
     in later calls.

## Narrow approvals

Acceptable approval prefixes are limited to:

- `["<profile-root>/bin/shimmy","profile","status"]`
- `["<profile-root>/bin/shimmy","profile","activate","--dry-run"]`
- `["<profile-root>/bin/shimmy","profile","activate"]`
- `["<profile-root>/bin/shimmy","profile","activate","--stop-running"]` only
  after separate workload-interruption confirmation
- `["podman","info"]` for final read-only verification

Use a justification that names the target profile and exact effect. Keep
wrapper smoke approvals in `shimmy-escalation`.

## Reporting

Summarize the selected profile root, status and dry-run results, exact approval
prefixes requested, any displayed workloads and acknowledgement, final engine
state, and whether the original wrapper succeeded.

## Safety

- Do not modify repository files, startup files, manifests, or installed shims
  as part of initialization.
- Do not install Podman or run direct Podman machine lifecycle commands.
- Do not provision, delete, rename, or adopt a machine.
- Prefer status, dry-run, `podman info`, and non-mutating tool smokes.
