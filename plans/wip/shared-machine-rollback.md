# Shared machine bootstrap rollback

## Objective

Close the macOS shared-machine creation rollback gap so fresh bootstrap and
explicit engine migration activate compensation as soon as durable creation
intent exists, remove a failed just-created machine only when exact created
identity evidence has been committed, and retain the configuration root plus
lifecycle evidence whenever cleanup is ambiguous or incomplete.

Success requires all of the following:

- a failure after the shared `lifecycle.conf` is created always enters shared
  engine compensation;
- the machine-init external mutation is preceded by a durable lifecycle phase;
- failure after exact created identity is committed removes the exact created
  machine and permits ordinary failed-bootstrap cleanup to remove the new
  installation root;
- failure before exact created identity is committed, or failure while removing
  the exact machine, preserves the lifecycle journal and bootstrap root and
  emits a non-secret incomplete-rollback diagnostic;
- shared bootstrap, migration, and isolated-machine creation continue to use
  the same ownership-safe lifecycle primitive and successful flows remain
  unchanged;
- focused and full automated acceptance pass using fake Podman lifecycle state.

This plan does not authorize or include deletion, adoption, repair, or mutation
of any existing real Podman machine or the user's current Shimmy installation.
It does not add a public recovery command, automatically claim an ambiguous
same-name machine, or change the POSIX-shell architecture.

## Target layout and terminology

Machine creation uses this durable state sequence:

```text
planned -> initializing -> initialized -> recorded -> starting -> started
        -> guest-marking -> guest-marked -> committed
```

- **planned** means exact machine and connection absence was validated and the
  creation journal exists, but machine initialization has not begun.
- **initializing** is written atomically before `podman machine init`. The
  command may not have run, may have failed without mutation, or may have
  created a machine whose exact identity has not yet been committed. The phase
  therefore carries no ownership token or created-identity fingerprint.
- **initialized** means the post-init machine identity and generated ownership
  token have been committed atomically to the lifecycle journal. This is the
  earliest phase at which rollback may remove a present machine after matching
  the recorded created identity.
- **complete compensation** removes every recoverable external change and then
  permits deletion of the fresh bootstrap configuration root.
- **incomplete compensation** preserves the bootstrap configuration root and
  lifecycle journal because deletion authority is ambiguous or an exact
  rollback action failed.

The lifecycle record retains `shimmy_engine_lifecycle_version=1` and its current
nine-line field layout. The change extends the accepted create-phase enum with
`initializing`; it does not add or reorder fields. New readers continue to
accept existing version-1 `planned` journals. Older readers encountering the
new phase fail closed rather than performing a destructive action.

## Recorded design decisions

1. Set `SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=1` immediately after
   `shimmy_engine_machine_create_prepare` successfully writes the shared
   lifecycle journal. Do not wait for initialization, projection, start, guest
   marking, or projection commit. Continue to clear the flag only after a
   complete create commit or complete shared rollback.
2. Use `SHIMMY_ENGINE_REGISTRY_SHARED_CONFIG` as the shared rollback root. It is
   established by shared-create preparation and is more specific than relying
   on ambient `SHIMMY_CONFIG_ROOT` state.
3. Add `create|planned|initializing` and
   `create|initializing|initialized` transitions. Write `initializing` before
   invoking `shimmy_engine_podman_machine_init`, reread the journal after the
   transition, then commit `initialized` only after exact identity rendering
   and ownership-token generation both succeed.
4. A `planned` or `initializing` rollback clears the journal only when exact
   machine and connection absence is validated. If either is present or state
   cannot be validated, return incomplete without deleting anything. Names,
   connection routing, prior absence, and the init command's apparent outcome
   are not sufficient ownership evidence.
5. Existing `initialized` and later rollback remains identity-gated: match the
   current machine fingerprint and, when present, the engine record before stop
   or removal. Guest-marker cleanup remains best effort because the marker is
   not established until after the machine starts.
6. Add a bootstrap-root preservation flag distinct from
   `SHIMMY_PROFILE_LIFECYCLE_PRESERVE_NEW_ROOT`. Reset it at the start of each
   bootstrap run, set it monotonically when shared rollback returns incomplete,
   and never clear it during later cleanup/trap passes. The final bootstrap-root
   removal branch must honor it. This keeps signal/EXIT double cleanup
   idempotent and conservative.
7. Cleanup must continue attempting profile-stage cleanup, startup restoration,
   and lock release. When bootstrap-root preservation is active, it must not
   recursively delete the retained installation root. It must emit one concise
   stderr diagnostic identifying the retained config root and
   `engines/shared/lifecycle.conf`, state that rollback is incomplete, and avoid
   printing ownership tokens, connection URIs, or other secret-bearing state.
   Cleanup must not replace the original command or signal exit status.
