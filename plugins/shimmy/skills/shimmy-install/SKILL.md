---
name: shimmy-install
description: Install, update, validate, roll back, or uninstall Shimmy for external project users. Use when an agent must manage a Shimmy install lifecycle, enforce a required Shimmy version, perform on-use auto-update checks, or emit machine-readable install state while respecting this repository's existing shimmy wrapper and scripts.
---

# Shimmy Install

Use this skill when managing Shimmy as a developer-facing tool dependency outside the Shimmy repository, or when designing/maintaining lifecycle automation for that use case.

## Goals

- Deterministic: the agent orchestrates; repo scripts, the selected profile manifest, and project version constraints define truth.
- Idempotent: repeated runs must converge without duplicate startup blocks, duplicate PATH entries, or unnecessary image work.
- Shimmy-aware: prefer activated `shimmy` commands, repo-root `./shimmy` commands, and documented script interfaces over ad hoc file edits.
- Updatable: support latest, pinned, rollback, and required-version flows for rapidly evolving Shimmy installs.
- Portable: assume only a POSIX-compatible shell plus a non-root Podman or Docker-compatible container runtime.
- Inspectable: every lifecycle action must emit machine-readable output derived from the selected profile manifest.

## Prerequisites

- POSIX-compatible shell: `/bin/sh` or equivalent.
- Container runtime: rootless/non-root `podman` preferred; `docker` is acceptable only when the target Shimmy implementation documents Docker support.
- Network access only when resolving `latest`, pulling repository updates, downloading release metadata, or refreshing images.

Do not install or provision Podman/Docker from this skill. If Shimmy-backed tools fail in an AI Agent shell while `podman info` succeeds, use `shimmy-escalation` first so the exact outer wrapper prefix can be approved. If Podman itself is missing or unreachable, use `shimmy-init` first and pause for user remediation when required.

## Source Of Truth

Before acting, inspect the target project and active Shimmy install:

- Prefer activated installed commands such as `shimmy status`, `shimmy install`, `shimmy update`, and `shimmy test` when working outside the Shimmy source checkout.
- In the Shimmy source checkout, use repo-root `./shimmy` for source-driven install, update, and test workflows.
- Use documented scripts directly only when the wrapper is unavailable or the lower-level interface is explicitly needed: `scripts/install-shimmy.sh`, `scripts/status-shimmy.sh`, `scripts/update-shimmy.sh`, `scripts/test-shimmy.sh`, and `scripts/activate-shimmy.sh`.
- Treat `shimmy status --format manifest` as the first inspection command. It reports the selected profile, profile manifest, dispatcher directory, profile implementation directory, and upstream checkout when applicable.
- Treat the selected profile manifest as installed-state truth. Default profile state is normally under `$SHIMMY_INSTALL_DIR/profiles/default/install-manifest.txt`; upstream profile state is normally under `$SHIMMY_INSTALL_DIR/profiles/upstream/install-manifest.txt`. The install-root `install-manifest.txt` is legacy default compatibility state.
- Treat an external pinned ref, release tag, commit SHA, or version constraint as stronger than `latest`.

Never bypass the install, update, activate, status, test, or uninstall scripts when they exist and cover the requested action.

## Manifest Contract

Each profile has a Shimmy-owned lifecycle state file. Keep manifests POSIX-readable: one `key=value` entry per line, with repeated keys allowed for lists such as `shim=` and `startup_file=`.

Required baseline fields:

```text
shimmy_profile_name=default
install_dir=...
config_dir=...
dispatcher_dir=...
bin_dir=...
manifest_path=...
profile_implementation_dir=...
shim_source=...
activate_file=...
startup_shell=...
startup_file=...
shim=...
shimmy_manifest_version=1
shimmy_source_url=...
shimmy_source_ref=...
```

Upstream profile manifests additionally record:

```text
source_checkout=...
```

`SHIMMY_UPSTREAM_DIR` is Shimmy-managed profile state, not the git checkout path. `SHIMMY_UPSTREAM_CHECKOUT_DIR` is an optional install-time checkout override for `shimmy install --profile upstream`.

Lifecycle fields must use the `shimmy_` prefix, for example:

```text
shimmy_target_ref=latest
shimmy_required_version=>=0.10.0
shimmy_update_policy=on-use
shimmy_update_interval_hours=12
shimmy_last_checked=2026-05-04T00:00:00Z
shimmy_previous_source_ref=...
shimmy_validation_status=ok
shimmy_skill=repo|shimmy-install|/path/to/.agents/skills/shimmy-install|fingerprint
```

Do not edit the manifest directly when a Shimmy script supports the action. If a script rewrites the manifest, it must preserve unknown `shimmy_*` fields unless it intentionally owns and refreshes that key.

Generated or shared agent skills are tracked with repeated `shimmy_skill=` entries. Use `./shimmy skills install` or `./shimmy skills update` to rewrite those entries idempotently instead of hand-editing them.

Every capability must produce machine-readable output for the action. Prefer `shimmy status --format manifest`, `shimmy status --profile upstream --format manifest`, or equivalent `key=value` output over JSON so bootstrap, activation, and recovery do not depend on JSON tooling.

