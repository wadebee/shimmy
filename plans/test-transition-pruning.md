# Test transition pruning plan

**Status:** In progress — Chunks 1–5 are accepted. Chunk 5's measured savings
leave the plan-wide 255-second target unmet; work is paused before Chunk 6.

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

- [x] Chunk 1 — Progressive startup implementation and verification accepted.
- [x] Chunk 2 — Progressive catalog publication and rollback implementation,
      assertion mapping, and measured 25-second median reduction accepted by
      the user on 2026-08-17.
- [x] Chunk 3 — Skills state and transport consolidation, assertion mapping,
      preserved ten-test coverage, and measured 2-second median regression/noise
      result accepted by the user on 2026-08-17.
- [x] Chunk 4 — Lifecycle materialization and cleanup worlds consolidated,
      assertion mapping and 14-test coverage preserved, and measured
      13-second median reduction accepted by the user on 2026-08-17.
- [x] Chunk 5 — Current onboarding progression, assertion mapping, preserved
      11-test coverage, and measured 15-second median reduction accepted by
      the user on 2026-08-17.
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

### Frozen before baseline

The before measurements ran on 2026-08-17 from commit
`f3a1376f8d2f37451f2da2eb257186a473088d67` on Darwin 25.5.0 arm64. The
worktree was clean before these runs and no test file was edited until all 19
required invocations passed. Each isolated sample used:

```sh
/usr/bin/time -p env SHIMMY_TEST_TIMING=1 \
  ./tests/test.sh --serial --group <group>
```

Raw isolated before samples:

| Group | Sample | Setup (s) | Group (s) | Total (s) | Real (s) | User (s) | Sys (s) | Tests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `commands-onboarding` | 1 | 39 | 228 | 267 | 270.46 | 116.24 | 142.39 | 11 |
| `commands-onboarding` | 2 | 38 | 228 | 266 | 269.75 | 116.54 | 141.25 | 11 |
| `commands-onboarding` | 3 | 38 | 229 | 268 | 271.05 | 117.20 | 141.70 | 11 |
| `commands-skills` | 1 | 39 | 195 | 234 | 237.44 | 79.72 | 138.34 | 10 |
| `commands-skills` | 2 | 38 | 194 | 232 | 236.41 | 79.49 | 138.07 | 10 |
| `commands-skills` | 3 | 39 | 195 | 234 | 238.11 | 80.04 | 138.88 | 10 |
| `commands-catalog` | 1 | 38 | 204 | 243 | 248.18 | 82.95 | 145.28 | 6 |
| `commands-catalog` | 2 | 39 | 204 | 243 | 247.82 | 82.82 | 145.30 | 6 |
| `commands-catalog` | 3 | 38 | 204 | 243 | 247.33 | 82.73 | 145.10 | 6 |
| `commands-startup` | 1 | 39 | 136 | 175 | 178.12 | 60.66 | 106.05 | 5 |
| `commands-startup` | 2 | 39 | 138 | 177 | 180.65 | 61.53 | 107.60 | 5 |
| `commands-startup` | 3 | 40 | 135 | 175 | 178.60 | 61.09 | 106.27 | 5 |
| `commands-lifecycle` | 1 | 39 | 225 | 264 | 268.19 | 88.89 | 158.07 | 14 |
| `commands-lifecycle` | 2 | 38 | 226 | 264 | 268.87 | 89.04 | 158.79 | 14 |
| `commands-lifecycle` | 3 | 39 | 228 | 267 | 271.45 | 89.49 | 159.62 | 14 |

| Group | Median setup (s) | Median group (s) | Median total (s) | Median real (s) | Median user (s) | Median sys (s) | Tests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `commands-onboarding` | 38 | 228 | 267 | 270.46 | 116.54 | 141.70 | 11 |
| `commands-skills` | 39 | 195 | 234 | 237.44 | 79.72 | 138.34 | 10 |
| `commands-catalog` | 38 | 204 | 243 | 247.82 | 82.82 | 145.28 | 6 |
| `commands-startup` | 39 | 136 | 175 | 178.60 | 61.09 | 106.27 | 5 |
| `commands-lifecycle` | 39 | 226 | 264 | 268.87 | 89.04 | 158.79 | 14 |

