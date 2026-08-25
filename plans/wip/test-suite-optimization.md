# Lifecycle test critical-path optimization

## Objective

Reduce lifecycle test feedback time by replacing the monolithic
`commands-lifecycle` critical path with independently scheduled, internally
indivisible scenario groups, adding timing-gated progress and failure evidence,
and reusing one immutable prepared lifecycle checkout through isolated fixture
copies.

Success requires all of the following:

- a current passing same-host timing baseline before optimization edits;
- five independently selectable lifecycle scenario groups that retain every
  current assertion and logical pass record;
- one canonical group registry, deterministic replay, exact count/status
  validation, and at most three bounded workers;
- unchanged output when `SHIMMY_TEST_TIMING` is unset;
- timing-enabled setup, group, and total records on success and failure, plus
  deterministic timing-gated `START` evidence in private group logs and the
  interrupted transcript;
- one immutable lifecycle checkout template prepared at session scope and
  scenario-private copies that preserve Git metadata, executable modes,
  symlinks, clean-main authority, and mutation independence;
- a low-cost direct contract for generated fake-Podman machine-init success,
  pre-mutation failure, and post-create failure;
- fake-only machine lifecycle acceptance with no access to a real Podman
  machine or the current Shimmy installation;
- a final measured improvement target derived from the passing current
  baseline rather than historical timings; and
- one final timing-enabled focused acceptance followed, without further edits,
  by one timing-enabled default full-suite acceptance.

This plan does not authorize removing assertions, weakening destructive-action
or ownership coverage, introducing a separate fast suite, exceeding three
workers, changing production command behavior merely to improve a test time,
or mutating a real Podman machine. The production engine-migration conflict
found during baseline discovery is unresolved below and is not silently
included in the optimization scope.

## Target layout and terminology

- **Lifecycle scenario group** is one registered child-process boundary whose
  internal state transitions remain serial and indivisible.
- **Lifecycle checkout template** is one session-owned, immutable, clean Git
  repository containing the current worktree plus lifecycle fake runtimes.
- **Scenario checkout** is a private copy of that template beneath one
  `setup_scenario` root. End-to-end publication and sync mutate only this copy.
- **Progress record** is an opt-in record with stable shape
  `shimmy_test_progress=<setup|group>|<name>|START`.
- **Timing record** retains the existing stable shape
  `shimmy_test_timing=<setup|group|total>|<name>|<elapsed-seconds>`.
- **Passing baseline** means setup, selected-group, and total timing records are
  present and the selected test count is accepted. A failed or interrupted run
  is diagnostic evidence, not a performance baseline.

The intended registry replacement is contiguous and canonical:

```text
commands-lifecycle-bootstrap|test_commands_lifecycle_darwin_bootstrap_engine_states
commands-lifecycle-isolated|test_commands_lifecycle_owned_isolated
commands-lifecycle-migration|test_commands_lifecycle_explicit_migration
commands-lifecycle-uninstall|test_commands_lifecycle_global_owned_uninstall
commands-lifecycle-end-to-end|test_commands_lifecycle_end_to_end
```

The old umbrella `commands-lifecycle|test_commands_lifecycle_run` entry and
wrapper are removed after future-facing invocations are updated. Existing
completed-plan results remain historical evidence and are not rewritten.

## Recorded design decisions

1. The durable indivisibility boundary is each top-level lifecycle scenario,
   not all five scenarios sharing one worker. Every scenario currently creates
   its own world directly or through
   `test_commands_lifecycle_darwin_bootstrap_case`, and registered groups run in
   separate child processes, isolating their shell globals.
2. Do not add a duplicate `scenario` timing scope. Once each scenario is a
   registered group, its authoritative scenario duration is its existing
   `group` timing record.
3. Add the separate progress record above under the existing invocation-only
   `SHIMMY_TEST_TIMING=1` toggle. The runner writes a group `START` record before
   launching the group into its private log. Lifecycle-template preparation
   emits a setup `START` record before work begins.
4. Preserve timing evidence on failures by capturing the group-run status
   without allowing `set -e` to skip total timing, replaying logs and emitting
   total timing, then returning the original nonzero result. On HUP, INT, or
   TERM, a worker appends elapsed group timing after terminating its recorded
   group child; the parent replays existing logs in canonical order and emits
   elapsed total timing before cleanup. Interrupted replay is enabled only when
   timing is opted in, preserving the timing-disabled transcript.
