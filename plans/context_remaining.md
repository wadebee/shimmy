# Remaining Context-first Shimmy Reorganization

## Goal

Complete the context-first migration without reducing Shimmy behavior coverage.
Preserve the documented management commands, tool names, profiles, runtime
variables, image strategies, credentials, mounts, and non-mutating smoke
capabilities.

## Approach 

You may split this work into smaller iterations as needed to keep your context window manageable and to prevent truncation  of work when token usage budget is exceeded. Use this plan to maintain a section marked "Checklist" and place your work segments there marking each as done and allowing user review before continuing.

## Handoff context

### Current repository state

- The current checked-out commit is `b057923` (`feat(context): add
  comprehensive plan for context-first Shimmy reorganization`), and the
  worktree was clean when this handoff plan was updated.
- The source layout has already moved from `lib/`, `scripts/`, `shims/`, and
  `images/` into `core/`, `commands/`, `tools/`, and `tests/`.
- `commands/run-tool.sh <kind> ...` is the generic source dispatcher. It reads
  `tools/<kind>/tool.conf`, resolves the optional selector, and executes
  `tools/<kind>/versions/<major.minor>/run.sh`.
- Tool metadata currently uses `shim_name=`, `tool_default_version=`, and
  `tool_selector_env=` in `tool.conf`; concrete versions retain `shim_name=`
  and smoke arguments in `smoke.conf`. There are 16 tool kinds and 18 concrete
  versions, including the three `oc` tracks.
- Default and upstream profile installs use manifest layout version 2. The
  installer intentionally rejects a version-1 root manifest and tells the
  user to uninstall/reinstall; verify that every command handles this path
  consistently.
- `commands/status.sh` and `core/catalog/catalog.sh` have already been
  rewritten around tool-local metadata. `commands/update.sh` has not: its
  explicit tool/version refresh cases are the principal remaining centralized
  behavior.

### Known shortcuts that must be corrected

- `commands/install.sh` is still 1,375 lines, `commands/update.sh` is 737
  lines, and `commands/netinfo.sh` is 944 lines. Their target decomposition is
  described below; do not treat the current folder move as a completed module
  split.
- `tests/test.sh` is only a 94-line focused smoke suite. The prior 4,151-line
  behavioral suite was removed rather than migrated, so its coverage must be
  recovered and split before declaring the migration complete.
- Historical source is available from Git. The most useful recovery point is
  `git show 836ae00:scripts/test-shimmy.sh`; older behavior can be traced with
  `git log --all -- scripts/test-shimmy.sh` and `git log --all -- shims/jq`.
- `tests/context-tree.sh` now enforces linked contexts for every source-bearing
  directory below `agent/`, `commands/`, `core/`, `tools/`, and `tests/`,
  including canonical skills, test modules, and local container contexts.
- `agent/` and `tools/<kind>/agent/` contain canonical copies created during
  the migration, but core skill text and the read-only `.agents/` adapter have
  not been fully reconciled with the new paths.

### Environment and permission constraints

- `.git` is read-only to agents in this workspace. `git mv` and commits fail
  because Git cannot create `index.lock`; use `apply_patch` for edits and let
  the user perform staging/committing.
- `.agents/` is read-only. Do not overwrite its existing skills; treat it as
  an externally managed distribution adapter and update canonical sources plus
  `commands/skills.sh` instead.
- Podman is installed and works only with narrow escalation for this agent
  environment. `podman info` needs the `['podman', 'info']` approval, and a
  live generic jq smoke succeeded with the outer prefix
  `['./commands/run-tool.sh', 'jq', '--version']`.
- The user may have a pre-existing layout-version-1 installation under their
  normal Shimmy install root. Use disposable `/tmp` install roots for tests;
  do not alter the user's installation while validating migration behavior.

### Verification already performed

- `./shimmy test` passed, but it currently covers only context integrity,
  catalog/default discovery, preview paths, and a clean default-profile
  install/dispatch/uninstall flow.
- POSIX syntax checks were run over `shimmy`, commands, core modules, concrete
  version runtimes, and test scripts.
- Fresh default and upstream profile installs successfully dispatched jq
  previews; `shimmy update --shim jq` completed against a disposable install.
- Skills export worked from the new tool-local canonical jq skill, and a live
  `./commands/run-tool.sh jq --version` Podman smoke returned `jq-1.8.1`.
- A stale-path scan found no retired source-root references outside the
  read-only `.agents/` adapter and normal paths inside container build files.

## Checklist

- [x] Segment 1: Rebuild the test runner as sourceable core and management
  modules, covering metadata, previews, runtime helpers, lifecycle, profiles,
  skills, netinfo, and layout-version rejection against disposable installs.