The complete serial baseline used `/usr/bin/time -p env
SHIMMY_TEST_TIMING=1 ./tests/test.sh --serial`. It passed all 41 groups and 159
tests with setup 39 seconds, suite total 1,385 seconds, real 1,393.48 seconds,
user 491.82 seconds, and sys 786.74 seconds.

The three default-worker baselines used `/usr/bin/time -p env
SHIMMY_TEST_TIMING=1 ./tests/test.sh`. All three passed 41 groups and 159 tests:

| Sample | Setup (s) | Total (s) | Real (s) | User (s) | Sys (s) | Tests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 39 | 568 | 576.57 | 569.76 | 962.52 | 159 |
| 2 | 41 | 571 | 579.10 | 571.21 | 966.34 | 159 |
| 3 | 42 | 569 | 577.63 | 570.10 | 962.59 | 159 |
| Median | 41 | 569 | 577.63 | 570.10 | 962.59 | 159 |

The raw contention-affected target-group records inside those default runs
were onboarding 271/272/267, skills 229/228/225, catalog 235/236/237,
startup 158/162/158, and lifecycle 262/260/260 seconds. The isolated samples,
not these parallel records, govern chunk savings.

### Startup assertion and transition ledger

| Before case | Before proof and transitions | Chunk 1 mapping |
| --- | --- | --- |
| Automatic default bootstrap | Fresh automatic bootstrap wrote owned markers and the profile shell-init path to zsh, Bash interactive, and Bash login files; the manifest owned each file and ignored unsupported `SHELL=/bin/sh`. One default transition. | Progressive phase 2 performs automatic repair after explicit zsh installation and repeats every file-content, manifest-ownership, and unsupported-shell assertion over the same files. |
| Existing-profile automatic repair | Explicit zsh bootstrap left both Bash files absent; a second automatic bootstrap adopted zsh plus both Bash files. Two default transitions. | Progressive phases 1 and 2 preserve the exact absent-then-adopted state sequence. |
| Default startup ownership | Explicit startup installation wrote the owned marker and shell-init path; installed `shimmy install` retained one marker and one manifest entry. Two default transitions. | Progressive phase 1 proves initial marker, shell-init, and manifest bytes. Phase 3 targets the existing `.zshrc` explicitly and proves exactly one marker and exactly one manifest entry. |
| Upstream isolation | A pristine upstream clone plus a fresh default install preceded rejected upstream `install` and `update --repair-startup`; neither manifest nor the default startup file changed and no upstream startup file appeared. One default transition plus two rejected operations. | Progressive phase 4 retains both rejected operations after phases 1–3, compares both profile manifests, compares all three default startup files byte-for-byte, and proves the upstream target remains absent. |
| External failure/retry | An invalid startup target committed a valid default profile while reporting external integration failure; an installed command then repaired a new file. Two committed/successful default transitions. | Retained unchanged in its own fresh scenario. |

The baseline therefore used five runtime scenarios and eight committed or
successful default install/repair transitions. Chunk 1 uses two scenarios and
five transitions: explicit default bootstrap, automatic repair, installed
default repair, failure-path profile commit, and retry.

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

- [x] The plan contains raw and median before samples for all five target
      groups, a full serial baseline, and a three-run default baseline.
- [x] Every prior startup assertion is present in the ledger above, and the
      reviewer accepted the automatic-first equivalent mapping.
- [x] The startup group retains its baseline test count and passes three
      isolated timed serial runs.
- [x] Startup scenario creation drops from five runtime scenarios to two, and
      committed/successful default install/repair transitions drop from eight
      to five.
- [x] The reviewer output calculates before/after group, setup, real, and CPU
      medians; absolute and percentage savings; and cumulative projected full
      serial time.
- [x] `dash -n tests/commands/startup.sh` passes.
- [x] `./tests/context-tree.sh` passes.

### Chunk 1 reviewer output

Raw after samples used the identical isolated command recorded above:

| Sample | Setup (s) | Group (s) | Total (s) | Real (s) | User (s) | Sys (s) | CPU user+sys (s) | Tests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 39 | 78 | 117 | 120.74 | 40.90 | 71.86 | 112.76 | 5 |
| 2 | 39 | 78 | 118 | 121.43 | 41.15 | 72.24 | 113.39 | 5 |
| 3 | 39 | 78 | 117 | 120.89 | 41.08 | 71.92 | 113.00 | 5 |
| Median | 39 | 78 | 117 | 120.89 | 41.08 | 71.92 | 113.00 | 5 |

