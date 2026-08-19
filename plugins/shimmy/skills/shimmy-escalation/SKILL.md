---
name: shimmy-escalation
description: Request narrow AI Agent escalation permissions for Shimmy wrappers that run through Podman. Use when the user asks to make installed shims usable from AI Agent shells, pre-authorize wrapper smoke checks, or troubleshoot sandbox permission prompts.
---

# Shimmy Escalation Skill

Use this skill when the user wants AI Agent shell approvals for installed Shimmy wrappers.

## Goal

Run Shimmy wrappers through the AI Agent's outer-command approval boundary
without misclassifying sandbox-denied Podman inspection as an inactive
profile. When a selected command is known to be a Shimmy wrapper, use an
already-approved outer-wrapper prefix on the first actual tool invocation;
do not first make a sandboxed call that is expected to lose Podman socket or
machine-metadata access.

If approval is not already available, request it for the operation the user
actually needs. For repeat repository searches, the read-only `rg` wrapper may
use the bounded persistent prefix `["rg"]`. Credentialed, networked, or
potentially mutating tools require an exact non-mutating command prefix. A
skill cannot grant permissions directly; it can only invoke the approval
mechanism and suggest a persistent prefix when that prefix is safe.

When working in the Shimmy repository, `./commands/agent-preflight.sh` can
print exact installed and repo-local wrapper prefixes to approve.

For installed shims selected on `PATH`, invoke the normal tool name such as
`rg` or `jq`; do not call the resolved installed shim path. For source
validation, use `./commands/run-tool.sh <tool> --preview-shim ...` or the
concrete version runtime.

Shimmy wrappers require the selected profile's deterministic Podman engine
before any wrapper can run. A sandboxed failure does not prove that engine is
inactive: it proves only that readiness is unverified from the sandbox.
Profile activation belongs to `shimmy-init`; this skill owns the first
outer-wrapper retry and delegates only evidence-backed engine remediation.

## Discovery

1. Read `CONTRIBUTING.md` if making repository changes. For permission-only runs, no file changes are needed.
2. Discover the selected Shimmy install:
   - Resolve the `shimmy` command and require it to live below the
     absolute `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>/bin`
     directory for that profile.
3. Discover installed shims:
   - Use `shimmy status --format manifest`, then read
     the invoking profile manifest's `tool=` entries.
   - If status is unavailable, inspect the manifest in the selected
     profile root, then that profile's `bin/` directory.
   - If that is unavailable, inspect executables in `PATH` directories whose
     path ends in `/shimmy/profiles/default/bin` or
     `/shimmy/profiles/upstream/bin`.
4. Keep only executable shim names that resolve through the active shell with
   `command -v <name>`. Use `shimmy status` for the invoking profile's
   implementation path.

## Evidence order

1. Resolve the selected tool command. If it is a Shimmy wrapper and its safe
   outer prefix is already approved, run the actual requested operation with
   escalation immediately. Do not run a preliminary smoke or profile check.
2. If the wrapper was attempted in the sandbox and reports unreachable
   connection metadata, a socket denial, `operation not permitted`, or an
   unknown machine state, label the profile `unverified from the sandbox`.
   Retry the same wrapper operation through the approval mechanism.
3. If approval is unavailable, request it for that wrapper operation. Do not
   fall back to a host tool merely to avoid the approval boundary.
4. If the escalated wrapper succeeds, continue the task. Do not invoke
   `shimmy-init`, run `profile activate --dry-run`, or announce that the
   profile was inactive.
5. Delegate to `shimmy-init` only when the escalated wrapper still reports an
   affinity mismatch, stopped or missing deterministic machine, unreachable
   engine, stale registry projection, or masking connection override.
6. `shimmy-init` may request approval for an exact absolute profile-local
   activation command. It must obtain separate explicit confirmation before
   adding `--stop-running`.

Approval for `profile activate` or `["podman","info"]` does not approve nested
Podman access through a Shimmy wrapper. Conversely, an approved outer wrapper
does not authorize profile activation.

## Approval workflow

For the requested shim operation:

1. Prefer the actual non-mutating operation needed for the task. If the user
   explicitly asks for pre-authorization or no task operation exists, choose a
   smoke command:
   - `rg --version`
   - `jq --version`
   - `terraform version`
   - `aws --version`
   - `go version`
   - `task --version`
   - `textual --version`
   - `netcat --help`
   - Otherwise try `<shim> --version`, then `<shim> --help` if version is not appropriate.
2. Run the operation with the AI Agent's approval mechanism.
3. Use a justification such as: `Allow the <shim> Shimmy wrapper to run Podman outside the sandbox.`
4. For repeat read-only `rg` searches, `["rg"]` is an acceptable persistent
   wrapper prefix. Otherwise use the narrowest useful non-mutating prefix, for
   example `["rg","--version"]` for a smoke-only approval.
5. Do not request broad approvals such as `["podman"]`, `["shimmy"]`,
   `["sh"]`, `["bash"]`, `["python"]`, or a wildcard path.
6. If a shim needs credentials or may contact an external service, use a local/version command only. Do not run mutating commands.

## Reporting

Summarize:

- Podman path, machine state, and whether `podman info` succeeded.
- The absolute profile activation command delegated to `shimmy-init`, if any,
  and whether separate workload interruption was confirmed.
- Shims found and their resolved paths.
- Podman prefix rules requested, if any.
- Prefix rules requested.
- Smoke checks that succeeded.
- Smoke checks that failed, including whether failure came from approval denial, missing Podman, image pull/network, credentials, or the tool itself.

If no installed shims are found on `PATH`, report the profile root checked and
suggest sourcing its absolute `shell-init.sh` or sourcing `./bootstrap.sh` from a
Shimmy source checkout.

## Safety

- Do not modify repository files, startup files, manifests, or shell profiles during a permission-only run.
- Do not install Podman or directly provision, start, stop, restart, delete,
  rename, or adopt a Podman machine. Profile switching is permitted only
  through the exact absolute `profile activate` command delegated to
  `shimmy-init`.
- Do not infer or perform profile activation from sandbox-only reachability
  evidence.
- Do not use destructive commands.
- Treat image pulls as acceptable only when they are required by the shim smoke check and the user approved the escalated run.
