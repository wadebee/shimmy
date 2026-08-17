# Unit-test performance improvement plan

## Objective

Reduce the wall-clock duration of the complete repository test suite by at
least 50 percent on the measured Apple Silicon development host, from the
verified baseline of 1,392.62 seconds to no more than 696.31 seconds, while
preserving all 145 current passing cases, test isolation, failure propagation,
POSIX-shell compatibility, and the default suite's offline behavior.

Success requires:

- an unchanged serial compatibility mode that passes all existing tests;
- a bounded parallel default mode that produces deterministic, reviewable
  output and returns nonzero if any worker fails;
- reusable timing output that identifies setup and test-group durations;
- no live registry access, live tool-container execution, or fake Podman
  substitution added to the default repository suite; and
- an optimized-run median of at most 696.31 seconds across three clean runs on
  the same host, with no unexplained test-count or coverage loss.

This work does not change Shimmy runtime behavior, profile semantics, tool
images, installed-profile smoke behavior, or production command interfaces.
It does not replace the POSIX shell architecture or add a new test framework.

## Target layout and terminology

- **Session fixtures** are the immutable clean source, catalog, default-profile,
  upstream-profile, and update-source snapshots created once by
  `tests/test.sh`.
- **Scenario fixtures** are disposable copies created beneath a scenario's
  private `HOME` and `XDG_CONFIG_HOME`.
- **Test group** is one named, independently executable `test_*_run` boundary.
  The lifecycle prepare/complete sequence is one indivisible group.
- **Worker** is a background POSIX-shell subshell that executes an ordered list
  of test groups against read-only session fixtures and private scenario roots.
- **Serial mode** runs the same ordered group registry with one worker.

The target test-support layout is:

```text
tests/
├── test.sh                 # argument parsing, session setup, worker orchestration
├── runner.sh               # group registry, timing, worker/log/count helpers
├── support.sh              # assertions and fixture-copy helpers
├── lib/
│   └── runner.sh           # runner and copy-strategy regression coverage
└── ...                     # existing behavior modules remain owned in place
```

## Recorded design decisions

1. Preserve one canonical suite. `./tests/test.sh`, serial mode, group-filtered
   mode, and parallel mode select from one group registry; no separate “fast”
   suite may omit behavior silently.
2. Keep the source suite offline. Parallelization must not turn preview-based
   tests into live Podman or registry tests.
3. Create session fixtures once in the parent before starting workers. Workers
   may read them and must create all mutable state below unique scenario roots.
4. Treat `test_commands_lifecycle_prepare` followed by
   `test_commands_lifecycle_complete` as one group because those functions
   intentionally share scenario state and ordering.
5. Use three workers by default. Accept `--jobs <1-3>` and `--serial` for local
   diagnostics; reject zero, non-numeric, duplicate, and out-of-range values
   before fixture creation. `--serial` is equivalent to `--jobs 1`.
6. Add repeatable `--group <name>` selection and `--list-groups`. Unknown,
   duplicate, or empty group requests fail before fixture creation. Installed
   profile smoke arguments retain their current parsing and behavior.
7. Capture each group's output in a private file and replay it in canonical
   group order after its worker finishes. Sum worker test counts only after
   successful completion. Wait
   for every started worker, return nonzero when any worker fails, identify all
   failed workers, and preserve their logs. Signal cleanup must terminate
   started workers before removing the session root.
8. Timing is opt-in through `SHIMMY_TEST_TIMING=1`. Emit stable manifest-style
   records for session setup, every group, and total duration using integer
   elapsed seconds. The normal PASS output remains unchanged when timing is
   disabled.
9. Centralize recursive test-tree copying in one helper. On hosts where a
   verified copy-on-write clone is supported, use it for clean-source,
   profile, catalog, update-source, and scenario copies. Otherwise retain the
   portable recursive-copy path. Never follow or normalize symlinks in ways
   that weaken existing ownership and traversal tests.