| Metric | Before median (s) | After median (s) | Savings (s) | Improvement | Before/after test count |
| --- | ---: | ---: | ---: | ---: | ---: |
| `commands-startup` group | 136 | 78 | 58 | 42.6% | 5 / 5 |
| Isolated setup | 39 | 39 | 0 | 0.0% | 5 / 5 |
| Isolated total | 175 | 117 | 58 | 33.1% | 5 / 5 |
| `/usr/bin/time` real | 178.60 | 120.89 | 57.71 | 32.3% | 5 / 5 |
| CPU (`user + sys`) | 167.36 | 113.00 | 54.36 | 32.5% | 5 / 5 |

The five isolated target-group medians totalled 989 seconds before Chunk 1.
Only startup changed, so the cumulative affected-set projection is 931
seconds, a 58-second reduction. Applying the same isolated group delta to the
1,385-second serial baseline projects 1,327 seconds after Chunk 1, a 4.2%
suite reduction. The plan-wide 255-second acceptance threshold therefore has
197 seconds remaining for Chunks 2–5. This is a projection; Chunk 6 owns the
final complete serial and worker acceptance measurements.

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

### Catalog assertion and transition ledger

| Before case | Before proof and transitions | Chunk 2 mapping |
| --- | --- | --- |
| Rebind and publish | One cloned profile world and replacement checkout prove invalid rebind rejection, explicit rebind, live-upstream visibility, dirty republish non-mutation, clean publication, immutable provenance, ignored-file exclusion, explicit profile update, HEAD-race rejection, and corrupt-retained rollback rejection. | Retained in the progressive scenario without weakening its assertions. The exact initial `catalog.conf` bytes are saved before corruption and restored before the rollback phases. |
| Rollback recovery | A second cloned profile world and checkout repeat rebind, tool creation, commit, and publication before moving the checkout, rolling back to the initial generation, corrupting that current generation, and recovering forward to the published generation. | The first scenario's initial and published generations supply the same ordering. After exact retained-generation restoration and resolution, the bound checkout is moved, rollback proves source independence and absence of the published `instant` tool, current-generation corruption still fails resolution, and recovery returns to the published generation and final preview. |

The baseline therefore used two profile worlds, two checkout clones, two
rebinds, two Git commits, and two publications across these cases. Chunk 2
retains both logical pass records in one profile world with one checkout clone,
one rebind, one publication commit plus the required HEAD-race fixture commit,
and one publication.

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

- [x] `commands-catalog` retains its baseline test count or has an explicitly
      accepted assertion/count mapping.
- [x] One scenario now proves publish, corrupt-retained rejection, source-loss
      rollback, invalid-current recovery, and final tool preview.
- [x] The standalone rollback setup and its second profile clone, checkout
      clone, rebind, publication-fixture Git commit, and publish sequence are
      absent; the required checkout-HEAD race fixture commit remains.
- [x] Dirty initial publication still proves that no profile, registry,
      staging, or generation state is created.
- [x] Dirty republish still proves existing registry, profile, and staging
      state is unchanged.
- [x] Three isolated timed serial runs pass and reviewer output reports raw
      values, medians, calculated savings/percentage, test counts, and
      cumulative projection.
- [x] `dash -n tests/commands/catalog.sh` passes.
- [x] `./tests/context-tree.sh` passes.

### Chunk 2 reviewer output

Raw after samples used the identical isolated command recorded in Chunk 1:

| Sample | Setup (s) | Group (s) | Total (s) | Real (s) | User (s) | Sys (s) | CPU user+sys (s) | Tests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 40 | 179 | 219 | 223.66 | 74.84 | 131.14 | 205.98 | 6 |
| 2 | 39 | 179 | 218 | 222.10 | 74.26 | 130.29 | 204.55 | 6 |
| 3 | 39 | 179 | 218 | 222.12 | 74.24 | 130.39 | 204.63 | 6 |
| Median | 39 | 179 | 218 | 222.12 | 74.26 | 130.39 | 204.63 | 6 |

| Metric | Before median (s) | After median (s) | Savings (s) | Improvement | Before/after test count |
| --- | ---: | ---: | ---: | ---: | ---: |
| `commands-catalog` group | 204 | 179 | 25 | 12.3% | 6 / 6 |
| Isolated setup | 38 | 39 | -1 | -2.6% | 6 / 6 |
| Isolated total | 243 | 218 | 25 | 10.3% | 6 / 6 |
| `/usr/bin/time` real | 247.82 | 222.12 | 25.70 | 10.4% | 6 / 6 |
| CPU (`user + sys`) | 228.12 | 204.63 | 23.49 | 10.3% | 6 / 6 |

