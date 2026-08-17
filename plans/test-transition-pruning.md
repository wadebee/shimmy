# Test transition pruning plan

**Status:** Proposed — awaiting review; no implementation is authorized.

## Objective

Reduce serial test time by pruning duplicate expensive state transitions in
the `commands-onboarding`, `commands-skills`, `commands-catalog`,
`commands-startup`, and `commands-lifecycle` groups while preserving their
behavioral assertions, isolation boundaries, failure coverage, and the same
41-group source-suite registry.

Success requires:

- a current, same-host before baseline recorded before test edits;
- every existing behavioral assertion retained directly or mapped to an
  equivalent proof over the same bytes or state;
- the current 159 passing test-case records retained unless a reviewer
  explicitly accepts a documented count change after verifying the assertion
  mapping;
- at least 255 seconds of aggregate median serial group-time reduction across
  the five target groups, matching the lower bound of the supplied estimate;
- a faster complete serial suite with no setup-time regression that explains
  away the group savings;
- a rebalanced three-worker schedule whose three-run median does not regress;
  and
- unchanged production behavior, POSIX-shell compatibility, offline default
  suite behavior, and real integration coverage where the transition itself
  is the behavior under test.

If safe consolidation cannot reach the 255-second target, implementation must
stop at the current chunk's review gate with measured evidence. It must not
remove assertions, replace unique integration boundaries with mocks, or move
work into shared setup merely to make a group timing appear smaller.

This plan does not change runtime commands, catalog/profile semantics, tool
images, the public test-runner interface, installed-profile smoke behavior, or
the POSIX shell architecture. It does not reopen or replace the completed
`plans/unit-test-performance.md` plan.

## Target layout and terminology

- **Expensive transition** means a real bootstrap, profile install/update/
  uninstall, catalog rebind/publish/rollback, skill target replacement/export,
  source checkout copy/commit, or equivalent operation that materializes or
  replaces substantial state.
- **Scenario** is one disposable `HOME`, `XDG_CONFIG_HOME`, work directory,
  catalog copy, and optional profile-fixture copy created by
  `setup_scenario` or `setup_scenario_with_profiles`.
- **Progressive scenario** starts once and moves monotonically through related
  states so later assertions consume state produced by earlier assertions.
- **Assertion mapping** records where every removed assertion line or logical
  test case is proven after consolidation. Byte-for-byte inventory equality is
  an acceptable equivalent proof; silently dropping a check is not.
- **Group time** is the integer elapsed value in
  `shimmy_test_timing=group|<name>|<seconds>` and excludes parent session setup.
- **Run time** is `/usr/bin/time -p` `real`; **CPU time** is `user + sys`.
- **Before** and **after** are medians of three identical isolated group
  invocations on the same host. Setup, group, real, user, sys, and test count
  are retained for every sample.
- **Net affected time** is the sum of medians for every group changed by a
  chunk. Moving an assertion to another group cannot be reported as savings
  until both groups are included.

The source layout remains unchanged:

```text
tests/
├── commands/
│   ├── onboarding.sh
│   ├── skills.sh
│   ├── catalog.sh
│   ├── startup.sh
│   ├── lifecycle.sh
│   └── CONTEXT.md
├── runner.sh
├── CONTEXT.md
└── lib/runner.sh
docs/testing.md
```

## Recorded design decisions

1. Use the current tree, not stale scenario names, as authority. The supplied
   onboarding names such as `agent_flow`, `agent_blocked`, and
   `agent_default_current` do not occur in the current test or its recent
   pre-performance-plan history. No replacement matrix will be invented.
2. Freeze new before measurements before editing tests. The historical values
   remain planning evidence only because their group and suite totals came
   from different benchmark stages.
3. Preserve assertions rather than function boundaries. Multiple logical
   cases may share one progressive scenario and may retain separate `pass`
   records.
4. Do not replace a real operation when that operation is the unique
   integration boundary. In particular, retain the skills live-upstream versus
   published-default test, the catalog dirty-initial-publication test, the
   catalog-to-profile explicit-update check, startup failure/retry, lifecycle
   migration rollback, and lifecycle registry/projection refusal paths.
