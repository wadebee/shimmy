# Recover Stopped Active Profile Plan
Completed: 2026-08-22

## Objective

Make the installed command `shimmy profile activate <name>` recover the
recorded active profile when its own managed engine is not currently active,
including the observed macOS state where `shimmy-default` exists but is
stopped. Recovery must continue through Shimmy's existing engine, registry,
active-record, AI-skill-link, and rollback control plane; it must not require
or recommend a direct `podman machine start` workaround.

Success means:

- `shimmy profile activate default --dry-run` succeeds when `default` is both
  the recorded active profile and the requested profile while
  `shimmy-default` is stopped, and reports the planned start and registry
  projection without mutation;
- the corresponding non-dry-run activation starts the deterministic machine,
  projects and validates registry policy, selects the expected connection when
  needed, and leaves the active profile record and exact AI-skill ownership
  coherent;
- same-profile recovery also honors existing actionable states already emitted
  by status and recommendation code, including Darwin
  `registry_restart_required` with explicit `--restart` and Linux registry
  state that is ready but not current;
- switching to a different profile still requires the recorded prior profile
  engine and registry state to be fully active before mutation, preserving the
  validated rollback source;
- invalid metadata, missing machines, connection or registry overrides,
  unreachable engines, workload guards, lock checks, and rollback failures
  retain their existing fail-closed behavior; and
- focused and full repository tests pass, or any unrelated pre-existing failure
  is recorded as partial verification with evidence before review.

Explicit exclusions:

- Do not provision, adopt, rename, migrate, delete, or directly start a Podman
  machine outside the existing profile activation implementation.
- Do not add a recovery flag, change public command syntax, change profile or
  catalog schemas, or create a compatibility path.
- Do not permit a cross-profile transition to proceed from an unhealthy prior
  active profile.
- Do not weaken target-specific engine, registry, workload, environment
  override, ownership, locking, transaction, or rollback validation.
- Do not mutate the currently installed profile or run the live recovery
  workflow as part of repository implementation. Installed-profile refresh and
  live activation require separate authorization after the code review gate.
- Do not edit generated `.agents/skills/` copies.
- Do not modify or discard the unrelated existing README, npx skill/guide, or
  npx plan changes in the dirty worktree.

## Target layout and terminology

- **Recorded active profile** is the profile named by
  `active-profile.conf`. It owns installation-wide engine, registry,
  active-record, and exact AI-skill-link authority.
- **Requested profile** is the validated name passed to
  `profile activate <name>`.
- **Same-profile recovery** means the recorded active profile and requested
  profile have the same name. The requested profile's activation layer is
  responsible for validating and repairing its current state.
- **Validated rollback source** is the recorded active profile after management
  confirms its engine and registry activation state before planning and again
  after locks are acquired.
- **Cross-profile transition** means those names differ. The recorded active
  profile must remain a validated rollback source before the requested
  profile may mutate global engine or registry authority.
- **Prior-engine prerequisite** is the management-layer check currently
  performed before planning and again after activation locks are acquired.
  The target state checks in `lib/profile/activation.sh` are separate and
  remain mandatory.

The target decision table is:

| Recorded active | Requested | Observed state | Required behavior |
|---|---|---|---|
| `default` | `default` | Darwin `stopped` | Ordinary dry-run/activation may plan and start `shimmy-default` through the existing target activation path. |
| `default` | `default` | Darwin `registry_restart_required` | Ordinary activation retains the exact restart diagnostic; explicit `--restart` may perform the guarded restart. |
| `default` | `default` | Linux `ready` with absent/sibling managed link | Existing Linux activation may reconcile the exact managed registry link. |
| `default` | `default` | invalid, overridden, missing, unsupported, or unsafe | Existing target-specific validation rejects the operation without mutation. |
| `default` | another profile | prior state other than `active` | Management rejects the switch before target mutation because no validated rollback source exists. |

No new files or installed-state formats are introduced. Primary repository
changes remain within the existing profile management, tests, documentation,
and this retained plan.

## Recorded design decisions

1. Fix orchestration at the management boundary rather than teaching status to
   misreport a stopped engine as active or adding a state-specific bypass in
   the Podman layer. The target activation implementation already knows how to
   start a stopped deterministic machine safely.