The one-second setup-median increase does not explain away the group savings:
the isolated total median still fell by 25 seconds, and the real-time median
fell by 25.70 seconds. The five isolated target-group medians now total 906
seconds after accepted Chunk 1 and implemented Chunk 2, an 83-second cumulative
reduction from the 989-second baseline. Applying those isolated group deltas to
the 1,385-second serial baseline projects 1,302 seconds, a 6.0% suite
reduction. The plan-wide 255-second acceptance threshold therefore has 172
seconds remaining for Chunks 3–5. This is a projection; Chunk 6 owns the final
complete serial and worker acceptance measurements.

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

- [x] Directory and extracted ZIP inventories match exactly and all prior ZIP
      semantic assertions are mapped through that equality or retained
      directly.
- [x] Default, installed, explicit-complete, directory, and ZIP export
      behaviors all execute.
- [x] Repo/home ownership, cross-profile update/uninstall, unknown sibling
      preservation, stale manifest filtering, removed target rejection,
      failure retry, schema rejection, unavailable catalog rejection, and
      manifest-owned uninstall all remain covered.
- [x] Live upstream skill visibility and published default visibility still use
      a real catalog publication.
- [x] The group retains its baseline test count unless a reviewer accepts a
      fully documented mapping.
- [x] Three isolated timed serial runs pass and reviewer output reports raw
      values, medians, calculated savings/percentage, test counts, and
      cumulative projection.
- [x] `dash -n tests/commands/skills.sh` passes.
- [x] `./tests/context-tree.sh` passes.

### Chunk 3 assertion mapping

| Before proof | Chunk 3 proof |
| --- | --- |
| Default installed selection excludes uninstalled skills, then an additive task install changes the default selection. | Retained unchanged in the portable-export scenario, including the default jq/rg selection, local-build exclusion, task exclusion, additive task install, and subsequent task inclusion. |
| Explicit directory export contains every requested management/tool skill, exactly one `SKILL.md` per skill, no tool assets, and the required activation, registry, OC redirect, and secret guidance. | Retained as the semantic authority. The new inventory records every relative regular-file path, POSIX checksum, and byte count in sorted order. |
| ZIP export repeats each per-skill file-count and selected guidance assertion after extraction. | The extracted archive retains direct single-root/layout and representative manifest/skill checks plus explicit task asset absences. Exact equality with the complete verified directory inventory transfers every per-skill path, byte-count, checksum, and semantic-content proof without repeating selected content assertions. |
| Stale-manifest filtering uses a pristine default profile and leaves the retired untracked sibling while removing it from the owned manifest. | The assertions and operation are unchanged; the case now uses the shared pristine default profile and an isolated `work/stale-manifest` repository target. |
| Removed plugin target and unknown skill reject before mutation; the former override is inert and a normal repo install succeeds. | The assertions and operations are unchanged in isolated `work/removed-target`; profile-manifest and unmanaged-sentinel checks prevent shared-profile state from hiding mutation. |
| External target collision leaves the installed profile unchanged and succeeds on direct retry. | The assertions and operations are unchanged in isolated `work/external-failure`, including manifest checksum and installed-status proofs. |
| Schema-incompatible catalog rejects target update without mutation; manifest-owned uninstall still works; missing registry rejects export without creating output. | The assertions and operations are unchanged in isolated `work/catalog-failure`. Exact valid catalog bytes are restored before the registry-unavailable phase, and the registry is restored before the logical case passes. |
| Repo/home ownership, cross-profile update/uninstall, unknown-sibling preservation, and default-profile lifecycle isolation. | Retained unchanged in its independent default/upstream scenario. |
| Live upstream addition, unpublished default rejection, real commit/publication, published default visibility, and profile-manifest non-mutation. | Retained unchanged in its independent real catalog-authority scenario. |

The consolidation removes three pristine default-profile fixture clones: the
four failure-boundary cases now share one profile world instead of four. Each
repository target remains isolated, and all ten logical pass records remain.

### Chunk 3 reviewer output

Raw after samples used the identical isolated command recorded in Chunk 1:

