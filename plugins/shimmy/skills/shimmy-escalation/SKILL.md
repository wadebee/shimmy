---
name: shimmy-escalation
description: Request narrow AI Agent escalation approvals for activated Shimmy wrappers. Use when asked to approve installed shims for Codex, make wrappers usable from an agent shell, or resolve wrapper sandbox permission prompts. Does not install Podman or Shimmy.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# Shimmy Escalation

## Goal and scope

Discover activated Shimmy wrappers, request exact-command approvals, and verify
them with local, non-mutating smoke checks. A skill cannot grant or persist
permissions; report what the execution environment actually approved.
An unrelated request such as “Install Podman” does not invoke this workflow.

For permission-only runs, do not modify files or shell configuration. Engine
recovery requires the authorization described below. Do not execute recovery
merely because the user asked to list or pre-authorize wrappers.

When troubleshooting an actual operation with an already-approved safe wrapper
prefix, execute that operation with escalation first. Do not insert a preliminary
sandboxed Podman call or version smoke. For explicit pre-authorization requests,
use the smoke-check workflow below.

## Discovery

1. Prefer the absolute `SHIMMY_INSTALL_DIR` when set; otherwise begin at
   `$HOME/.config/shimmy`. Do not execute a relative or malformed install path.
   If a selected launcher proves the installation is elsewhere, including an
   XDG configuration root, record that root and explain the discrepancy.
2. Locate `shimmy` and inspect its supported status interface with local help.
   Use `shimmy status --format manifest` when supported and it returns successful,
   usable manifest data. Current grouped launchers use
   `shimmy profile status --format manifest` and
   `shimmy shim list --format manifest`. Do not repeatedly call an unsupported
   interface or assume that human-readable output is a manifest.
3. Establish the selected profile from status or the installation's
   `active-profile.conf` (`shimmy_active_profile_name=`). Validate a profile name
   against `^[a-z0-9]+(-[a-z0-9]+)*$` before forming paths. For grouped launchers,
   check that the selected launcher belongs to that profile's `bin/` directory.
   If active-record, launcher, and status disagree, report the conflict and stop
   before executing wrappers. Do not guess `default` or `upstream`.
4. If status is unavailable or unusable, read the selected profile's
   `install-manifest.txt` under `<install-root>/profiles/<profile>/`.
   A directly evidenced older installation may instead own
   `<install-root>/install-manifest.txt`. Read these as data; never source or
   `eval` them. Without evidence of the selected profile or a readable manifest,
   report discovery as blocked rather than scanning arbitrary PATH executables.
5. Inventory records look like:

   ```text
   shim=rg|tracking
   shim_version=rg|15.1|default
   ```

   Extract shim names from `shim=` entries, taking the name before the first
   `|`. `shim_version=` describes versions of that shim, not additional commands.
   Status may label the same inventory `shimmy_profile_shim=`; normalize only
   that known key to `shim=` before extraction. Do not parse `kind=` entries.
   Treat a successful, recognized status manifest with an empty inventory as
   empty; do not replace it with a stale inventory from another profile.

   This POSIX example reads a validated, quoted manifest path and emits unique
   names only after all shim names pass validation:

   ```sh
   shimmy_shim_names=$(LC_ALL=C awk '
     /^shim=/ {
       entry = substr($0, 6)
       separator = index(entry, "|")
       name = separator ? substr(entry, 1, separator - 1) : ""
       if (name !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) {
         invalid = 1
         next
       }
       if (!seen[name]++) names[++count] = name
     }
     END {
       if (invalid) exit 1
       for (i = 1; i <= count; i++) print names[i]
     }
   ' "$shimmy_manifest_path") || {
     printf '%s\n' 'Invalid shim name in manifest; stop discovery.' >&2
     exit 1
   }
   printf '%s\n' "$shimmy_shim_names"
   ```

6. For each validated name, use `command -v "$shimmy_shim_name"` only to confirm
   shell reachability and record the resolved path. This does not prove wrapper
   ownership or identify a stable dispatcher. Confirm the resolved executable
   belongs to the selected installation using its manifest and actual wrapper
   path or symlink destination. Mark missing commands, aliases/functions, host
   binaries shadowing a wrapper, and ambiguous ownership as unrun with a reason.
   Invoke confirmed installed wrappers by their normal tool name, such as `rg`,
   rather than their resolved installed path. Scope checks to named tools when
   the user requests a subset.

