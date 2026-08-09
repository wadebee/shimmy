# Remaining Context-first Shimmy Reorganization

> Status: complete. This file retains the implementation record and the
> evidence needed to review the finished migration. Use
> [context-handoff.md](context-handoff.md) as the prompt for any fresh review
> or follow-up session.

## Goal

Complete the context-first migration without reducing Shimmy behavior coverage.
Preserve the documented management commands, tool names, profiles, runtime
variables, image strategies, credentials, mounts, and non-mutating smoke
capabilities.

## Approach 

You may split this work into smaller iterations as needed to keep your context window manageable and to prevent truncation  of work when token usage budget is exceeded. Use this plan to maintain a section marked "Checklist" and place your work segments there marking each as done and allowing user review before continuing.

## Handoff context

### Current repository state

#### Completion status

- The context-first migration is complete: runtime, lifecycle, skills,
  contexts, documentation, and tests use `commands/`, `lib/`, `tools/`, and
  `tests/` rather than the retired source roots.
- Every tool kind owns a test module. The complete source suite passes when
  run directly as `./tests/test.sh`; it does not dispatch through an installed
  profile.
- All 18 concrete versions have an exact-approved, live non-mutating smoke
  result. The three OC tracks use Red Hat multi-architecture manifest-list
  digests and `oc --help` to avoid network-dependent version checks.
- The user owns commits. Do not assume that locally built or pulled images
  remain available in a later environment; obtain explicit authority before
  refreshing them again.

- Latest validated commit: `0fccc9d` (`test(gcloud): add gcloud context test
  files, update test script`). The worktree was clean when this handoff was
  refreshed. The user commits bounded segments; do not commit as the agent.
- The source layout has already moved from its pre-context roots into
  `lib/`, `commands/`, `tools/`, and `tests/`.
- `commands/run-tool.sh <kind> ...` is the generic source dispatcher. It reads
  `tools/<kind>/tool.conf`, resolves the optional selector, and executes
  `tools/<kind>/versions/<major.minor>/run.sh`.
- There are 16 tool kinds and 18 concrete versions, including the three `oc`
  tracks. Every version now owns `run.sh`, `refresh.sh`, `smoke.conf`, and
  `status.conf`; update and status have no command-level tool/version case
  lists.
- Default and upstream profile installs use manifest layout version 3 and
  independent canonical XDG flat roots. The installer intentionally rejects
  legacy root manifests and all active
  management paths have coverage for that rejection.
- `lib/install/`, `lib/update/`, and `lib/netinfo/` are decomposed into
  narrow sourceable modules. `commands/` remains thin public entrypoints.
- `tests/test.sh` now loads sourceable library, command, and tool-local
  modules. An installed profile provides smoke mode for its enclosing
  manifest with `--shim <kind>[@<version>]` and `--all`. Segments 3m and 3n
  cover that mode with XDG-isolated disposable fixtures; no live wrapper smoke
  has been run through it.
- Tool-local tests currently exist for Nmap, both OPNsense MCP variants, and
  gcloud configuration diagnostics. The gcloud diagnostic tests use the
  non-mutating `--shimmy-config-help` path and never create host config state.
- `tests/context-tree.sh` now enforces linked contexts for every source-bearing
  directory below `agent/`, `commands/`, `lib/`, `tools/`, and `tests/`,
  including canonical skills, test modules, and local container contexts.
- `agent/` and `tools/<kind>/agent/` are the sole canonical skill sources.
  `commands/skills.sh` exports from them without falling back to the read-only
  `.agents/` compatibility adapter.

### Environment and permission constraints

- Use `apply_patch` for all repository edits. Do not commit; the user stages
  and commits completed segments.
- `.agents/` is read-only. Do not overwrite its existing skills; treat it as
  an externally managed distribution adapter and update canonical sources plus
  `commands/skills.sh` instead.
- Podman live checks must be non-mutating. If an image is unavailable, do not
  silently pull or build it; report the missing authority because refresh is
  mutating. For every live wrapper smoke, request approval for the exact outer
  wrapper prefix through the Shimmy escalation workflow. Do not fall back to a
  host tool.
- The user may have a pre-existing legacy installation under their normal
  Shimmy config root. Use an absolute disposable `XDG_CONFIG_HOME` for tests;
  do not alter the user's installation.

### Recent verification

- After every completed segment, the relevant `dash -n` checks,
  `./tests/context-tree.sh`, `git diff --check`, and `./tests/test.sh` passed.
- A prior live `./commands/run-tool.sh jq --version` smoke succeeded. It does
  not satisfy the final per-version live-smoke requirement.

### Historical execution plan (complete)