| Sample | Setup (s) | Group (s) | Total (s) | Real (s) | User (s) | Sys (s) | CPU user+sys (s) | Tests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 39 | 196 | 235 | 239.01 | 80.86 | 139.75 | 220.61 | 10 |
| 2 | 39 | 199 | 239 | 242.32 | 81.38 | 141.39 | 222.77 | 10 |
| 3 | 40 | 197 | 237 | 240.61 | 81.55 | 140.05 | 221.60 | 10 |
| Median | 39 | 197 | 237 | 240.61 | 81.38 | 140.05 | 221.60 | 10 |

| Metric | Before median (s) | After median (s) | Savings (s) | Improvement | Before/after test count |
| --- | ---: | ---: | ---: | ---: | ---: |
| `commands-skills` group | 195 | 197 | -2 | -1.0% | 10 / 10 |
| Isolated setup | 39 | 39 | 0 | 0.0% | 10 / 10 |
| Isolated total | 234 | 237 | -3 | -1.3% | 10 / 10 |
| `/usr/bin/time` real | 237.44 | 240.61 | -3.17 | -1.3% | 10 / 10 |
| CPU (`user + sys`) | 218.06 | 221.60 | -3.54 | -1.6% | 10 / 10 |

The measured result is below noise and does not support the supplied
60–100-second skills estimate. The removed fixture clones are copy-on-write
copies; the retained additive install, ownership lifecycle, source refresh,
and real catalog publication dominate this group. Per the chunk constraints,
those unique transitions and all semantic assertions remain.

The five isolated target-group medians now total 908 seconds after accepted
Chunk 1, accepted Chunk 2, and implemented Chunk 3, an 81-second cumulative
reduction from the 989-second baseline. Applying those isolated group deltas to
the 1,385-second serial baseline projects 1,304 seconds, a 5.8% suite
reduction. The plan-wide 255-second acceptance threshold therefore has 174
seconds remaining for Chunks 4–5. This is a projection; Chunk 6 owns the final
complete serial and worker acceptance measurements.

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

- [x] Task materialization and isolation are proven in the existing main
      lifecycle world before default uninstall.
- [x] Default uninstall preserves its unmanaged sentinel and upstream sibling;
      final upstream uninstall removes the empty profiles container and
      preserves both catalog registries.
- [x] Standalone materialization and empty-container scenarios and their
      duplicate task/install/uninstall transitions are absent.
- [x] All migration, rollback, registry, activation, projection, global, and
      source-loss cases remain separate and pass.
- [x] The lifecycle group retains its baseline test count unless a reviewer
      accepts a fully documented assertion/count mapping.
- [x] Three isolated timed serial runs pass and reviewer output reports raw
      values, medians, calculated savings/percentage, test counts, and
      cumulative projection.
- [x] `dash -n tests/commands/lifecycle.sh` passes.
- [x] `./tests/context-tree.sh` passes.

### Chunk 4 assertion mapping

| Before proof | Chunk 4 proof |
| --- | --- |
| The standalone materialization-isolation world captured the upstream manifest and jq implementation plus both catalog registries, installed task into default, and proved its dispatcher, metadata, runtime, skill exclusion, and upstream/catalog isolation. | Lifecycle prepare captures the upstream manifest, jq implementation, and launcher plus both catalog registries. Lifecycle complete performs the existing task install once and repeats every task, skill-exclusion, upstream-absence, and exact-checksum assertion before default uninstall. |
| The main lifecycle world preserved an explicit unmanaged default sentinel and an upstream sibling sentinel through default uninstall. | The explicit unmanaged default sentinel remains through real default uninstall. Exact upstream manifest, jq implementation, and launcher checksums remain unchanged before and after that uninstall, mapping the former sibling-sentinel boundary to three substantive sibling assets. |
| The standalone single-profile cleanup world proved an owned profile registry disappears, the last profile removes the profiles container, and the default catalog remains. | Default uninstall removes its owned registry while retaining only the explicit sentinel. After that sentinel and its verified-empty profile directory are removed by exact paths, the real upstream last-profile uninstall removes the profiles container; the default catalog registry remains byte-exact. |
| The standalone sibling-profile cleanup world proved default uninstall preserves upstream profile state and the profiles container, then upstream uninstall removes the last profile while preserving the upstream catalog. | The progressive world proves the profiles container and byte-exact upstream manifest, implementation, and launcher remain after default uninstall. Real upstream uninstall then removes its profile and the container while both default and upstream catalog registries remain byte-exact. |
| Launcher repair, control-plane refresh, mixed-layout rejection/recreation, late-commit rollback, registry upgrade/refusal, Linux activation cleanup, Darwin projection refusal, catalog-loss execution, and global uninstall used independent cases. | Every case remains independent and unchanged apart from call-order closure after the progressive lifecycle phases. |