If no activated shims are found, report the roots and manifests checked and any
PATH mismatch. Give guidance appropriate to the installed launcher's help;
do not install, activate, or change startup files during discovery.

## Podman readiness decision table

Locate Podman with `command -v podman`. On macOS, also check whether
`/opt/podman/bin/podman` exists and is executable. If it exists but is missing
from PATH, report that distinction; a command-local PATH adjustment is allowed,
but do not edit startup files. Carry that adjustment into later wrapper calls;
environment changes in one agent tool call do not persist in the next.

For pre-authorization, run `podman info` using the narrow approval adapter when
socket access requires escalation. For an already-approved task operation, try
the wrapper first as described above. Direct Podman success does not verify the
profile binding or approve Podman access nested through a wrapper.

| Evidence | Action |
| --- | --- |
| Podman absent from PATH and the macOS fallback location | Stop wrapper checks. Report missing dependency and all remaining checks as unrun. Do not install Podman or open Podman Desktop. |
| `podman info` succeeds | Record the engine result and proceed with individual wrapper approvals. |
| Sandboxed info or wrapper fails with socket/lockfile denial, `operation not permitted`, unreachable, or unknown state | Record `unverified from the sandbox`. Retry the same command once with exact outer-command escalation. Do not infer a stopped machine or activate a profile from this evidence. |
| Escalation is denied or unavailable | Stop that check, record the exact prefix and approval blocker, and mark dependent checks unrun. Do not retry through another executable or broader prefix. |
| Escalated engine check or wrapper still reports a Podman problem on macOS | Inspect with narrowly approved `podman machine list` and, if needed, `podman machine inspect <exact-name>`. Read-only inspection must establish the selected profile's engine identity and state; do not pick the first machine. |
| Existing required machine is confirmed stopped | Start it only when the user asked to make Shimmy usable, or separately authorized recovery. For a managed profile, use the activation procedure below. For an older installation without managed activation, use `podman machine start <exact-name>` only when the intended machine is unambiguous and direct startup is permitted by applicable instructions. Include the name in the approval prefix. |
| No machine exists, or the recorded required machine is missing | Stop and report the missing engine. Explicit user approval is required before any `podman machine init`; this skill does not initialize machines. For managed profiles, use a separately authorized Shimmy lifecycle workflow, never manual same-name recreation or adoption. |
| Machine inspection fails or state/identity is ambiguous | Stop recovery. Report the inspection exit status and diagnostic; ask for the missing identity or authorization. Do not infer “no machine” from failed inspection. |
| Machine is running but escalated info remains unreachable | Stop and report a Podman connection/engine blocker. Do not start it again, reset connections, or change Podman configuration. |
| After one authorized startup, escalated info or wrapper still fails | Record startup and verification separately. Stop further recovery attempts. Classify the wrapper error: engine/profile, network/image pull, credentials, or wrapped tool. |
| Escalated engine access fails on Linux | Report the local rootless engine diagnostic and stop; do not run macOS machine lifecycle commands. |

For managed profiles, recovery uses the installed control plane. If only direct
Podman inspection has failed, first attempt the affected safe wrapper smoke with
escalation to establish profile-specific evidence; if it succeeds, skip recovery.
After an escalated wrapper failure establishes an engine/profile problem, use the exact
absolute selected launcher for `profile status`, then
`profile activate <name> --dry-run`. Present the concrete effects and obtain
authorization for the exact absolute `profile activate <name>` command before
running it; retain prior explicit authorization if it already covers those
effects. Obtain separate confirmation before adding `--stop-running`.
If activation is unsupported, state is ambiguous, or the recorded machine is
missing, stop; do not substitute direct machine provisioning or configuration.
After authorized recovery, verify `podman info` and retry the affected wrapper
once with its own narrow escalation.

## Codex execution adapter

