# Lifecycle test decomposition plan

## Objective

Replace the ambiguous and oversized lifecycle test boundaries with explicit,
independently scheduled scenarios:

- distinguish Darwin bootstrap from Linux bootstrap;
- extract Linux bootstrap acceptance from the current Linux end-to-end world;
- retain one bounded installed Linux workflow that proves cross-command behavior
  from a real generated launcher through uninstall;
- extract control-source and catalog synchronization into its own scenario; and
- eliminate the generic `commands-lifecycle-end-to-end` group after every
  existing assertion has an explicit destination.

Success requires six independently selectable lifecycle groups, preservation of
all current assertions and logical pass outcomes, private mutable state per
group, fake-only Podman execution, updated runner scheduling and current
documentation, and a materially shorter lifecycle critical path without an
unbounded increase in aggregate test work.

This plan does not authorize production behavior changes, assertion pruning,
new rejection/absence coverage, real Podman access, more than three workers, a
second test runner, or implementation before human approval. The current
uncommitted `engine.conf` comment work is outside this plan and must be
preserved.

## Target layout and terminology

- **Platform bootstrap scenario** proves a fresh default installation on one
  host model. Darwin and Linux are separate scenarios because they create
  different engine ownership records and lifecycle effects.
- **Installed Linux workflow** is the retained integration chain that starts
  from a fresh generated installation, exercises ordinary profile/shim/skill
  operations through installed launchers, and ends with uninstall. It replaces
  the vague end-to-end label without becoming a general assertion sink.
- **Control-source sync scenario** proves that control-only source changes,
  catalog publication, profile synchronization, direct skill-link
  reconciliation, catalog-content publication, verification, and rollback
  preserve their distinct authorities.
- **Lifecycle group** remains one registered child-process boundary with a
  private scenario checkout, HOME, configuration root, fake Podman state, and
  logs. Transitions inside one scenario remain serial.

The target registry segment is:

```text
commands-lifecycle-darwin-bootstrap|test_commands_lifecycle_darwin_bootstrap
commands-lifecycle-linux-bootstrap|test_commands_lifecycle_linux_bootstrap
commands-lifecycle-isolated|test_commands_lifecycle_owned_isolated
commands-lifecycle-uninstall|test_commands_lifecycle_global_owned_uninstall
commands-lifecycle-linux-workflow|test_commands_lifecycle_linux_workflow
commands-lifecycle-control-sync|test_commands_lifecycle_control_sync
```

The current `commands-lifecycle-bootstrap` name becomes
`commands-lifecycle-darwin-bootstrap`; no compatibility alias is retained.
The current `commands-lifecycle-end-to-end` group is removed after its
assertions move to the three explicit Linux scenarios.

## Recorded design decisions

1. Keep a reduced installed Linux workflow. Focused command tests prove local
   parser and transaction behavior, but they do not replace the current proof
   that bootstrap-generated launchers, manifests, shims, bundles, registry
   authority, shell selection, profile transitions, and uninstall work
   together.
2. Do not retain a generic end-to-end group. Its current 414-line body combines
   bootstrap, catalog inspection, shim/AI-skill mutation, profile create/clone,
   source publication/synchronization, administration, networking, startup
   repair, activation, uninstall, and failed-bootstrap compensation. The label
   no longer identifies one coherent ownership boundary.
3. Move fresh Linux bootstrap, initial default-profile/tool/catalog/engine
   inspection, startup and initial skill-link ownership, and the independent
   failed-bootstrap compensation case into
   `commands-lifecycle-linux-bootstrap`.
4. Move redirect/shim/AI-skill integration, dry-run non-mutation, sourced-shell
   profile creation, sibling isolation, clone behavior, installed artifact
   syntax, startup repair, admin/network inspection, activation, profile
   deletion, Linux uninstall, and unrelated-skill preservation into
   `commands-lifecycle-linux-workflow`.