The consolidation removes three pristine profile-fixture worlds, one duplicate
task install, and two duplicate default uninstall transitions. It retains the
single real upstream last-profile uninstall in the progressive lifecycle and
all 14 logical pass records.

### Chunk 4 reviewer output

Raw after samples used the identical isolated command recorded in Chunk 1:

| Sample | Setup (s) | Group (s) | Total (s) | Real (s) | User (s) | Sys (s) | CPU user+sys (s) | Tests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 40 | 212 | 252 | 256.74 | 85.00 | 151.42 | 236.42 | 14 |
| 2 | 39 | 213 | 252 | 256.30 | 84.79 | 150.55 | 235.34 | 14 |
| 3 | 39 | 213 | 252 | 255.85 | 85.28 | 150.52 | 235.80 | 14 |
| Median | 39 | 213 | 252 | 256.30 | 85.00 | 150.55 | 235.80 | 14 |

| Metric | Before median (s) | After median (s) | Savings (s) | Improvement | Before/after test count |
| --- | ---: | ---: | ---: | ---: | ---: |
| `commands-lifecycle` group | 226 | 213 | 13 | 5.8% | 14 / 14 |
| Isolated setup | 39 | 39 | 0 | 0.0% | 14 / 14 |
| Isolated total | 264 | 252 | 12 | 4.5% | 14 / 14 |
| `/usr/bin/time` real | 268.87 | 256.30 | 12.57 | 4.7% | 14 / 14 |
| CPU (`user + sys`) | 247.83 | 235.80 | 12.03 | 4.9% | 14 / 14 |

The lifecycle group median fell by 13 seconds while setup stayed unchanged.
The five isolated target-group medians now total 895 seconds after accepted
Chunks 1–3 and implemented Chunk 4, a 94-second cumulative reduction from the
989-second baseline. Applying those isolated group deltas to the 1,385-second
serial baseline projects 1,291 seconds, a 6.8% suite reduction. The plan-wide
255-second acceptance threshold therefore has 161 seconds remaining for Chunk
5. This is a projection; Chunk 6 owns the final complete serial and worker
acceptance measurements.

### Human review gate

Confirm the test deletes only its explicit sentinel after first proving
unmanaged preservation, last-profile cleanup exercises the real uninstall
path, all standalone assertions are mapped, and no migration or registry
boundary was conflated for speed.

Accepted by the user on 2026-08-17.

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

- [x] Absolute execution, sourced caller-state preservation, fixed baseline,
      empty selection rejection, additive installed selection, refresh
      preservation, and default/upstream/default PATH selection all pass in one
      progressive world.
- [x] Failure, help, documentation, startup failure, Bash/Zsh, malformed
      shell-init, and PATH-only cases remain separately isolated.
- [x] Every prior onboarding assertion and logical pass is retained or mapped.
- [x] The consolidated path uses one scenario instead of the former five
      scenario initializations across absolute execution, sourced state,
      selection policy, and switching, and removes at least one real profile
      materialization/refresh.
- [x] Three isolated timed serial runs pass and reviewer output reports raw
      values, medians, calculated savings/percentage, test counts, and
      cumulative projection.
- [x] `dash -n tests/commands/onboarding.sh` passes under `/bin/sh`; available
      Bash and Zsh source-form cases pass.
- [x] `./tests/context-tree.sh` passes.

### Chunk 5 assertion and transition mapping

