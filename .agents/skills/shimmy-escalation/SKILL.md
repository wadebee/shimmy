---
name: shimmy-escalation
description: Request Codex escalation permissions for activated Shimmy wrappers that run through Podman. Use when the user asks to make Shimmy shims usable from Codex shells, pre-authorize shim wrappers, approve all activated shims, or troubleshoot Codex sandbox permission prompts for installed shims.
---

# Shimmy Escalation Skill

Use this skill when the user wants Codex shell approvals for installed Shimmy wrappers.

## Goal

Trigger Codex approval prompts for activated shims using narrow command prefixes such as `["rg"]` or `["jq"]`. A skill cannot grant permanent permissions directly; it can only run harmless shim smoke checks with escalation and suggest persistent prefix approval.

## Discovery

1. Read `../../../CONTRIBUTING.md` if making repository changes. For permission-only runs, no file changes are needed.
2. Discover the active Shimmy install:
   - Prefer `SHIMMY_INSTALL_DIR` when it is set.
   - Otherwise use `$HOME/.config/shimmy`.
3. Discover activated shims:
   - Prefer `$SHIMMY_INSTALL_DIR/install-manifest.txt` and read `shim=` entries.
   - If the manifest is missing, inspect `$SHIMMY_INSTALL_DIR/shims`.
   - If that is unavailable, inspect every executable in `PATH` directories whose path ends in `/shimmy/shims`.
4. Keep only executable shim names that resolve through the active shell with `command -v <name>`.

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
2. Run the smoke command with `sandbox_permissions: "require_escalated"`.
3. Set `justification` to: `Do you want to allow the <shim> Shimmy wrapper to run Podman outside the sandbox?`
4. Set `prefix_rule` to the exact shim command, for example `["rg"]`.
5. Do not request broad approvals such as `["podman"]`, `["sh"]`, `["bash"]`, `["python"]`, or a wildcard path.
6. If a shim needs credentials or may contact an external service, use a local/version command only. Do not run mutating commands.

## Reporting

Summarize:

- Shims found and their resolved paths.
- Prefix rules requested.
- Smoke checks that succeeded.
- Smoke checks that failed, including whether failure came from approval denial, missing Podman, image pull/network, credentials, or the tool itself.

If no activated shims are found, report the install directory checked and suggest activating Shimmy first with `eval "$(./shimmy activate)"` or installing shims with `./shimmy install`.

## Safety

- Do not modify repository files, startup files, manifests, or shell profiles during a permission-only run.
- Do not install Podman or start Podman machines unless the user explicitly asks.
- Do not use destructive commands.
- Treat image pulls as acceptable only when they are required by the shim smoke check and the user approved the escalated run.
