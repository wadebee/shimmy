# Darwin lifecycle helper refactor plan

Completed: 2026-08-30

## Objective

Refactor the Darwin lifecycle test helpers so fixture creation, successful
bootstrap preparation, bootstrap validation, and shared-redirect transaction
validation have explicit boundaries.

Success requires the Darwin bootstrap, owned-isolated, and global-uninstall
groups to retain their current observable assertions and logical PASS outcomes;
each registered group to keep a private checkout, HOME, configuration root,
fake Podman state, and logs; isolated and uninstall scenarios to start from a
fresh successful Darwin bootstrap without inheriting the bootstrap group's
redirect mutation; and every affected group to remain independently selectable
and fake-only.

This plan does not authorize production changes, lifecycle group renames,
runner-assignment changes, assertion pruning, new rejection or absence tests,
shared mutable scenario state, completed-installation caching, real Podman
access, or resolution of the separate Linux performance threshold in
`plans/wip/lifecycle-test-decomposition.md`.

## Target layout and terminology

- **Generic fixture preparation** remains `test_lifecycle_fixture_setup`. It
  creates one scenario-private checkout, HOME, configuration root, fake Podman
  executable, state files, and logs without performing bootstrap.
- **Darwin fixture preparation** initializes the Darwin created-machine state
  and service-PID inputs on top of one generic fixture. Its target name is
  `test_lifecycle_darwin_fixture_prepare`.
- **Darwin bootstrap preparation** creates a Darwin fixture, performs one
  successful real source bootstrap through the generated fake Podman boundary,
  and leaves a fresh installed `default` profile. Its target name is
  `test_lifecycle_darwin_bootstrap_prepare`.
- **Bootstrap validation** inspects the prepared bootstrap output, engine and
  binding records, status surfaces, and bootstrap operation ordering without
  changing the prepared profile. Its target name is
  `test_lifecycle_darwin_bootstrap_validate`.
- **Shared-redirect validation** owns the successful redirect mutation, rootless
  service-recycle assertions, injected projection failure, and exact rollback
  assertions. Its target name is
  `test_lifecycle_darwin_shared_redirect_validate`.

The target call structure is:

```text
test_commands_lifecycle_darwin_bootstrap
├── test_lifecycle_darwin_bootstrap_prepare
│   ├── test_lifecycle_darwin_fixture_prepare
│   │   └── test_lifecycle_fixture_setup
│   └── test_lifecycle_darwin_bootstrap_command
├── test_lifecycle_darwin_bootstrap_validate
├── test_lifecycle_darwin_shared_redirect_validate
└── existing bootstrap failure and collision transitions

test_commands_lifecycle_owned_isolated
└── test_lifecycle_darwin_bootstrap_prepare

test_commands_lifecycle_global_owned_uninstall
└── test_lifecycle_darwin_bootstrap_prepare
```

## Recorded design decisions

1. Retain one actual successful Darwin bootstrap in each registered scenario
   that requires an installed default profile. Do not share a bootstrapped
   installation across child processes or replace bootstrap with synthetic
   materialized state.
2. Run detailed bootstrap and shared-redirect validation only in
   `commands-lifecycle-darwin-bootstrap`. Successful bootstrap remains an
   operational prerequisite in isolated and uninstall, but those groups no
   longer repeat unrelated assertions or inherit the retained successful
   redirect.
3. Keep bootstrap validation read-only. The redirect transaction is a separate
   validating action because it deliberately mutates the profile before proving
   failed replacement rollback.
4. Preserve the current Darwin-bootstrap failure sequence and fixture reuse
   boundaries: successful bootstrap, image-preparation failure, and
   machine-start failure begin in three private fixtures; the post-create init
   failure reuses the machine-start fixture only after exact cleanup is proven;
   rollback-removal failure and collision continue with their separate
   configuration subroots.
5. Replace the duplicated Darwin created-state/service-PID preamble in the
   successful, image-failure, and machine-start cases with
   `test_lifecycle_darwin_fixture_prepare`. Do not broaden that helper to reset
   later transition-specific subroots or logs implicitly.
