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
profile activation control plane. On macOS, ordinary profiles use the
installation-owned shared `shimmy-default` machine; explicitly isolated profiles use
their recorded owned `shimmy-<name>` machine. Use an exact absolute installed
launcher for activation.

Do not install Podman or directly provision, start, stop, restart, delete,
rename, or adopt a Podman machine. Do not request a broad Podman, shell, or
scripting-language approval.
Checkout bootstrap activation is not general authorization to switch an
existing installation. Retain the separate status, named dry-run, activation,
and workload-interruption approval gates below.

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
     `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>` and validate the
     safe profile name.
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
   - Run `"$profile_root/bin/shimmy" profile activate "$profile_name" --dry-run`.
   - Use narrow escalation for these exact absolute commands if the AI Agent
     sandbox blocks inspection.
   - Never print values of `CONTAINER_CONNECTION` or `CONTAINER_HOST`; identify
     only the masking variable name and ask the user to unset it.
5. Handle a missing recorded machine:
   - Stop without attempting activation or a direct Podman repair.
   - Report the binding mode, engine ID, expected name, origin, and exact
     ownership diagnostic from Shimmy.
   - Never recreate the name manually: a new same-name machine does not match
     the recorded ownership token and stable identity and remains ambiguous.
   - Use only a documented Shimmy recovery/removal command after separate user
     authorization. Fresh shared and isolated provisioning belongs to bootstrap,
     profile create, or profile clone; it is not an activation side effect.
   - State that Shimmy never adopts, renames, or claims
     `podman-machine-default` or any other pre-existing machine.
6. Activate only after status and dry-run succeed:
   - Request approval for the exact absolute command recommended by the
     resolved state: `"$profile_root/bin/shimmy" profile activate
     "$profile_name"`, or the same command with `--restart` for a stale Darwin
     projection.
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
     activate <name> --restart --stop-running`; otherwise it ends in `profile
     activate <name> --stop-running`. Use the exact prefix equivalent.
   - Treat `--stop-running` as acknowledgement, not a promise that interrupted
     containers will resume during rollback.
8. Verify the result:
   - Run `"$profile_root/bin/shimmy" profile status` and `podman info`.
   - If registry redirects are configured, require status to report current
     policy. Use the exact printed `profile activate <name> --restart` command for a
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
- `["<profile-root>/bin/shimmy","profile","activate","<name>","--dry-run"]`
- `["<profile-root>/bin/shimmy","profile","activate","<name>"]`
- `["<profile-root>/bin/shimmy","profile","activate","<name>","--restart"]` when
  recommended for a stale Darwin projection
- `["<profile-root>/bin/shimmy","profile","activate","<name>","--stop-running"]` only
  after separate workload-interruption confirmation
- `["<profile-root>/bin/shimmy","profile","activate","<name>","--restart","--stop-running"]`
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
- Do not directly provision, delete, rename, or adopt a machine. Shimmy's own
  bootstrap, profile-create/clone/delete, and global-uninstall control-plane
  transactions are the only owned-machine lifecycle authorities.
- Prefer status, dry-run, `podman info`, and non-mutating tool smokes.