Profile precedence is explicit `--profile`, then `SHIMMY_PROFILE_ACTIVE`, then `default`. Direct tool commands such as `rg` and `jq` read `SHIMMY_PROFILE_ACTIVE`; they do not accept `--profile`. `command -v <tool>` shows the stable dispatcher path, not the selected profile implementation. Use `shimmy status` to inspect the selected target.

## Capabilities

### detect_environment

1. Locate the Shimmy control surface: `./shimmy`, then `scripts/*.sh`, then active `SHIMMY_INSTALL_DIR`.
2. Locate install state: run `shimmy status --format manifest` or read the selected profile manifest if present.
3. Locate runtime: prefer `podman`; verify rootless/non-root with a non-mutating command such as `podman info`.
4. Detect active PATH state with `./shimmy status` or `scripts/status-shimmy.sh`.
5. Emit machine-readable output with installed status, install root, runtime details, current version/ref if known, and validation gaps.

### install

Install flow:

1. Run `detect_environment`.
2. Read existing state and manifest, if any.
3. If not installed, run `shimmy install` or `./shimmy install` with the requested `--profile`, `--install-dir`, `--shim`, `--shell`, `--startup-file`, or `--no-startup` arguments.
4. If installed, rerun install only when the requested install options differ or repair is needed.
5. Share Shimmy agent skills during install, including tool skills for installed shims, by asking the user for `repo`, `profile`, or `plugin`, or by passing `--skills-target <target>` for non-interactive command-line installs.
6. Validate installed state.
7. Persist lifecycle state through manifest-aware Shimmy commands. Do not create a separate state file.

Activation is a shell-session action. Report the exact activation command, usually `eval "$(shimmy activate)"` for installed workflows or `eval "$(./shimmy activate --profile upstream)"` for maintainer upstream workflows, but do not assume the agent can mutate the user's current shell.

### update

Update flow:

1. Read the selected profile manifest.
2. Resolve target:
   - `latest`: query GitHub Releases, GitHub API, package registry, or the documented upstream source.
   - pinned: use the requested tag, commit SHA, branch, or release artifact.
   - constrained: resolve the newest available version satisfying the repo requirement.
3. Compare current version/ref against target.
4. If target is newer or `force=true`, update the Shimmy source/install using the documented repo process.
5. Run `shimmy update` or `./shimmy update` with appropriate flags such as `--profile`, `--pull`, `--build`, or `--repair-startup`.
6. Validate installed state.
7. Persist new manifest fields only after validation succeeds.

Supported update policies:

- Passive/manual: run only when the user or agent explicitly asks.
- On-use auto-update: on first Shimmy invocation in a session, read `shimmy_last_checked`; check at most every configured interval, default 12 hours; skip network work when cache is fresh.
- Repo-driven enforcement: read the repo's required Shimmy version, such as `version: ">=0.10.0"`; if installed version does not satisfy it, update automatically before continuing.

### validate

1. Run `shimmy status --format manifest` or `./shimmy status --format manifest`.
2. Confirm the selected profile manifest exists when installed.
3. Confirm activation script exists.
4. Confirm installed shim files are executable.
5. Confirm PATH activation when required by the workflow.
6. Run `shimmy test`, `shimmy test --profile upstream`, or focused non-mutating shim smoke checks when live container execution is in scope.
7. Emit machine-readable output with pass/fail checks and raw command references.

Use live non-mutating runtime calls such as `version`, `--version`, or `--help`. Do not use fake Podman/Docker binaries for validation.

### rollback

1. Read the previous successful ref from `shimmy_previous_source_ref` or the repo's declared pin.
2. Resolve the rollback ref to a tag, commit SHA, or release artifact.
3. Restore the Shimmy source/install using the documented process for that ref.
4. Run `shimmy update`, `./shimmy update`, or reinstall from the restored source.
5. Validate.
6. Persist rollback state with `shimmy_previous_source_ref`, `shimmy_source_ref`, timestamp fields, and validation result.

If no previous known-good ref exists, stop and ask for a target ref. Do not guess.

### uninstall

1. Read the selected profile manifest.
2. Run `shimmy uninstall --profile <profile>` or `./shimmy uninstall --profile <profile>`.
3. Validate removal with `./shimmy status` or by confirming the manifest, activation file, shims, and managed startup blocks are gone.
4. Emit final machine-readable output showing `installed=no`, timestamp, and removed paths.

## Version Resolution

- Prefer immutable refs for pins: commit SHA, release artifact digest, or exact tag.
- For `latest`, use the documented release channel. If the channel is ambiguous, ask before updating.
- For semver constraints, use strict semantic comparison. Do not compare versions lexicographically.
- Record both requested target and resolved target.
- Keep rollback metadata before replacing an installed ref.

## Failure Rules

- If the container runtime is missing, rootful-only, or unreachable, stop and report remediation instead of installing or updating. If only the Shimmy wrapper is blocked by AI Agent sandbox permissions while `podman info` works, use `shimmy-escalation` before reporting remediation.
- If the desired target cannot be resolved, stop before changing files.
- If validation fails after update, attempt rollback only when a known-good ref exists.
- If existing scripts do not support a requested lifecycle behavior, state that gap and propose the smallest script/spec addition rather than inventing hidden behavior.
