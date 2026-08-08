# Core-to-lib flattening refactor

## Objective

Make the following non-backward-compatible layout change consistently across
implementation, tests, documentation, contexts, and skills:

- rename the repository shared-module directory from `core/` to `lib/`
- relocate the repository management launcher from `shimmy` to `bin/shimmy`
- install control and runtime assets directly in the install root instead of
  below a bundled `core/` directory
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

### Installation

```text
~/.config/shimmy/
  activate.sh
  install-manifest.txt
  bin/
    shimmy
    <generated tool dispatchers>
  commands/
  lib/
  plugins/
  tests/
  tools/
  agent/
  profiles/
    default/
    upstream/
```

The flat install does not contain `<install>/.agents/skills`. Installed skill
commands use the canonical sources under `<install>/agent/core/` and
`<install>/tools/<kind>/agent/`. A `.agents/skills` directory is created only
at an explicit user-selected `shimmy skills` target such as a repository or
home profile, and remains governed by its own skills manifest.

Terminology used throughout this plan:

- `lib/` means shared POSIX shell modules.
- `agent/core/` means core management skills and is unrelated to the renamed
  shared-module tree.
- `bin/shimmy` is the sole repository and installed management launcher.
- The install root is the installed control/runtime root; there is no
  installed `core/` bundle.

## Recorded design decisions

These decisions are final for this refactor and must not be reopened during
implementation.

### Atomic transition

The source rename, installed flattening, launcher relocation, dispatcher
change, manifest schema change, and minimum lifecycle tests form one atomic
first chunk. They span both path models and cannot be split into independently
operational states without temporary compatibility machinery that this
refactor does not need.

### Ownership boundaries

Treat the install root as a container of individually owned paths, never as a
recursively replaceable bundle.

- `commands`, `lib`, `tools`, `tests`, `plugins`, and `agent` are
  replace-owned root assets. Fresh install, additive install, refresh, and
  self-update may replace any file, directory, or symlink at those exact
  names because the install root is wholly Shimmy-owned for them.
- Replace each claimed path independently. Remove a displaced symlink itself;
  never follow it.
- `bin/` is merge-owned. Replace or remove only manifest-owned entries, never
  the directory as a whole.
- Preserve `profiles/`, all manifests, and unknown sibling paths during
  additive install, refresh, self-update, and uninstall.
- On final-profile uninstall, remove each verified Shimmy-owned root asset and
  use `rmdir` for `bin/` and the install root so unmanaged content survives.
- Never translate the current `rm -rf "$SHIMMY_CORE_DIR"` behavior into
  recursive removal of the install root.

### Launcher contract

- Move `<repo>/shimmy` to `<repo>/bin/shimmy` and preserve its executable bit.
- Install one executable regular launcher at `<install>/bin/shimmy`; do not
  create `<install>/shimmy` or a launcher symlink.
- Both source and installed launchers resolve their root as the parent of
  `bin/`.
- A root manifest identifies an installed-layout candidate and must pass
  compatibility validation before installed paths are loaded. Without one,
  the launcher requires a valid source checkout and runs in source mode.
- Bootstrap a first install with `./bin/shimmy install`.
- With no root manifest, reject any existing `<install>/bin/shimmy`, including
  a symlink, before mutation. With a compatible root manifest, require the
  path to equal its recorded managed launcher before replacement.
- Install or refresh the launcher through a temporary regular file in the
  same directory, set mode `0755`, then atomically rename it. Failure must
  leave the prior launcher and all siblings unchanged.
- Record `control_bin=<install>/bin/shimmy` in the root manifest.
- Self-update validates and invokes `<fetched-source>/bin/shimmy` and refreshes
  only the installed launcher file.
- The upstream profile continues to put `<install>/bin` on `PATH` for stable
  generated tool dispatchers. Repository `bin/` is not an upstream tool PATH.

### Manifest compatibility contract

- Root manifests use `shimmy_install_manifest_version=3` and
  `shimmy_install_layout=flat-root`.
- Profile manifests use `shimmy_profile_manifest_version=3` and omit the
  ambiguous unscoped `shimmy_layout` key.
- Validate root version and layout together, then validate the selected
  profile version before consuming profile-owned paths or metadata.
- Apply this contract to install, additive install, refresh, update, status,
  activation, dispatch, profile enumeration, and uninstall.
- An absent root manifest is a fresh-install candidate. An existing manifest
  with missing or different identity fields is incompatible.
- Do not migrate, alias, or automatically delete version-2 installations.

Root incompatibility must fail before mutation with:

```text
incompatible Shimmy install layout at <manifest-path> (expected shimmy_install_manifest_version=3 and shimmy_install_layout=flat-root); uninstall it with the Shimmy version that created it, then reinstall
```