2. Add a transition-aware management helper in
   `lib/profile/management.sh` that accepts the installation config, recorded
   active profile name, and requested profile name. It returns success without
   imposing the prior-engine prerequisite only when the two validated names
   are equal; otherwise it delegates to the existing
   `shimmy_profile_active_engine_validate` check.
3. Use that helper at both existing validation points: initial read-only
   preflight and post-lock state revalidation. Do not remove the second check;
   it protects against authority or engine changes between planning and
   mutation.
4. Do not special-case only the string `stopped`. Same-profile activation must
   reach the existing target-specific state machine for every state. That
   makes the already-published ordinary and `--restart` recommendations
   executable while retaining the target layer's durable rejection boundaries.
5. Leave `shimmy_profile_active_engine_validate` unchanged for profile create,
   profile sync, and other callers. Those workflows are outside this recovery
   transition and continue to require their current active-engine invariant.
6. Preserve validation order around the relaxed prerequisite: installation and
   active-record context resolve first; candidate materialization and AI-skill
   plans validate before engine mutation; non-dry-run state is re-read under
   activation/profile/registry locks; engine authority commits before the
   active record and links; compensation restores the previous state on later
   failure.
7. Treat the stopped Darwin scenario as positive behavior coverage, not as a
   permanent rejection test. Reuse existing authoritative invalid-metadata,
   override, workload, lock, and rollback tests rather than duplicating
   negative coverage.
8. Document the supported stopped-state recovery in `docs/podman.md` and the
   same-profile versus cross-profile prerequisite in
   `lib/profile/CONTEXT.md`. The existing README command examples and canonical
   `plugins/shimmy/skills/shimmy-init/SKILL.md` already state the intended
   workflow and require no semantic edit.
9. Keep the implementation in POSIX shell and preserve executable modes. Do
   not introduce another language or a direct Podman lifecycle entrypoint.

## Verified implementation inventory

This inventory is a verified baseline, not permission to ignore newly
discovered dependencies during implementation.

- `lib/profile/management.sh`
  - `shimmy_profile_active_engine_validate` resolves the recorded active
    profile and currently accepts only `SHIMMY_PROFILE_ACTIVATION_STATE=active`.
  - `shimmy_profile_activate_run` calls that validator before candidate and
    AI-skill planning and repeats it after acquiring activation, profile, and
    registry locks. Both calls currently fail before same-profile recovery can
    reach the target activation layer.
  - The same validator is also consumed by profile creation and profile sync;
    those callers must remain unchanged.
- `lib/profile/activation.sh`
  - Darwin state classifies an existing non-running deterministic machine as
    `stopped` and recommends ordinary `profile activate`.
  - Darwin activation already plans `would_start`, starts the stopped target,
    projects registry policy, validates the rootless remote engine, records
    projection ownership, and commits the default connection last.
  - A running stale projection is classified as
    `registry_restart_required` and recommends `profile activate --restart`.
  - Linux activation already repairs an absent or sibling Shimmy-owned active
    registry link after validating the local rootless engine.
  - The activation rollback journal can stop a target whose start was attempted,
    restore the previous default connection, restore a prior running machine
    when applicable, and report incomplete restoration explicitly.
- `tests/commands/profile.sh`
  - Exercises the public installed-profile command surface with fake Darwin
    and Linux engines, active records, registry projections, bundle
    reconciliation, lock ordering, and rollback.
  - Existing cross-profile and same-profile restart tests begin from a healthy
    recorded active engine, so they do not expose the management preflight
    deadlock.
- `tests/lib/profile-activation.sh`
  - Already proves stopped-state classification and recommendation, target
    start/projection ordering, workload guards, invalid-state rejection, and
    engine rollback below the management layer. It should remain regression
    coverage rather than receive duplicate management behavior assertions.
- `docs/podman.md` documents profile inspection, named activation, stale
  projection restart, and the prohibition against arbitrary machine handling,
  but does not yet explicitly connect a stopped selected profile to ordinary
  same-profile activation.
- `plugins/shimmy/skills/shimmy-init/SKILL.md` requires status, successful
  activation dry-run, exact named activation, workload acknowledgement, and
  final verification without direct machine lifecycle commands. The fix makes
  this existing consumer executable for the stopped state.