5. Guard interrupted replay with explicit parent state so a signal after
   ordinary replay cannot duplicate logs. Continue terminating and waiting
   only for recorded worker and group PIDs.
6. Prepare the lifecycle checkout template once after copy-on-write detection
   and only when at least one registered lifecycle scenario is selected. Time
   template preparation separately as setup. Remove ignored checkout-only
   content such as `.kilo/` from the disposable clean template before making
   scenario copies; retain every committed or non-ignored current-worktree
   byte in its new clean Git history.
7. `test_lifecycle_fixture_setup` creates scenario HOME/config/log/fake-Podman
   state as it does now, but obtains its checkout through
   `test_fixture_tree_copy` from the prepared template. It never shares mutable
   HOME, config, logs, machine-state files, or a checkout with another group.
8. Validate the template after successful group execution by checking its
   recorded HEAD and clean Git state. Existing copy-helper coverage remains the
   authority for clone selection, portable fallback, mode/symlink preservation,
   path safety, and post-copy mutation independence.
9. Put the generated fake-Podman init contract in
   `tests/lib/profile-activation.sh`, where
   `profile_activation_fake_create` is owned. One existing logical test records
   ordinary success/`stopped`, injected pre-mutation failure/`absent`, and
   injected post-create failure/`stopped`, including the explicit success-path
   status terminator. These are durable destructive-boundary assertions, not
   generic rejection duplication.
10. Preserve all five lifecycle logical pass records. The only planned test
    count increase is the one new fake-provider contract record; runner
    progress/interruption assertions extend existing runner logical records.
11. After structural changes are stable, run one timing-enabled complete serial
    calibration to obtain every final group time. Recompute both two-worker and
    three-worker static assignments from those values, minimizing the maximum
    worker sum while preserving canonical replay and exact once-only group
    coverage. The calibration is evidence, not final acceptance.
12. After assignment changes, run cheap runner verification, then the one final
    focused lifecycle acceptance and one final default full suite specified in
    the objective. No implementation or documentation edits occur between
    those two final acceptance commands.
13. Update current contributor documentation, test contexts, and pending
    future-plan commands that would otherwise select the removed umbrella
    group. Preserve completed results and already-executed WIP evidence as
    historical records.

## Verified implementation inventory

This inventory is the verified planning baseline, not permission to ignore
additional dependencies discovered during implementation.

### Frozen repository state

- Repository: `/Users/wade/Repos/Github/wadebee/shimmy`
- Initial planning commit: `c11895713311cb660b8a16fec992db68beb0b968`
- ACT baseline commit: `30b2df1` plus the user's coherent uncommitted
  shared-engine cleanup and uninstall-fixture corrections
- Host: Darwin 25.5.0 arm64; macOS product version 26.5.1
- Pre-plan worktree: only
  `plans/notional/test-suite-optimization-handoff.md` modified by the user
- Frozen handoff diff checksum: `932958084 10436` from POSIX `cksum`
- The new plan file is the only artifact created by this PLAN phase.

### Current runner and fixture behavior

- `tests/runner.sh` registers 39 groups and assigns each exactly once for one,
  two, and three worker execution.
- The single `commands-lifecycle` entry maps to
  `test_commands_lifecycle_run`, which calls five top-level scenarios
  serially.
- The current lifecycle group owns five pass records. The complete suite's
  last accepted historical result contains 129 pass records, but it predates
  commit `c118957`.
- Each top-level scenario establishes a private root. Static inspection found
  no scenario consuming another top-level scenario's HOME, config, checkout,
  log, Git, or fake-machine state.
- `test_lifecycle_fixture_setup` is invoked six times. Every call copies the
  complete repository, removes/recreates `.git`, stages and commits the
  checkout, writes fake tool runtimes, commits again, and creates private fake
  Podman state.
- The checkout is approximately 67,764 KiB on this host. The ignored
  `.kilo/` tree is approximately 58,188 KiB and is copied into every lifecycle
  checkout even though it is excluded from the fixture's Git commit.