5. The current skills target-ownership test is already one combined
   repo/profile and default/upstream scenario. Do not refactor it as though it
   were separate end-to-end matrices. Preserve its full install/update/
   uninstall and cross-profile ownership proof unless timing evidence exposes
   a specific redundant transition.
6. Directory export is the semantic authority for portable skill payloads.
   ZIP coverage will extract the archive and compare a deterministic relative
   path plus checksum/byte-count inventory with the verified directory export,
   then retain ZIP-specific root/layout checks. This transfers, rather than
   deletes, the per-skill content assertions.
7. Keep catalog initial dirty-publication rejection separate from dirty
   republish rejection. They share a cleanliness guard but prove different
   transaction boundaries: absence of all initial profile/catalog state versus
   preservation of an existing registry/generation/profile.
8. Keep lifecycle launcher repair, upstream control-plane refresh, and legacy
   mixed-layout rejection separate. The current implementation proves three
   different ownership and migration contracts; the supplied review treated
   them as more symmetric than they are.
9. Never share mutable scenario state across registered groups or workers.
   Consolidation stays inside a group, and all session fixtures remain
   immutable.
10. Benchmark isolated target groups with `--serial --group <name>`. Record
    each raw sample in this plan during execution, calculate medians, and use:

    ```text
    savings_seconds = before_median - after_median
    improvement_percent = 100 * savings_seconds / before_median
    ```

    A negative savings value is a regression and must be shown as such.
11. Every chunk review must include this table, populated with measured values:

    | Group or affected set | Before median (s) | After median (s) | Savings (s) | Improvement | Before/after test count |
    | --- | ---: | ---: | ---: | ---: | ---: |

    It must also report setup and `/usr/bin/time -p` medians, raw sample values,
    assertion mappings, failures, uncertainties, and cumulative projected
    full-serial time.
12. Recompute both two-worker and three-worker assignments only after the
    serial group changes are accepted. Static assignments must use the final
    complete serial timing records, minimizing the largest worker total rather
    than preserving historical placement.
13. Use the suggested AI reasoning effort for each chunk as a minimum. Increase
    it when newly discovered cross-component dependencies justify doing so; do
    not lower it merely to reduce execution cost. The levels refer to Codex
    reasoning-effort settings:

    | Chunk | Suggested effort | Reason |
    | --- | --- | --- |
    | 1 — Baseline and startup | `high` | Benchmark discipline plus moderate progressive shell-state coupling |
    | 2 — Catalog publication/rollback | `xhigh` | Transaction ordering, generation integrity, corruption recovery, and rollback invariants |
    | 3 — Skills consolidation | `high` | Broad assertion mapping and target isolation, with unique catalog integration retained |
    | 4 — Lifecycle reuse | `xhigh` | Destructive lifecycle boundaries, unmanaged-state preservation, and final-profile cleanup sequencing |
    | 5 — Onboarding progression | `high` | Sourced-shell state, environment leakage, PATH precedence, and multi-shell behavior |
    | 6 — Rebalance and benchmark | `high` | Measurement analysis and deterministic assignment balancing without runtime semantic changes |

## Verified implementation inventory

The completed performance plan records these historical facts:

- Chunk 1: 1,385 seconds serial, 40 seconds setup, and 150 tests.
- Chunk 2: 1,366 seconds serial, 39 seconds setup, and 154 tests.
- Final serial verification: 1,411.20 seconds and 159 tests after runner
  failure/scheduling coverage was completed.
- Final three-worker runs: 586.76, 578.78, and 584.02 seconds, with a
  584.02-second median.
- The historical largest group values were onboarding 232, lifecycle 227,
  catalog 206, skills 197, and startup 135 seconds. They sum to 997 seconds.

The 997-second group sum was documented under Chunk 1, while the supplied
1,366-second suite total belongs to Chunk 2. Therefore the following arithmetic
is a projection, not a measured before/after comparison:

| Projection from supplied ranges | Seconds | Percent |
| --- | ---: | ---: |
| Minimum claimed savings | 255 | 18.7% of 1,366; 25.6% of 997 |
| Maximum claimed savings | 415 | 30.4% of 1,366; 41.6% of 997 |
| Illustrative resulting serial total | 951–1,111 | — |
| Illustrative resulting five-group sum | 582–742 | — |
| Midpoint resulting serial total | 1,031 | 24.5% improvement |