8. Migration already treats either the shared-create active flag or a retained
   shared lifecycle journal as rollback authority. Preserve that behavior and
   its existing migration journal retention. Isolated creation already sets its
   outer active flag immediately after journal creation; it adopts the new
   `initializing` lifecycle semantics through the shared primitive without a
   separate state machine.
9. Do not add a public recovery/adoption/removal interface in this change. An
   ambiguous `initializing` machine remains preserved for explicit follow-up;
   the fix prevents silent destruction of the evidence needed to diagnose that
   state.
10. Treat the failure assertions as explicit durable transaction and ownership
    invariants. Add them to the existing engine and lifecycle scenarios rather
    than creating redundant rejection-only fixtures.

## Verified implementation inventory

This inventory is the verified baseline, not permission to ignore additional
dependencies discovered during implementation.

- `lib/engine/registry.sh` initializes the shared machine at line 170 but does
  not set `SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE` until line 183. Its
  isolated-create path sets the equivalent active flag immediately after
  lifecycle preparation.
- `lib/engine/lifecycle.sh` writes `planned`, calls Podman machine init, renders
  identity, generates a token, and only then writes `initialized`. Its current
  `planned` rollback validates absence and refuses to remove a present machine.
- `lib/engine/state.sh` owns the strict lifecycle phase enum, field validation,
  rendering, and round-trip reader. It currently allows empty ownership fields
  only for `create|planned`.
- `lib/install/lifecycle.sh` invokes shared rollback only when the late active
  flag is set, suppresses its result, and later unconditionally removes
  `SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT`. Isolated rollback failure already
  has a narrower preservation pattern for the new profile root.
- `commands/bootstrap.sh` installs EXIT, HUP, INT, and TERM cleanup traps. A
  signal path can invoke cleanup before EXIT invokes it again, so preservation
  state must be monotonic and cleanup must remain idempotent.
- `lib/engine/registry.sh` migration rollback already checks the active flag or
  the existence of `engines/shared/lifecycle.conf`, and existing lifecycle
  acceptance proves retained migration state when machine removal fails.
- `tests/lib/engine.sh` owns the focused fake Podman machine lifecycle seam and
  lifecycle journal transition assertions. Its current fake can fail before
  `machine init` or during later actions but cannot yet fail after changing the
  machine to stopped during init.
- `tests/lib/profile-activation.sh` supplies the fake Podman executable reused
  by `tests/commands/lifecycle.sh`; it supports machine-start and machine-remove
  failure injection and needs one after-create init failure boundary.
- `tests/commands/lifecycle.sh` already owns successful Darwin bootstrap,
  collision safety, migration rollback/retry, isolated creation compensation,
  and failed-bootstrap cleanup. It does not exercise a shared bootstrap failure
  between lifecycle preparation and the late active flag.
- Transaction and ownership guidance is retained in `CONTEXT.md`,
  `lib/engine/CONTEXT.md`, `lib/install/CONTEXT.md`, test context files,
  `BOOTSTRAP.md`, `README.md`, `docs/podman.md`,
  `docs/prompt-shimmy-project.md`, and the canonical
  `plugins/shimmy/skills/shimmy-install/SKILL.md`.
- The retained `plans/wip/hybrid-podman-engine-lifecycle.md` records the
  existing requirements that lifecycle transitions precede external mutation
  and incomplete creation compensation retains minimal retry evidence. It is
  historical implementation evidence, not the authoritative plan for this
  focused fix, and must not be rewritten by this work.

## Unresolved

None.

## Progress Checklist

- Active chunk: None — Chunk 1 is implemented and awaiting human review.

- [x] Chunk 1 — Make shared machine creation rollback journal-first,
  ownership-safe, and recovery-state preserving; update tests and guidance.

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

## Chunk 1 — Close the shared machine rollback gap

### Goal

Implement the complete journal, rollback-activation, bootstrap preservation,
test, and documentation change as one coherent transaction-boundary update.
Do not leave a review state in which a new lifecycle phase is written without
all readers, rollback paths, cleanup behavior, and fixtures understanding it.

### Files

Primary implementation and tests:

- `lib/engine/state.sh`
- `lib/engine/lifecycle.sh`
- `lib/engine/registry.sh`
- `lib/install/lifecycle.sh`
- `tests/lib/engine.sh`
- `tests/lib/profile-activation.sh`
- `tests/commands/lifecycle.sh`

Required semantic guidance updates:

- `CONTEXT.md`
- `lib/engine/CONTEXT.md`
- `lib/install/CONTEXT.md`
- `tests/lib/CONTEXT.md`
- `tests/commands/CONTEXT.md`
- `README.md`
- `BOOTSTRAP.md`
- `docs/podman.md`
- `docs/prompt-shimmy-project.md`
- `plugins/shimmy/skills/shimmy-install/SKILL.md`