- `test_fixture_tree_copy` already probes native copy-on-write support, has a
  portable `cp -R` fallback, rejects unsafe targets, and directly proves Git,
  mode, symlink, and mutation independence.
- End-to-end publication mutates its checkout. An immutable template is safe
  only when every group receives a private copy.
- Group logs are buffered and replayed canonically. On ordinary group failure,
  group timing is appended and replayed. Because `main` runs the group helper
  under `set -e`, a failed group currently skips total timing. Signal cleanup
  removes logs without replay or elapsed group/total timing.
- `profile_activation_fake_create` owns the command fake used by lifecycle
  acceptance. Its init branch can fail after writing `stopped`, but has no
  direct low-cost three-state contract and no pre-mutation init injection.

### Historical comparison

- The accepted 2026-08-17 lifecycle measurement of approximately 227 seconds
  came from commit `f3a1376f8d2f37451f2da2eb257186a473088d67` and an older
  494-line lifecycle test.
- The current lifecycle file is 1,006 lines. Across 74 commits from that
  baseline to `c118957`, the file gained 961 lines and lost 449.
- The added behavior includes shared-engine bootstrap/projection, owned
  isolated create/clone/delete, explicit engine migration and rollback,
  journaled global owned-engine uninstall/retry, name-reappearance protection,
  ambiguous-init retention, and the redesigned end-to-end control surface.
- The triggering approximately 42-minute runs predated `c118957` and did not
  enable `SHIMMY_TEST_TIMING`; they remain historical evidence only.

### Current baseline attempt and discovered blocker

The required current command was run once from the frozen state:

```sh
SHIMMY_TEST_TIMING=1 ./tests/test.sh --group commands-lifecycle
```

Observed result:

```text
shimmy_test_timing=setup|copy-on-write-probe|0
PASS: Darwin bootstrap creates the owned shared engine and rejects an exact pre-existing machine without mutation
PASS: owned isolated create stages before transition, prepares images on target, and deletion resumes after machine removal
ERROR: Podman machine or connection name collision: shimmy-default
ERROR: engine migration failed
shimmy_test_timing=group|commands-lifecycle|796
FAIL: test worker failed: three-a
```

The run is not a performance baseline: it failed after 796 seconds, emitted no
total timing, and never executed the uninstall or end-to-end scenarios.

The cause is confirmed in `c118957`:

- unmigrated profile `default` resolves its existing legacy machine as
  `shimmy-default`;
- the same commit changed migration's new shared-machine target from `shimmy`
  to `shimmy-$SHIMMY_PROFILE_ACTIVE_NAME`, also `shimmy-default`;
- migration preflight first requires that new shared target to be absent, then
  requires each existing legacy profile machine, including the same
  `shimmy-default`, to exist;
- those conditions are mutually exclusive for the active profile. Changing
  only the fake fixture cannot make the production migration contract valid.

The user repaired that regression in `30b2df1` by retaining the reserved
`shimmy` name for the shared engine created during compatibility migration and
keeping legacy `shimmy-default` external. The exact timing command was then
rerun from the repaired worktree and passed all five logical lifecycle tests:

```text
shimmy_test_timing=setup|copy-on-write-probe|0
shimmy_test_timing=group|commands-lifecycle|2492
shimmy_test_timing=total|suite|2492
All 5 Shimmy tests passed.
```

The accepted optimization target is at least a 20 percent reduction from this
2,492-second same-host critical path: the final five-group focused acceptance
must complete in no more than 1,993 seconds. Final two- and three-worker
assignments remain measurement-driven from the post-split serial calibration.

### Assertion and invariant mapping

| Target group | Existing authoritative proof retained inside the group |
| --- | --- |
| `commands-lifecycle-bootstrap` | Fresh shared creation; activation-before-image order; shared policy service recycle without VM restart; projection rollback; exact complete rollback after start failure; ambiguous post-init retention; removal-failure retention; exact pre-existing collision refusal |
| `commands-lifecycle-isolated` | Workload guard; isolated dry run; journaled create/order/image preparation; shared/isolated activation; clone mode planning; fresh ownership token; destructive deletion warning; interrupted removal journal and exact retry cleanup |
| `commands-lifecycle-migration` | No implicit migration on sync; dry-run plan; pre-commit rollback; retained incomplete rollback; retry to complete schema; legacy-external preservation; absence of stop/start/remove against the legacy machine |
| `commands-lifecycle-uninstall` | Owned shared/isolated plan; external and identity-mismatched preservation; workload acknowledgement; durable partial-removal journal; reused-name rejection; exact owned retry completion |
| `commands-lifecycle-end-to-end` | Sourced bootstrap/PATH; catalog/profile/engine status; redirects; shim and AI-skill lifecycle; dry-run non-mutation; profile create/clone/delete isolation; installed artifact syntax; startup repair; catalog publish/sync/rollback; admin/network; activation; global uninstall; unrelated skill preservation; failed-bootstrap compensation |