Current source inspection verifies:

| Group | Historical time | Lexical scenario setup sites | `setup_scenario_with_profiles` sites | Current expensive/repeated shape |
| --- | ---: | ---: | ---: | --- |
| onboarding | 232s | 11 | 2 | Real absolute/sourced bootstraps, additive install/refresh, profile switching, Bash/Zsh source matrix |
| skills | 197s | 7 | 7 | Four portable exports, repo/profile target lifecycle, real live/published catalog transition |
| catalog | 206s | 6 | 3 | Two checkout clone/rebind/commit/publication sequences; rollback starts a second world |
| startup | 135s | 5 | 1 | Eight committed or successful default install/repair transitions across fresh scenarios |
| lifecycle | 227s | 19 | 15 | Repeated task installs, refreshes, profile clones, and standalone last-profile cleanup worlds |

The five groups contain 28 of the current 50 actual repository-wide
`setup_scenario_with_profiles` call sites. A raw text search returns 51 matches
because it also includes the function definition in `tests/support.sh`; the
historical plan's count of 52 call sites is no longer current.

Important current boundaries:

- `tests/runner.sh` owns 41 groups and static two-/three-worker assignments.
- `commands-lifecycle` is an indivisible prepare/complete group; those two
  entrypoints intentionally share one scenario.
- `setup_scenario_with_profiles` uses validated clone copies and rewrites
  relocated shell-init and implementation roots; replacing clone calls alone
  is unlikely to deliver the estimated gains.
- `tests/commands/catalog.sh` already performs dirty rejection, publication,
  provenance, immutable generation, explicit profile update, rollback
  corruption, and recovery checks.
- `tests/commands/skills.sh` already combines repo/profile target ownership in
  one scenario, but repeats semantic payload checks between directory and ZIP
  transports and uses several independent default-profile scenarios.
- `tests/commands/startup.sh` has three default-success scenarios that can be
  expressed as one monotonic lifecycle and an upstream-isolation scenario that
  can supply the upstream prerequisite to that lifecycle.
- `tests/commands/lifecycle.sh` can absorb the unique task-materialization
  assertions into its existing prepare/complete world and can test last-profile
  cleanup after its existing default uninstall.

This inventory is a verified baseline, not permission to ignore newly
discovered dependencies during implementation.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Freeze the current benchmark and consolidate startup.
- [ ] Chunk 2 — Merge catalog publication and rollback state evolution.
- [ ] Chunk 3 — Consolidate skills scenarios and transport verification.
- [ ] Chunk 4 — Remove duplicate lifecycle materialization and cleanup worlds.
- [ ] Chunk 5 — Consolidate the current onboarding bootstrap progression.
- [ ] Chunk 6 — Rebalance workers and run final acceptance benchmarks.

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

## Chunk 1 — Baseline and progressive startup

### Goal

Freeze comparable current before measurements, then replace the repeated
default startup setup/install worlds with one progressive default/upstream
scenario while retaining the distinct external failure/retry scenario.

### Suggested AI reasoning effort

`high` — the code change is localized, but the benchmark must be comparable
and progressive shell/startup state must not make later assertions
tautological.

### Files

- `tests/commands/startup.sh`
- `tests/commands/CONTEXT.md`
- `docs/testing.md`
- this plan

### Implementation requirements

1. Before editing any test, run three isolated timed serial samples for each of
   the five target groups, one current complete timed serial suite, and three
   current default three-worker samples. Record all raw timing and count values
   plus medians in this plan. Use identical commands and the same host for the
   corresponding after measurements.
2. Record an assertion/transition ledger for every current startup case before
   editing. The ledger must distinguish startup-file content, manifest
   ownership, initial automatic shell coverage, repair/adoption, idempotence,
   upstream rejection/non-mutation, and external failure/retry.
3. Start the progressive success scenario from one pristine upstream profile
   fixture. Install the default profile first with explicit zsh startup, verify
   only that requested startup state, re-run the default bootstrap with
   automatic shell discovery, verify zsh plus Bash login/non-login adoption,
   then run the installed default command against an existing startup file and
   prove a single owned marker and manifest entry.