1. Close test-recovery coverage.
   - Compare the current suite with `git show 33c0240:scripts/test-shimmy.sh`.
     The previously suggested `836ae00:scripts/test-shimmy.sh` path is absent;
     use `git log --all -- scripts/test-shimmy.sh` if another historical point
     is needed.
   - Restore only still-intended, distinct behaviors that are not already
     covered: likely candidates are remaining Podman-preflight guidance and
     tool-specific configuration/error paths. Put tool behavior in
     `tools/<kind>/tests/` with linked contexts. Read the canonical tool skill
     and every path context before changing a tool.
   - The acceptance criterion requires every kind to own tests. Only gcloud,
     Nmap, and the two OPNsense MCP kinds currently have tool-local test
     directories; add a focused non-Podman module for every remaining kind,
     even when the assertion is a version-owned preview contract.
   - Document consciously retired behavior rather than reintroducing legacy
     layout assumptions. Leave the high-level recovery checkbox unchecked
     until the comparison is explicitly closed.

2. Complete static acceptance.
   - Scan runtime, lifecycle, documentation, canonical skills, templates, and
     guides for retired `scripts/`, `shims/`, and `images/` source-root
     references and stale pre-flattening shared-module paths. Exclude the
     read-only `.agents/` compatibility adapter and legitimate container
     build-context paths only when documented.
   - Verify no command-level tool/version catalog, status-image, or refresh
     cases remain. Check executable bits, all shell syntax, contexts, and the
     full test suite. Exercise default/upstream installs only under disposable
     roots.
   - Do not run mutating pull/build refreshes as live checks without new user
     authority; retain preview and hook-contract coverage for those actions.

3. Complete live acceptance and request review.
   - Use temporary absolute `XDG_CONFIG_HOME` roots and execute a non-mutating smoke for every
     concrete version: `--version`, `version`, or `--help` from its
     `smoke.conf`. Cover all three `oc` tracks explicitly.
   - Request exact outer-wrapper approval before each live Shimmy invocation.
     Use installed/public wrappers where appropriate and the concrete runtime
     only where required to address a non-default installed version. Record
     the result for all 18 versions.
   - Re-run the documented matrix, report any unavailable local-build image as
     an authority blocker rather than building it, then obtain user review.

## Checklist

- [x] Segment 1: Rebuild the test runner as sourceable shared-library and management
  modules, covering metadata, previews, runtime helpers, lifecycle, profiles,
  skills, netinfo, and layout-version rejection against disposable installs.
- [x] Segment 2a: Move the install, update, and netinfo implementations into
  sourceable `lib/` entry modules and retain thin public command entrypoints.
- [x] Segment 2b: Split those library entry modules into their planned narrow
  request, manifest, profile, runtime-refresh, platform-discovery, and
  rendering modules.
- [x] Recover and modularize the complete behavioral test suite before further
  runtime refactors; run it after each subsequent segment.
- [x] Segment 3a: Restore bootstrap profile selection, status availability,
  profile-isolated uninstall, and repair-guidance coverage with disposable
  installs.
- [x] Segment 3b: Restore selected-shim profile-local update refresh,
  manifest-preservation, and update-validation coverage with disposable
  installs.
- [x] Segment 3c: Validate every concrete runtime and its generic dispatch
  path against the version-owned smoke metadata without contacting Podman.
- [x] Segment 3d: Restore activation idempotence and explicit startup-block
  install and repair coverage with disposable home directories.
- [x] Segment 3e: Restore canonical skill-source, portable-manifest, export,
  installed-kind, refresh, and manifest-tracked cleanup coverage.
- [x] Segment 3f: Restore source and installed dispatcher request-validation,
  canonical-profile, and recursion-protection coverage.
- [x] Segment 3g: Restore deterministic netinfo CIDR, explicit-host
  precedence, help, and malformed-input coverage.
- [x] Segment 3h: Enforce and verify consistent version-1 layout rejection for
  install, update, activate, and status while retaining the uninstall path.
- [x] Segment 3i: Add Nmap-owned preview tests for explicit LAN, network,
  capability, and privilege safety controls.
- [x] Segment 3j: Add read-only and admin OPNsense MCP-owned tests for URL
  normalization, secret separation, no-write defaults, and admin guidance.
- [x] Segment 3k: Restore additive install, enclosing-profile uninstall, and
  macOS Podman guidance coverage.
- [x] Segment 3l: Restore installed-management update coverage against a
  disposable manifest-recorded Git source.
- [x] Segment 4a: Reconcile canonical management skills under `agent/core/`
  with the context-first command, library, tool, test, and local-build layout.
- [x] Segment 4b: Reconcile all canonical tool skills and make skill export
  source only canonical `agent/` and `tools/<kind>/agent/` directories.
- [x] Segment 2b.1: Split netinfo orchestration into sourceable request, CIDR,
  platform-discovery, and rendering modules while preserving its public command.
- [x] Segment 2b.2: Split update request parsing and installed-profile/version
  selection into narrow sourceable library modules.
- [x] Segment 2b.3: Split update installed-management and profile-refresh
  lifecycle units into sourceable library modules.
- [x] Segment 2b.4: Replace centralized update image refresh cases with
  concrete-version `refresh.sh` hooks and generic hook dispatch.