This section describes Codex's `exec_command` adapter, not a universal Agent
Skills API. Submit the smoke command directly with `login=false`,
`sandbox_permissions="require_escalated"`, an exact-command `prefix_rule`, and
a justification naming the Shimmy wrapper. For example:

```json
{
  "cmd": "rg --version",
  "login": false,
  "sandbox_permissions": "require_escalated",
  "prefix_rule": ["rg", "--version"],
  "justification": "Allow the rg Shimmy wrapper to run its local version check through Podman outside the sandbox."
}
```

Use `tools.exec_command({...})` when the runtime exposes it through
`functions.exec`. Other agents must use their own equivalent approval interface;
if none exists, report the check as unrun and provide the exact command for the
user. Do not claim permission was granted merely because a request was issued.

For read-only engine inspection, exact prefix examples are `["podman","info"]`,
`["podman","machine","list"]`, and
`["podman","machine","inspect","<confirmed-machine-name>"]`. Replace placeholders
with confirmed literal values, including an absolute Podman path if that is the
command actually invoked. Recovery prefixes must include the exact launcher,
profile or machine name, and approved flags.

Run commands individually. Do not wrap them in `sh -c`, `bash -lc`, `eval`,
pipelines, or compound command strings to bypass the outer approval boundary.
Never request `["podman"]`, `["shimmy"]`, `["sh"]`, `["bash"]`, scripting-language
prefixes, or wildcard paths. For pre-authorization, keep the full smoke command
as the prefix; a version approval does not approve arbitrary future tool use.
Approval for `podman info` does not cover wrappers, and wrapper approval does
not authorize profile activation or machine startup.

## Smoke-check selection

Prefer a documented local version command from the installed tool's skill,
guide, or smoke metadata. Examples: `rg --version`, `jq --version`,
`terraform version`, `aws --version`, `go version`, and `task --version`.
Use documented local help only if version is unavailable. For an unknown tool,
inspect its maintained guidance before execution; if no safe command can be
established, mark the check unrun. Do not blindly try flags that might launch a
server, invoke a package runner, or contact an external service.

Smoke commands must not modify project data, require credentials, install
packages, start services, scan targets, or call remote APIs. Disable documented
optional update checks where needed; if local behavior cannot be ensured, skip
that check. The wrapper may need to pull its container image: allow that only
as part of the approved smoke invocation. Do not force pulls/builds or change
image configuration. Distinguish image acquisition from wrapped-tool traffic.

Record each command, prefix request, approval outcome, exit status, and concise
version/help evidence. On denial, do not rerun that check. Continue independent
checks unless the user or approval system denied the whole workflow. A shared
Podman failure blocks dependent checks. Never print credential values.

## Reporting

Report:

- Installation/profile evidence, discovered shim names, resolved paths, and any
  unreachable or shadowed wrappers.
- Podman path, `podman info` result, sandbox versus escalated evidence, and
  machine state if inspected. Say `not run` when an engine check was skipped.
- Every approval requested and its outcome; distinguish requested, allowed,
  denied, unavailable, and persistence unverified.
- A per-shim table: command, **succeeded / failed / unrun**, exit status when
  executed, evidence, and blocker. An approval denial is an unrun smoke, not a
  wrapped-tool failure. Do not infer smoke success from `podman info` success.
- Failures by category: discovery/PATH, approval, user authorization,
  Podman/profile, network/image pull, credentials, wrapped tool, or unknown.
  Preserve uncertainty when diagnostics do not establish the cause.
- Whether work completed, partially completed, or stopped; name the blocking
  category and the concrete next action. Include recovery commands actually
  authorized and their results, if any.
- Exact persistent prefix rules the user may approve for the selected safe
  checks, such as `["rg","--version"]` and `["jq","--version"]`. Separate these
  suggestions from approvals observed in this run. Never promise persistence
  without confirmation from the execution environment.

## Safety boundaries

Keep permissions narrow and preserve selected-profile identity. Permission-only
runs must not modify repository files, governance, startup files, manifests,
installed profiles, or Podman configuration. Do not install dependencies or
initialize machines implicitly. Do not stop workloads without separate explicit
confirmation. Do not use destructive recovery, change profiles to evade a
failure, or substitute a host tool to bypass a denied wrapper approval.