6. Remove `test_commands_lifecycle_darwin_bootstrap_case` and its unused
   `fresh`, `isolated`, and `global-uninstall` argument. Test-local helper names
   are not compatibility surfaces; update all callers without an alias.
7. Preserve every existing assertion, failure guard, and logical PASS statement
   exactly once in source. Relocating bootstrap and redirect checks so they
   execute in their owning group is intentional deduplication, not assertion
   pruning.
8. Keep the current runner registry, lifecycle checkout template, documentation
   descriptions, and production code unchanged. No current documentation or
   active source outside `tests/commands/lifecycle.sh` names the helper being
   removed; completed plans remain historical evidence.
9. Treat the existing dirty worktree as the implementation baseline. Preserve
   the authorized Linux workflow/control-sync split and every unrelated change;
   this plan neither accepts nor modifies the unresolved WIP lifecycle plan.

## Verified implementation inventory

This inventory is the verified planning baseline, not permission to ignore
new dependencies discovered during implementation.

- Repository HEAD is `1923892ddfef9977a73d82107c776edc22a6cf6e`.
- The worktree already contains user-authorized changes in `docs/testing.md`,
  `plans/notional/bash-completion.md`,
  `plans/notional/image-retention-resilience.md`,
  `plans/wip/lifecycle-test-decomposition.md`,
  `tests/commands/CONTEXT.md`, `tests/commands/lifecycle.sh`,
  `tests/lib/runner.sh`, and `tests/runner.sh`. The current lifecycle diff is
  confined to the Linux group split and lifecycle-template registration; the
  Darwin helper body is unchanged from HEAD.
- `test_lifecycle_fixture_setup` creates a new scenario directory and private
  checkout/HOME/config/fake/log set on every call.
- `test_commands_lifecycle_darwin_bootstrap_case` currently combines generic
  fixture preparation, Darwin fake-state initialization, one successful
  bootstrap, 20 top-level check statements, and a retained successful redirect
  mutation followed by rollback validation.
- The combined helper is called by Darwin bootstrap, owned isolated, and global
  uninstall. Its argument is assigned to `test_lifecycle_case` but never read.
- Consequently, detailed bootstrap and redirect checks run three times across
  the default suite, and isolated/uninstall inherit the successful redirect even
  though neither downstream scenario references its exact location.
- `test_commands_lifecycle_darwin_bootstrap` directly calls
  `test_lifecycle_fixture_setup` twice in addition to the combined helper's
  call. It performs six bootstrap attempts: one successful preparation, four
  injected-failure calls through `test_lifecycle_darwin_bootstrap_command`, and
  one direct collision attempt.
- The current WIP calibration recorded
  `commands-lifecycle-darwin-bootstrap=248`,
  `commands-lifecycle-isolated=567`, and
  `commands-lifecycle-uninstall=419` seconds in a complete serial run. These are
  contextual observations, not acceptance thresholds for this refactor.
- `tests/runner.sh` registers the three affected groups independently, and
  `tests/lib/runner.sh` proves independent selection and private template use.
- No production file consumes these test-local helper names. The only retained
  non-source reference to the old helper is in a completed historical plan,
  which must not be rewritten.

## Unresolved

None.

## Progress Checklist

- [x] Chunk 1 — Separate Darwin fixture, preparation, and validation
  responsibilities while preserving all affected scenario behavior.
  **Implemented and verified on 2026-08-29; human-verified and accepted on
  2026-08-30.**
  - The pre-edit inventory found three old-helper callers, 20 combined-helper
    check/failure-guard statements, three affected logical PASS statements,
    three Darwin-bootstrap fixture starts, six Darwin-bootstrap attempts, and
    eight bootstrap attempts across the three registered scenarios.
  - The post-edit inventory retains the 20 combined checks as 11 read-only
    bootstrap checks plus nine shared-redirect checks. The registered scenario
    bodies retain 25, 42, and 29 check-or-PASS statements respectively, with
    exactly one logical PASS each.
  - Runner coverage passed all 15 tests. The required three-worker lifecycle
    selection passed exactly three logical groups in 604 seconds: Darwin
    bootstrap in 267 seconds, isolated lifecycle in 504 seconds, and global
    uninstall in 336 seconds.

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