## Unresolved

None.

## Progress Checklist

- Active phase: ACT — Chunk 2 complete and awaiting human review.
- [x] Confirm objective and `plans` lifecycle root.
- [x] Read repository guidance, test contexts, current runner/lifecycle sources,
  and retained performance/rollback plans.
- [x] Freeze commit, host, and pre-plan worktree evidence.
- [x] Freeze a passing current lifecycle baseline.
  - Result: setup `0`, monolithic lifecycle group `2492`, total `2492`, all five
    logical tests passed.
  - Target: final five-group focused acceptance at or below `1993` seconds.
- [x] Resolve all design decisions and set `## Unresolved` to `None`.
- [x] Chunk 1 — Add runner evidence retention and the fake-provider contract.
  - Human accepted Chunk 1 by requesting Chunk 2 implementation on
    2026-08-24.
- [x] Chunk 2 — Split lifecycle groups, reuse the checkout template, calibrate
  assignments, and complete final acceptance.

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

The user authorized implementation by requesting a retry after repairing the
baseline failure. Execute one chunk at a time and retain the human review gates.

## Chunk 1 — Preserve progress and fake-init evidence

### Goal

Make timing-enabled runs explain progress and preserve setup/group/total
evidence through success, failure, and interruption, and establish the cheap
generated fake-Podman init contract before expensive lifecycle work.

### Files

- `tests/runner.sh`
- `tests/lib/runner.sh`
- `tests/lib/profile-activation.sh`
- `tests/CONTEXT.md`
- `tests/lib/CONTEXT.md`
- `docs/testing.md`
- this plan

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. Signal/status propagation and fake machine
mutation are failure-boundary contracts.

1. Implement the progress/timing/failure decisions recorded above without
   changing timing-disabled successful or interrupted output.
2. Extend existing runner timing and signal logical tests rather than adding
   duplicate pass records. Use a harmless slow synthetic group to prove a
   timing-enabled TERM run replays `START`, elapsed group timing, elapsed total
   timing, and the original interruption status while removing only its test
   session root.
3. Add pre-mutation `machine_init` injection to the generated fake before it
   writes `stopped`; retain the current post-create injection after that write
   and an explicit `:` success terminator.
4. Add one direct fake-provider logical test that invokes the generated fake in
   all three init states and checks exit status plus the exact state file.
5. Preserve existing result validation, canonical replay, PID ownership,
   signal statuses, POSIX shell, and fake-only behavior.

### Verification checklist

- [x] `/bin/sh -n tests/runner.sh tests/lib/runner.sh
  tests/lib/profile-activation.sh` passes.
- [x] `SHIMMY_TEST_TIMING=1 ./tests/test.sh --group runner --group
  lib-profile-activation --jobs 3` passes with progress and complete timing
  records.
  - Result: setup `0`, runner `1`, profile activation `9`, total `9`, all 24
    logical tests passed.
- [x] The same focused command without the toggle contains no progress or
  timing records and preserves its prior transcript shape apart from the one
  new fake-contract PASS record.
  - Result: all 24 logical tests passed with no `shimmy_test_progress` or
    `shimmy_test_timing` records.
- [x] Focused runner signal coverage proves original status, partial evidence,
  no duplicate replay, and safe cleanup.
  - Result: the existing signal logical record now exercises timing-disabled
    and timing-enabled TERM, retains status `143`, replays one canonical START
    plus elapsed group/total records only when enabled, terminates the recorded
    worker, and removes only its session root.
- [x] `./tests/context-tree.sh` and `git diff --check` pass.

### Human review gate