- `plans/complete/install-activation-engine-status.md` records the completed
  design in which `stopped` recommends ordinary activation and
  `registry_restart_required` recommends explicit restart. This new plan fixes
  the implementation gap without reopening that completed design.
- The planning baseline found unrelated modifications in `README.md`,
  `plans/wip/npx-shimmy-tool.md`, `tools/npx/SKILL.md`, and
  `tools/npx/guide.md`. They are outside this plan and must be preserved.
- A planning-time run of
  `./tests/test.sh --group lib-profile-activation --group commands-profile`
  produced no buffered output for more than four minutes and was interrupted,
  returning the runner's `FAIL: test suite interrupted by INT` diagnostic.
  This is not evidence of a source assertion failure; implementation
  verification must rerun the focused groups to completion and record the
  result.

## Unresolved

None.

## Progress Checklist

- [x] Chunk 1 — Make same-profile activation recover target-owned inactive
      state, add regression coverage and documentation, and complete
      verification. Implementation and human verification are complete; the
      installed profile and live Podman machine remain unchanged.

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

## Chunk 1 — Restore same-profile recovery

### Goal

Remove the management-layer deadlock for the recorded active profile while
preserving cross-profile source validation, target-specific safety checks, and
transactional rollback. Leave the repository coherent and fully verified at
the single human review gate.

### Files

Primary change surface:

- `lib/profile/management.sh`
- `lib/profile/CONTEXT.md`
- `tests/commands/profile.sh`
- `docs/podman.md`
- `plans/complete/recover-stopped-active-profile.md` for progress, verification
  notes, and lessons learned

Inspect but do not edit unless a newly discovered required dependency is
reported for review:

- `lib/profile/activation.sh`
- `tests/lib/profile-activation.sh`
- `plugins/shimmy/skills/shimmy-init/SKILL.md`
- `README.md`

### Implementation requirements

1. Add the transition-aware prior-engine validation helper described in the
   recorded decisions and use it for both preflight and locked revalidation in
   `shimmy_profile_activate_run`.
2. Compare only already validated canonical profile names. Do not infer
   same-profile identity from paths, launchers, Podman defaults, or environment
   variables.
3. For same-profile activation, continue through candidate materialization,
   supported AI-skill bundle planning, target engine context resolution, and
   the existing OS-specific activation implementation. Do not duplicate target
   state classification in management code.
4. For cross-profile activation, preserve the exact existing requirement that
   the recorded active profile resolve to activation state `active` before
   target mutation, both before dry-run planning and after locks are acquired.
5. Preserve dry-run side-effect freedom. A stopped same-profile Darwin dry-run
   must report the existing `would_start`, projection/record, and active-profile
   plan fields without starting or stopping a machine, changing the default
   connection, changing registry ownership, replacing the active record, or
   reconciling links.
6. Preserve Darwin start, projection, validation, record, and default-connection
   ordering. A post-start validation failure must invoke existing target
   cleanup and leave the recorded active profile unchanged.
7. Preserve explicit `--restart` and `--stop-running` semantics. A stale running
   same-profile projection must still require `--restart`; any containers that
   would be interrupted must still require separate `--stop-running`
   acknowledgement.
8. Add public command tests that positively prove:
   - stopped recorded-active Darwin dry-run reaches the target plan and makes
     no Podman mutation;
   - stopped recorded-active Darwin activation starts the deterministic target
     through Shimmy and retains coherent active authority;
   - injected validation failure after that start cleans the attempted target
     up and preserves the active record;
   - stale recorded-active Darwin recovery reaches the existing explicit
     restart path; and
   - recorded-active Linux recovery can restore its exact managed registry
     link when the engine is ready but the link is not current.
9. Retain existing cross-profile, invalid metadata, override, workload, lock,
   AI-skill collision, and rollback assertions as the authoritative safety
   coverage. Add no redundant absence or generic rejection test.
10. Update `lib/profile/CONTEXT.md` with the distinction between same-profile
    target repair and the cross-profile validated rollback-source requirement.
    Update `docs/podman.md` so stopped-profile troubleshooting directs users
    through the exact status/dry-run/activation control plane and never through
    direct machine start.