Do not edit generated `.agents/skills` copies or the broader retained hybrid
engine plan.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. Machine deletion authority and durable
rollback evidence are destructive-operation and data-integrity boundaries.

1. Extend the version-1 lifecycle phase validator and renderer so `initializing`
   is valid only for create operations and, like `planned`, requires empty token
   and identity fields. Add only the two new ordered transitions specified in
   the recorded decisions; retain all current transition validation.
2. Change machine initialization to atomically transition and reread
   `initializing` before invoking Podman. Leave the journal in `initializing` on
   init, inspection, token-generation, or initialized-journal-write failure.
   Do not infer ownership or synthesize an initialized record during cleanup.
3. Extend create rollback so both pre-identity phases use absence-only cleanup.
   A present or unreadable state must return nonzero with the journal intact.
   Keep exact-identity rollback behavior for `initialized` and later phases.
4. Activate shared creation compensation immediately after lifecycle prepare.
   Verify every later return path leaves the flag active until commit or
   complete rollback. Retain migration and isolated-create behavior.
5. Add and reset a bootstrap-root preservation flag, use the specific shared
   registry config root for rollback, and branch on the rollback result. On
   incomplete rollback, preserve the root and emit the required single
   diagnostic. Keep preservation monotonic across repeated trap cleanup and
   ensure cleanup remains safe when sourced by a caller using `set -e`.
6. Extend fake Podman with narrowly named injections for failure after machine
   init has created a stopped machine and for the already supported start/rm
   boundaries. Do not add production-only test hooks when the fake seam can
   expose the boundary.
7. Extend existing tests at the lowest-cost authoritative layer:
   - focused engine tests prove the `planned -> initializing -> initialized`
     round trip, absence-only initializing cleanup, retention of a present
     initializing machine, and exact initialized rollback;
   - the existing Darwin bootstrap scenario injects machine-start failure and
     proves complete rollback removes the fake machine and fresh config root;
   - a machine-init-after-create failure proves the stopped machine and
     initializing journal/config root are retained with the incomplete
     diagnostic;
   - a machine-remove rollback failure proves the initialized journal, engine
     evidence, and config root are retained with the incomplete diagnostic;
   - successful Darwin bootstrap, collision refusal, migration retry, and
     isolated creation remain green.
8. Update guidance to distinguish the normal fully compensated bootstrap
   failure from the safety case in which Shimmy retains an incomplete config
   root. State that a retained root is deliberate recovery evidence, prevents
   a fresh bootstrap retry, and is not permission to delete or adopt a machine
   by name. Do not document an unsupported manual deletion procedure.
9. Preserve POSIX shell syntax, existing executable modes, current public
   command grammar, lifecycle record field order, lock order, and secret
   redaction.

### Verification checklist

- [x] Review the diff to confirm the shared active flag is set immediately
  after journal creation and cannot be cleared by a failed prepare path.
- [x] Run `./tests/test.sh --jobs 3 --group lib-engine --group commands-lifecycle`;
  both groups pass with the new complete-rollback and retained-state cases.
- [x] Run any failing group alone with `--serial` only for diagnosis, record the
  failure and rerun result in this plan, and do not replace the parallel
  acceptance outcome with a broad serial run.
- [x] Run the complete default `./tests/test.sh`; all registered groups pass.
- [x] Run `/bin/sh -n` on every changed `.sh` file and every generated installed
  shell artifact exercised by the lifecycle tests.
- [x] Run `./tests/context-tree.sh`; context links and retained guidance pass.
- [x] Inspect `git diff --summary` to confirm executable modes are unchanged and
  `git diff --check` reports no whitespace errors.
- [x] Inspect the final fake-Podman logs and retained fixtures to confirm no
  test invokes a real Podman machine mutation and diagnostics expose no
  ownership token or connection URI.
- [x] Compare documentation and canonical skill guidance semantically: normal
  rollback removes a fresh failed installation, incomplete rollback retains
  evidence, and neither path adopts or deletes an ambiguous machine.

### Human review gate

Stop after implementation and verification. The reviewer must confirm the new
phase semantics, exact point where shared rollback becomes active, identity
boundary for deletion, monotonic bootstrap-root preservation, user-facing
diagnostic, test evidence for complete and incomplete compensation, and the
absence of any real Podman-machine mutation. Implementation completion does not
authorize moving this plan to `complete`; final human acceptance is required.

## Risk register

