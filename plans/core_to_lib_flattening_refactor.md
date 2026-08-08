# Core-to-lib flattening refactor

## Objective

Make the following non-backward-compatible layout change consistently across
implementation, tests, documentation, contexts, and skills:

- rename the repository shared-module directory from `core/` to `lib/`
- relocate the repository management launcher from `shimmy` to `bin/shimmy`
- install each profile's control, runtime, configuration, and manifest assets
  directly in that profile's canonical XDG-rooted directory instead of below
  a shared bundled `core/` directory
- remove `--install-dir` from the complete management-command surface
- remove Shimmy-defined public environment overrides for installation and
  profile-state locations
- remove all shared-module and installed-layout `core` variables and paths

The work is divided into reviewable chunks for execution across fresh AI
sessions. Every accepted chunk must leave source and installed dispatch
operational. Backward compatibility and in-place migration from the version-2
layout are explicitly out of scope.

## Target layout and terminology

### Repository

```text
shimmy/
  agent/
  bin/
    shimmy
  commands/
  lib/
  plugins/
  tests/
  tools/
```

### Profile installations

Resolve the XDG and Shimmy roots as follows:

```text
<config-home> = $XDG_CONFIG_HOME when it is set, non-empty, and absolute
                $HOME/.config otherwise
<shimmy-config-root> = <config-home>/shimmy
<profiles-root> = <shimmy-config-root>/profiles
<profile-root> = <profiles-root>/<profile-name>
```

`XDG_CONFIG_HOME` is an upstream standard and is the only supported location
input. Shimmy does not place its profile directories directly under the
generic `<config-home>/profiles` path; the `shimmy/` application namespace
prevents collisions with other applications.

Each profile is a complete, independent installation. The current built-in
profiles produce these roots:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/
```

Every profile root has the same installed structure:

```text
<profile-root>/
  activate.sh
  install-manifest.txt
  bin/
    shimmy
    <generated tool dispatchers>
  commands/
  config/
    shims/
  implementations/
    <generated kind and version wrappers>
  lib/
  plugins/
  tests/
  tools/
  agent/