5. Move management-only control-skill add/remove publication, unchanged catalog
   authority, profile control-source adoption, exact direct-link reconciliation,
   catalog-content publication, profile sync, verification, and rollback into
   `commands-lifecycle-control-sync`.
6. Preserve every current assertion during the structural split. Do not add
   tests proving that removed group names are rejected. If later pruning is
   desirable, perform a separate invariant-mapping review against the focused
   command suites.
7. Extract narrow Linux fixture helpers for repeated environment assembly,
   user-skill sentinels, bootstrap, image fixtures, and optional profile
   preparation. Helpers may reduce source duplication but must not share mutable
   scenario state across registered groups.
8. Continue using one immutable lifecycle checkout template with a private copy
   per selected group. Update the template-required predicate for all six target
   lifecycle names.
9. Rename current future-facing group references in contributor documentation
   and active/notional plans. Preserve completed plans and explicitly
   superseded historical plans as historical evidence.
10. Recalibrate the two- and three-worker static assignments only after the
    final group boundaries exist. Calibration uses the allowed serial diagnostic
    mode; ordinary acceptance uses the default bounded scheduler or explicit
    `--jobs 3`.
11. Use generated fake Podman state exclusively. No lifecycle command may reach
    the installed profile or real `shimmy-default` machine.
12. Do not create an ADR. Test grouping is reversible, the runner already
    establishes the governing pattern, and no production architecture decision
    is introduced.

## Verified implementation inventory

This inventory is the verified planning baseline, not permission to ignore
new dependencies discovered during implementation.

- Repository baseline: commit
  `2dca31997b38ab5344949414c4f2b58e984fc8a9`, Darwin arm64.
- The planning baseline recorded user engine-record comment changes in
  `README.md`, `lib/engine/state.sh`, `tests/lib/engine.sh`, and
  `tests/commands/lifecycle.sh`. The Chunk 1 ACT recheck found no remaining
  diffs in those files before implementation; future unrelated changes must
  still be preserved.
- The runner currently registers 43 groups and four lifecycle groups:
  bootstrap, isolated, uninstall, and end-to-end.
- `tests/commands/lifecycle.sh` is 1,128 lines. The current end-to-end function
  occupies lines 715-1128 and emits one logical PASS record despite spanning
  several independent behavioral clusters.
- The retained 2026-08-24 serial calibration measured
  `commands-lifecycle-end-to-end=1209` seconds; focused parallel acceptance
  measured it at 1327 seconds. The selected run on 2026-08-29 remained active
  beyond 20 minutes before passing, while the process tree showed normal
  progress rather than a hang.
- Commit `64617e5` subsequently added 128 lines to lifecycle coverage, primarily
  management-only control-skill publication and synchronization. That coherent
  block is an evidence-backed extraction boundary.
- Focused `commands-catalog`, `commands-shim`, `commands-profile`, and
  `commands-ai-skill` tests cover local command semantics. The lifecycle world
  uniquely covers their interaction through bootstrap-generated installed
  assets and authority transitions, so the installed workflow remains valuable.
- `tests/runner.sh` owns canonical registry and static worker assignments.
  `tests/lib/runner.sh` asserts exact lifecycle mappings, independent selection,
  template gating, deterministic replay, and one-/two-/three-worker behavior.
- `docs/testing.md` and `tests/commands/CONTEXT.md` describe the current four
  lifecycle groups.
- Future-facing commands in `plans/notional/bash-completion.md` and
  `plans/notional/image-retention-resilience.md` reference the group names being
  removed. `plans/wip/split-profile-create-clone.md` is explicitly superseded
  and remains historical; completed performance plans also remain unchanged.
- No production file consumes lifecycle group names. The change surface is the
  source test runner, lifecycle tests, runner tests, test documentation/context,
  and current future-plan commands.

## Performance acceptance

Before restructuring edits, capture one timing-enabled serial baseline for the
current end-to-end group. Preserve its group, total, real, user, system, and
logical-test evidence in this plan.