Confirm record schemas, opt-in behavior, failure/signal status preservation,
PID-scoped cleanup, and the direct fake init state contract. Acceptance
authorizes only Chunk 2.

## Chunk 2 — Split and reuse lifecycle scenarios

### Goal

Replace the monolithic lifecycle critical path with five scenario groups,
prepare one immutable checkout template, rebalance static workers from final
measurements, and complete focused plus full acceptance without coverage loss.

### Files

- `tests/test.sh`
- `tests/runner.sh`
- `tests/support.sh` only if implementation discovers a required generic-copy
  seam; do not weaken its existing contract
- `tests/lib/runner.sh`
- `tests/commands/lifecycle.sh`
- `tests/CONTEXT.md`
- `tests/lib/CONTEXT.md`
- `tests/commands/CONTEXT.md`
- `docs/testing.md`
- pending future-facing plans identified by the final terminology search,
  including `plans/wip/split-profile-create-clone.md`,
  `plans/notional/bash-completion.md`, and
  `plans/notional/image-retention-resilience.md`
- this plan

### Implementation requirements and suggested reasoning level

Suggested reasoning level: xhigh. The change crosses concurrency, fixture
isolation, Git publication authority, destructive lifecycle acceptance, and
static scheduling.

1. Register the five exact target groups in the recorded order, remove the old
   umbrella entry/wrapper, and update runner contract coverage to protect each
   scenario's indivisibility and exact mapping.
2. Implement conditional parent template preparation, ignored-content pruning,
   separate setup timing, scenario copies, and post-run immutability validation
   exactly as recorded above.
3. Preserve the complete assertion mapping. Do not move an assertion between
   scenarios merely to balance time and do not introduce new negative coverage
   beyond the already approved fake-init destructive boundary.
4. Prove all five functions execute independently in fresh child processes and
   concurrently under three workers with private scenario roots and fake logs.
5. Run syntax, cheap runner/profile-activation tests, and direct static review
   before broad calibration. Do not launch lifecycle acceptance while code is
   still changing.
6. Run one timing-enabled complete serial calibration. Record setup, every
   group, total, final group count, and final test count in this plan. Compute
   and apply final two-/three-worker static assignments, then rerun only cheap
   runner coverage after the assignment edit.
7. Prefix the final focused command with `SHIMMY_TEST_TIMING=1`, select all
   five lifecycle groups, and use `--jobs 3`. Require one setup-template time,
   five group times, one total time, five existing lifecycle pass records, and
   the improvement target that will be fixed after the prerequisite baseline.
8. Make no further edits, then run `SHIMMY_TEST_TIMING=1 ./tests/test.sh` once.
   Require every registered group exactly once, the final expected test count,
   deterministic output, and a passing total record.
9. Run `/bin/sh -n` on changed shell files and generated installed artifacts
   exercised by lifecycle, `./tests/context-tree.sh`, executable-mode review,
   `git diff --check`, and a final terminology search.
10. Confirm every lifecycle command path still receives the generated fake
    through `SHIMMY_TEST_PROFILE_PODMAN_BIN`; do not inspect or invoke a real
    Podman machine.

### Verification checklist

- [x] Runner registry/assignment validation proves the final group count,
  unique function mappings, scenario ordering, and one-/two-/three-worker
  scheduling.
- [x] Template preparation is conditional, separately timed, clean, immutable,
  and safe through both copy-on-write and portable copy contracts.
- [x] Serial calibration passes and final assignments minimize the measured
  maximum worker sum.
- [x] The timing-enabled five-group focused run passes with all required setup,
  progress, group, total, count, isolation, and performance evidence.
- [x] With no intervening edit, the timing-enabled default full suite passes
  exact group/count coverage.
- [x] Syntax, generated artifact syntax, context tree, executable modes,
  whitespace, fake-only boundary, and future-facing selection commands pass
  final review.

### Chunk 2 serial calibration evidence

The one required timing-enabled complete serial calibration passed on
2026-08-24 with 43 groups, 130 logical tests, setup times of `0` seconds for
copy-on-write detection and `1` second for the lifecycle checkout template,
and a `4297`-second total. Every group record was:

```text
runner=1
lib-catalog=204
lib-codec=0
lib-profile-state=1
lib-ai-skill-state=1
lib-lock=2
lib-transaction=1
lib-ai-skill-link=2
lib-runtime=1
lib-engine=5
lib-profile-activation=9
lib-registries=1
commands-agent-preflight=3
commands-catalog=106
commands-shim=611
commands-ai-skill=102
commands-profile=761
commands-surface=1
commands-lifecycle-bootstrap=184
commands-lifecycle-isolated=525
commands-lifecycle-migration=178
commands-lifecycle-uninstall=382
commands-lifecycle-end-to-end=1209
tools-aws=0
tools-bats=0
tools-community-ansible-dev-tools=1
tools-gcloud=0
tools-gdrive=0
tools-gh=1
tools-go=0
tools-jq=0
tools-netcat=0
tools-nmap=0
tools-npx=0
tools-oc=0
tools-opnsense-mcp-read-only=0
tools-opnsense-mcp-admin=1
tools-rg=0
tools-skopeo=1
tools-task=0
tools-terraform=0
tools-tessl=0
tools-textual=0
```

The 43 group records sum to `4294` seconds. The final two-worker assignment
achieves the exact lower bound, `2147/2147`. The final three-worker assignment
achieves the exact ceiling lower bound, `1432/1431/1431`:

- `three-a=1432`: lifecycle end-to-end, lib-catalog,
  lib-profile-activation, lib-engine, commands-agent-preflight, and lib-lock.
- `three-b=1431`: commands-profile, lifecycle uninstall, lifecycle bootstrap,
  commands-ai-skill, and lib-ai-skill-link.
- `three-c=1431`: every remaining group, including commands-shim, lifecycle
  isolated, lifecycle migration, and commands-catalog.

### Chunk 2 final acceptance evidence

The final focused command selected all five lifecycle groups with `--jobs 3`.
Template setup took `1` second; group times were `217` bootstrap, `615`
isolated, `199` migration, `449` uninstall, and `1327` end-to-end. All five
logical tests passed in `1329` seconds. This is `1163` seconds, or 46.7 percent,
faster than the accepted `2492`-second lifecycle baseline and is below the
`1993`-second acceptance limit.

With no intervening edit, `SHIMMY_TEST_TIMING=1 ./tests/test.sh` passed all 43
registered groups exactly once and all 130 logical tests. Copy-on-write setup
took `0` seconds, lifecycle-template setup took `1` second, and total elapsed
time was `1695` seconds. Canonical replay included five lifecycle START, PASS,
and group-timing records; successful post-suite validation accepted the
template's unchanged recorded HEAD, clean worktree, and empty ignored-content
inventory.

Final direct checks passed `/bin/sh -n` for changed shell files,
`./tests/context-tree.sh`, executable-mode review, `git diff --check`, the
generated installed-artifact syntax exercised inside both lifecycle runs, the
fake-Podman injection inventory, and the final future-facing umbrella-group
terminology search. Remaining `commands-lifecycle` matches describe retained
historical baselines or accepted past invocations rather than executable
future selection commands.

### Human review gate

Stop after implementation and verification. The reviewer must confirm the
scenario assertion mapping, template immutability, fake-only destructive
boundary, record retention, static schedule, passing focused/full results, and
measured improvement. Final implementation completion does not authorize
moving this plan to `complete`; explicit acceptance is required.

## Risk register

| Risk | Impact | Required mitigation |
| --- | --- | --- |
| Optimizing against a failed checkout | Performance numbers conceal a correctness regression | Require a passing current baseline before setting targets or entering ACT |
| Silently folding migration repair into test work | Destructive ownership semantics change without appropriate review | Resolve production identity separately or explicitly expand scope before completing this plan |
| Hidden shell-global dependency | Split scenarios fail or become order-dependent | Fresh child process per group, static inspection, serial calibration, and bounded parallel acceptance |
| Shared mutable checkout | End-to-end publish/sync contaminates another scenario or the template | Immutable parent template, private copies, post-run HEAD/clean validation |
| Ignored repository bulk retained in every fixture | Portable copies remain expensive without behavioral value | Remove ignored content only inside the disposable committed template before scenario copies |
| Progress output becomes nondeterministic | Parallel logs become hard to compare | Write START into private group logs and replay only in canonical registry order |
| Signal replay duplicates completed output | Interrupted transcript becomes misleading | Track replay completion and replay partial logs at most once |
| Failure loses total timing | Failed runs cannot be attributed | Capture status, emit total timing, then return the original failure |
| Test count mistaken for assertion preservation | Coverage can erode while PASS count stays stable | Retain the scenario assertion mapping plus exact pass records |
| Static rebalance uses stale timings | A new critical path replaces the old one | Calibrate once from final serial group times before final acceptance |
| Real Podman mutation | User machines, containers, images, or volumes could be damaged | Require generated fake injection on every lifecycle command and review logs/variables before acceptance |