- [x] Segment 2b.5: Split install lifecycle request, manifest, profile-asset,
  startup, and uninstall responsibilities into sourceable library modules.
- [x] Segment 2b.6: Move status image descriptions into concrete-version
  `status.conf` metadata and remove status runtime-image inspection.
- [x] Segment 3m: Restore `shimmy test` installed-profile request parsing,
  manifest validation, and version-owned non-mutating smoke orchestration.
- [x] Segment 3n: Cover installed-profile test dispatch, concrete-version
  selection, metadata errors, and canonical profile identity with disposable
  fixtures.
- [x] Segment 3o: Restore gcloud configuration-diagnostic coverage for
  missing, overridden, and present host configuration paths.
- [x] Segment 3p: Add tool-owned preview-contract tests for every remaining
  kind, restore Podman-unreachable approval guidance coverage, and replace
  command-level agent-preflight smoke cases with concrete-version metadata.
- [x] Segment 5a: Complete static acceptance: context links, POSIX parsing,
  metadata-driven preflight, retired-layout scan, executable test modules,
  and disposable default/upstream profile coverage.
- [x] Segment 5b.1: Build or pull all non-OC images and run exact-approved
  live smokes successfully for the remaining 15 concrete versions.
- [x] Segment 5b.2: Pin OC 4.20 to the supplied Red Hat multi-architecture
  CLI manifest-list digest and make OC smoke metadata non-network.
- [x] Segment 5b.3: Pin the supplied Red Hat manifest-list digests for the
  4.18 and 4.22 tracks, rebuild all three OC local images, and complete the
  exact-approved `oc --help` live smokes.
- [x] Split install, update, and netinfo into the planned `lib/` submodules.
- [x] Replace update cases with version-local refresh/status hooks.
- [x] Complete agent-skill canonicalization and adapter/export behavior.
- [x] Extend contexts and context validation to every source-bearing subtree.
- [x] Execute the full acceptance verification matrix and obtain user review.

## Core and lifecycle modularization

- Split `commands/install.sh` into sourceable `lib/install/` modules for
  request resolution, manifests, profile assets, startup integration, and
  uninstall cleanup; leave `commands/install.sh` as argument parsing and
  orchestration.
- Split `commands/update.sh` into `lib/update/` modules for profile refresh,
  source-management refresh, image pull/build refresh, and cleanup; retain
  `commands/update.sh` as the public entrypoint.
- Move host-network discovery functions from `commands/netinfo.sh` into
  `lib/netinfo/` modules grouped by input validation, CIDR handling, Linux,
  macOS, and output rendering.
- Add a `CONTEXT.md` file to every new library subtree and link it from
  `lib/CONTEXT.md`.

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
  in `tests/commands/`, shared-library tests in `tests/lib/`, and tool-specific
  tests under `tools/<kind>/tests/`.
- Make `tests/test.sh` load every module and retain all previous assertions for
  installation, manifests, activation, status, update, skills, netinfo,
  profiles, dispatch, credentials, error guidance, and tool behavior.
- Add test coverage for each new refresh/status hook and for every concrete
  tool version's metadata, preview path, installed dispatch, and live
  non-mutating Podman smoke command.
- Extend context-tree validation to cover `agent/`, tool `agent/` directories,
  test modules, local container directories that contain source files, and all
  new library subtrees. Require every context to be linked by its parent and every
  documented path to exist.
- Run `./tests/test.sh`, POSIX syntax checks, executable-bit checks,
  `git diff --check`, clean default/upstream install tests, `update --pull` and
  `update --build` tests, and live version/help smokes for all versions.

## Agent guidance and documentation

- Make `agent/` and each `tools/<kind>/agent/` the canonical skill sources.
  Update `commands/skills.sh` to materialize repository, profile, plugin, and
  export targets from those sources.
- Keep the read-only `.agents/` tree as a compatibility distribution adapter;
  document its generated or externally managed status without depending on it
  as the canonical source.
- Update all management skills under `agent/core/` and every tool skill so paths point to
  `commands/`, `lib/`, `tools/`, and `tests/`; remove remaining references to
  the retired source roots.
- Reconcile README, contributor guidance, templates, tool guides, and Podman
  instructions with the final hook and test layout.

## Acceptance criteria

- No runtime, lifecycle, or documentation path refers to retired `scripts/`,
  `shims/`, or `images/` source roots or the stale pre-flattening
  shared-module path.
- No command-level catalog, status-image, or update-refresh case list names a
  particular tool or concrete version.
- Every tool owns its runtime, metadata, guide, skill, tests, and local build
  context where applicable.
- The complete restored suite passes, and every concrete version has a live
  non-mutating Podman smoke result.

## Fresh-prompt handoff

Start a follow-up session with [context-handoff.md](context-handoff.md). It
sets the current scope to review and follow-up work instead of replaying the
completed migration. The separate
[multi-architecture-manifest.md](multi-architecture-manifest.md) plan records
future research into reusable manifest-list defaults for local-build tools.