After the final split:

- the slowest new Linux lifecycle group must be at least 40 percent faster than
  the baseline end-to-end group;
- the three new Linux groups selected together with `--jobs 3` must complete in
  no more than 65 percent of the baseline end-to-end wall time;
- their summed serial group time must not exceed 135 percent of the baseline,
  bounding repeated bootstrap cost; and
- final static assignments must be recalculated from a complete timing-enabled
  serial calibration rather than guessed from historical weights.

If a threshold fails, stop at the active human review gate with timings and
the responsible phase identified. Do not delete assertions or move work into
shared setup merely to satisfy a number.

## Unresolved

None.

## Progress Checklist

- [x] Chunk 1 — Separate and explicitly name Darwin and Linux bootstrap
  acceptance. **Completed and verified; awaiting human acceptance.**
  - Pre-edit timing baseline passed on 2026-08-29 with
    `commands-lifecycle-end-to-end=1401` seconds, `total=1402` seconds,
    `real=1404.85` seconds, `user=519.87` seconds, `system=828.93` seconds,
    and one logical test. An immediately preceding runner-only measurement also
    passed at group 1393 seconds and total 1395 seconds.
  - Post-edit three-worker acceptance passed with Darwin bootstrap at 281
    seconds, Linux bootstrap at 151 seconds, retained end-to-end at 1349
    seconds, total 1351 seconds, and three logical tests.
- [ ] Chunk 2 — Replace the remaining catch-all end-to-end group with the
  installed Linux workflow and control-source sync groups, recalibrate, and
  complete acceptance. **Blocked pending explicit Chunk 1 acceptance.**

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

## Chunk 1 — Platform-specific bootstrap groups

### Goal

Give fresh Darwin and Linux bootstrap their own accurately named, independently
selectable scenarios while leaving the remainder of the existing end-to-end
world coherent for the next review gate.

### Files

- `tests/commands/lifecycle.sh`
- `tests/runner.sh`
- `tests/lib/runner.sh`
- `tests/commands/CONTEXT.md`
- `docs/testing.md`
- current future-facing plan commands that reference the renamed bootstrap
  group
- this plan

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. The work moves bootstrap, rollback, startup,
and exact skill-ownership assertions across child-process boundaries.

1. Capture the current timing-enabled serial end-to-end baseline before the
   first structural edit and record it under the progress checklist.
2. Rename the existing Darwin group/function to the exact target names without
   an alias. Preserve all existing Darwin assertions and PASS text except where
   platform-explicit wording improves accuracy.
3. Create the Linux bootstrap scenario from the initial fresh-bootstrap and
   default installation assertions plus the independent failed-bootstrap
   compensation block currently at the end of the end-to-end function.
4. Keep the remaining end-to-end function runnable and coherent. It may invoke
   the shared Linux bootstrap helper as a prerequisite, but it must not repeat
   assertions moved to the Linux bootstrap group.
5. Update runner registry, provisional assignments, exact runner mapping tests,
   template gating, test context, testing documentation, and future-facing
   commands for the Darwin rename and new Linux group.
6. Preserve all current assertions, fake-only environment injection, canonical
   replay order, exact result validation, and default three-worker bound.

### Verification checklist

- [x] `/bin/sh -n tests/commands/lifecycle.sh tests/runner.sh
  tests/lib/runner.sh` passes.
- [x] `./tests/test.sh --group runner` passes all 15 registry, mapping,
  selection, template, and scheduling tests.
- [x] `SHIMMY_TEST_TIMING=1 ./tests/test.sh --group
  commands-lifecycle-darwin-bootstrap --group
  commands-lifecycle-linux-bootstrap --group commands-lifecycle-end-to-end
  --jobs 3` passes and preserves every pre-split bootstrap/end-to-end assertion
  exactly once. Static accounting found 139 pre-split check/PASS statements and
  140 post-split statements: the same 139 plus the new Linux group PASS.
