# Test-suite optimization planning handoff

## Purpose and authority

This document is evidence and planning input for a future prompt that will
produce a decision-complete implementation plan. It is not itself an
implementation plan, does not authorize test or production changes, and does
not supersede `docs/testing.md`, repository context, or accepted historical
plans.

The planning task is to reduce test feedback time, especially the current
`commands-lifecycle` critical path, without dropping behavioral assertions,
weakening destructive-action or ownership coverage, introducing real Podman
machine mutation, or creating a separate incomplete “fast” suite.

As of 2026-08-24, the working tree is clean, but the current `main` checkout
contains the committed, human-unaccepted shared-machine rollback implementation
and tests recorded by `plans/wip/shared-machine-rollback.md`. Commit `c118957`
then changed shared-engine naming and lifecycle tests after the triggering runs
below. A future planning agent must preserve and inventory the current checkout,
freeze its exact commit and worktree state, and must not treat the triggering
timings as a current baseline.

## Triggering run

The shared-machine rollback implementation session launched the source suite
nine times:

| Invocation | Scope | Result | Reported cases | Timing evidence |
| ---: | --- | --- | ---: | ---: |
| 1 | serial `lib-engine` | complete pass, pre-final code | 6 | not retained |
| 2 | serial `commands-lifecycle` | partial failure in fake-Podman behavior | 0 completed scenarios confirmed | not retained |
| 3 | serial `commands-lifecycle` | manually interrupted after appearing stalled | partial | not retained |
| 4 | parallel `lib-engine` + `commands-lifecycle` | complete pass, pre-final code | 11 | not retained |
| 5 | default full suite | interrupted with status 130 after a late cleanup issue invalidated the run | partial | approximately 11 minutes |
| 6 | serial `lib-engine` | partial failure in a new test’s stderr capture | 3 passes, then failure | 9.36 seconds |
| 7 | serial `lib-engine` | complete pass | 7 | 11.01 seconds |
| 8 | parallel `lib-engine` + `commands-lifecycle` | complete pass, then-final rollback-session code | 12 | approximately 42 minutes |
| 9 | default full suite | complete pass, then-final rollback-session code | 129 | approximately 44 minutes |

`SHIMMY_TEST_TIMING=1` was not enabled. Successful and interrupted runner
cleanup removed the temporary group logs, so the approximate durations above
come from observed temporary-file timestamps rather than retained stable timing
records. Unknown values must not be reconstructed as exact measurements.
The later `c118957` changes make these results historical evidence only even
though the rollback plan remains unaccepted.

### Confirmed duplication

- `lib-engine`: six complete group runs plus one partial failed run.
- `commands-lifecycle`: three complete group runs plus two interrupted and one
  failed group launch.
- Fourteen groups completed once in the interrupted full suite and again in
  the final full suite: `runner`, `lib-catalog`, `lib-codec`,
  `lib-profile-state`, `lib-ai-skill-state`, `lib-lock`, `lib-transaction`,
  `lib-ai-skill-link`, `lib-runtime`, `lib-profile-activation`,
  `lib-registries`, `commands-agent-preflight`, `commands-catalog`, and
  `commands-ai-skill`.
- `commands-profile` and `commands-shim` were observed in progress during the
  interrupted full run and completed in the final full run. Their interrupted
  per-test completion status is unavailable.
- The remaining registered groups have one confirmed complete final run. An
  additional late launch during the interrupted suite cannot be ruled out
  after the last retained progress snapshot.

The cheap `lib-engine` failure/retry cycle cost about 20 seconds and was
proportionate. The dominant cost was repeated execution of the lifecycle
critical path.

## Current verified test architecture

- `tests/runner.sh` currently registers 39 groups and uses a default maximum of
  three bounded workers.
- `commands-lifecycle` is one registered group whose run function calls five
  top-level scenarios serially:
  - `test_commands_lifecycle_darwin_bootstrap_engine_states`
  - `test_commands_lifecycle_owned_isolated`
  - `test_commands_lifecycle_explicit_migration`
  - `test_commands_lifecycle_global_owned_uninstall`
  - `test_commands_lifecycle_end_to_end`
- `tests/lib/runner.sh` explicitly protects the current single lifecycle-group
  shape as an invariant named “runner keeps the final lifecycle acceptance
  scenarios indivisible.” The planning agent must determine whether the real
  invariant is scenario indivisibility or whole-group serialization.