4. In the same scenario, exercise upstream `install` and `update
   --repair-startup` rejection and prove neither profile nor the default startup
   files changed. This retains the upstream-isolation contract without another
   real default installation.
5. Keep external failure/retry in a fresh scenario because it intentionally
   commits a profile while external startup integration fails, then repairs it
   through an independently repeatable installed command.
6. Retain separate logical `pass` records or document any necessary count
   change. Do not count fewer functions as a performance result; count the
   eliminated scenarios and real transitions.
7. Document the benchmark command and median/delta formula in
   `docs/testing.md` without changing the runner interface.

### Verification checklist

- [ ] The plan contains raw and median before samples for all five target
      groups, a full serial baseline, and a three-run default baseline.
- [ ] Every prior startup assertion is present or listed in an accepted
      equivalent assertion mapping.
- [ ] The startup group retains its baseline test count and passes three
      isolated timed serial runs.
- [ ] Startup scenario creation drops from five runtime scenarios to two, and
      committed/successful default install/repair transitions drop from eight
      to five.
- [ ] The reviewer output calculates before/after group, setup, real, and CPU
      medians; absolute and percentage savings; and cumulative projected full
      serial time.
- [ ] `dash -n tests/commands/startup.sh` passes.
- [ ] `./tests/context-tree.sh` passes.

### Human review gate

Confirm the initial benchmark is reproducible, the automatic-first-install
coverage is acceptably represented by explicit-first then automatic repair,
upstream isolation remains non-mutating, every assertion is mapped, and the
review output contains the required calculated before/after table. Do not
start catalog work until this chunk is explicitly accepted.

## Chunk 2 — Progressive catalog publication and rollback

### Goal

Make rollback operate on generations created by the existing rebind/publish
scenario, eliminating the second profile world and repeated checkout clone,
rebind, commit, and publish sequence.

### Suggested AI reasoning effort

`xhigh` — this chunk combines transaction history, exact generation metadata,
intentional corruption, restoration, source loss, rollback, and recovery. A
sequencing error could preserve surface assertions while weakening the
rollback invariant.

### Files

- `tests/commands/catalog.sh`
- `tests/commands/CONTEXT.md`
- this plan

### Implementation requirements

1. Keep list validation, dirty initial publication, registration collision,
   registry symlink rejection, and rebind/publication as separate logical
   cases. Only `rollback_recovery` is folded into the progressive publication
   lifecycle.
2. Preserve the current clean-to-dirty-to-committed publication sequence,
   provenance/fingerprint assertions, ignored-content exclusion, live upstream
   versus immutable default visibility, and explicit default-profile update
   adoption.
3. Before corrupting the retained initial generation, save the exact file
   bytes required to restore it. Prove a corrupt retained generation rejects
   rollback without changing the registry, restore it exactly, and verify the
   generation resolves before continuing.
4. Continue the same scenario by relocating the bound checkout, rolling back
   from the published generation to the initial generation, verifying source
   loss does not prevent rollback, corrupting the now-current initial
   generation, and rolling forward through rollback recovery to the published
   generation. Preserve the final preview and registry-history assertions.
5. Preserve the checkout-HEAD race recheck without leaving the bound checkout
   in a state that invalidates the later rollback assertions.
6. Remove the standalone rollback setup only after every assertion from it is
   mapped into the progressive lifecycle.

### Verification checklist

- [ ] `commands-catalog` retains its baseline test count or has an explicitly
      accepted assertion/count mapping.
- [ ] One scenario now proves publish, corrupt-retained rejection, source-loss
      rollback, invalid-current recovery, and final tool preview.
- [ ] The second profile clone, checkout clone, rebind, Git commit, and publish
      sequence is absent.
- [ ] Dirty initial publication still proves that no profile, registry,
      staging, or generation state is created.
- [ ] Dirty republish still proves existing registry, profile, and staging
      state is unchanged.
- [ ] Three isolated timed serial runs pass and reviewer output reports raw
      values, medians, calculated savings/percentage, test counts, and
      cumulative projection.
- [ ] `dash -n tests/commands/catalog.sh` passes.
- [ ] `./tests/context-tree.sh` passes.