Profile incompatibility must fail before mutation with:

```text
incompatible Shimmy profile manifest at <manifest-path> (expected shimmy_profile_manifest_version=3); uninstall the existing Shimmy installation with the Shimmy version that created it, then reinstall
```

### Naming and scope

- Eliminate `SHIMMY_INSTALL_CORE_DIR`, `SHIMMY_CORE_DIR`, test helpers that
  encode an installed-core model, and equivalent aliases. Remaining such
  names are defects, not deferred compatibility.
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

Atomically rename the source library, relocate the launcher, flatten installed
assets, introduce the version-3 manifest contract, and update enough lifecycle
tests to leave both source and installed dispatch operational.

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
- Install `commands`, `lib`, `tools`, `tests`, `plugins`, and `agent` directly
  under the install root using the ownership rules above.
- Do not copy the repository `.agents/skills` tree into the install root.
- Change dispatcher symlinks to `../commands/dispatch-tool.sh`; retain the
  existing recursion and broken-target protections.
- Implement the launcher and manifest contracts exactly as recorded above.
- Validate the flattened installed shape instead of treating directory
  existence as proof of an installation.
- Preserve profiles, manifests, generated dispatchers, and unmanaged siblings
  through additive install, refresh, and self-update.
- Final-profile uninstall removes only verified owned assets.
- Add a disposable unmanaged install-root sentinel to install, refresh,
  self-update, and uninstall coverage.

### Verification

- [ ] `core/` is renamed to `lib/`; all direct source references and shellcheck
      comments use `lib/`.
- [ ] `bin/shimmy` is the executable source launcher and resolves the repository
      root as the parent of `bin/`.
- [ ] Fresh install creates `bin/shimmy`, `commands/`, `lib/`, `tools/`,
      `tests/`, `plugins/`, and `agent/`, with no `<install>/core`,
      `<install>/shimmy`, or `<install>/.agents/skills`.
- [ ] Installed launcher is an executable regular file, uses same-directory
      atomic replacement, and preserves all `bin/` siblings.
- [ ] An unmanaged or symlinked pre-existing `bin/shimmy` is rejected before
      mutation; a managed launcher must match `control_bin` before replacement.
- [ ] Dispatcher symlinks target exactly `../commands/dispatch-tool.sh`, load
      helpers from `<install>/lib`, and are neither broken nor recursive.
- [ ] Claimed root paths replace pre-existing files, directories, and symlinks
      without following displaced symlinks.
- [ ] Additive install, refresh, and self-update preserve profiles, manifests,
      and unknown siblings.
- [ ] The unmanaged sentinel survives install, refresh, self-update, and final
      uninstall.
- [ ] Final uninstall removes owned assets and uses `rmdir`, never recursive
      install-root deletion.
- [ ] Root manifests contain version `3`, `flat-root`, and exact `control_bin`;
      profile manifests contain version `3` and no `shimmy_layout`.
- [ ] Missing identity fields, version 2, unknown versions, wrong layout label,
      and mixed root/profile versions fail before mutation with the specified
      remediation messages.
- [ ] No `SHIMMY_INSTALL_CORE_DIR`, `SHIMMY_CORE_DIR`, `core/core`, or old
      dispatcher target remains in implementation.
- [ ] Minimum source, fresh-install, dispatch, refresh, update, and uninstall
      tests pass at the review gate.
- Notes:

### Human review gate

Confirm the repository is operational, the flat tree is understandable,
manifest failures occur before mutation, and no owned-path operation can erase
profile or unmanaged state.

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
  - `tests/commands/status.sh`
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
  `<install>/bin/shimmy`.
- Cover default-only, upstream-only, and combined-profile installs.
- Prove removing one profile preserves the other and shared assets; removing
  the final profile removes owned assets but preserves unmanaged root and
  `bin/` entries.
- Cover file, directory, and symlink collisions for every claimed root asset.
- Prove launcher refresh changes only `bin/shimmy`.
- Cover malformed, missing, version-2, unknown-version, wrong-label, and
  mixed-version manifests, with unchanged installed assets after rejection.
- Verify source-checkout validation requires `bin/shimmy`, `commands/`,
  `lib/`, and `tools/` and rejects stale `core/` layouts.
- Verify executable bits on launchers, command and library entrypoints,
  version runtimes, and refresh hooks.

### Verification

- [ ] All command tests assert the flat install layout.
- [ ] Shared-library tests live under `tests/lib/`, use `test_lib_*`, and run in
      the default suite.