10. Move copy-on-write capability detection before the initial clean-source
    snapshot so the largest first copy can benefit. Do not depend on
    macOS-only behavior: the fallback path remains required and tested.
11. Do not replace real bootstrap, install, update, publication, rollback, or
    uninstall operations when those operations are the behavior under test.
    Optimize their fixture inputs and parallel scheduling, not their semantic
    coverage.
12. Do not impose a hard CI timeout from a single host measurement. Record the
    benchmark procedure and result; use the 50-percent target as an acceptance
    gate for this change.

## Verified implementation inventory

Baseline command on 2026-08-16:

```text
/usr/bin/time -p ./tests/test.sh
All 145 Shimmy tests passed.
real 1392.62
user 487.87
sys 789.45
```

Confirmed performance characteristics:

- `tests/test.sh` runs all library, management-command, and tool groups
  sequentially after two session-fixture setup functions.
- Setup produces no PASS output for approximately the first minute.
- The 1,277.32 seconds of combined user and system CPU time is approximately
  92 percent of wall time, consistent with a process- and filesystem-heavy
  serial workload rather than waiting on live services.
- `setup_session_profile_fixtures` recursively copies the whole checkout,
  removes the copied `.git`, initializes and commits a new repository, and
  bootstraps default and upstream profiles.
- `setup_session_update_source_fixture` creates another source repository by
  recursively copying `commands`, `lib`, `plugins`, `tests`, and `tools`, then
  initializes and commits it.
- The checkout is approximately 82,216 KiB and its `.git` directory is
  approximately 21,544 KiB on the measured host; the initial recursive copy is
  therefore materially larger than the source-bearing project directories.
- `setup_scenario_with_profiles` has 52 verified call sites. It supports APFS
  clone copies for profile fixtures, but capability detection currently occurs
  after the initial clean-source copy and other large clean-source/catalog
  copies continue to use ordinary `cp -R`.
- Catalog, lifecycle, onboarding, startup, update, and skills coverage performs
  repeated real install, Git, publication, clone, export, and uninstall work.
  These are the visibly slow regions of the successful baseline and must
  retain semantic coverage.
- Session fixtures are consumed as immutable sources. Mutable profile,
  catalog, checkout, and skill-export operations are performed on scenario
  copies. The lifecycle prepare/complete pair is the one explicit cross-call
  state dependency.
- Relevant guidance and ownership surfaces are `CONTEXT.md`,
  `CONTRIBUTING.md`, `docs/testing.md`, `tests/CONTEXT.md`,
  `tests/lib/CONTEXT.md`, and `tests/commands/CONTEXT.md`.
- The working tree was clean before and after the baseline run.

This inventory is the verified baseline, not permission to ignore dependencies
discovered during implementation.

## Unresolved

None.

## Progress Checklist

- [x] Chunk 1 — Introduce one observable, selectable serial group registry.
- [ ] Chunk 2 — Centralize and accelerate disposable fixture materialization.
- [ ] Chunk 3 — Enable bounded parallel execution and verify the performance target.

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

## Chunk 1 — Observable serial group registry

### Goal

Refactor the existing hard-coded main sequence into one named group registry
with selection and timing, while retaining serial execution and all current
behavior. This creates evidence for balanced parallel shards without changing
the default concurrency yet.

### Files

- `tests/test.sh`
- `tests/runner.sh` (new)
- `tests/lib/runner.sh` (new)
- `tests/CONTEXT.md`
- `tests/lib/CONTEXT.md`
- `docs/testing.md`

### Implementation requirements

1. Define every current `test_*_run` call exactly once in canonical order in
   `tests/runner.sh`, with stable lowercase hyphenated group names.
2. Combine lifecycle prepare and complete in one registered lifecycle group;
   do not allow callers to select either half.
3. Add `--list-groups`, repeatable `--group <name>`, `--serial`, and
   `--jobs <1-3>` parsing without changing installed-profile smoke parsing.
   Chunk 1 executes source-suite groups serially even when the accepted jobs
   value is greater than one; parallel dispatch belongs only to Chunk 3.