### Human review gate

Confirm generation ordering is understandable, corruption is restored only
inside the disposable fixture, rollback still proves source independence, and
the calculated timing improvement comes from one removed transition sequence
rather than removed coverage.

## Chunk 3 — Skills state and transport consolidation

### Goal

Reduce repeated skills profile worlds and duplicate transport verification
while retaining the existing ownership lifecycle and the real catalog-to-skills
integration boundary.

### Suggested AI reasoning effort

`high` — the main difficulty is maintaining an explicit assertion mapping
across consolidated target state and proving ZIP equivalence without removing
transport-specific behavior.

### Files

- `tests/commands/skills.sh`
- `tests/commands/CONTEXT.md`
- this plan

### Implementation requirements

1. Create a deterministic helper that emits a portable export inventory as
   sorted relative path, checksum, and byte count records. Verify the complete
   directory export semantically once, extract the ZIP, compare the ZIP
   inventory to the directory inventory, and retain ZIP-specific root/layout
   and absence-of-extra-assets checks.
2. Preserve default-selection, changed installed-selection, complete explicit
   selection, directory transport, and ZIP transport operations. Do not claim
   speedup from deleting the changed-selection or ZIP behavior.
3. Consolidate stale-manifest filtering, removed plugin target rejection,
   retryable external-target failure, and catalog failure-boundary checks onto
   one pristine default-profile scenario. Give each repo-target case a distinct
   work subdirectory and explicitly restore any catalog files/registry moved
   for a failure case before the next case.
4. Preserve separate logical pass records and a written assertion mapping so
   progressive state cannot make a rejection pass because of contamination
   from a prior case.
5. Keep target ownership as its existing independent default/upstream scenario
   because it uninstalls the default profile and proves external target
   survival. Do not add another default/upstream/target matrix.
6. Keep catalog authority as an independent real rebind, live addition, commit,
   publish, and default visibility scenario. This is the one intentional
   catalog-to-skills end-to-end boundary; moving publication cost into parent
   setup or hand-authoring generation metadata is prohibited.
7. If the measured savings are below noise, report that result. Do not remove
   semantic assertions or the real catalog boundary to chase the historical
   60–100-second estimate.

### Verification checklist

- [ ] Directory and extracted ZIP inventories match exactly and all prior ZIP
      semantic assertions are mapped through that equality or retained
      directly.
- [ ] Default, installed, explicit-complete, directory, and ZIP export
      behaviors all execute.
- [ ] Repo/home ownership, cross-profile update/uninstall, unknown sibling
      preservation, stale manifest filtering, removed target rejection,
      failure retry, schema rejection, unavailable catalog rejection, and
      manifest-owned uninstall all remain covered.
- [ ] Live upstream skill visibility and published default visibility still use
      a real catalog publication.
- [ ] The group retains its baseline test count unless a reviewer accepts a
      fully documented mapping.
- [ ] Three isolated timed serial runs pass and reviewer output reports raw
      values, medians, calculated savings/percentage, test counts, and
      cumulative projection.
- [ ] `dash -n tests/commands/skills.sh` passes.
- [ ] `./tests/context-tree.sh` passes.

### Human review gate

Confirm inventory equality truly transfers all directory semantic checks to
ZIP, progressive repo-target cases remain isolated, the existing ownership
lifecycle was not expanded or weakened, and any shortfall against the supplied
skills estimate is reported rather than hidden.

## Chunk 4 — Lifecycle world reuse

### Goal

Reuse the existing indivisible lifecycle prepare/complete world for unique
materialization and final-container cleanup assertions, removing standalone
profile scenarios and duplicate task install/uninstall transitions.

### Suggested AI reasoning effort

`xhigh` — this chunk crosses install, materialization, uninstall, unmanaged
ownership, sibling preservation, and empty-container cleanup. It requires the
strictest reasoning about destructive boundaries and state ordering.

### Files

- `tests/commands/lifecycle.sh`
- `tests/commands/CONTEXT.md`
- this plan

### Implementation requirements

1. During lifecycle prepare, capture upstream profile and both catalog registry
   checksums needed by the materialization-isolation proof.