## Lessons learned

### Initial

- The former whole-group indivisibility test protects an obsolete boundary.
  Every current top-level scenario initializes private state; internal scenario
  transitions, not the five-scenario aggregate, are the durable unit.
- Splitting scenarios makes existing group timing authoritative at scenario
  granularity and avoids a duplicate timing schema.
- The checkout template is worthwhile beyond copy-on-write hosts because the
  current fixture repeatedly rebuilds Git history and carries a 58 MiB ignored
  dependency tree into six disposable checkouts.
- The first current timing run proved the handoff's process diagnosis: private
  logs showed healthy progress through bootstrap and isolated transitions even
  while the terminal remained silent.
- That run also found a correctness blocker introduced after the triggering
  runs. `c118957` makes the migration's existing legacy and proposed shared
  machine names identical for the active profile, so the preflight contract is
  unsatisfiable and the suite is currently red.
- A failed group emits group timing but `set -e` skips total timing. The
  observability work must cover ordinary failure as well as signal
  interruption.

### Chunk 1

- Wrapping the sourced group runner in an `||` status capture suppressed the
  nested group's `set -e` behavior and initially made the synthetic return-7
  worker appear successful. The corrected boundary invokes the suite runner as
  an ordinary command while the parent temporarily disables immediate exit,
  then restores `set -e` after recording the exact status. The focused test
  failed once with `runner ignored a failed worker`, then passed after this
  correction.
- Timing-gated START records can remain deterministic by writing them into each
  private group log before launch. Ordinary replay needs no new ordering path.
- A worker signal trap has enough state to terminate only its recorded group
  child and append elapsed group timing before the parent replays partial logs.
  Parent replay state prevents duplicate canonical output and total timing is
  emitted before session cleanup.
- The generated fake's explicit trailing `:` keeps successful `machine init`
  status independent of the optional failure predicate. The direct contract
  now proves success/`stopped`, pre-mutation failure/`absent`, and post-create
  failure/`stopped` without a lifecycle fixture.

### Chunk 2

- Preparing one clean template, pruning ignored content, adding lifecycle fake
  runtimes, and recording its immutable HEAD took one second. Scenario copies
  retained independent Git histories while the post-suite validator confirmed
  that the template HEAD and worktree never changed.
- Splitting the lifecycle group preserved all five logical pass records and
  measured `184/525/178/382/1209` seconds. Their `2478`-second sum is within 14
  seconds of the accepted `2492`-second monolithic baseline; the performance
  gain therefore comes from safe scenario parallelism, not removed behavior.
- The full serial group sum admits exact optimal partitions for both supported
  worker counts. Two workers reach `2147/2147`; three reach
  `1432/1431/1431`, the mathematical lower bounds for a `4294`-second sum.
- Parallel host contention raised individual final group times above their
  serial calibration values, but the focused lifecycle total still improved
  46.7 percent and the full suite improved from `4297` serial seconds to
  `1695` bounded-parallel seconds while preserving every logical pass record.

## Session bootstrap

Resume in PLAN. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`,
`tests/CONTEXT.md`, `tests/lib/CONTEXT.md`, `tests/commands/CONTEXT.md`,
`docs/testing.md`, this plan, the handoff, `tests/test.sh`, `tests/runner.sh`,
`tests/support.sh`, `tests/lib/runner.sh`, `tests/lib/engine.sh`,
`tests/lib/profile-activation.sh`, `tests/commands/lifecycle.sh`,
`lib/engine/registry.sh`, `plans/wip/shared-machine-rollback.md`, and the two
completed performance plans.

Recheck commit and worktree state and preserve the user's shared-engine and
uninstall-fixture edits. Resume the active chunk only, run its verification,
record evidence and lessons here, then stop at its human review gate.