4. Reject invalid or conflicting runner options before
   `setup_session_profile_fixtures` and
   `setup_session_update_source_fixture` run.
5. Add `SHIMMY_TEST_TIMING=1` timing records for fixture setup, each selected
   group, and total execution. Timing output must be stable, parseable, and
   absent by default.
6. Preserve the exact assertion count by continuing to increment `TEST_COUNT`
   through the existing `pass` helper.
7. Add focused helper tests for registry ordering, group selection, option
   validation, timing record shape, and lifecycle grouping. They must exercise
   helpers directly and must not recursively run the full suite.
8. Update testing documentation and retained contexts with the new runner
   surface and ownership.

### Verification checklist

- [x] `dash -n` passes for every changed or added shell file.
- [x] `./tests/test.sh --list-groups` completes before fixture creation and
      lists every registered group once in canonical order.
- [x] Invalid `--group`, `--jobs`, duplicate, missing-value, and conflicting
      requests fail before fixture creation and leave no test temporary root.
- [x] A representative `--group` run executes only that group and reports its
      exact test count. `--group runner` reported 5 tests.
- [x] `SHIMMY_TEST_TIMING=1 ./tests/test.sh --serial` passes all tests and emits
      one timing record per group plus setup and total records.
- [x] `./tests/test.sh --serial` passes every prior assertion plus the new
      runner assertions; the timing-enabled serial verification reported 150
      total, comprising the prior 145 and 5 focused runner assertions.
- [x] Default output contains no timing records when timing is disabled.
- [x] `./tests/context-tree.sh` passes.

### Human review gate

Confirm that group boundaries cover the former main sequence exactly once,
that selection cannot silently omit requested coverage, and that serial output
and failure behavior remain understandable before accepting Chunk 1.

## Chunk 2 — Efficient fixture materialization

### Goal

Reduce filesystem work without replacing real lifecycle behavior or weakening
isolation by applying one verified copy strategy to all large disposable test
trees.

### Files

- `tests/support.sh`
- `tests/lib/runner.sh`
- `tests/commands/catalog.sh`
- `tests/commands/images.sh`
- `tests/commands/lifecycle.sh`
- `tests/commands/skills.sh`
- `tests/commands/update.sh`
- any additional test module containing a newly discovered recursive fixture
  copy
- `tests/CONTEXT.md`
- `docs/testing.md`

### Implementation requirements

1. Move copy-on-write detection ahead of clean-source setup and expose one
   internal test helper that copies a source directory to a nonexistent target.
2. Use clone copies only after a disposable probe succeeds on the current
   filesystem. Use portable `cp -R` otherwise; do not assume Darwin implies
   clone support.
3. Route the initial clean-source snapshot, update-source fixture, catalog
   fixture, profile fixture, and all scenario copies of those trees through the
   helper. Retain small intentional copies where using the helper would obscure
   a test's behavior.
4. Validate source and target boundaries before each helper call. Targets must
   be nonexistent descendants of `TMP_ROOT`; reject empty, root, repository,
   source-equal, and source-descendant targets.
5. Preserve file modes, symlinks, Git metadata when the caller needs it, and
   exact profile bytes expected by checksum assertions. Do not traverse
   symlinked directories.
6. Keep clean-source semantics unchanged: it represents the current checkout
   contents, owns a newly initialized Git repository, and includes current
   uncommitted source changes needed by the test run while excluding the
   original repository's `.git` identity.
7. Add direct tests for clone selection, portable fallback, target rejection,
   symlink preservation, executable modes, and independence after mutation of
   a copied file.
8. Use Chunk 1 timing to report setup and group deltas from the recorded serial
   baseline; do not remove assertions solely to obtain a speedup.

### Verification checklist