2. After the existing task install in lifecycle complete and before default
   uninstall, assert the task dispatcher, tool metadata, concrete runtime,
   absence of canonical skill payload, upstream profile non-mutation, and both
   catalog registry checksums. Remove the standalone
   `profile_materialization_isolation` scenario and its duplicate task install.
3. Preserve the existing unmanaged default sentinel and upstream sibling
   assertions through default uninstall. After those assertions pass, remove
   only the explicit test-created default sentinel and its now-empty disposable
   profile directory, then uninstall upstream and prove the profiles container
   is removed while default and upstream catalog registries remain.
4. Remove the standalone two-world `empty_container_cleanup` coverage only
   after mapping its single-profile and sibling-profile assertions to the
   progressive last-profile sequence. Do not use broad cleanup or remove any
   state not created by the test.
5. Keep launcher repair, upstream control-plane refresh, legacy mixed-layout
   rejection/recreation, late-commit rollback, registry upgrades, Linux
   activation cleanup, Darwin projection refusal, global uninstall, and
   catalog-independent execution as distinct cases.
6. Do not move lifecycle assertions into `commands-install` or
   `commands-update` unless review discovers a unique owner there. If any move
   becomes necessary, expand timing comparison to every affected group before
   reporting net savings.

### Verification checklist

- [ ] Task materialization and isolation are proven in the existing main
      lifecycle world before default uninstall.
- [ ] Default uninstall preserves its unmanaged sentinel and upstream sibling;
      final upstream uninstall removes the empty profiles container and
      preserves both catalog registries.
- [ ] Standalone materialization and empty-container scenarios and their
      duplicate task/install/uninstall transitions are absent.
- [ ] All migration, rollback, registry, activation, projection, global, and
      source-loss cases remain separate and pass.
- [ ] The lifecycle group retains its baseline test count unless a reviewer
      accepts a fully documented assertion/count mapping.
- [ ] Three isolated timed serial runs pass and reviewer output reports raw
      values, medians, calculated savings/percentage, test counts, and
      cumulative projection.
- [ ] `dash -n tests/commands/lifecycle.sh` passes.
- [ ] `./tests/context-tree.sh` passes.

### Human review gate

Confirm the test deletes only its explicit sentinel after first proving
unmanaged preservation, last-profile cleanup exercises the real uninstall
path, all standalone assertions are mapped, and no migration or registry
boundary was conflated for speed.

## Chunk 5 — Current onboarding progression

### Goal

Consolidate the current absolute/sourced/default-selection/profile-switching
bootstrap path into one progressive scenario without introducing the stale
agent-state matrix from the supplied review.

### Suggested AI reasoning effort

`high` — sourced execution preserves caller flags, traps, positional
parameters, functions, environment, and PATH while filesystem state advances
through multiple profiles and shell implementations.

### Files

- `tests/commands/onboarding.sh`
- `tests/commands/CONTEXT.md`
- this plan

### Implementation requirements

1. Preserve documentation, help/no-mutation, sourced failure cleanup under
   ordinary and `set -e` callers, startup failure, Bash/Zsh documented source
   compatibility, malformed shell-init rejection, and shell-init PATH behavior
   as separate cases.
2. In one new progressive scenario, execute the installer by absolute path
   outside the checkout for upstream, then source the default bootstrap under
   `/bin/sh` while retaining the existing caller status, PATH, cwd, flags,
   positional parameters, function, trap, leak, baseline tool, and no-startup
   assertions.
3. Continue from that default profile to reject an empty installed selection
   without manifest mutation, add task plus `oc@4.18`, source the default
   bootstrap again, and verify additive selection survives refresh.
4. Source upstream and then default again to prove PATH precedence switches
   deterministically. Reuse the upstream profile created by absolute execution;
   do not create a second upstream world.
5. Compare default/upstream baseline selection with the immutable session
   fixture manifests where installation itself is not the behavior being
   asserted.
6. Retain distinct logical pass records for absolute execution, sourced state,
   selection policy, and profile switching. Do not rewrite the Bash/Zsh source
   matrix into shell-init-only tests because it intentionally validates
   `source ./install.sh`.
7. Report the actual savings. The supplied 55–90-second estimate is not an
   acceptance fact because its named onboarding scenarios are absent from the
   current tree.

