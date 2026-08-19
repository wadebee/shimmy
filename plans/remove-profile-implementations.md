# Remove Profile Implementations

## Objective

Remove Shimmy-generated `profiles/<profile>/implementations/` executable
adapters and route installed logical tools directly from the profile dispatcher
to `commands/run-tool.sh`. Preserve installed logical-tool execution,
environment-selected default versions, exact concrete-version smoke testing,
catalog-loss execution independence, profile isolation, and fail-closed runtime
target validation.

This refactor is feasible. Its operational value is real but modest: it removes
one executable asset per installed logical tool and concrete version, and one
shell load plus `exec` transition from each installed tool or concrete-version
smoke invocation. It is primarily an ownership and maintenance simplification,
not a meaningful disk-usage or container-runtime performance optimization.

Success requires:

- fresh profiles contain no Shimmy-owned `implementations/` directory;
- `bin/<tool>` remains the only public tool-command shape and resolves through
  `dispatch-tool.sh -> run-tool.sh <tool> -> versions/<label>/run.sh`;
- `shimmy test --shim <tool>@<label>` and `shimmy test --all` invoke concrete
  runtimes from explicit manifest fields, without parsing names such as
  `jq_1_8`;
- the redesigned profile format starts a fresh version-1 epoch, with both
  manifest identities set to 1 and the existing
  `profile-materialized-root` layout label retained;
- no pre-change profile is migrated, edited, or removed by the redesigned
  implementation; the user will run the currently installed
  `shimmy uninstall --global` before reinstalling the redesigned version;
- lifecycle rollback, sibling isolation, catalog-loss execution, and
  unmanaged-path preservation continue to hold; and
- implementation, tests, contexts, contributor guidance, canonical skills,
  and retained architectural plans agree on the new layout.

Excluded:

- adding public `bin/<concrete-version-name>` commands; they do not exist in the
  current implementation;
- changing `tool.conf`, `smoke.conf`, or catalog schema version 1;
- adding routing keys to `config/shims/*.conf`;
- inferring tool or version identity from underscore-separated shim names;
- migrating, editing, or uninstalling pre-change profiles with the new
  version-1 code;
- changing version-owned Podman runtime policy; and
- editing generated `.agents/skills/` adapters.

## Target layout and terminology

```text
profiles/<profile>/
  bin/
    shimmy
    jq -> ../commands/dispatch-tool.sh
  commands/
    dispatch-tool.sh
    run-tool.sh
  config/shims/
    jq.conf
    jq_1_8.conf
  install-manifest.txt
  tools/
    jq/
      tool.conf
      versions/1.8/run.sh
```

Public logical-tool execution:

```text
bin/jq
  -> commands/dispatch-tool.sh
  -> commands/run-tool.sh jq
  -> tools/jq/versions/<selected>/run.sh
```

Installed concrete-version smoke execution:

```text
shimmy test --shim jq@1.8
  -> tool_version=jq|1.8|jq_1_8
  -> tools/jq/versions/1.8/run.sh
```

Terms:

- **logical tool**: a public manifest `tool=<name>` entry and `bin/<name>`
  dispatcher, such as `jq`;
- **concrete version**: a non-`default`
  `tool_version=<tool>|<label>|<version-name>` entry, such as
  `jq|1.8|jq_1_8`;
- **default alias**: the manifest's `tool_version=<tool>|default|<version-name>`
  pointer; it is not a concrete runtime directory and must not cause duplicate
  metadata staging or smoke execution;
- **shim config**: the copied `config/shims/<name>.conf` smoke metadata; it does
  not become routing authority; and
- **implementation adapter**: the generated executable currently under
  `implementations/`; this asset class is removed.

## Recorded design decisions

1. Start a fresh version-1 profile epoch with
   `shimmy_install_manifest_version=1` and
   `shimmy_profile_manifest_version=1`; retain the accurate
   `shimmy_install_layout=profile-materialized-root` label.