| Before proof | Chunk 5 proof |
| --- | --- |
| Absolute execution used a fresh scenario to execute the repository installer by absolute path from outside the checkout and materialize upstream. | The progressive world retains the same absolute repository installer invocation from its disposable work directory, validates the upstream profile identity, and captures its baseline selection before later phases. |
| Sourced state used a second fresh scenario to source default under `/bin/sh` and prove status, PATH, cwd, flags, positional parameters, function, trap, unrelated variable, bootstrap cleanup, baseline commands, profile identity, and `--no-startup` behavior. | The next progressive phase sources default under `/bin/sh` and repeats every assertion unchanged before advancing profile state. |
| Selection policy used one rejected fresh bootstrap plus a cloned default fixture for baseline comparison, empty installed-selection rejection/non-mutation, additive task and `oc@4.18` install, and real default refresh preservation. | The progressive world starts with the same rejected request before any default profile exists. Its newly bootstrapped default and absolute upstream selections are compared with both immutable session manifests. The empty request retains the exact manifest-checksum proof; task/OC installation and the real default bootstrap refresh retain the additive and byte-derived selection equality checks. |
| Profile switching used a fifth fresh scenario and sourced default, upstream, then default, materializing both profiles independently of the absolute-execution case. | The already-selected progressive default supplies the first PATH proof. The test sources the repository bootstrap for the existing absolute-execution upstream profile, then sources the existing default bootstrap again and proves all three launcher paths. No second upstream world is created. |
| Documentation, help/non-mutation, ordinary and `set -e` failure cleanup, startup failure, Bash/Zsh source compatibility, malformed shell-init rejection, and shell-init PATH behavior were independent cases. | Every case remains independently initialized and unchanged. All 11 logical pass records remain. |

The consolidation reduces five scenario initializations to one across the four
progressive logical cases. It removes the switching case's redundant fresh
default materialization while retaining the absolute upstream bootstrap, the
first sourced default bootstrap, additive installed-tool transition, real
default refresh, and sourced upstream/default refreshes required by the
behavioral contract.

### Chunk 5 reviewer output

Raw after samples used the identical isolated command recorded in Chunk 1:

| Sample | Setup (s) | Group (s) | Total (s) | Real (s) | User (s) | Sys (s) | CPU user+sys (s) | Tests |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 39 | 211 | 250 | 254.22 | 111.09 | 131.88 | 242.97 | 11 |
| 2 | 39 | 213 | 252 | 256.44 | 112.22 | 132.62 | 244.84 | 11 |
| 3 | 39 | 213 | 252 | 255.99 | 112.47 | 132.23 | 244.70 | 11 |
| Median | 39 | 213 | 252 | 255.99 | 112.22 | 132.23 | 244.70 | 11 |

| Metric | Before median (s) | After median (s) | Savings (s) | Improvement | Before/after test count |
| --- | ---: | ---: | ---: | ---: | ---: |
| `commands-onboarding` group | 228 | 213 | 15 | 6.6% | 11 / 11 |
| Isolated setup | 38 | 39 | -1 | -2.6% | 11 / 11 |
| Isolated total | 267 | 252 | 15 | 5.6% | 11 / 11 |
| `/usr/bin/time` real | 270.46 | 255.99 | 14.47 | 5.4% | 11 / 11 |
| CPU (`user + sys`) | 258.63 | 244.70 | 13.93 | 5.4% | 11 / 11 |

The one-second setup-median increase does not explain away the group savings:
the isolated total fell by 15 seconds, real time fell by 14.47 seconds, and
CPU time fell by 13.93 seconds. The actual 15-second onboarding reduction is
40 seconds below the supplied estimate's 55-second lower bound and 75 seconds
below its 90-second upper bound.

The five isolated target-group medians now total 880 seconds after implemented
Chunks 1–5, a 109-second cumulative reduction from the 989-second baseline.
Applying those isolated group deltas to the 1,385-second serial baseline
projects 1,276 seconds, a 7.9% suite reduction. The plan-wide 255-second
acceptance threshold remains short by 146 seconds. The objective therefore
cannot be reached by the approved Chunks 1–5 without removing retained unique
integration behavior or expanding scope. Per the plan stop condition, work
stops at this review gate; Chunk 6 has not started.

### Human review gate

Confirm invocation-mode coverage remains real, progressive state does not make
selection or switching assertions tautological, stale scenario assumptions
were not introduced, and the reviewer output clearly distinguishes measured
savings from the original estimate. Also decide whether to accept the safe
consolidation with the 146-second plan-wide shortfall, revise the objective or
scope, or request rollback; do not begin Chunk 6 without explicit direction.

Accepted by the user on 2026-08-17 with the documented 146-second plan-wide
shortfall. Chunk 6 remains pending separate explicit direction.

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

### Chunk 1