### Verification checklist

- [ ] Absolute execution, sourced caller-state preservation, fixed baseline,
      empty selection rejection, additive installed selection, refresh
      preservation, and default/upstream/default PATH selection all pass in one
      progressive world.
- [ ] Failure, help, documentation, startup failure, Bash/Zsh, malformed
      shell-init, and PATH-only cases remain separately isolated.
- [ ] Every prior onboarding assertion and logical pass is retained or mapped.
- [ ] The consolidated path uses one scenario instead of the former five
      scenario initializations across absolute execution, sourced state,
      selection policy, and switching, and removes at least one real profile
      materialization/refresh.
- [ ] Three isolated timed serial runs pass and reviewer output reports raw
      values, medians, calculated savings/percentage, test counts, and
      cumulative projection.
- [ ] `dash -n tests/commands/onboarding.sh` passes under `/bin/sh`; available
      Bash and Zsh source-form cases pass.
- [ ] `./tests/context-tree.sh` passes.

### Human review gate

Confirm invocation-mode coverage remains real, progressive state does not make
selection or switching assertions tautological, stale scenario assumptions
were not introduced, and the reviewer output clearly distinguishes measured
savings from the original estimate.

## Chunk 6 — Rebalance and acceptance benchmark

### Goal

Validate the cumulative serial result, rebalance static workers from final
measurements, and calculate final before/after serial and parallel outcomes.

### Suggested AI reasoning effort

`high` — the work is measurement- and scheduling-heavy rather than
transactional, but it requires careful median/delta calculations, exact group
coverage, and separation of serial savings from parallel critical-path effects.

### Files

- `tests/runner.sh`
- `tests/lib/runner.sh` only if assignment validation coverage requires a
  corresponding expectation update
- `tests/CONTEXT.md`
- `tests/lib/CONTEXT.md` only if runner-test ownership changes
- `docs/testing.md`
- this plan

### Implementation requirements

1. Run one complete timed serial suite before changing assignments and record
   every final group timing, setup, real, user, sys, and test count.
2. Calculate two-worker and three-worker assignments from the final group
   values. Preserve every group exactly once, lifecycle indivisibility,
   canonical log replay, and current option behavior. Choose assignments that
   minimize the maximum summed group time; record projected totals in the
   adjacent comment.
3. Do not alter group boundaries or add dynamic scheduling in this chunk.
   Assignment-only changes keep the completed runner architecture intact.
4. Run the complete serial suite after assignment edits to confirm assignments
   do not affect serial behavior, then run `--jobs 2` once and the default
   three-worker suite three clean times.
5. Calculate final results against the frozen baseline: each target group,
   aggregate five-group median, complete serial real/CPU/setup, two-worker
   result, three-worker median, test count, and projected versus actual worker
   totals.
6. Final acceptance requires at least 255 seconds aggregate target-group
   savings, a faster full serial result, no default three-worker median
   regression, all 41 groups exactly once, and the baseline assertion/test
   mapping. If any condition fails, mark it `[~]`, explain impact and proposed
   action, and stop without declaring the plan complete.
7. Update testing guidance and retained contexts with final scenario ownership,
   benchmark results, and new measured shard totals. Do not add a host-specific
   CI timeout.

### Verification checklist

- [ ] `dash -n` passes for every changed shell file.
- [ ] Each target group passes three isolated serial samples with expected
      counts and complete timing records.
- [ ] The complete serial suite passes all 41 groups and baseline-mapped tests;
      aggregate target-group savings are at least 255 seconds and full serial
      real time is lower than before.
- [ ] `./tests/test.sh --jobs 2` passes with exact group/count coverage.
- [ ] Three clean default runs pass; their median does not regress and actual
      worker totals are reasonably consistent with the recorded projections.
- [ ] Final reviewer output includes raw samples plus calculated before/after
      seconds, percentages, CPU changes, setup changes, counts, estimate error,
      and cumulative results.
- [ ] `./tests/context-tree.sh` passes.
- [ ] `git diff --check` passes and only approved test, context, documentation,
      and plan files changed.

### Human review gate

Confirm the final calculated timings use comparable samples, all assertion
mappings and test counts are acceptable, worker rebalancing reflects the new
critical path, and every success condition is met before accepting the plan as
complete.