2. Make global teardown a deployment precondition, not a compatibility path.
   After implementation is ready and before reinstalling it, the user will run
   `shimmy uninstall --global` through the currently installed version. The new
   version-1 code creates and validates only the redesigned layout and contains
   no migration, legacy-update, or legacy-uninstall branch. Implementation work
   must not perform that destructive live uninstall without separate explicit
   authorization.
3. Keep public dispatch logical-tool-only. `dispatch-tool.sh` validates the
   enclosing new version-1 profile and exact `tool=` ownership, validates the
   fixed profile-local `commands/run-tool.sh` target as an executable regular
   non-symlink file, and executes it with the logical tool name.
4. Do not read `config/shims/*.conf` in the dispatcher. Public mapping is an
   identity mapping enforced by catalog and manifest validation: public shim
   name equals logical tool name.
5. Use explicit manifest fields for concrete-version smoke routing. Installed
   tests carry the parsed tool, non-default version label, and logical version
   name together and execute `tools/<tool>/versions/<label>/run.sh` directly.
6. Never derive `jq -> jq_1_8` or `jq_1_8 -> jq@1.8` from filename syntax.
   `run-tool.sh` continues to own logical-tool default/environment selection;
   non-default manifest entries own exact smoke routing.
7. Stage logical-tool config from `tools/<tool>/tool.conf` and concrete config
   from the explicit non-default manifest tuple. Skip `default` aliases so one
   concrete version is copied and tested once.
8. Remove wrapper rendering, executable-mode handling, implementation-directory
   staging/replacement/rollback, profile-path constants, materialization
   validation, relocation rewriting, uninstall ownership, and collision tests
   that exist solely for implementation adapters.
9. Preserve fail-closed recursion and damage protection at the new fixed
   dispatcher target. Adapt the existing dispatcher integrity coverage to
   symlinked and non-executable `commands/run-tool.sh`; do not replace it with
   generic tests proving an obsolete wrapper path is rejected.
10. A new version-1 profile does not own an `implementations/` path. Fresh
    install still rejects any non-empty unmanaged profile root, but its
    uninstall must not claim or delete a user-created post-install directory
    with that name.
11. Implement the format, ownership, dispatch, test, and documentation changes
    as one atomic chunk. Do not leave a retained state in which a new manifest
    describes an old layout or old code is expected to consume a new layout.
12. Preserve the user's existing unrelated worktree changes, especially the
    overlapping edits in `docs/testing.md` and `tests/CONTEXT.md`.

## Verified implementation inventory

### Confirmed current behavior

- Only logical tools receive public `bin/<tool>` symlinks. Neither installation
  nor commit code creates `bin/jq_1_8`; concrete wrappers are internal assets
  used by installed smoke tests.
- `dispatch-tool.sh` currently validates the profile and manifest `tool=`
  ownership, then executes `implementations/<tool>`.
- Generated logical wrappers execute `commands/run-tool.sh <tool>`; generated
  concrete wrappers execute `tools/<tool>/versions/<label>/run.sh`.
- `run-tool.sh` already owns logical-tool default and environment-selector
  resolution.
- `config/shims/<tool>.conf` is copied from `tool.conf`, while
  `config/shims/<version-name>.conf` is copied from `smoke.conf`. Concrete
  smoke config does not contain its owning tool or version label.
- The explicit concrete route already exists in manifest entries of the form
  `tool_version=<tool>|<label>|<version-name>`.
- Profile validation checks implementation names, regular-file shape, symlink
  exclusion, and executable mode, but not wrapper contents. The wrappers are
  therefore a structural cross-check, not a code-integrity boundary.
- Installed test mode executes concrete wrappers directly for `--all`; public
  logical-tool smoke goes through `bin/<tool>`.
- Current generated wrappers always point to the materialized profile root,
  including `upstream`. Contributor and canonical-skill statements that say
  upstream wrappers execute the recorded checkout are stale and must be
  corrected.
- Prior manifest transitions bumped both manifest identities and intentionally
  did not migrate earlier layouts. For this change, the user has chosen a full
  global teardown followed by a fresh version-1 epoch, so historical profile
  formats are outside the redesigned implementation.