- Each top-level lifecycle scenario establishes its own world directly or by
  calling `test_commands_lifecycle_darwin_bootstrap_case`, which itself calls
  `test_lifecycle_fixture_setup`. This makes scenario-level independence
  plausible but not yet proven.
- A complete lifecycle group performs approximately six calls to
  `test_lifecycle_fixture_setup`. Each call creates a new scenario, constructs
  a catalog checkout, writes fake tool versions and runtimes, stages and commits
  Git state, and creates a fake Podman executable and logs.
- The end-to-end lifecycle scenario intentionally mutates its checkout during
  catalog publication/sync. Any shared checkout optimization therefore needs
  immutable session state plus isolated scenario-local copies.
- `tests/support.sh` and runner coverage already provide and verify a
  copy-on-write-capable fixture-tree copy helper with a portable fallback.
- Group output is buffered for deterministic replay. `SHIMMY_TEST_TIMING=1`
  records setup, group, and total integer timings, but the monolithic lifecycle
  group exposes no scenario-level timing while it is running.
- The current lifecycle tests use generated fake Podman only. Optimization must
  retain that boundary and must not invoke a real Podman machine operation.

## Historical evidence that must be reconciled

Read these accepted plans before designing new work:

- `plans/complete/unit-test-performance.md`
- `plans/complete/test-transition-pruning.md`

Relevant retained evidence:

- The completed unit-test performance plan introduced one canonical selectable
  group registry, copy-on-write fixture copying, deterministic bounded workers,
  opt-in timing, and default three-worker execution.
- Its final historical three-worker median was approximately 584 seconds for
  the then-current suite.
- The completed transition-pruning plan recorded a historical
  `commands-lifecycle` group time of approximately 227 seconds and reduced that
  group by a measured 13 seconds while preserving its accepted coverage.
- Historical repeated-run/median instructions in those plans are explicitly
  superseded by `docs/testing.md`. Current work should use one coarse same-host
  measurement when timing is relevant unless the user explicitly requests a
  different benchmark protocol.

The approximately 42-minute lifecycle duration observed in the triggering run
is more than ten times the retained 227-second historical value. Repository
shape and lifecycle coverage have changed since that benchmark, so this is not
proof of one specific regression. It is, however, strong evidence that a new
plan must measure and attribute the current cost before treating it as an
expected byproduct of integration coverage.

## Findings

### Process findings

1. Expensive acceptance began before the final destructive-boundary and
   repeated-trap review was complete. A later implementation change invalidated
   one complete focused result and an in-progress full result.
2. Buffered output plus missing timing/progress evidence caused a healthy
   lifecycle diagnostic to be mistaken for a stall and interrupted.
3. Timing support existed but was not enabled, leaving the most useful
   performance evidence ephemeral.
4. The low-cost unit failure was appropriate and quickly resolved. Repeated
   long lifecycle launches, not ordinary caught failures, explain most of the
   exceptional duration.

### Suite findings

1. The current critical path is a monolithic lifecycle group, so the default
   three-worker scheduler cannot parallelize its five top-level scenarios.
2. Scenario setup repeats checkout construction and Git materialization that
   may be reusable through an immutable prepared template and isolated
   copy-on-write copies.
3. Group-only timing cannot distinguish fixture construction, bootstrap,
   isolated lifecycle, migration, uninstall, and end-to-end command cost.
4. Generated fake-Podman behavior lacked a cheap direct contract test for the
   distinction between normal init, pre-mutation failure, and post-create
   failure. A POSIX conditional status defect therefore surfaced through an
   expensive command fixture.
5. The rollback change now has a cheap repeated-cleanup proof in `lib-engine`.
   Future development should stabilize this unit layer before invoking command
   lifecycle acceptance.

## Candidate recommendations for formal planning

These are candidates to investigate and decide, not pre-approved design
decisions.

### A. Immediate process changes

1. Require the invocation-only `SHIMMY_TEST_TIMING=1` toggle for every benchmark
   and agent-run focused or full acceptance. This must not change the default
   transcript when the toggle is unset. Reject a purported measurement if its
   expected setup, selected-group, and total timing records are absent.
2. Add a pre-acceptance gate:
   - syntax and cheap unit groups;
   - final state-machine, destructive-authority, and trap-idempotency review;
   - test-double contract verification;
   - one focused acceptance run;
   - no further edits;
   - one full suite run.