## Risk register

- **Historical baseline mismatch:** The supplied group values and 1,366-second
  total came from different stages. Mitigation: freeze current isolated group,
  complete serial, and default baselines before edits; label historical
  arithmetic as projection only.
- **Over-consolidated state hides bugs:** A later assertion may pass only
  because an earlier operation prepared more state than a fresh user would
  have. Mitigation: monotonic scenarios only, explicit precondition assertions,
  fresh scenarios for failure recovery and distinct transaction boundaries,
  and assertion mapping at each gate.
- **Test count mistaken for coverage:** `pass` count can remain stable while
  assertions disappear. Mitigation: require assertion mappings in addition to
  baseline count preservation.
- **Timing moved rather than removed:** Shared setup or another group could
  absorb work. Mitigation: compare setup, all affected groups, complete serial,
  and CPU time; report net affected time.
- **Skills estimate is overstated:** The current ownership matrix is already
  consolidated and real publication is a unique boundary. Mitigation: retain
  it and accept only measured savings from state reuse and transport proof;
  stop for review rather than erode coverage.
- **Onboarding review references stale behavior:** Implementing the supplied
  names would create irrelevant tests. Mitigation: use current functions and
  recent history as authority and report estimate variance.
- **Catalog progressive corruption contaminates recovery:** A restored file
  may not match generation metadata. Mitigation: save and restore exact bytes,
  validate resolution before rollback, and retain registry checksums.
- **Lifecycle manual fixture cleanup becomes unsafe:** Removing an entire
  profile tree could mask ownership bugs. Mitigation: first assert real
  uninstall preservation, then remove only the exact test-created sentinel and
  empty directory before testing the sibling's real final uninstall.
- **Static worker imbalance after serial pruning:** The fastest serial result
  may worsen default wall time. Mitigation: defer assignment updates until all
  group changes are final and benchmark three default runs.
- **Benchmark noise:** Filesystem cache, Podman VM load, and host activity can
  distort integer group timings. Mitigation: identical isolated commands,
  three samples and medians, raw-value disclosure, setup/CPU reporting, and no
  cross-host absolute timeout.

## Lessons learned

### Initial

- The governing optimization rule is sound: prune duplicate expensive state
  transitions, not behavioral assertions.
- The prior copy-on-write change improved 1,385 seconds to 1,366 seconds, so
  fixture copy mechanics alone are not the remaining dominant lever.
- The supplied savings ranges sum to 255–415 seconds, not 250–350 seconds; the
  illustrative 1,000–1,100-second total is approximately the center/conservative
  portion of a mathematically wider 951–1,111-second range.
- Current source inspection invalidates parts of the session review: onboarding
  scenario names are stale, target ownership is already collapsed, lifecycle
  refresh cases have distinct semantics, and the profile-scenario call-site
  count has changed.
- Startup and catalog have the strongest current monotonic-state opportunities.
  Skills must be treated conservatively because its largest apparent
  transitions prove unique transport, ownership, or catalog integration
  boundaries.
- The current static runner assigns onboarding and catalog to `three-a`,
  lifecycle and startup to `three-b`, and skills to `three-c`; pruning those
  groups will change all three worker totals and requires final rebalancing.

## Session bootstrap

Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this plan,
`docs/testing.md`, `tests/CONTEXT.md`, `tests/commands/CONTEXT.md`,
`tests/lib/CONTEXT.md`, `tests/test.sh`, `tests/runner.sh`, `tests/support.sh`,
and `tests/lib/runner.sh`. For the active chunk, read every target test module
in full and recheck the working tree before editing.

The target is to remove duplicate real state transitions inside the five
expensive command groups while preserving behavioral assertions, 41-group
coverage, isolation, POSIX shell, and offline behavior. The non-negotiable
rule is: do not replace unique real integration behavior or move cost into
shared setup merely to improve a group number.

The active chunk is Chunk 1. Freeze and record the current baseline before any
test edit, execute only the startup consolidation, update this plan's progress
and lessons, produce the required calculated reviewer table, and stop at the
Chunk 1 human review gate. Use at least the chunk's recorded suggested AI
reasoning effort.