- [ ] Copy-helper tests pass on the native clone-capable path.
- [ ] Forced portable fallback tests pass without invoking clone-only options.
- [ ] Unsafe or pre-existing targets fail without source or target mutation.
- [ ] Copied fixtures preserve executable modes, symlinks, Git operations, and
      byte-sensitive profile assertions.
- [ ] `SHIMMY_TEST_TIMING=1 ./tests/test.sh --serial` passes the complete suite
      and records the same registered group set as Chunk 1.
- [ ] Serial setup and total timings are compared with Chunk 1 and any
      regression greater than 10 percent is explained and resolved before
      review.
- [ ] `./tests/context-tree.sh` passes.

### Human review gate

Confirm that every optimized copy remains disposable and isolated, that real
bootstrap/update/publication coverage is intact, and that both clone-capable
and portable fallback paths have evidence before accepting Chunk 2.

## Chunk 3 — Bounded parallel execution and acceptance benchmark

### Goal

Run independent groups concurrently against immutable session fixtures, retain
a serial diagnostic path, and demonstrate the required wall-time reduction.

### Files

- `tests/test.sh`
- `tests/runner.sh`
- `tests/lib/runner.sh`
- `tests/CONTEXT.md`
- `tests/lib/CONTEXT.md`
- `docs/testing.md`
- CI workflow files only if discovery shows they invoke the source suite with
  assumptions invalidated by the accepted runner interface

### Implementation requirements

1. Use Chunk 1 timing data to assign groups to three static, named shards with
   approximately balanced measured serial durations. Record the measured group
   totals in comments next to the shard registry so rebalancing has evidence.
2. After parent-only session setup, execute shards in background subshells.
   Each shard inherits read-only session fixture paths and uses only unique
   scenario directories for mutation.
3. Capture each group's output in its own file and each shard's status, elapsed
   time, and test count in separate result files below `TMP_ROOT`. Replay group
   logs in canonical registry order after workers complete so ordinary output
   is deterministic even when static shards contain noncontiguous groups.
4. Wait for all started workers. Success requires every status file, a zero
   status from every worker, the expected group registry coverage, and the
   summed assertion count. Missing or malformed worker results fail closed.
5. On `HUP`, `INT`, or `TERM`, terminate only recorded live worker PIDs, wait
   for them, and then run existing safe cleanup. Never use broad process-name
   matching.
6. Make three workers the default for the source suite. Honor `--jobs 1-3` and
   `--serial`; group-filtered runs may use fewer workers than requested when
   fewer shards contain selected groups.
7. Add failure-injection tests around the orchestration helper to prove worker
   failure propagation, complete log retention, missing-result rejection,
   count mismatch rejection, deterministic replay, and signal cleanup. These
   tests must use harmless fixture worker functions, not recursive full-suite
   execution.
8. Document the default, serial debugging, group selection, timing, and
   benchmark commands. Explain that parallel failure output may contain
   multiple failed shards because all started workers are awaited.
9. Do not introduce external scheduling, timing, or test-framework
   dependencies.

### Verification checklist

- [ ] Runner unit tests prove one-, two-, and three-worker scheduling,
      deterministic logs, count aggregation, and nonzero failure propagation.
- [ ] Failure injection in one worker causes the parent to fail while retaining
      every worker log and cleaning only the session root.
- [ ] `./tests/test.sh --serial` passes the complete suite with the expected
      assertion count.
- [ ] `./tests/test.sh --jobs 2` and default `./tests/test.sh` each pass with the
      same group coverage and assertion count as serial mode.
- [ ] Three clean timed default runs on the same baseline host all pass; their
      median real time is at most 696.31 seconds.
- [ ] Compare median user-plus-system time with the 1,277.32-second baseline.
      Investigate any increase greater than 15 percent to rule out copy storms,
      accidental repeated setup, or oversubscription.
- [ ] No default run contacts a registry or starts a live tool container.
- [ ] `./tests/context-tree.sh` passes.
- [ ] Documentation accurately describes normal, serial, selected-group, and
      timed workflows.

### Human review gate