## Chunk 1 — Explicit Darwin lifecycle helper boundaries

### Goal

Replace the combined Darwin bootstrap-case helper with composable preparation
and validation helpers, so every registered scenario receives only the setup
and behavioral checks it owns.

### Files

- `tests/commands/lifecycle.sh`
- this plan

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. The source change is localized, but the
current helper leaves mutable redirect state that silently becomes a
precondition for two independent ownership/destruction scenarios.

1. Recheck the dirty worktree and preserve the existing Linux lifecycle split
   byte-for-byte outside any unavoidable nearby merge context.
2. Record a mechanical pre-edit inventory of the old helper's callers,
   assertion/failure-guard statements, logical PASS statements, direct fixture
   calls, and bootstrap attempts.
3. Add `test_lifecycle_darwin_fixture_prepare` with only the generic fixture
   call and the common created-machine/service-PID initialization currently
   duplicated by the successful, image-failure, and machine-start cases.
4. Add `test_lifecycle_darwin_bootstrap_prepare` to call Darwin fixture
   preparation and perform one successful `test_lifecycle_darwin_bootstrap_command`,
   preserving the variables consumed by the three registered scenario bodies.
5. Move only read-only bootstrap output/state/status/order checks into
   `test_lifecycle_darwin_bootstrap_validate`.
6. Move redirect dry-run, successful mutation/service recycle, injected
   projection failure, and checksum rollback checks together into
   `test_lifecycle_darwin_shared_redirect_validate`. Invoke this helper only
   from `test_commands_lifecycle_darwin_bootstrap`.
7. Make `test_commands_lifecycle_darwin_bootstrap` call preparation, bootstrap
   validation, and redirect validation in that order. Replace its two direct
   generic-fixture preambles with Darwin fixture preparation while leaving the
   later failure transition order and reuse unchanged.
8. Make owned-isolated and global-uninstall call only Darwin bootstrap
   preparation before their own scenario transitions.
9. Remove the old combined helper and unused case variable/arguments without a
   forwarding alias. Preserve all assertion and PASS text unless a helper name
   in diagnostic text must change for accuracy.
10. Do not add coverage proving that the removed helper or arguments no longer
    exist. The durable acceptance evidence is positive execution of all three
    affected registered groups from private fake-only worlds.

### Verification checklist

- [x] `/bin/sh -n tests/commands/lifecycle.sh` passes.
- [x] A mechanical before/after inventory accounts for every prior
  assertion/failure-guard statement and all three affected logical PASS
  outcomes exactly once in source.
- [x] A scoped call inventory proves Darwin bootstrap validation and
  shared-redirect validation each have exactly one caller, while Darwin
  bootstrap preparation has exactly the three intended registered callers.
- [x] `./tests/test.sh --group runner` passes registry, independent-selection,
  fixture-copy, and bounded-scheduling coverage.
- [x] `SHIMMY_TEST_TIMING=1 ./tests/test.sh --group
  commands-lifecycle-darwin-bootstrap --group commands-lifecycle-isolated
  --group commands-lifecycle-uninstall --jobs 3` passes exactly three logical
  groups. Darwin bootstrap retains all success, ordering, redirect rollback,
  failure-compensation, incomplete-rollback, and collision evidence; isolated
  and uninstall pass from fresh successful bootstrap state without the
  bootstrap group's redirect mutation.
- [x] Command-path inventory confirms every affected lifecycle path still uses
  `SHIMMY_TEST_PROFILE_PODMAN_BIN` and generated fake state; no installed
  profile or real Podman machine is reached.