### Quantified baseline and expected value

Measurements were taken read-only on 2026-08-18 from the current checkout and
installed default profile.

| Measure | Current default baseline | Fully selected current catalog | Target |
|---|---:|---:|---:|
| Logical tools | 2 | 20 | unchanged |
| Concrete versions | 2 | 22 | unchanged |
| Generated implementation files | 4 | 42 | 0 |
| Wrapper logical bytes | 1,421 | 15,226 rendered bytes | 0 |
| Approximate 4 KiB-block allocation | 16 KiB | 168 KiB | 0 |
| Extra shell/`exec` transitions per installed invocation | 1 | 1 | 0 |

The full-catalog projection uses one final wrapper per 20 logical tools plus 22
globally unique concrete versions. Container images dominate storage and
startup cost, so no material wall-clock or disk-capacity claim should be made.

The active implementation/test/documentation surface contains 39 exact
`implementations` or `SHIMMY_PROFILE_IMPLEMENTATION_DIR` references across 15
files. The pre-change manifest identity has 15 exact references across 9 files.
Two architectural references in `plans/catalog-profile-separation.md` would
otherwise recreate the retired layout in later work.

### Primary producers, consumers, and lifecycle boundaries

- Producer and transaction boundary:
  `lib/install/profile-assets.sh`, `lib/install/install.sh`,
  `lib/install/manifest.sh`, and `lib/install/uninstall.sh`.
- Runtime consumer: `commands/dispatch-tool.sh` and
  `commands/run-tool.sh` (the latter should remain behaviorally unchanged).
- Ownership and schema validation: `lib/profile/profile.sh` and
  `lib/install/launcher-template.sh`.
- Installed smoke consumer: `tests/profile-smoke.sh`.
- Fixture and behavioral coverage: `tests/support.sh`,
  `tests/commands/dispatcher.sh`, `tests/commands/install.sh`,
  `tests/commands/lifecycle.sh`, `tests/commands/profiles.sh`,
  `tests/commands/test.sh`, and `tests/commands/update.sh`.
- Current guidance and retained architecture: `CONTEXT.md`,
  `commands/CONTEXT.md`, `lib/profile/CONTEXT.md`,
  `lib/install/CONTEXT.md`, `tests/CONTEXT.md`,
  `tests/commands/CONTEXT.md`, `docs/testing.md`, `CONTRIBUTING.md`,
  `README.md`, `plugins/shimmy/skills/shimmy-install/SKILL.md`, and
  `plans/catalog-profile-separation.md`.

This inventory is a verified baseline, not permission to ignore dependencies
found during implementation.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Atomically introduce fresh version-1 direct dispatch and remove the
  implementation-adapter asset class.

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

## Chunk 1 — Fresh Version-1 Direct Dispatch

### Goal

Commit one coherent fresh version-1 profile format in which logical public shims
dispatch directly through `run-tool.sh`, concrete installed smokes resolve from
manifest tuples, and no lifecycle component creates, validates, rewrites,
backs up, restores, or removes implementation adapters.

### Files

Primary code:

- `commands/dispatch-tool.sh`
- `lib/install/install.sh`
- `lib/install/launcher-template.sh`
- `lib/install/manifest.sh`
- `lib/install/profile-assets.sh`
- `lib/install/uninstall.sh`
- `lib/profile/profile.sh`
- `tests/profile-smoke.sh`
- `tests/support.sh`

Primary tests:

- `tests/commands/dispatcher.sh`
- `tests/commands/install.sh`
- `tests/commands/lifecycle.sh`
- `tests/commands/profiles.sh`
- `tests/commands/test.sh`
- `tests/commands/update.sh`

Guidance and retained context:

- `CONTEXT.md`
- `commands/CONTEXT.md`
- `lib/install/CONTEXT.md`
- `lib/profile/CONTEXT.md`
- `tests/CONTEXT.md`
- `tests/commands/CONTEXT.md`
- `docs/testing.md`
- `README.md`
- `CONTRIBUTING.md`
- `plugins/shimmy/skills/shimmy-install/SKILL.md`
- `plans/catalog-profile-separation.md`