- [x] Generated command paths use only `SHIMMY_TEST_PROFILE_PODMAN_BIN` and the
  scenario fake; command-path inventory and the passing lifecycle run confirm
  no installed profile or real Podman machine was touched.
- [x] Context/documentation and current future-plan commands use the new Darwin
  and Linux bootstrap names; a scoped terminology search found no obsolete
  names, while completed and explicitly superseded history remains unchanged.
- [x] Executable modes are unchanged, `./tests/context-tree.sh` passes, and
  `git diff --check` passes.

### Human review gate

Confirm the Linux bootstrap boundary is complete, the remaining end-to-end
world still passes without duplicate bootstrap assertions, and the recorded
timing/coverage evidence supports Chunk 2. Acceptance authorizes only Chunk 2.

## Chunk 2 — Explicit Linux workflow and sync groups

### Goal

Remove the catch-all end-to-end group while retaining its valuable installed
integration chain and isolating control-source/catalog synchronization as an
independent scenario.

### Files

- `tests/commands/lifecycle.sh`
- `tests/runner.sh`
- `tests/lib/runner.sh`
- `tests/CONTEXT.md`
- `tests/commands/CONTEXT.md`
- `docs/testing.md`
- `plans/notional/bash-completion.md`
- `plans/notional/image-retention-resilience.md`
- this plan

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. The split must retain transactional and
ownership evidence while introducing independently mutable Git/profile worlds
and recalibrating the bounded scheduler.

1. Extract reusable Linux fixture helpers only where they express identical
   setup. Each registered group must still call `test_lifecycle_fixture_setup`
   and own a private checkout, HOME, config, fake Podman state, and logs.
2. Implement `commands-lifecycle-linux-workflow` with the assertion mapping in
   recorded decision 4. Retain one real installed lifecycle from bootstrap to
   uninstall and its unrelated-content preservation evidence.
3. Implement `commands-lifecycle-control-sync` with the assertion mapping in
   recorded decision 5. It owns source-checkout commits, management-only
   publication invariants, profile sync/link transitions, catalog-content
   publication, verification, and rollback.
4. Remove `commands-lifecycle-end-to-end` and its function only after an
   assertion inventory proves every statement moved exactly once. Do not add a
   negative test for the obsolete group name.
5. Update registry ordering, exact runner mapping tests, template gating,
   documentation/context, and current future-plan commands to the six-group
   target. Preserve completed and superseded historical evidence.
6. Run one timing-enabled complete serial calibration after the split, compute
   optimal bounded two-/three-worker static assignments from all final group
   times, update assignments, then run focused lifecycle and default-suite
   acceptance without intervening implementation edits.
7. Record all performance calculations and verification evidence in this plan.
   Treat a failed threshold as a review item, not permission to weaken coverage.

### Verification checklist

- [ ] `/bin/sh -n tests/commands/lifecycle.sh tests/runner.sh
  tests/lib/runner.sh` passes.
- [ ] `./tests/test.sh --group runner` passes with six exact lifecycle mappings,
  independent selection, template gating, and bounded scheduling.
- [ ] A mechanical before/after assertion inventory accounts for every
  pre-split assertion and all six logical lifecycle PASS outcomes.
- [ ] One timing-enabled serial calibration passes every registered group and
  supplies the final assignment weights.
- [ ] The timing-enabled six-group lifecycle selection passes with `--jobs 3`,
  fake-only execution, exact group/count coverage, and every performance
  threshold above.
- [ ] With no intervening implementation edit, one timing-enabled default suite
  passes every registered group exactly once using the recalibrated assignments.
- [ ] `./tests/context-tree.sh`, executable-mode review, generated installed
  artifact syntax, fake-Podman injection inventory, `git diff --check`, and a
  terminology search for obsolete future-facing group names pass.

### Human review gate

