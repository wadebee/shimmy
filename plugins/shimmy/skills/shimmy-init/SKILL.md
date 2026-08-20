---
name: shimmy-init
description: Initialize and verify Podman readiness after an escalated Shimmy wrapper call proves a profile or engine problem. Do not use for sandbox-only reachability failures.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Shimmy Init

Use this skill when a Shimmy tool still fails outside the sandbox because its
profile-bound Podman engine is demonstrably inactive, mismatched, stopped,
missing, stale, masked, or unreachable.

## Goal

Make Shimmy wrappers usable from an AI Agent shell through the installed
profile's activation control plane. On macOS, `default` requires the
pre-existing `shimmy-default` machine and `upstream` requires the pre-existing
`shimmy-upstream` machine. Only the exact absolute profile-local launcher may
activate that deterministic engine.

Do not install Podman or directly provision, start, stop, restart, delete,
rename, or adopt a Podman machine. Do not request a broad Podman, shell, or
scripting-language approval.
The combined `bootstrap.sh --activate` human convenience is not evidence of AI
Agent authorization and must not replace the separate status, dry-run,
activation, and workload-interruption approval gates below.

## Workflow

1. Confirm the entry evidence:
   - Require a failed wrapper invocation that already used the AI Agent's
     outer-command approval mechanism, or an explicit user request to inspect
     or activate a profile.
   - A sandbox-only `unreachable`, `unknown`, socket-denied, or
     `operation not permitted` result means `unverified from the sandbox`, not
     `inactive`. Return that case to `shimmy-escalation` for the same wrapper
     operation to be retried with escalation.
2. Resolve the selected installed profile:
   - Prefer the profile containing the resolved `shimmy` or tool command.
   - Require the canonical absolute root
     `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<default|upstream>`.
   - Set `profile_root` to that validated absolute path and use
     `"$profile_root/bin/shimmy"` for every management check. Do not activate a
     sibling profile through the currently selected launcher.
3. Check control-plane support:
   - Run `"$profile_root/bin/shimmy" profile --help`.
   - If the installed profile lacks `profile activate`, stop and give
     user-shell guidance to update or reinstall that profile. Do not replace
     the missing control plane with direct `podman machine` lifecycle commands.
4. Inspect without mutation:
   - Run `"$profile_root/bin/shimmy" profile status`.
   - Run `"$profile_root/bin/shimmy" profile activate --dry-run`.
   - Use narrow escalation for these exact absolute commands if the AI Agent
     sandbox blocks inspection.
   - Never print values of `CONTAINER_CONNECTION` or `CONTAINER_HOST`; identify
     only the masking variable name and ask the user to unset it.
5. Handle a missing deterministic machine:
   - Stop without attempting activation.
   - Repeat the command emitted by Shimmy for the user to run in a normal
     shell: `podman machine init shimmy-<profile>`.
   - If Shimmy reports that the configuration home is outside `HOME`, also
     repeat its exact same-path volume form:
     `podman machine init --volume <absolute-config-home>:<absolute-config-home> shimmy-<profile>`.
   - State that Shimmy never adopts, renames, migrates, or removes
     `podman-machine-default`.
6. Activate only after status and dry-run succeed:
   - Request approval for the exact absolute command recommended by the
     resolved state: `"$profile_root/bin/shimmy" profile activate`, or the same
     command with `--restart` for a stale Darwin projection.
   - Use the exact prefix equivalent, including `--restart` when recommended;
     never request `["shimmy"]`, `["podman"]`, a shell prefix, or a wildcard
     path.
   - Explain any machine that the dry run will stop and start. On macOS only
     one Podman-managed VM can run, so switching profiles can interrupt
     workloads hosted by another VM.
7. If activation reports running containers:
   - Stop and report the displayed workload names or IDs.
   - Obtain separate explicit user confirmation to interrupt those workloads.
   - Only after that confirmation, request and run the exact absolute command
     recommended by status, adding `--stop-running` to the existing options.
     For a stale projection, the exact absolute command ends in `profile
     activate --restart --stop-running`; otherwise it ends in `profile activate
     --stop-running`. Use the exact prefix equivalent.
   - Treat `--stop-running` as acknowledgement, not a promise that interrupted
     containers will resume during rollback.
8. Verify the result:
   - Run `"$profile_root/bin/shimmy" profile status` and `podman info`.
   - If registry redirects are configured, require status to report current
     policy. Use the exact printed `profile activate --restart` command for a
     stale Darwin projection; do not let Skopeo silently omit a prepared or
     stale policy.
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
- `["<profile-root>/bin/shimmy","profile","activate","--restart"]` when
  recommended for a stale Darwin projection
- `["<profile-root>/bin/shimmy","profile","activate","--stop-running"]` only
  after separate workload-interruption confirmation
- `["<profile-root>/bin/shimmy","profile","activate","--restart","--stop-running"]`
  only when both restart and workload interruption were separately justified
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