The list identifies the primary surface; implementation must include any newly
discovered required producer, consumer, validator, fixture, or context update.
Do not modify generated `.agents/skills/` adapters.

### Implementation requirements

1. Refactor `dispatch-tool.sh` to keep its existing basename/direct-call shim
   name handling, profile-root derivation, safe-name validation, canonical
   profile validation, and exact manifest `tool=` ownership check. Replace the
   implementation lookup with a fixed profile-local `commands/run-tool.sh`
   target, require that target to be an executable regular non-symlink file,
   and `exec` it as `run-tool.sh "$shim_name" "$@"`.
2. Remove implementation-target absolute-resolution and recursive-adapter
   comparison. Preserve recursion safety by rejecting a symlinked fixed target
   and by never deriving the target from user-controlled metadata.
3. Leave `commands/run-tool.sh` responsible for tool metadata, default version,
   `SHIMMY_*` selector, available-version diagnostics, and concrete runtime
   execution. Do not teach it public concrete-shim naming.
4. Replace the combined wrapper/config staging helper with explicit metadata
   staging:
   - logical `tool=` entries copy `<tool>/tool.conf` to
     `config/shims/<tool>.conf`;
   - non-default `tool_version=` entries copy
     `<tool>/versions/<label>/smoke.conf` to
     `config/shims/<version-name>.conf`;
   - `default` aliases do not stage duplicate config; and
   - all source and destination paths come from validated tuple fields, not
     parsing `<version-name>`.
5. Use explicit non-default manifest labels in tool-version materialization and
   catalog snapshot comparison as well. Remove catalog-wide reverse lookup by
   logical version name where it existed solely to support wrappers.
6. Remove creation of the stage `implementations/` directory and remove that
   directory from owned-directory replacement, rollback, materialization
   validation, canonical path variables, uninstall cleanup, and all
   implementation-only helpers. Preserve transaction rollback for every
   remaining owned directory and file.
7. Render both manifest identities as version 1 and require the exact
   version-1 plus `profile-materialized-root` identity in the installed launcher
   and shared profile validation. Adapt the existing authoritative schema tests
   to accept that identity and retain integrity coverage for a mismatched
   layout or an arbitrary unsupported version. Do not add tests solely to prove
   rejection of the retired profile format, and add no legacy validation or
   migration branch.
8. In installed smoke mode, retain the parsed tool, label, and version name:
   - public tool smoke still runs through `bin/<tool>` and therefore exercises
     the dispatcher plus `run-tool.sh` selection;
   - exact version smoke executes
     `tools/<tool>/versions/<label>/run.sh`;
   - `--all` skips `default` aliases and executes each non-default manifest
     entry once; and
   - existing smoke env/arg loading continues to use copied shim configs.
9. Update fixture relocation to stop rewriting wrapper-embedded profile roots.
   Continue rewriting only assets that genuinely embed the relocated root.
10. Map existing tests to retained invariants:
    - replace implementation checksums used as sibling/non-mutation sentinels
      with materialized runtime or config checksums;
    - adapt dispatcher symlink/non-executable/recursion cases to the fixed
      `commands/run-tool.sh` integrity boundary;
    - retain unowned dispatch, unknown-version install, catalog-loss execution,
      selected-only materialization, update isolation, rollback, and uninstall
      assertions;
    - positively exercise `shimmy test --shim jq@1.8` and `shimmy test --all`
      against live Podman using non-mutating version smokes; and
    - prove fresh default and upstream version-1 profiles dispatch logical tools
      without wrapper generation.
11. Remove obsolete collision fixtures and assertions for a Shimmy-owned
    `implementations` path. Do not add tests whose only purpose is to prove that
    manual invocation of the obsolete path fails.
12. Update all closest contexts and current guidance. Correct the stale claim
    that upstream generated implementations execute a source checkout; current
    and target runtimes execute independently from the profile materialization,
    while the checkout remains catalog authority.
13. Update the retained catalog/profile separation plan's target tree and
    lesson so later work preserves profile-root execution independence without
    recreating executable adapters.
