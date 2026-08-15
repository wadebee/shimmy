---
name: shimmy-escalation
description: Request narrow AI Agent escalation permissions for Shimmy wrappers that run through Podman. Use when the user asks to make installed shims usable from AI Agent shells, pre-authorize wrapper smoke checks, or troubleshoot sandbox permission prompts.
---

# Shimmy Escalation Skill

Use this skill when the user wants AI Agent shell approvals for installed Shimmy wrappers.

## Goal

Trigger AI Agent approval prompts for installed shims using narrow,
non-mutating command prefixes such as `["rg","--version"]` or
`["jq","--version"]`. A skill cannot grant permanent permissions directly; it
can only run harmless shim smoke checks with escalation and suggest persistent
prefix approval.

When working in the Shimmy repository, `./commands/agent-preflight.sh` can
print exact installed and repo-local wrapper prefixes to approve.

For installed shims selected on `PATH`, invoke the normal tool name such as
`rg` or `jq`; do not call the resolved installed shim path. For source
validation, use `./commands/run-tool.sh <tool> --preview-shim ...` or the
concrete version runtime.

Shimmy wrappers require the selected profile's deterministic Podman engine
before any wrapper can run. Profile activation belongs to `shimmy-init`; this
skill owns only the subsequent exact outer-wrapper smoke approval.

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

## Profile readiness

Before running shim smoke checks:

1. Use the selected profile's absolute launcher to run `profile status` and
   `profile activate --dry-run`.
2. If the profile is inactive, mismatched, stopped, unreachable, or masked by
   `CONTAINER_CONNECTION` or `CONTAINER_HOST`, delegate remediation to
   `shimmy-init`. Resume this skill only after `shimmy-init` verifies the
   profile is active and `podman info` succeeds.
3. `shimmy-init` may request approval for the exact absolute profile-local
   `bin/shimmy profile activate` command. If running containers block the
   transition, it must obtain separate explicit confirmation before adding
   `--stop-running`.
4. If the installed profile lacks `profile activate`, stop with user-shell
   update or reinstall guidance. Do not use direct Podman machine lifecycle
   commands as a legacy fallback.
5. Do not install Podman or directly provision, start, stop, restart, delete,
   rename, or adopt a machine. Do not request a broad Podman approval.

Approval for `profile activate` or `["podman","info"]` does not approve nested
Podman access through a Shimmy wrapper. Continue with the exact outer-wrapper
workflow after readiness succeeds.

## Approval Workflow

For each discovered shim:

1. Choose a non-mutating smoke command:
   - `rg --version`
   - `jq --version`
   - `terraform version`
   - `aws --version`
   - `go version`
   - `task --version`
   - `textual --version`
   - `netcat --help`
   - Otherwise try `<shim> --version`, then `<shim> --help` if version is not appropriate.
2. Run the smoke command with the AI Agent's approval mechanism.
3. Use a justification such as: `Allow the <shim> Shimmy wrapper to run Podman outside the sandbox.`
4. Use the exact dry-run smoke command as the prefix rule equivalent, for example `["rg","--version"]`.
5. Do not request broad approvals such as `["podman"]`, `["sh"]`, `["bash"]`, `["python"]`, or a wildcard path.
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
suggest sourcing its absolute `shell-init.sh` or sourcing `./install.sh` from a
Shimmy source checkout.

## Safety

- Do not modify repository files, startup files, manifests, or shell profiles during a permission-only run.
- Do not install Podman or directly provision, start, stop, restart, delete,
  rename, or adopt a Podman machine. Profile switching is permitted only
  through the exact absolute `profile activate` command delegated to
  `shimmy-init`.
- Do not use destructive commands.
- Treat image pulls as acceptable only when they are required by the shim smoke check and the user approved the escalated run.