Review the serial/parallel equivalence evidence, failure-injection results,
three-run timing table, CPU-cost comparison, deterministic logs, and remaining
platform variance. Accept the chunk only if the 50-percent wall-time target is
met without an unexplained coverage or isolation change.

## Risk register

- **Hidden mutable global state across groups:** Parallel workers could expose
  dependencies masked by serial execution. Mitigation: workers are subshells,
  session fixtures are read-only, lifecycle prepare/complete stays atomic, and
  serial/parallel group and assertion counts must match.
- **Filesystem saturation:** Too many workers could increase system time and
  erase wall-time gains. Mitigation: cap at three, balance from measured group
  durations, and gate on both real time and total CPU regression.
- **Copy-on-write portability:** `cp -cR` is not portable and clone support can
  vary by filesystem. Mitigation: capability probe before use, one centralized
  helper, and a verified `cp -R` fallback.
- **Fail-fast behavior changes:** POSIX `wait` lacks a portable `wait -n`, so a
  parallel failure may be reported after other started shards finish.
  Mitigation: document this tradeoff, retain serial mode for immediate
  diagnosis, preserve all logs, and always return nonzero.
- **Output interleaving or lost diagnostics:** Concurrent stdout would make
  failures difficult to read. Mitigation: per-worker logs replayed in stable
  order and fail-closed result files.
- **Benchmark noise:** VM, filesystem cache, and host load affect wall time.
  Mitigation: three clean post-change runs on the same host, median acceptance,
  per-group timing records, and no hard cross-host CI timeout.
- **Coverage erosion through fixture substitution:** Replacing real lifecycle
  actions with fixture copies could make tests faster but less meaningful.
  Mitigation: explicitly preserve real operations when they are the behavior
  under test and review each changed copy call against its scenario purpose.

## Lessons learned

### Initial

- The complete suite is functionally healthy but takes 23m 12.62s for 145
  passing tests on the measured host.
- High system time and observed pauses around install, catalog, lifecycle,
  update, onboarding, startup, and skills scenarios make filesystem/process
  work the primary optimization target.
- Existing session-level profile reuse and APFS profile cloning are useful
  foundations, but the largest initial source copy happens before clone
  capability detection and several later large copies bypass it.
- Parallelism is viable only at explicit group boundaries with immutable
  session fixtures; arbitrary scenario-level backgrounding would obscure
  shared shell state and failure reporting.

### Chunk 1

- The canonical registry contains 41 named groups. Listing and invalid option
  requests complete before the session temporary root and fixtures are
  created; selected groups still pay the shared setup cost by design.
- The lifecycle prepare/complete wrapper passes when the two calls are made
  adjacent and indivisible. Management and onboarding retain their own group
  boundaries and every former main-sequence entrypoint remains registered
  exactly once.
- The timed serial suite passed all 150 tests in 1,385 integer seconds,
  including 40 seconds of session setup. The five-test increase is entirely
  the focused runner coverage for ordering, selection, validation, timing, and
  lifecycle grouping.
- The largest measured groups were onboarding (232 seconds), lifecycle (227),
  catalog (206), skills (197), and startup (135). These measurements provide
  the initial shard-balancing evidence for Chunk 3.
- Timing-enabled helper tests must explicitly disable timing around synthetic
  group output when asserting the exact output body; otherwise correct timing
  records contaminate the fixture expectation.

## Session bootstrap

Start by reading `AGENTS.md`, root `CONTEXT.md`, `CONTRIBUTING.md`, this plan,
`docs/testing.md`, `tests/CONTEXT.md`, `tests/lib/CONTEXT.md`,
`tests/commands/CONTEXT.md`, `tests/test.sh`, and `tests/support.sh`. For each
chunk, also read every target test module before editing it. Preserve POSIX
shell, the 145-test baseline behavior, offline default-suite boundaries, and
real lifecycle coverage. The active chunk is Chunk 1. Implement only that
chunk, update this plan's checklist and lessons with verification evidence,
and stop at its human review gate.