3. Do not interrupt buffered groups based only on lack of terminal output.
   Inspect retained group logs or explicit progress state first.
4. Treat a post-acceptance edit as invalidating prior affected results, but do
   not automatically rerun unrelated groups until the final code is stable.

### B. Timing and progress observability

1. Route scenario-level timing and any lifecycle `START` markers through the
   existing `SHIMMY_TEST_TIMING=1` toggle. Do not introduce a second timing
   toggle, and preserve the normal transcript when timing is disabled. If the
   stable timing schema gains a `scenario` scope or a separate progress record,
   update `docs/testing.md` and runner contract coverage together.
2. Add scenario-level timing around each top-level lifecycle function, using a
   stable record shape distinct from group timing.
3. Add deterministic `START` markers for lifecycle scenarios to the private
   group log so progress is visible before a `PASS` record.
4. Preserve timing records in the final transcript or a deliberate retained
   artifact when a run fails or is interrupted. Do not retain entire mutable
   fixtures by default solely for timing.
5. Measure fixture preparation separately from scenario command execution.

### C. Cheap fake-Podman contract coverage

Add a low-cost focused test that invokes the generated fake directly and
proves:

- ordinary machine init returns zero and creates stopped state;
- pre-mutation failure returns nonzero and leaves absent state;
- post-create failure returns nonzero after creating stopped state;
- optional failure checks cannot become the success path’s final status.

Keep this test at the fake-provider ownership layer rather than duplicating it
in every command scenario.

### D. Revisit lifecycle group boundaries

Investigate registering scenario-level lifecycle groups such as:

- `commands-lifecycle-bootstrap`
- `commands-lifecycle-isolated`
- `commands-lifecycle-migration`
- `commands-lifecycle-uninstall`
- `commands-lifecycle-end-to-end`

The likely durable invariant is that each scenario’s internal transitions are
indivisible, not necessarily that all five scenarios must share one worker.
Before choosing this design, prove:

- no scenario consumes state from a previous top-level scenario;
- shell globals are fully initialized for independent group execution;
- temporary roots, fake logs, Git repositories, and environment state remain
  isolated under parallel workers;
- bounded parallel execution does not create nondeterministic failures or
  unacceptable filesystem contention;
- deterministic canonical output and exact test counts remain intact.

If scenario groups are accepted, update runner grouping coverage to protect
the new scenario-level boundaries rather than deleting grouping protection.

### E. Reduce repeated lifecycle fixture construction

Measure the cost of `test_lifecycle_fixture_setup` before changing it. If it is
material:

1. Prepare one immutable lifecycle checkout template at session scope.
2. Create isolated scenario-local copies through the existing validated
   fixture-tree copy helper and its verified portable fallback.
3. Preserve Git metadata, executable modes, symlinks, clean-main authority,
   and source mutation independence.
4. Never share the mutable checkout used by end-to-end publication/sync.
5. Keep real bootstrap, install, migration, rollback, and uninstall execution
   where those transitions are the unique behavior under test.

Do not introduce fixture caching merely to reduce a reported group time if the
cost is actually in command execution.

### F. Rebalance workers only after accepted group changes

If lifecycle is split or fixture costs change materially, recompute the static
two- and three-worker assignments from final coarse group timings. Do not
preserve historical assignments when they leave one dominant critical path.

## Required invariants and constraints

A formal plan must preserve all of the following:

- one canonical suite and one validated registry that exactly maps each
  selectable group to one run function; accepted scenario splitting may change
  registry membership only with corresponding runner contract coverage;
- default bounded parallelism with at most three workers unless separately
  approved;
- deterministic canonical output and correct failure propagation;
- opt-in timing through `SHIMMY_TEST_TIMING=1`, no replacement timing toggle,
  and unchanged normal output when the toggle is unset;
- POSIX shell and offline default source-suite behavior;
- no real Podman machine or current Shimmy installation mutation;
- fake-only machine lifecycle acceptance;
- exact destructive-action, ownership, rollback, retained-evidence,
  secret-redaction, collision, migration, isolation, and uninstall proofs;
- no assertion or test-case removal without an explicit mapping to an
  equivalent authoritative proof;