14. Preserve unrelated dirty changes line-by-line when editing overlapping
    files. Do not regenerate or edit external skill adapters.

### Verification checklist

- [ ] Re-read `git status --short` and the pre-existing diff before edits;
  confirm only intended lines in dirty files changed.
- [ ] Static search shows no active code, test, context, contributor, canonical
  skill, or retained-target reference that still creates or requires
  `implementations/`, `SHIMMY_PROFILE_IMPLEMENTATION_DIR`, or
  `render_shim_exec_wrapper`.
- [ ] Manifest renderer, launcher, shared validator, contexts, and tests agree
  on version 1 plus the `profile-materialized-root` layout; authoritative schema
  coverage rejects a mismatched layout and an arbitrary unsupported version
  without mutating profile assets.
- [ ] A fresh disposable default profile has logical `bin/jq` and `bin/rg`
  dispatcher links, no Shimmy-generated implementation adapters, and valid
  copied logical/concrete smoke metadata.
- [ ] A fresh disposable upstream profile has the same profile-local routing
  shape and continues to execute installed tools after its recorded checkout is
  unavailable, while catalog-aware operations still fail as designed.
- [ ] `bin/jq --preview-shim --version` resolves through
  `dispatch-tool.sh -> run-tool.sh jq -> jq/versions/1.8/run.sh` and preserves
  argument forwarding and environment-selector behavior.
- [ ] Symlinked or non-executable `commands/run-tool.sh` fails closed without
  recursion; an explicit request for an unowned logical tool remains rejected.
- [ ] `shimmy test --shim jq`, `shimmy test --shim jq@1.8`, and `shimmy test
  --all` pass through their intended public/exact paths with live Podman and
  non-mutating smoke arguments.
- [ ] Additive install, targeted update, self-update, catalog rollback,
  catalog-loss execution, profile-only uninstall, global uninstall, and sibling
  profile isolation retain their positive observable behavior under the new
  version-1 format.
- [ ] Failure-injected profile replacement restores all remaining owned
  directories/files and never leaves a mixed old/new profile.
- [ ] Targeted groups pass with the runner's bounded parallel default:

  ```sh
  ./tests/test.sh \
    --group commands-dispatcher \
    --group commands-test \
    --group commands-install \
    --group commands-lifecycle \
    --group commands-profiles \
    --group commands-update
  ```

- [ ] The complete default suite passes with its bounded parallel execution:

  ```sh
  ./tests/test.sh
  ```

  Diagnose only any failing group serially; do not replace acceptance with a
  broad serial run.
- [ ] Runnable shell files retain executable modes and the final diff contains
  no generated `.agents/skills/` changes.
- [ ] Record final file-count, logical-byte, and process-transition deltas in
  this plan. The required asset-count outcome is 4 to 0 for the baseline
  default profile and 42 to 0 for a fully selected current catalog; do not claim
  unmeasured wall-clock improvement.

### Human review gate

Confirm that fresh version-1 profiles preserve logical dispatch, selector
behavior, exact-version and `--all` smoke coverage, transaction rollback,
catalog-loss execution, and sibling isolation; that no implementation-adapter
ownership remains; and that the explicit global uninstall/reinstall boundary
and loss of internal adapter execution are acceptable. Stop after this review;
there is no later implementation chunk.

### Deployment handoff

After the implementation and review gate are complete, return control to the
user without changing the live installation. The user will optionally capture
any selections or redirects they want to recreate, run `shimmy uninstall
--global` with the currently installed pre-change launcher, then reinstall from
the redesigned checkout. Do not use the redesigned launcher to remove the old
layout, and do not treat successful disposable-profile tests as authorization
to mutate the live installation.

## Risk register