- [x] Segment 2a: Move the install, update, and netinfo implementations into
  sourceable `core/` entry modules and retain thin public command entrypoints.
- [ ] Segment 2b: Split those core entry modules into their planned narrow
  request, manifest, profile, runtime-refresh, platform-discovery, and
  rendering modules.
- [ ] Recover and modularize the complete behavioral test suite before further
  runtime refactors; run it after each subsequent segment.
- [x] Segment 3a: Restore profile selection, status availability,
  profile-isolated uninstall, and repair-guidance coverage with disposable
  installs.
- [x] Segment 3b: Restore selected-shim and all-profile update refresh,
  manifest-preservation, and update-validation coverage with disposable
  installs.
- [ ] Split install, update, and netinfo into the planned `core/` submodules.
- [ ] Replace update cases with version-local refresh/status hooks.
- [ ] Complete agent-skill canonicalization and adapter/export behavior.
- [x] Extend contexts and context validation to every source-bearing subtree.
- [ ] Execute the full acceptance verification matrix and obtain user review.

## Core and lifecycle modularization

- Split `commands/install.sh` into sourceable `core/install/` modules for
  request resolution, manifests, profile assets, startup integration, and
  uninstall cleanup; leave `commands/install.sh` as argument parsing and
  orchestration.
- Split `commands/update.sh` into `core/update/` modules for profile refresh,
  source-management refresh, image pull/build refresh, and cleanup; retain
  `commands/update.sh` as the public entrypoint.
- Move host-network discovery functions from `commands/netinfo.sh` into
  `core/netinfo/` modules grouped by input validation, CIDR handling, Linux,
  macOS, and output rendering.
- Add a `CONTEXT.md` file to every new core subtree and link it from
  `core/CONTEXT.md`.

## Tool-local metadata and refresh hooks

- Replace the remaining tool/version `case` statements in update behavior with
  version-local hooks at `tools/<kind>/versions/<version>/refresh.sh`.
- Define a common hook contract: accept `pull` or `build`, perform only the
  relevant remote-image pull or local-image rebuild, and preserve the existing
  environment override semantics and non-mutating tool invocation used to
  trigger refreshes.
- Add version-local status metadata or hooks so status image descriptions are
  derived from the owning version directory rather than command-level logic.
- Keep `tool.conf` as the source of default-version and selector metadata;
  retain `smoke.conf` as the source of installed smoke configuration.

## Tests and verification

- Restore the prior behavioral suite by splitting it into sourceable modules:
  shared assertions and fixtures in `tests/`, command/profile lifecycle tests
  in `tests/commands/`, shared-core tests in `tests/core/`, and tool-specific
  tests under `tools/<kind>/tests/`.
- Make `tests/test.sh` load every module and retain all previous assertions for
  installation, manifests, activation, status, update, skills, netinfo,
  profiles, dispatch, credentials, error guidance, and tool behavior.
- Add test coverage for each new refresh/status hook and for every concrete
  tool version's metadata, preview path, installed dispatch, and live
  non-mutating Podman smoke command.
- Extend context-tree validation to cover `agent/`, tool `agent/` directories,
  test modules, local container directories that contain source files, and all
  new core subtrees. Require every context to be linked by its parent and every
  documented path to exist.
- Run `./shimmy test`, POSIX syntax checks, executable-bit checks,
  `git diff --check`, clean default/upstream install tests, `update --pull` and
  `update --build` tests, and live version/help smokes for all versions.

## Agent guidance and documentation

- Make `agent/` and each `tools/<kind>/agent/` the canonical skill sources.
  Update `commands/skills.sh` to materialize repository, profile, plugin, and
  export targets from those sources.
- Keep the read-only `.agents/` tree as a compatibility distribution adapter;
  document its generated or externally managed status without depending on it
  as the canonical source.
- Update all core agent skills and every tool skill so paths point to
  `commands/`, `core/`, `tools/`, and `tests/`; remove remaining references to
  the retired source roots.
- Reconcile README, contributor guidance, templates, tool guides, and Podman
  instructions with the final hook and test layout.

## Acceptance criteria

- No runtime, lifecycle, or documentation path refers to retired `lib/`,
  `scripts/`, `shims/`, or `images/` source roots.
- No command-level catalog, status-image, or update-refresh case list names a
  particular tool or concrete version.
- Every tool owns its runtime, metadata, guide, skill, tests, and local build
  context where applicable.
- The complete restored suite passes, and every concrete version has a live
  non-mutating Podman smoke result.