```

The Shimmy config root and profiles root are merge-owned containers. They do
not contain a shared launcher, shared manifest, shared runtime payload, or
shared dispatcher directory. Installing, refreshing, updating, or removing
one profile must not mutate any sibling profile.

The flat profile install does not contain `<profile-root>/.agents/skills`.
Installed skill commands use the canonical sources under
`<profile-root>/agent/core/` and `<profile-root>/tools/<kind>/agent/`. A
`.agents/skills` directory is created only at an explicit user-selected
`shimmy skills` target such as a repository or home agent profile, and remains
governed by its own skills manifest.

Terminology used throughout this plan:

- `lib/` means shared POSIX shell modules.
- `agent/core/` means core management skills and is unrelated to the renamed
  shared-module tree.
- `bin/shimmy` is the sole repository and installed management launcher.
- A profile root is the complete installed control/runtime root for exactly
  one profile; there is no shared install root or installed `core/` bundle.
- Profile selection chooses a canonical location. It never accepts a caller-
  supplied filesystem path.

## Recorded design decisions

These decisions are final for this refactor and must not be reopened during
implementation.

### Atomic transition

The source rename, profile-local installed flattening, launcher relocation,
XDG path resolution, removal of public location overrides, dispatcher change,
manifest schema change, and minimum lifecycle tests form one atomic first
chunk. They span both path models and cannot be split into independently
operational states without temporary compatibility machinery that this
refactor does not need.

### Canonical XDG path and profile selection

- Resolve the config home from absolute, non-empty `XDG_CONFIG_HOME`, falling
  back to `$HOME/.config` only when `XDG_CONFIG_HOME` is unset or empty.
- Reject a non-empty relative `XDG_CONFIG_HOME` with a clear error; never
  reinterpret it relative to the current working directory.
- Keep the supported profile names `default` and `upstream`. Future built-in
  profiles must use the same `<profiles-root>/<profile-name>` convention.
- Preserve profile selection precedence: explicit `--profile`, then
  `SHIMMY_PROFILE_ACTIVE`, then `default`.
- Retain `SHIMMY_PROFILE_ACTIVE` as a profile-name selector, not a filesystem
  override. Activation prepends the selected profile's `bin/` and exports the
  matching name. A direct installed tool dispatcher is bound to its enclosing
  profile root and must reject a conflicting active-profile value with
  guidance to activate the intended profile; it never jumps to a sibling
  profile through an environment-derived path.
- Remove `--install-dir` from install, uninstall, activate, status, update,
  test, skills, agent-preflight, and any internal forwarding path. Passing it
  must fail as an unknown argument without mutation.
- Remove `SHIMMY_INSTALL_DIR`, `SHIMMY_CONTROL_INSTALL_DIR`, and
  `SHIMMY_UPSTREAM_DIR` as public or internal location inputs. If any legacy
  variable is non-empty, fail with guidance to unset it and select a profile;
  do not silently honor or ignore it.
- Retain `SHIMMY_UPSTREAM_CHECKOUT_DIR`: it selects the source checkout
  recorded by an upstream profile and does not relocate installed state.
- Repository tests isolate installations by setting an absolute disposable
  `XDG_CONFIG_HOME`; no private install-directory override replaces the public
  option.

### Ownership boundaries

Treat every profile root as a container of individually owned paths, never as
a recursively replaceable bundle.

- `<shimmy-config-root>` and `<profiles-root>` are merge-owned containers.
  Create them as needed, never replace them, and remove them only with
  `rmdir` after a profile uninstall.
- A fresh profile install may proceed only when the profile root is absent or
  empty. A non-empty profile root without a compatible manifest is unmanaged
  and must be rejected before mutation.
- Within a compatible profile, `commands`, `config`, `implementations`, `lib`,
  `tools`, `tests`, `plugins`, and `agent` are replace-owned root assets.
- `activate.sh` and `install-manifest.txt` are individually owned regular
  files. Write them with same-directory temporary files and atomic renames.
- Replace each claimed path independently. Remove a displaced symlink itself;
  never follow it, and reject symlinks in the profile-root parent chain.
- `bin/` is merge-owned within the profile. Replace or remove only compatible-
  manifest-owned entries; never replace the directory as a whole. Reject a
  new dispatcher collision until the requested command is recorded as owned.
- Preserve unknown siblings during additive install, refresh, self-update, and
  uninstall of a compatible profile.
- Profile uninstall removes only that profile's verified owned paths and uses
  `rmdir` for `bin/`, the profile root, profiles root, and Shimmy config root so
  unmanaged content and sibling profiles survive.
- Never translate the current `rm -rf "$SHIMMY_CORE_DIR"` behavior into
  recursive removal of a profile root, profiles root, or Shimmy config root.

### Launcher contract

- Move `<repo>/shimmy` to `<repo>/profiles/default/bin/shimmy` and preserve its executable bit.
- Install one executable regular launcher at `<profile-root>/bin/shimmy`; do
  not create `<profile-root>/shimmy` or a launcher symlink.
- Both source and installed launchers resolve their root as the parent of
  `bin/`.
- An installed launcher derives its profile root from its own location and
  requires that root to equal the canonical XDG path for the manifest's
  profile name. It never consumes a manifest path as a location override.
- A profile manifest identifies an installed-layout candidate and must pass
  compatibility validation before installed paths are loaded. Without one,
  an installed launcher reports a damaged profile; it never falls back to
  source mode.
- Source mode requires a source-only repository marker that is not copied into
  profile installations in addition to the required repository structure.
  Use the repository-root `CONTEXT.md` and `CONTRIBUTING.md` together for this
  distinction; neither file is part of a profile payload.
- Bootstrap a first install with `./bin/shimmy install`.
- With no profile manifest, reject any existing `<profile-root>/bin/shimmy`,
  including a symlink, before mutation. With a compatible profile manifest,
  require the path to equal its recorded managed launcher before replacement.
- Install or refresh the launcher through a temporary regular file in the
  same directory, set mode `0755`, then atomically rename it. Failure must
  leave the prior launcher and all siblings unchanged.
- Record `control_bin=<profile-root>/bin/shimmy` as a validated assertion in
  the profile manifest; it never redirects execution.
- Self-update validates and invokes `<fetched-source>/bin/shimmy` and refreshes
  the selected profile's complete control/runtime payload. Within merge-owned
  `bin/`, it refreshes only the installed launcher and owned dispatchers.
- Activation puts the selected `<profile-root>/bin` on `PATH`. Repository
  `/profiles/default/bin/` is not an installed tool PATH.

### Manifest compatibility contract

- Each profile has exactly one manifest at
  `<profile-root>/install-manifest.txt`; there is no shared root manifest or
  profile registry.
- Profile manifests use `shimmy_install_manifest_version=3`,
  `shimmy_install_layout=profile-flat-root`,
  `shimmy_profile_manifest_version=3`, and the exact
  `shimmy_profile_name=<profile-name>`.
- Omit the ambiguous unscoped `shimmy_layout` key and redundant location
  fields such as `install_dir`, `bin_dir`, `config_dir`, and
  `profile_implementation_dir`.
- Validate all identity fields together, reject duplicate identity keys, and
  validate `control_bin` against the derived canonical path before consuming
  any remaining metadata.
- Apply this contract to install, additive install, refresh, update, status,
  activation, dispatch, profile enumeration, and uninstall.
- An absent profile manifest is a fresh-install candidate only when the
  profile root is absent or empty. An existing manifest with missing or
  different identity fields is incompatible.
- Profile enumeration scans only direct children of the canonical profiles
  root, validates supported profile names, and validates each manifest before
  reporting or using it.
- Before installing any v3 profile, detect the canonical version-2 shared
  manifest at `<shimmy-config-root>/install-manifest.txt` and fail before
  mutation with version-2 removal guidance.
- Do not scan the filesystem for version-2 custom-root installations. Document
  that users of the removed option must invoke the launcher in each old custom
  root with the old Shimmy version, uninstall every profile there, and then
  install canonical v3 profiles.
- Do not migrate, alias, or automatically delete version-2 installations.

Profile incompatibility must fail before mutation with:

```text
incompatible Shimmy profile install layout at <manifest-path> (expected shimmy_install_manifest_version=3, shimmy_install_layout=profile-flat-root, shimmy_profile_manifest_version=3, and shimmy_profile_name=<profile-name>); uninstall it with the Shimmy version that created it, then reinstall the selected profile
```

### Naming and scope

- Eliminate `SHIMMY_INSTALL_CORE_DIR`, `SHIMMY_CORE_DIR`, test helpers that
  encode an installed-core model, and equivalent aliases. Remaining such
  names are defects, not deferred compatibility.
- Eliminate `--install-dir`, `SHIMMY_INSTALL_DIR`,
  `SHIMMY_CONTROL_INSTALL_DIR`, `SHIMMY_UPSTREAM_DIR`, and equivalent install-
  location aliases from implementation, tests, documentation, contexts, and
  skills. Do not remove `SHIMMY_UPSTREAM_CHECKOUT_DIR`.
- Rename `tests/core/` to `tests/lib/` and `test_core_*` functions in that
  grouping to `test_lib_*`.
- Retain `agent/core/` as the canonical source for core management skills.
  Selecting one canonical ownership model across `agent/`, `.agents/skills/`,
  tool-local skills, and plugin copies is separate follow-up work.
- Make only migration-required edits to canonical, plugin, and `.agents` skill
  files; do not broadly reconcile their existing differences.
- Rewrite migrated paths in persistent historical plans to the current model.
  Preserve their goals, decisions, completion state, and intentional uses such
  as `agent/core/` or upstream API paths.
- Preserve unrelated uses of the word `core`, including OPNsense API endpoints
  such as `/core/system/info` and `/core/firmware/status`. Cleanup searches
  require classification, not blind replacement.

## Verified migration inventory

### Shared source tree

- Rename the complete `<repo>/core/` tree to `<repo>/lib/`, including all shell
  modules and its nine `CONTEXT.md` files.
- Update moved-file self-references, especially:
  - `lib/install/install.sh`
  - `lib/netinfo/netinfo.sh`
  - `lib/runtime/image.sh`
  - `lib/update/update.sh`
- Update source-checkout structural validation in `lib/profile/profile.sh`.

### Management surface

- Move `<repo>/shimmy` to `<repo>/bin/shimmy`.
- Add `<repo>/bin/CONTEXT.md` and link it from the root context.
- Update these command entrypoints:
  - `commands/activate.sh`
  - `commands/agent-preflight.sh`
  - `commands/dispatch-tool.sh`
  - `commands/install.sh`
  - `commands/netinfo.sh`
  - `commands/skills.sh`
  - `commands/status.sh`
  - `commands/update.sh`

### Versioned runtimes and refresh hooks

Update shared runtime/helper paths in:

- `tools/aws/versions/2.31/run.sh`
- `tools/gcloud/versions/573.0/run.sh`
- `tools/gdrive/versions/0.2/run.sh`
- `tools/gdrive/versions/0.2/refresh.sh`
- `tools/gh/versions/2.94/run.sh`
- `tools/gh/versions/2.94/refresh.sh`
- `tools/go/versions/1.26/run.sh`
- `tools/jq/versions/1.8/run.sh`
- `tools/logmine/versions/0.1/run.sh`
- `tools/logmine/versions/0.1/refresh.sh`
- `tools/netcat/versions/7.92/run.sh`
- `tools/netcat/versions/7.92/refresh.sh`
- `tools/nmap/versions/7.98/run.sh`
- `tools/oc/versions/4.18/run.sh`
- `tools/oc/versions/4.18/refresh.sh`
- `tools/oc/versions/4.20/run.sh`
- `tools/oc/versions/4.20/refresh.sh`
- `tools/oc/versions/4.22/run.sh`
- `tools/oc/versions/4.22/refresh.sh`
- `tools/opnsense-mcp-admin/versions/1.0/run.sh`
- `tools/opnsense-mcp-admin/versions/1.0/refresh.sh`
- `tools/opnsense-mcp-read-only/versions/0.4/run.sh`
- `tools/opnsense-mcp-read-only/versions/0.4/refresh.sh`
- `tools/rg/versions/15.1/run.sh`
- `tools/skopeo/versions/1.22/run.sh`
- `tools/task/versions/3.45/run.sh`
- `tools/task/versions/3.45/refresh.sh`
- `tools/terraform/versions/1.15/run.sh`
- `tools/tessl/versions/0.1/run.sh`
- `tools/tessl/versions/0.1/refresh.sh`
- `tools/textual/versions/8.2/run.sh`
- `tools/textual/versions/8.2/refresh.sh`

Repeat the repository-wide scrub during implementation; this list is a
verified baseline, not permission to ignore new or previously missed matches.

## Execution protocol

For every chunk:

1. Read `AGENTS.md`, `CONTEXT.md`, every child context on the path to a changed
   file, this plan, and the chunk's target files.
2. Execute only that chunk's scope.
3. Run its verification checklist and record `[x]`, `[ ]`, or `[~]` with notes.
4. Update the cumulative **Lessons learned** block.
5. Summarize changes, tests, failures, uncertainties, and remaining risks.
6. Stop for human review and explicit acceptance before starting the next
   chunk.

Repository paths in this plan are relative to `<repo>` so it remains portable
across workstations and sessions.

## Chunk 1 — Atomic layout transition

### Goal

Atomically rename the source library, relocate the launcher, move every
installation into a canonical XDG profile root, remove public location
overrides, introduce the version-3 manifest contract, and update enough
lifecycle tests to leave source and installed dispatch operational.

### Files

- rename `core/` to `lib/`
- move `shimmy` to `bin/shimmy`
- add `bin/CONTEXT.md`
- all command entrypoints listed in **Management surface**
- all files under the renamed `lib/` tree, with primary behavior changes in:
  - `lib/profile/profile.sh`
  - `lib/install/request.sh`
  - `lib/install/profile-assets.sh`
  - `lib/install/install.sh`
  - `lib/install/uninstall.sh`
  - `lib/install/manifest.sh`
  - `lib/update/management.sh`
  - `lib/update/profile.sh`
  - `lib/update/refresh.sh`
  - `lib/update/update.sh`
- every versioned runtime and refresh hook in the verified inventory
- `.github/workflows/test.yml`
- minimum lifecycle coverage in:
  - `tests/test.sh`
  - `tests/support.sh`
  - `tests/context-tree.sh`
  - `tests/core/catalog.sh`
  - `tests/core/runtime.sh`
  - `tests/core/update.sh`
  - `tests/commands/install.sh`
  - `tests/commands/lifecycle.sh`
  - `tests/commands/update.sh`
  - `tests/commands/dispatcher.sh`
  - `tests/commands/management.sh`

Mechanically update any additional test that invokes the old source launcher
or a renamed module path when required to keep the default suite operational;
defer the test-directory and function-name cleanup to Chunk 2.

Files may move before their context documents are rewritten in Chunk 3, but
links and runner paths required for a passing repository must be updated here.

### Implementation requirements

- Source every shared module from `lib/`; update shellcheck source comments.
- Resolve the selected canonical profile root exclusively from
  `XDG_CONFIG_HOME`, `$HOME`, and the profile name.
- Remove `--install-dir` parsing and forwarding and remove the three legacy
  Shimmy location variables named in the canonical-path contract.
- Install `commands`, `config`, `implementations`, `lib`, `tools`, `tests`,
  `plugins`, and `agent` directly under the selected profile root using the
  ownership rules above.
- Do not copy the repository `.agents/skills` tree into a profile root.
- Change dispatcher symlinks to `../commands/dispatch-tool.sh`; retain the
  existing recursion and broken-target protections.
- Implement the launcher and manifest contracts exactly as recorded above.
- Validate the complete profile-local installed shape instead of treating
  directory existence as proof of an installation.
- Preserve sibling profiles, the selected manifest, generated dispatchers,
  and unmanaged siblings through additive install, refresh, and self-update.
- Profile uninstall removes only the selected profile's verified owned assets.
- Stage and validate replacement assets before mutation, commit the manifest
  last, and retain or restore the prior compatible profile after a failure.
- Add disposable unmanaged profile-root and sibling-profile sentinels to
  install, refresh, self-update, and uninstall coverage.

### Verification

- [ ] `core/` is renamed to `lib/`; all direct source references and shellcheck
      comments use `lib/`.
- [ ] `bin/shimmy` is the executable source launcher and resolves the repository
      root as the parent of `bin/`.
- [ ] Unset or empty `XDG_CONFIG_HOME` resolves profiles below
      `$HOME/.config/shimmy/profiles`; an absolute value resolves them below
      `$XDG_CONFIG_HOME/shimmy/profiles`; a relative value fails before
      mutation.
- [ ] No management command accepts or forwards `--install-dir`, and the
      removed Shimmy location variables fail with targeted guidance rather
      than changing a path.
- [ ] Fresh install creates `activate.sh`, `install-manifest.txt`,
      `bin/shimmy`, `commands/`, `config/`, `implementations/`, `lib/`,
      `tools/`, `tests/`, `plugins/`, and `agent/` below the selected profile
      root, with no `<profile-root>/core`, `<profile-root>/shimmy`, or
      `<profile-root>/.agents/skills`.
- [ ] Installed launcher is an executable regular file, uses same-directory
      atomic replacement, and preserves all `bin/` siblings.
- [ ] An unmanaged or symlinked pre-existing `bin/shimmy` is rejected before
      mutation; a managed launcher must match `control_bin` before replacement.
- [ ] Dispatcher symlinks target exactly `../commands/dispatch-tool.sh`, load
      helpers from `<profile-root>/lib`, and are neither broken nor recursive.
- [ ] Fresh installs reject non-empty unmanaged profile roots and all unmanaged
      claimed-path or dispatcher collisions before mutation.
- [ ] Additive install, refresh, and self-update preserve the selected
      manifest, sibling profiles, and unknown siblings.
- [ ] Unmanaged sentinels in the selected profile and sibling profiles survive
      install, refresh, self-update, and unrelated-profile uninstall.
- [ ] Profile uninstall removes owned assets and uses `rmdir`, never recursive
      profile-root or config-root deletion.
- [ ] Each profile manifest contains both version `3` fields,
      `profile-flat-root`, the exact profile name, and exact `control_bin`, and
      contains no `shimmy_layout` or redundant location fields.
- [ ] Missing or duplicate identity fields, version 2, unknown versions, wrong
      layout label, wrong profile name, and malformed manifests fail before
      mutation with the specified remediation message.
- [ ] A canonical version-2 shared installation blocks v3 profile creation
      before mutation and reports removal guidance.
- [ ] No `SHIMMY_INSTALL_CORE_DIR`, `SHIMMY_CORE_DIR`,
      `SHIMMY_INSTALL_DIR`, `SHIMMY_CONTROL_INSTALL_DIR`,
      `SHIMMY_UPSTREAM_DIR`, `core/core`, old dispatcher target, or
      `--install-dir` remains in implementation.
- [ ] Minimum source, fresh-install, dispatch, refresh, update, and uninstall
      tests pass at the review gate.
- Notes:

### Human review gate

Confirm the repository is operational, canonical profile roots and their flat
trees are understandable, manifest failures occur before mutation, and no
owned-path operation can erase sibling-profile or unmanaged state.

## Chunk 2 — Comprehensive test migration

### Goal

Complete the test and verification-harness migration, rename shared-library
tests, and provide exhaustive regression coverage for the recorded contracts.

### Files

- command tests:
  - `tests/commands/activate.sh`
  - `tests/commands/agent-preflight.sh`
  - `tests/commands/dispatcher.sh`
  - `tests/commands/install.sh`
  - `tests/commands/lifecycle.sh`
  - `tests/commands/management.sh`
  - `tests/commands/netinfo.sh`
  - `tests/commands/profiles.sh`
  - `tests/commands/skills.sh`
  - `tests/commands/startup.sh`
  - add `tests/commands/status.sh`
  - `tests/commands/test.sh`
  - `tests/commands/update.sh`
- rename `tests/core/` to `tests/lib/`, including:
  - `tests/lib/catalog.sh`
  - `tests/lib/runtime.sh`
  - `tests/lib/update.sh`
  - `tests/lib/CONTEXT.md`
- test infrastructure:
  - `tests/test.sh`
  - `tests/support.sh`
  - `tests/context-tree.sh`
  - `tests/profile-smoke.sh`

### Implementation requirements

- Use `tests/lib/`, `test_lib_*`, and `lib/` consistently in runner paths,
  function names, shellcheck comments, helper names, and documentation.
- Invoke the source launcher as `./bin/shimmy` and installed launcher as
  `<profile-root>/bin/shimmy`.
- Give every lifecycle scenario an absolute disposable `XDG_CONFIG_HOME` and
  derive expected default and upstream profile roots from it.
- Cover default-only, upstream-only, and combined-profile installs.
- Verify activation switches `PATH` and `SHIMMY_PROFILE_ACTIVE` together and a
  dispatcher refuses a conflicting active-profile value without crossing into
  a sibling root.
- Prove installing, refreshing, updating, and removing one profile never
  mutates the sibling profile. Removing the last profile may remove only empty
  merge-owned container directories.
- Cover file, directory, and symlink collisions for every claimed profile-root
  asset and every merge-owned container.
- Prove launcher refresh changes only owned entries within that profile's
  `bin/` and does not mutate sibling profile launchers or dispatchers.
- Cover malformed, missing, duplicate-key, version-2, unknown-version,
  wrong-label, and wrong-profile manifests, with unchanged profile assets
  after rejection.
- Cover unset, empty, absolute, and relative `XDG_CONFIG_HOME` and prove that
  the removed CLI option and Shimmy location variables cannot relocate state.
- Verify source-checkout validation requires `bin/shimmy`, `commands/`,
  `lib/`, and `tools/` and rejects stale `core/` layouts.
- Verify executable bits on launchers, command and library entrypoints,
  version runtimes, and refresh hooks.

### Verification

- [ ] All command tests assert the canonical profile-flat layout.
- [ ] Shared-library tests live under `tests/lib/`, use `test_lib_*`, and run in
      the default suite.
- [ ] Default-only, upstream-only, and combined-profile scenarios pass.
- [ ] Profile isolation, profile removal, and empty-container cleanup obey the
      ownership contract.
- [ ] Collision, symlink-safety, sentinel-preservation, launcher, dispatcher,
      and manifest rejection cases pass.
- [ ] XDG fallback, absolute override, relative-path rejection, removed-option,
      and removed-variable cases pass.
- [ ] Profile smoke and context-tree tests pass.
- [ ] No test asserts legacy installed paths or uses installed-core aliases.
- [ ] No test uses a private install-root override; isolation is achieved with
      disposable `HOME` and `XDG_CONFIG_HOME` values.
- [ ] Required runnable files retain executable bits.
- Notes:

### Human review gate

Confirm test names and expected trees match the agreed design and no test was
silently omitted during the directory rename.

## Chunk 3 — Documentation, contexts, skills, and historical plans

### Goal

Align maintainer-facing, user-facing, and AI-facing guidance with the new
source and installed layouts without redesigning skill ownership.

### Files

- root and contributor docs:
  - `README.md`
  - `CONTEXT.md`
  - `CONTRIBUTING.md`
  - `AGENTS.md`
  - `commands/README.md`
- context tree:
  - `bin/CONTEXT.md`
  - `commands/CONTEXT.md`
  - `tests/CONTEXT.md`
  - `tests/lib/CONTEXT.md`
  - every `CONTEXT.md` under `lib/`
  - `agent/CONTEXT.md`
  - `agent/core/CONTEXT.md`
  - `agent/core/shimmy-create-tool/CONTEXT.md`
  - `agent/core/shimmy-escalation/CONTEXT.md`
  - `agent/core/shimmy-init/CONTEXT.md`
  - `agent/core/shimmy-install/CONTEXT.md`
  - `agent/core/shimmy-tool-local-build/CONTEXT.md`
- skill guidance:
  - every migration-matched `SKILL.md` under `agent/core/`
  - every migration-matched `SKILL.md` under `tools/*/agent/`
  - every migration-matched `SKILL.md` under `plugins/shimmy/skills/`
  - every migration-matched `SKILL.md` under `.agents/skills/`
- other documentation:
  - `docs/netinfo.md`
  - `docs/network-tools.md`
  - `docs/podman.md`
  - `docs/prompt-shimmy-project.md`
  - `docs/testing.md`
  - `docs/templates/generic-shim/SKILL.md`
  - every migration-matched `tools/*/guide.md`
- persistent historical plans:
  - `plans/context.md`
  - `plans/context_remaining.md`
  - `plans/multi-architecture-manifest.md`
  - any additional plan found by the repeat scrub

### Implementation requirements

- Describe `lib/` as the shared library, the canonical XDG path resolver, and
  each profile root as a complete flat control/runtime installation.
- Remove `--install-dir`, `SHIMMY_INSTALL_DIR`,
  `SHIMMY_CONTROL_INSTALL_DIR`, and `SHIMMY_UPSTREAM_DIR` from all current
  guidance. Retain and clearly distinguish `SHIMMY_UPSTREAM_CHECKOUT_DIR`.
- Explain that disposable validation uses an absolute temporary
  `XDG_CONFIG_HOME`, not an installation-directory override.
- Link `bin/CONTEXT.md` from the root context and keep all renamed context-tree
  links valid.
- Explicitly audit `agent/CONTEXT.md`, `agent/core/CONTEXT.md`, and all five
  leaf contexts while retaining the `agent/core/` name.
- Update only migration-related advice in canonical, plugin, and `.agents`
  skills; do not synchronize unrelated content.
- Rewrite stale source, test, launcher, and installed-layout paths in all
  persistent plans. Preserve intentional unrelated `core` references after
  reviewing each match.

### Verification

- [ ] Root and contributor docs accurately describe `lib/`, `bin/shimmy`, XDG
      resolution, and independent profile-flat installations.
- [ ] All context links and paths are valid; the context-tree test passes.
- [ ] AI skill guidance contains no migrated `core/` path advice.
- [ ] User, contributor, and AI guidance contains no removed install-location
      option or Shimmy environment override.
- [ ] The canonical management-skill context subtree was explicitly reviewed
      and remains at `agent/core/`.
- [ ] No skill tree was moved or broadly reconciled.
- [ ] Persistent historical plans use current migrated paths without losing
      their non-path history.
- [ ] Every remaining `core` match in documentation is classified as an
      intentional concept, API path, or other unrelated use.
- Notes:

### Human review gate

Confirm the wording is durable, context navigation is coherent, and future
maintainers or AI sessions will not be directed to legacy paths.

## Chunk 4 — Final scrub and end-to-end validation

### Goal

Remove remaining legacy naming, run full validation, and prepare the completed
refactor for acceptance.

This cleanup chunk may touch any previously modified file when the final scrub
finds a missed migration reference or verification defect.

### Verification

- [ ] Repository-wide search finds no unintended `core/core`,
      `SHIMMY_INSTALL_CORE_DIR`, `SHIMMY_CORE_DIR`, old dispatcher target,
      `<repo>/shimmy`, or migrated source `core/` paths.
- [ ] Active implementation, tests, documentation, contexts, and skills contain
      no `--install-dir`, `SHIMMY_INSTALL_DIR`,
      `SHIMMY_CONTROL_INSTALL_DIR`, `SHIMMY_UPSTREAM_DIR`, or equivalent
      location alias. Historical removal references in this plan are
      classified, and intentional `SHIMMY_UPSTREAM_CHECKOUT_DIR` uses remain.
- [ ] Every remaining `core` match is reviewed and documented as intentional,
      including `agent/core/`, ordinary prose, and upstream API paths.
- [ ] Repository-wide search finds no installed `.agents/skills` payload
      assumption; explicit `shimmy skills` targets remain supported.
- [ ] `./bin/shimmy test` passes.
- [ ] `./tests/context-tree.sh` passes.
- [ ] A disposable fresh default install works.
- [ ] A disposable fresh upstream install works.
- [ ] Default and upstream installs occupy independent canonical profile roots;
      activating either profile and dispatching its installed shims works.
- [ ] Additive install, management refresh, and self-update work without
      changing unmanaged or sibling-profile sentinels.
- [ ] Removing either profile preserves the other; removing the last profile
      removes only its owned assets and empty merge-owned containers while
      preserving unmanaged content.
- [ ] The complete tree of each installed profile, including hidden paths,
      matches the target layout, and no shared control/runtime payload exists
      above the profile roots.
- [ ] The repository diff contains no stale workstation-specific absolute
      paths and no unintended executable-bit changes.
- Notes:

### Suggested commands

Set `<tmp-config-home>` to an absolute disposable directory and adjust the
selected shim as needed:

```sh
./bin/shimmy test
./tests/context-tree.sh
XDG_CONFIG_HOME=<tmp-config-home> ./bin/shimmy install --profile default --no-startup --no-skills
XDG_CONFIG_HOME=<tmp-config-home> ./bin/shimmy activate --profile default
XDG_CONFIG_HOME=<tmp-config-home> <tmp-config-home>/shimmy/profiles/default/bin/<shim> --version
XDG_CONFIG_HOME=<tmp-config-home> ./bin/shimmy update --profile default
XDG_CONFIG_HOME=<tmp-config-home> ./bin/shimmy uninstall --profile default
```

### Human review gate

Confirm the source and profile-local installed layouts are clear, all tests
pass, no removed path override remains, and no legacy path can be recreated.

## Risk register

### High risk

1. **Destructive profile-root replacement** — Flattening removes the safety
   boundary of a bundled directory. Fresh installs must reject non-empty
   unmanaged profile roots, and refresh and cleanup must use the explicit
   ownership rules and safe-path validation.
2. **XDG resolution and removed overrides** — Empty, relative, or inherited
   environment values must not place files outside the canonical application
   namespace, and legacy Shimmy location variables must not silently work.
3. **Cross-profile isolation** — Each profile contains a full independent
   payload. Selection, update, and uninstall mistakes must not mutate a sibling
   profile or a shared container.
4. **Launcher mode detection and replacement** — Both launchers live below
   `bin/`; incorrect root resolution, weak manifest checks, or non-atomic
   replacement could break every management command.
5. **Merge-owned `bin/` collisions** — Replacing `bin/`, following a launcher
   symlink, or accepting an unproven launcher could destroy or hijack managed
   dispatch.
6. **Manifest identity validation** — Partial, duplicate, or mismatched profile
   schemas must be rejected before any metadata is trusted or any asset is
   changed.
7. **Dispatcher target integrity** — A stale central target can produce broken
   or recursive symlinks.
8. **Update detection** — Installed-management and fetched-source checks are
   tightly coupled to the profile-flat layout and can silently misclassify
   partial trees.
9. **Versioned runtime paths** — One missed `core/runtime` reference causes a
   tool-specific failure that broad lifecycle tests may not expose.

### Medium risk

10. **Test rename coordination** — Runner paths, functions, shellcheck comments,
    and contexts must move together so tests are not silently dropped.
11. **Context and historical-plan drift** — Stale actionable paths can cause
    later sessions to restore the old model.
12. **Skills duplication assumptions** — Removing the installed
    `.agents/skills` copy is safe only while canonical `agent/` and tool-local
    agent sources remain part of every profile payload and skill commands
    continue resolving them there.

## Lessons learned

Append concise, durable findings after each accepted chunk. Do not duplicate
the fixed design decisions above.

### Initial

- Path resolution and installer copy targets jointly create the current
  nested layout; renaming the repository directory alone cannot flatten it.
- The current dispatcher assumes `core/core` and `core/commands`, the launcher
  treats `../core` as its installed payload, and update detection checks
  `<install>/core`; these must change atomically.
- The current installer copies one repository-root launcher to both
  `<install>/bin/shimmy` and `<install>/core/shimmy`; the target design has one
  launcher per profile and file-level ownership in each profile's `bin/`.
- Directory renames also affect shellcheck source comments, context links,
  source-checkout validation, test support globs, and historical working plans.
- A shared install root makes profile isolation and uninstall ownership harder
  to reason about. The target gives every profile a complete payload below the
  canonical XDG Shimmy namespace.
- Removing `--install-dir` is incomplete unless all lifecycle forwarding and
  equivalent Shimmy location environment variables are removed together.
- Disposable tests do not need a private path override; an absolute temporary
  `XDG_CONFIG_HOME` provides standards-aligned isolation.

### Chunk 1

- _append after acceptance_

### Chunk 2

- _append after acceptance_

### Chunk 3

- _append after acceptance_

### Chunk 4

- _append after acceptance_

## Session bootstrap

At the start of a later session:

1. Read `AGENTS.md`, `CONTEXT.md`, this plan, the current chunk's files, and
   every context file on their paths.
2. Restate the non-backward-compatible target: source `core/` becomes `lib/`,
   `bin/shimmy` is the sole launcher, `--install-dir` and equivalent Shimmy
   location variables are removed, and each profile is a complete flat install
   below `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`.
3. Work only on the current chunk and stop at its human review gate.
4. Before stopping, update its checklist and **Lessons learned**, then report
   tests, uncertainties, and remaining risks.