- The same-host frozen baseline is stable: the five isolated group medians
  total 989 seconds, the full serial suite passed 159 tests in 1,385 integer
  seconds, and the three-worker real-time median is 577.63 seconds.
- Startup's five logical test records do not require five disposable worlds.
  The explicit zsh, automatic adoption, installed-command idempotence, and
  upstream rejection contracts form one monotonic state sequence; external
  failure/retry remains correctly isolated.
- Comparing all three default startup files plus both profile manifests after
  the rejected upstream operations strengthens the former single-file
  non-mutation proof without adding a transition.
- Consolidation reduced the startup group median from 136 to 78 seconds
  (42.6%) while setup stayed at 39 seconds and the five-test count remained
  unchanged. The projected full serial result is 1,327 seconds; final suite
  and worker measurements remain deferred to Chunk 6.

### Chunk 2

- Publication and rollback recovery can share one monotonic generation history
  without weakening transaction coverage when the retained initial generation
  is restored byte-for-byte and resolved before source-loss rollback.
- Keeping both logical pass records while deleting the standalone rollback
  world preserved the six-test count and made the removed cost attributable to
  one profile clone, checkout clone, rebind, publication commit, and publish
  sequence rather than removed assertions.
- The catalog group median fell from 204 to 179 seconds (12.3%). Together with
  accepted Chunk 1, cumulative isolated savings are 83 seconds and the
  projected full serial result is 1,302 seconds; final suite and worker
  measurements remain deferred to Chunk 6.

### Chunk 3

- Sorted relative-path, POSIX checksum, and byte-count inventory equality makes
  the fully asserted directory export authoritative for ZIP payload semantics
  while preserving direct ZIP root/layout and no-extra-assets checks.
- Four failure-boundary cases can share one pristine default profile safely
  when every repository target has a distinct work root and the temporary
  catalog and registry mutations are restored before progression.
- Consolidation reduced seven profile worlds to four and preserved all ten
  logical records, but the group median changed from 195 to 197 seconds. The
  three removed copy-on-write fixture clones are not a material cost compared
  with the unique install, ownership, update, uninstall, and publication
  transitions retained by design.
- Cumulative isolated savings remain 81 seconds and the projected full serial
  result is 1,304 seconds. The 174-second remaining target must come from
  Chunks 4–5 without weakening coverage.

### Chunk 4

- Task materialization, canonical-skill exclusion, upstream isolation, and
  both catalog-registry checks fit before default uninstall in the existing
  indivisible lifecycle world without another task install.
- Exact upstream manifest, implementation, and launcher checksums map the
  former synthetic sibling sentinel to substantive sibling state, while the
  explicit unmanaged default sentinel remains the only manually deleted test
  asset before real last-profile cleanup.
- Consolidation removed three profile-fixture worlds and two duplicate default
  uninstalls while preserving all 14 logical records. The lifecycle median
  fell from 226 to 213 seconds (5.8%) with unchanged setup.
- Cumulative isolated savings are 94 seconds and the projected full serial
  result is 1,291 seconds. Chunk 5 must supply the remaining 161 seconds to
  reach the plan threshold without weakening coverage.

### Chunk 5

- Absolute execution, sourced caller-state preservation, selection policy, and
  profile switching form one monotonic world without conflating invocation
  modes: execution creates upstream, `/bin/sh` sourcing creates default, and
  later sourced refreshes operate on those exact profiles.
- Immutable session manifests are useful selection authorities even when the
  progressive profiles themselves must be created by real bootstraps. This
  preserves exact baseline proof without another cloned profile scenario.
- Consolidation removed four scenario initializations and one redundant fresh
  default materialization while preserving all 11 pass records. The onboarding
  median fell from 228 to 213 seconds (6.6%) with a one-second setup increase
  and 14.47-second real-time reduction.
- The original 55–90-second onboarding estimate overstated the removable work:
  the retained absolute/sourced invocation boundaries, additive install, real
  refresh, profile switching, and Bash/Zsh matrix dominate the group.
- Cumulative isolated savings are 109 seconds and the projected full serial
  result is 1,276 seconds. The 146-second acceptance shortfall triggers the
  plan's stop condition; further pruning would require revised scope or removal
  of behavior that this plan explicitly protects.

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

Chunks 1–5 are explicitly accepted. Chunk 5's timing shortfall remains
documented, and Chunk 6 must remain pending until the user gives separate
explicit direction.