- [x] `./tests/context-tree.sh`, executable-mode review, scoped terminology
  search, and `git diff --check` pass. Completed historical plans retain their
  old helper reference unchanged.
- [x] The final diff contains no production, runner-registry, assignment,
  documentation, Linux lifecycle, or unrelated user changes attributable to
  this plan.

### Human review gate

Confirm that preparation and validation responsibilities are explicit, the
redirect transaction belongs only to Darwin bootstrap, isolated and uninstall
still exercise real successful bootstrap output without inherited mutation,
all prior assertions remain authoritative, and the existing dirty lifecycle
work is preserved. Acceptance completes implementation but does not complete
this plan until the reviewer explicitly accepts the result.

**Accepted on 2026-08-30 after explicit human verification. The plan is
complete.**

## Risk register

| Risk | Impact | Required mitigation |
| --- | --- | --- |
| Isolated or uninstall accidentally depended on the retained redirect | Removing the mutation changes an unstated scenario precondition | Run both groups from preparation-only state and treat either failure as a material design finding, not permission to restore unrelated validation implicitly |
| Assertion or failure-transition loss during extraction | Bootstrap ownership or rollback coverage silently weakens | Preserve source statements mechanically and run all three registered callers |
| A helper named as validation still mutates state | The original responsibility conflation survives under new names | Keep bootstrap validation read-only and isolate redirect action/validation in its own helper |
| Fixture reuse boundaries change | Failure cases become order-dependent or stop proving compensation | Preserve the current three full fixture starts and later subroot/reuse sequence |
| Existing WIP Linux changes are overwritten | Separate authorized work is lost or its evidence becomes misleading | Recheck the worktree before and after, constrain edits to Darwin helper regions, and do not update the WIP plan |
| Affected commands escape the fake Podman boundary | User machine state could be mutated | Retain exact fake environment injection and verify command-path inventory before acceptance |

## Lessons learned

### Initial

- The combined helper is not merely an assertion bundle: it leaves a successful
  redirect installed after proving failed replacement rollback. Reusing it in
  isolated and uninstall therefore imports mutable state unrelated to those
  scenarios.
- Scenario independence requires an actual successful bootstrap per registered
  child process, but it does not require repeating detailed bootstrap or
  redirect assertions in every consumer.
- The Darwin bootstrap group intentionally uses three full fixtures for its
  major success/failure worlds and reuses later state only after exact cleanup
  or by switching configuration subroots. Responsibility extraction should not
  become an unreviewed fixture-lifecycle redesign.
- The old helper's case argument is vestigial; private scenario identity already
  comes from `setup_scenario`.

### Chunk 1

- Isolated lifecycle and global uninstall both pass after preparation-only
  bootstrap, proving neither scenario depends on the successful shared
  redirect retained by the Darwin-bootstrap validation world.
- The common Darwin fixture preamble applies exactly to the successful,
  image-preparation-failure, and machine-start-failure worlds. The later
  post-create and rollback-removal transitions retain their explicit state and
  configuration resets.
- Separating read-only bootstrap validation from the redirect transaction made
  caller ownership mechanically visible without changing assertion text,
  failure ordering, or logical PASS outcomes.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, `tests/CONTEXT.md`,
`tests/commands/CONTEXT.md`, this plan, the Darwin helper/caller region in
`tests/commands/lifecycle.sh`, `tests/test.sh`, `tests/runner.sh`, and
`tests/lib/runner.sh`. Review `plans/wip/lifecycle-test-decomposition.md` only
to understand and preserve its separate dirty Linux split and unresolved
performance stop; do not execute or amend that plan under this authorization.

The target is explicit Darwin fixture preparation, successful bootstrap
preparation, read-only bootstrap validation, and separate redirect transaction
validation. Preserve all assertions, failure sequencing, private scenario
state, fake-only execution, and unrelated work. Chunk 1 is the only chunk; stop
at its human review gate after verification and plan updates. Chunk 1 was
human-verified and accepted on 2026-08-30; this plan is complete.