- [ ] Default-only, upstream-only, and combined-profile scenarios pass.
- [ ] Profile removal and final cleanup obey the ownership contract.
- [ ] Collision, symlink-safety, sentinel-preservation, launcher, dispatcher,
      and manifest rejection cases pass.
- [ ] Profile smoke and context-tree tests pass.
- [ ] No test asserts legacy installed paths or uses installed-core aliases.
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
  - `.agents/skills/shimmy-create-tool/SKILL.md`
  - `plugins/shimmy/skills/shimmy-create-tool/SKILL.md`
  - `agent/core/shimmy-create-tool/SKILL.md`
  - `agent/core/shimmy-tool-local-build/SKILL.md`
- other documentation:
  - `docs/prompt-shimmy-project.md`
  - `docs/testing.md`
  - `docs/templates/generic-shim/SKILL.md`
- persistent historical plans:
  - `plans/context.md`
  - `plans/context_remaining.md`
  - `plans/multi-architecture-manifest.md`
  - any additional plan found by the repeat scrub

### Implementation requirements

- Describe `lib/` as the shared library and the install root as the flat
  control/runtime root.
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

- [ ] Root and contributor docs accurately describe `lib/`, `bin/shimmy`, and
      the flat installation.
- [ ] All context links and paths are valid; the context-tree test passes.
- [ ] AI skill guidance contains no migrated `core/` path advice.
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
- [ ] Every remaining `core` match is reviewed and documented as intentional,
      including `agent/core/`, ordinary prose, and upstream API paths.
- [ ] Repository-wide search finds no installed `.agents/skills` payload
      assumption; explicit `shimmy skills` targets remain supported.
- [ ] `./bin/shimmy test` passes.
- [ ] `./tests/context-tree.sh` passes.
- [ ] A disposable fresh default install works.
- [ ] A disposable fresh upstream install works.
- [ ] Combined-profile activation and installed shim dispatch work.
- [ ] Additive install, management refresh, and self-update work without
      changing unmanaged sentinels.
- [ ] Removing one profile preserves the other; removing the final profile
      removes owned assets and preserves unmanaged content.
- [ ] The complete install tree, including hidden paths, matches the target
      layout.
- [ ] The repository diff contains no stale workstation-specific absolute
      paths and no unintended executable-bit changes.
- Notes:

### Suggested commands

Adjust temporary paths and selected shims as needed:

```sh
./bin/shimmy test
./tests/context-tree.sh
./bin/shimmy install --install-dir <tmpdir> --no-startup --no-skills
./bin/shimmy activate --install-dir <tmpdir>
<tmpdir>/bin/<shim> --version
./bin/shimmy update --install-dir <tmpdir>
./bin/shimmy uninstall --install-dir <tmpdir> --profile default
```

### Human review gate

Confirm the source and installed layouts are clear, all tests pass, and no
legacy path can be recreated.

## Risk register

### High risk

1. **Destructive install-root replacement** — Flattening removes the safety
   boundary of a bundled directory. All refresh and cleanup work must use the
   explicit ownership rules and safe-path validation.
2. **Launcher mode detection and replacement** — Both launchers live below
   `bin/`; incorrect root resolution, weak manifest checks, or non-atomic
   replacement could break every management command.
3. **Merge-owned `bin/` collisions** — Replacing `bin/`, following a launcher
   symlink, or accepting an unproven launcher could destroy or hijack managed
   dispatch.
4. **Manifest identity validation** — Partial or mixed schemas must be rejected
   before any path from them is trusted or any asset is changed.
5. **Dispatcher target integrity** — A stale central target can produce broken
   or recursive symlinks.
6. **Update detection** — Installed-management and fetched-source checks are
   tightly coupled to the layout and can silently misclassify partial trees.
7. **Versioned runtime paths** — One missed `core/runtime` reference causes a
   tool-specific failure that broad lifecycle tests may not expose.

### Medium risk

8. **Test rename coordination** — Runner paths, functions, shellcheck comments,
   and contexts must move together so tests are not silently dropped.
9. **Context and historical-plan drift** — Stale actionable paths can cause
   later sessions to restore the old model.
10. **Skills duplication assumptions** — Removing the installed
    `.agents/skills` copy is safe only while canonical `agent/` and tool-local
    agent sources remain part of the flat payload and skill commands continue
    resolving them there.

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
  launcher and file-level ownership in `bin/`.
- Directory renames also affect shellcheck source comments, context links,
  source-checkout validation, test support globs, and historical working plans.

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
   `bin/shimmy` is the sole launcher, and installed assets are flat.
3. Work only on the current chunk and stop at its human review gate.
4. Before stopping, update its checklist and **Lessons learned**, then report
   tests, uncertainties, and remaining risks.