11. Preserve all unrelated dirty-worktree changes and avoid formatting or
    mechanical rewrites outside the primary change surface.

### Verification checklist

- [x] Recheck `git status --short` before edits and confirm the unrelated
      README/npx files remain outside the chunk diff.
- [x] Run `sh -n lib/profile/management.sh tests/commands/profile.sh` and
      confirm both modified POSIX shell files parse successfully.
- [x] Run
      `./tests/test.sh --group lib-profile-activation --group commands-profile --group commands-lifecycle`
      with the runner's default bounded parallelism and confirm all selected
      groups pass. Do not use `--serial` unless diagnosing a failure.
- [x] Inspect the new command-test Podman log assertions and prove dry-run has
      no start/stop/default-selection/projection mutation, successful stopped
      recovery uses the existing start/projection/validation ordering, and an
      injected post-start failure performs target cleanup.
- [~] Run the complete default `./tests/test.sh` suite because
      `lib/profile/management.sh` is a shared lifecycle module. Rerun only an
      actual failing group serially for diagnosis. Record unrelated baseline
      failures as `[~]` with evidence, impact, and proposed disposition rather
      than altering unrelated code.
- [x] Run `git diff --check` and inspect the complete scoped diff, executable
      modes, documentation semantics, and absence of generated `.agents/skills/`
      changes.
- [x] Compare `plugins/shimmy/skills/shimmy-init/SKILL.md` with the implemented
      behavior and confirm its status/dry-run/exact-activation workflow is now
      executable for `stopped` without needing a canonical skill edit.
- [x] Update this plan's progress checklist, verification notes, and Chunk 1
      lessons before presenting the human review gate.

### Verification notes — 2026-08-22

- Pre-edit status contained only the unrelated modified `README.md`,
  `plans/wip/npx-shimmy-tool.md`, `tools/npx/SKILL.md`, and
  `tools/npx/guide.md`, plus this untracked retained plan. Those unrelated
  files remain untouched by this chunk.
- The stopped-recovery command test exposed a required dependency in
  `lib/profile/activation.sh`: its Darwin rollback call sites relied on
  `set -e`, but public management calls activation from a conditional context.
  Explicit failure returns were added after the existing rollback actions so a
  post-start validation failure cannot continue to apparent success.
- `sh -n lib/profile/management.sh lib/profile/activation.sh
  tests/commands/profile.sh` passed.
- The required focused run passed all 16 selected tests with the default
  bounded parallel schedule.
- Command-level fake-Podman assertions prove that stopped same-profile dry-run
  performs no start, stop, default-selection, projection apply, active-record,
  projection-record, or AI-skill-link mutation; successful recovery orders
  start before projection validation, engine validation, and default selection;
  and injected post-start validation failure stops the attempted target and
  preserves active authority.
- The complete default suite passed the changed activation, profile, lifecycle,
  and all other replayed groups except `lib-catalog`. That group failed on its
  existing human-table assertion: actual output begins with padded columns
  `TOOL         DEFAULT      VERSIONS`, while the assertion requires the
  contiguous substring `TOOL DEFAULT VERSIONS`. An isolated diagnostic rerun
  with `./tests/test.sh --serial --group lib-catalog` reproduced the same
  failure. The affected catalog test and implementation are outside this
  chunk; disposition is to leave the unrelated dirty catalog/npx work intact
  and correct its assertion or formatting in that workstream.
- `git diff --check` passed, executable modes are unchanged, and no generated
  `.agents/skills/` path was added or modified.
- The canonical `shimmy-init` workflow already requires status, exact named
  dry-run, and exact named activation without direct Podman lifecycle calls.
  It now reaches the implemented stopped-state recovery and needs no edit.

### Human review gate

**Result:** Passed 2026-08-22 19:22:58 EDT.

Stop after the implementation diff and verification results are recorded. The
reviewer must confirm that same-profile recovery—not cross-profile switching—
is the only relaxed management prerequisite; that all target validation,
workload, transaction, and rollback boundaries remain intact; that tests prove
the observed stopped-machine failure and adjacent documented recovery states;
and that unrelated dirty-worktree changes were preserved. Acceptance of this
chunk completes the repository change but does not authorize updating the
installed profile or activating its live Podman machine.