- scenario-private mutable state and immutable shared/session fixtures;
- portable fixture-copy fallback and existing path/symlink safety;
- no separate fast suite that silently omits supported behavior;
- repository test concurrency rules from `AGENTS.md` and `docs/testing.md`;
- current negative-test discipline, including retention of approved
  transactional rollback, ownership, secret-redaction, and destructive-action
  invariants.

## Questions the formal plan must resolve

1. What are the current coarse setup, group, and total times from one clean
   same-host timing-enabled run?
2. What is the scenario-level breakdown inside `commands-lifecycle`?
3. What stable scenario timing and progress record shape extends the current
   contract while leaving timing-disabled output unchanged?
4. Which code/test changes since the retained 227-second benchmark account for
   the current approximately 42-minute observation?
5. Are the five lifecycle scenarios independently runnable in fresh child
   processes, or do hidden shell globals/state couple any pair?
6. Does scenario-level parallelism reduce wall time under three workers, or
   does filesystem/Git contention erase the benefit?
7. How much time is spent constructing lifecycle checkouts versus executing
   the behavior under test?
8. Can an immutable prepared lifecycle checkout be shared safely without
   weakening clean-main, publication, or mutation-independence coverage?
9. Which fake-provider contract is authoritative for init failure semantics,
   and where should its single low-cost proof live?
10. What static worker assignment minimizes the final critical path after any
   group or fixture changes?
11. What improvement target is justified by the measured current baseline?
    Do not invent a threshold before measuring.

## Suggested planning sequence

The future formal plan should consider these phases, but must verify and revise
them rather than copying them mechanically:

1. **Inventory and baseline** — reconcile historical plans, current group
   registry, current lifecycle source, and the exact current commit and worktree
   state. Freeze one same-host baseline with the invocation-only toggle, using
   `SHIMMY_TEST_TIMING=1 ./tests/test.sh --group commands-lifecycle` for the
   current single-group architecture, and verify the emitted timing records.
   Add observability before structural optimization if current data cannot
   attribute cost.
2. **Low-cost safeguards** — add fake-provider contract coverage and codify the
   pre-acceptance process. Verify these without running repeated full lifecycle
   acceptance during development.
3. **Lifecycle critical-path refactor** — choose scenario-level groups,
   progressive scenario reuse, fixture-template reuse, or a measured
   combination. Preserve an assertion mapping and isolation proof.
4. **Testing, scheduling, and acceptance** — rebalance workers, prefix the one
   focused final acceptance invocation with `SHIMMY_TEST_TIMING=1`, make no
   further edits, then run the complete default bounded suite once as
   `SHIMMY_TEST_TIMING=1 ./tests/test.sh`. Verify that both runs emitted the
   expected timing records before comparing counts and coarse timings against
   the frozen baseline. Use `--serial` only to diagnose a failure.

## Source inventory for the next planning prompt

At minimum, read:

- `AGENTS.md`
- `CONTRIBUTING.md`
- `CONTEXT.md`
- `tests/CONTEXT.md`
- `tests/lib/CONTEXT.md`
- `tests/commands/CONTEXT.md`
- `docs/testing.md`
- `tests/test.sh`
- `tests/runner.sh`
- `tests/support.sh`
- `tests/lib/runner.sh`
- `tests/lib/engine.sh`
- `tests/lib/profile-activation.sh`
- `tests/commands/lifecycle.sh`
- `plans/wip/shared-machine-rollback.md`
- `plans/complete/unit-test-performance.md`
- `plans/complete/test-transition-pruning.md`
- this handoff in full

The planning agent must inspect current source rather than relying on historical
function names or group counts. It should produce a formal plan only after
resolving material ambiguities with evidence.

## Expected planning deliverable

Produce a decision-complete, reviewable implementation plan that includes:

- a frozen current baseline and explicit timing limitations;
- the exact commit and worktree state used for that baseline;
- an assertion and invariant mapping for every affected lifecycle scenario;
- selected group/fixture/progress architecture with rejected alternatives and
  reasons;
- concrete file inventory and ordered implementation chunks;
- focused verification that avoids repeated expensive acceptance while code is
  unstable;
- one final focused run and one final full run explicitly invoked with
  `SHIMMY_TEST_TIMING=1`, with required timing records present;
- worker rebalance criteria where applicable;
- risk register covering isolation, hidden shell state, output determinism,
  fixture mutation, destructive-action coverage, and false performance gains;
- explicit human review gates before implementation and after benchmark
  acceptance.