| Risk or capability loss | Impact | Mitigation or accepted disposition |
|---|---|---|
| Existing profiles cannot update in place | Before reinstalling, the user must use the currently installed code to run `shimmy uninstall --global`; profile selections, redirects, activation, startup policy, and external skill adapters must then be recreated as applicable | Explicitly accepted by the user; capture any desired status or redirect inventory before teardown, and keep migration and legacy uninstall out of the new code |
| No direct `profiles/<profile>/implementations/<name>` execution | Any undocumented scripts invoking those paths break | Accepted breaking removal; supported public tools and `shimmy test --shim <tool>@<label>` remain |
| Loss of a per-shim executable policy injection point | Future per-shim dispatch behavior would require declarative metadata, dispatcher policy, or version-runtime changes | Accepted because current wrappers contain no runtime policy; record the boundary in contributor guidance |
| Loss of wrapper structural validation | The profile no longer checks one duplicated executable per tool/version | Validate the fixed dispatcher target and retain exact config/runtime materialization validation; wrapper contents were never integrity-checked |
| Exact-version smoke could accidentally follow a default alias twice | Duplicate container runs or wrong route | Carry the manifest tuple explicitly and skip `label=default` |
| Same manifest tuple interpreted differently by installer, validator, and smoke code | Mixed or unrunnable profile | Update all producers/consumers in one fresh version-1 chunk and run failure-injected lifecycle coverage |
| Old and redesigned code cannot safely share installed state | Downgrade or rollback across the redesign requires another global teardown and reinstall; catalog rollback does not roll back profile schema | Document the clean-install boundary explicitly; do not imply catalog rollback is a control-plane rollback |
| Concurrent edits overlap dirty test documentation | User work could be overwritten | Inspect the existing diff before editing, patch narrowly, and review the final combined diff |
| Claimed performance benefit is overstated | Misleading rationale | Report only exact asset and process-transition counts; treat runtime savings as negligible beside Podman startup |

## Lessons learned

### Initial

- The proposed public `bin/jq_1_8` route is not current behavior. Concrete
  wrappers exist for installed smoke tests, not as public dispatcher links.
- The manifest is the only installed artifact that explicitly maps tool,
  concrete label, and logical version name. Copied smoke configs identify only
  the logical version name.
- Public dispatch does not need version mapping at all; adding a metadata parser
  there would widen responsibilities unnecessarily.
- Wrapper removal is a profile-format ownership change, not just deletion of a
  renderer. Manifest identity, lifecycle transactions, uninstall ownership,
  fixture relocation, installed smoke tests, and retained architectural
  guidance must move together.
- Current wrapper validation checks shape and mode but not contents, so the
  directory is not an integrity boundary.
- The user has explicitly chosen a global teardown and reinstall instead of a
  migration. This permits the redesigned layout to begin a fresh version-1
  epoch, but makes preservation of existing selections and redirects the
  user's pre-uninstall responsibility.
- The measurable resource saving is small: four files and 16 KiB allocated in
  the current baseline profile, or 42 files and about 168 KiB at full catalog
  selection. The stronger rationale is eliminating duplicated executable
  ownership and fixture/lifecycle branches.

## Session bootstrap

Start from the repository root. Read `AGENTS.md`, root `CONTEXT.md`,
`CONTRIBUTING.md`, this plan, and the child contexts for `commands/`,
`lib/profile/`, `lib/install/`, `tests/`, and `tests/commands/`. Reinspect
`git status --short` and the full pre-existing diff because
`docs/testing.md`, `plans/single-command-uninstall.md`, `tests/CONTEXT.md`,
`tests/lib/CONTEXT.md`, `tests/lib/runner.sh`, and `tests/runner.sh` already
contain user changes.

The active and only implementation unit is **Chunk 1 — Fresh Version-1 Direct
Dispatch**. The non-negotiable boundaries are: POSIX shell remains the
architecture; global uninstall/reinstall is a deployment precondition and
there is no pre-change migration or compatibility; no public concrete-name
dispatcher; no filename parsing for tool/version mapping; no routing fields in
shim config; no generated skill-adapter edits; preserve fixed-target
fail-closed validation, exact-version/`--all` smoke behavior, transaction
rollback, catalog-loss execution, and sibling isolation. Execute only Chunk 1,
update this plan with evidence and lessons, and stop at its human review gate.