Confirm that all prior assertions remain authoritative, each group now names
one coherent scenario, the installed Linux workflow retains meaningful
cross-command value, timing and CPU costs satisfy the recorded bounds, and no
real Podman state was touched. Acceptance completes implementation but does not
complete this plan until the reviewer explicitly accepts the final results.

## Risk register

| Risk | Impact | Required mitigation |
| --- | --- | --- |
| Repeated Linux bootstrap increases total work | Parallel wall time improves while serial/CPU cost regresses materially | Bound summed final group time to 135 percent of baseline and share only source helpers, never mutable state |
| Assertions are lost during a large function split | Ownership or rollback regressions lose public acceptance coverage | Create a mechanical assertion inventory and preserve every current assertion before removing the old function |
| A reduced workflow becomes another catch-all | Future features accumulate under a vague integration label | Define its bootstrap-to-uninstall user journey and route control-source/catalog authority to its dedicated group |
| Cross-group mutable state is introduced | Parallel runs become order-dependent or contaminate source authority | Require a private scenario checkout/HOME/config/fake/log set per registered group and validate the immutable template after execution |
| Static assignments use obsolete weights | The new critical path remains unbalanced | Recalibrate after the final split and compute assignments from complete serial group timings |
| Unrelated engine-comment changes are overwritten | The user's completed work is lost during structural edits | ACT began with those paths clean; continue checking and preserving any unrelated changes that appear |
| Real Podman is reached | User VM or container state could be mutated | Verify fake injection on every lifecycle command path and reject any unscoped Podman call |
| Historical plans become misleading | Accepted evidence is rewritten as if it used future group names | Update only current future-facing commands; preserve completed and explicitly superseded plans |

## Lessons learned

### Initial

- The prior optimization correctly split independent top-level lifecycle worlds,
  but feature growth subsequently concentrated new control-source behavior back
  into the single Linux end-to-end group.
- The retained 1209/1327-second measurements and the current greater-than-20-
  minute run identify the end-to-end group as the lifecycle critical path.
- A public installed workflow remains useful because focused command fixtures
  do not prove generated launchers and independently owned catalog, profile,
  engine, startup, and skill state working together.
- Management-only publication and control-bundle reconciliation were added as
  one contiguous 128-line change and already form a coherent independent
  transaction scenario.
- Linux failed-bootstrap compensation uses its own configuration root and does
  not depend on the successful installation; it belongs with Linux bootstrap,
  not at the tail of the installed workflow.

### Chunk 1

- A source-only Linux bootstrap preparation helper can serve independently
  scheduled scenarios without sharing mutable state because every caller first
  creates its own checkout, HOME, configuration root, fake Podman state, and
  logs.
- The initial Linux installation boundary is 151 seconds in the focused
  parallel run, while the retained end-to-end scenario remains 1349 seconds;
  Chunk 2 must therefore isolate the workflow and control-sync phases to shorten
  the actual critical path.
- Statement accounting is a low-cost guard for this structural move: the split
  retained all 139 prior check/PASS statements and added only the new scenario's
  logical PASS.
- The implementation-start worktree no longer contained the engine-comment
  diffs described by the planning snapshot, so no overlapping user edit had to
  be merged during Chunk 1.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, `tests/CONTEXT.md`,
`tests/lib/CONTEXT.md`, `tests/commands/CONTEXT.md`, `docs/testing.md`, this
plan, `tests/test.sh`, `tests/runner.sh`, `tests/lib/runner.sh`, and
`tests/commands/lifecycle.sh`. Review the current worktree and preserve all
unrelated changes; the engine-comment paths recorded during planning were clean
when Chunk 1 implementation began.

The target is six explicit lifecycle groups, no generic end-to-end group, no
assertion loss, private fake-only scenarios, and calibrated bounded scheduling.
Chunk 1 is complete and verified at its human review gate. Do not begin Chunk 2
without explicit acceptance of the Chunk 1 results.