## Risk register

- **Over-broad bypass:** Skipping prior-engine validation for different
  profiles would remove the validated rollback source. Mitigation: centralize
  an exact canonical-name equality check and retain both cross-profile
  validations.
- **Duplicated state policy:** Special-casing `stopped` in management would
  diverge from Darwin/Linux target validation and leave stale restart or Linux
  registry recommendations broken. Mitigation: bypass only the same-profile
  prior prerequisite and let the existing target state machine decide.
- **Rollback from an initially stopped target:** A later validation or
  integration failure must not leave a partially projected, newly started
  engine selected. Mitigation: preserve existing target-start attempt and
  projection journals and add a command-level injected-failure assertion.
- **Dry-run mutation:** Reaching target activation from a previously rejected
  state increases the importance of dry-run lock checks and no-mutation
  behavior. Mitigation: assert planned output and an empty mutation log.
- **Documentation/control-plane drift:** Troubleshooting guidance already
  promises exact activation and forbids direct machine lifecycle work.
  Mitigation: add the stopped case to Podman documentation and verify the
  canonical init skill against the implementation.
- **Dirty worktree overlap:** `README.md` and npx artifacts contain unrelated
  user changes. Mitigation: keep them out of the implementation change surface
  and inspect the final diff explicitly.
- **Slow or interrupted baseline:** The focused planning diagnostic was
  interrupted before buffered results appeared. Mitigation: require completed
  focused and full runs during implementation and treat only concrete
  assertion output as a failure diagnosis.

## Lessons learned

### Initial

- Live status established that the active profile, expected/default
  connection, machine metadata, and registry/catalog state were valid while
  only `shimmy-default` was stopped; no alternate machine or environment
  override caused the failure.
- The direct target activation layer already supports starting a stopped
  deterministic machine. The failure occurs earlier in
  `shimmy_profile_activate_run`, where the recorded active engine must be
  `active` even when it is also the requested repair target.
- Status and canonical troubleshooting guidance already recommend ordinary
  activation for `stopped` and explicit `--restart` for stale projection.
  Correcting orchestration restores an existing contract rather than adding a
  new public feature.
- Cross-profile rollback and same-profile repair have different prerequisites:
  the former needs a healthy prior source, while the latter needs the target's
  complete validation and rollback state machine.
- Existing lower-level tests prove engine-state classification and transition
  mechanics, but public command coverage did not combine a stopped engine with
  a same-name recorded active/requested profile, allowing the orchestration
  deadlock to escape.

### Chunk 1

- Comparing validated recorded and requested profile names at both management
  validation points is sufficient to relax only same-profile repair while
  retaining the existing active-engine prerequisite for cross-profile
  transitions.
- A sourced POSIX function called from an `||` condition cannot rely on
  `set -e` to stop after a rollback helper returns nonzero. Darwin activation
  now returns explicitly after each rollback boundary, including post-start
  engine validation.
- Public command coverage is necessary for this boundary: lower-level
  activation tests exercised rollback outside the management caller's
  conditional context and therefore could not expose the failure-propagation
  gap.
- The documented `shimmy-init` status, dry-run, and exact activation sequence
  is sufficient for stopped recovery once management allows the target state
  machine to run; no direct Podman start or new public flag is needed.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`,
   `lib/CONTEXT.md`, `lib/profile/CONTEXT.md`, `tests/CONTEXT.md`,
   `tests/lib/CONTEXT.md`, `tests/commands/CONTEXT.md`, and this complete plan.
2. Inspect `lib/profile/management.sh`, the target activation paths in
   `lib/profile/activation.sh`, `tests/commands/profile.sh`, the relevant
   existing coverage in `tests/lib/profile-activation.sh`, and
   `docs/podman.md` before editing.
3. Recheck the dirty worktree and preserve the unrelated README/npx changes.
4. Treat Chunk 1 as active only after explicit user approval. Implement only
   its same-profile recovery scope; do not modify installed Shimmy state or
   start a live Podman machine.
5. Run and record every Chunk 1 verification item, update the progress and
   lessons sections, and stop at its human review gate.