| Risk | Impact | Required mitigation |
| --- | --- | --- |
| Treating a present `initializing` machine as owned | Could delete an external or replaced machine | Never remove without committed exact created identity; retain journal/root and report incomplete rollback |
| Moving only the outer active flag | Cleanup is invoked but `planned`/`initializing` rollback still cannot prove deletion authority | Implement the lifecycle phase and preservation semantics in the same chunk |
| Cleanup removes the config root after rollback failure | Destroys the only durable transaction evidence and recreates the reported orphan state | Use a monotonic bootstrap-root preservation flag honored by every cleanup pass |
| Signal trap followed by EXIT trap | Double cleanup could duplicate output or reverse a prior preservation decision | Make cleanup idempotent; report once and never clear preservation during the process |
| Lifecycle enum extension is only partially deployed | Strict readers reject state or later code misclassifies ownership | Update producer, reader, transition validator, rollback, fixtures, installed controls, and guidance atomically; retain field layout/version and fail closed in older readers |
| End-to-end testing mutates a real machine | Could destroy user containers, images, or volumes | Use the existing fake Podman boundary only; real machine creation/removal is explicitly excluded |
| Retained incomplete config blocks fresh bootstrap | User cannot simply retry installation | Emit the exact retained root/journal diagnostic and document that this is deliberate safety behavior pending explicit recovery |

## Lessons learned

### Initial

- The late shared-create flag is a confirmed outer rollback gap, but moving it
  alone is insufficient because machine init currently mutates Podman while the
  durable journal still says `planned`.
- `LastUp: Never` is consistent with init succeeding before start, but it does
  not identify the exact failing command; the implementation must be correct
  for every failure between init and shared-create activation.
- The existing rollback primitive already refuses name-only deletion from a
  pre-identity phase. The destructive defect is compounded when bootstrap then
  discards that journal and the entire config root.
- Isolated creation demonstrates the correct outer active-flag ordering, and
  migration demonstrates the intended retained-journal behavior after
  incomplete machine removal.
- Podman and Shimmy do not share an atomic transaction. The unavoidable window
  between machine creation and committed identity must fail safe by preserving
  ambiguous state rather than claiming ownership retroactively.

### Chunk 1

- The shared active flag now becomes authoritative immediately after durable
  lifecycle preparation, and `initializing` is committed before Podman init.
  Only `initialized` and later phases carry the exact identity and token needed
  for machine deletion.
- Repeated trap cleanup must not retry a shared rollback after preservation is
  selected. A deeper review caught that a signal cleanup followed by EXIT could
  otherwise succeed on a second removal attempt and invalidate the retained
  journal diagnostic. Cleanup now skips later shared rollback attempts, and a
  focused test proves one attempt and one diagnostic across two cleanup calls.
- The fake Podman conditional required an explicit trailing `:` so a false
  failure-injection check did not become the successful init branch's return
  status under POSIX shell. The first serial command-lifecycle diagnostic
  exposed this and the required parallel acceptance passed after correction.
- The first serial `lib-engine` rerun after adding repeated-cleanup coverage
  failed because the test captured only the second call's stderr. Grouping both
  calls under one redirection fixed the test; the serial rerun then passed all
  seven cases.
- A complete-suite run already in progress was interrupted with status 130
  after the repeated-cleanup issue was found, because it no longer represented
  the final implementation. Verification was restarted from the final code.
- Final verification results: focused parallel acceptance passed all 12 tests;
  the complete default suite passed all 129 tests; changed-shell syntax,
  generated surface syntax exercised by acceptance, context-tree validation,
  whitespace checks, and executable-mode review all passed.
- All machine lifecycle acceptance used disposable fake Podman executables and
  temporary configuration roots. No real Podman machine or current Shimmy
  installation was inspected or mutated.

## Session bootstrap

This plan is the authoritative handoff. A fresh implementation agent must:

1. Confirm that the user explicitly authorized implementation, then move this
   file from `plans/notional/` to `plans/wip/` before editing implementation
   files.
2. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, `lib/CONTEXT.md`,
   `lib/engine/CONTEXT.md`, `lib/install/CONTEXT.md`, `tests/CONTEXT.md`,
   `tests/lib/CONTEXT.md`, `tests/commands/CONTEXT.md`, `docs/testing.md`, this
   complete plan, and every target file listed in Chunk 1.
3. Recheck `git status` and preserve unrelated user changes. Do not modify the
   retained hybrid lifecycle plan or generated `.agents/skills` content.
4. Implement only Chunk 1 as one atomic state/cleanup/test/guidance update. The
   non-negotiable boundaries are exact-identity deletion, no name-only
   ownership, monotonic retained recovery state, POSIX shell, and fake-only
   machine mutation tests.
5. Update the progress checklist and **Lessons learned**, execute every
   verification item, surface any `[~]` item explicitly, and stop at the human
   review gate.
