# Stop the active Podman machine during bootstrap

## Objective

Make fresh macOS bootstrap succeed when Podman's existing default machine
`podman-machine-default` is already running: Shimmy must inspect that machine's
workloads, stop it automatically when idle or after explicit interactive
permission when busy, start and activate the newly created `shimmy-default`,
and leave the prior machine stopped after successful bootstrap.

Success requires all of the following:

- bootstrap continues to reject an exact pre-existing `shimmy-default` machine
  or connection and never adopts, renames, or deletes an existing machine;
- a single valid alternate Podman VM, including `podman-machine-default`, is
  stopped automatically when its running-container inventory is available and
  empty;
- when that VM has running containers, bootstrap prints their IDs and names,
  warns that stopping the VM will interrupt them, and stops the VM only after
  an explicit interactive confirmation;
- bootstrap does not add or accept `--stop-running`; a non-interactive run, an
  unreadable workload inventory, or a declined confirmation fails closed before
  stopping the prior VM and provides actionable manual recovery guidance;
- successful bootstrap leaves the prior VM stopped, selects `shimmy-default`,
  and preserves all data in the prior VM;
- a later bootstrap failure removes the exactly proven new Shimmy machine and
  restores the prior running machine and default connection when recoverable;
- Linux bootstrap, existing profile transitions, ownership checks, and
  incomplete-rollback evidence remain unchanged;
- implementation, focused acceptance, full regression coverage, contributor
  guidance, operator documentation, and the canonical installation skill agree.

This change does not install Podman, adopt or delete
`podman-machine-default`, migrate its containers or VM-local data, restart it
after successful bootstrap, add a force/acknowledgement option to bootstrap, or
change Shimmy's POSIX-shell architecture.

## Target layout and terminology

- **Target machine** is the fresh, installation-owned `shimmy-default` created
  by bootstrap.
- **Prior machine** is the one valid alternate Podman VM that is running when
  bootstrap activates the target; the reported case is
  `podman-machine-default`.
- **Idle prior machine** has a valid rootless connection and an observable
  running-container count of zero.
- **Busy prior machine** has a valid rootless connection and one or more
  observable running containers. It may stop only after their ID/name list is
  shown and the operator explicitly confirms interruption in an interactive
  terminal.
- **Pending shared creation** is a target with a durable `create|recorded`
  lifecycle journal and exact host identity evidence, but which has not yet
  been started, guest-marked, projected, or committed.

The target sequence becomes:

```text
shared create preparation
  -> initialize and record stopped shimmy-default
  -> mark shared creation pending
  -> activation inventories the running prior VM
  -> stop an idle prior VM automatically, or warn/list/prompt for a busy VM
  -> start/guest-mark/project/validate shimmy-default
  -> finish bootstrap state and commit shared creation
```

On a post-transition failure, compensation runs in the existing order:

```text
activation rollback
  -> stop the target if its start was attempted
  -> restart the prior VM
  -> restore the prior default connection
shared-create rollback
  -> remove only the exactly identified new target
  -> remove the fresh installation root when rollback is complete
```

## Recorded design decisions

1. Use the existing managed activation transaction for the VM switch. Do not
   add a bootstrap-only direct `podman machine stop` path. Activation remains
   the authority for workload inspection, prior-machine stop, target start,
   default-connection selection, and compensating restoration.
2. Change shared-machine preparation to end at the same durable
   `create|recorded` boundary already used by isolated-machine creation. It
   initializes the machine, records exact ownership evidence, and stages the
   projection, but does not start the VM, install its guest drop-in, write its
   guest ownership marker, apply the projection, or commit creation.
3. In Darwin bootstrap, set `SHIMMY_PROFILE_ENGINE_CREATE_PENDING=1` after
   shared preparation and keep it set through activation and the shared-create
   commit. This makes `shimmy_profile_activate` start the new machine through
   `shimmy_engine_machine_create_start`, then install the drop-in and guest
   ownership marker through the existing pending-create branch. Clear the flag
   only after successful commit or during terminal cleanup.
4. Extend the private activation API with an explicit workload-interruption
   policy rather than overloading the existing boolean acknowledgement. Profile
   commands use `require-flag` and retain `--stop-running`; bootstrap uses
   `prompt`. Validate the policy at the activation boundary and do not expose it
   as a public environment selector.
5. Under bootstrap's `prompt` policy, print the existing running-container
   ID/name inventory and a direct warning before prompting on stderr:
   `Stop <machine> and interrupt these containers? [y/N]: `. Prompt only when
   stdin and stderr are terminals, accept only an explicit case-insensitive
   `y` or `yes`, and treat EOF, empty input, any other response, or a
   non-interactive invocation as refusal. A refusal returns failure before the
   prior-machine stop. Tests may use one narrowly named `SHIMMY_TEST_*`
   response injection following the repository's existing interactive-command
   seam, guarded by the existing test context. It remains an undocumented test
   seam, not a supported production confirmation mechanism.
6. An idle alternate VM needs no prompt. This intentionally uses the
   name-independent Podman constraint and safely covers a custom-named active
   VM as well as `podman-machine-default`; Podman permits only one managed VM to
   be active at a time.
7. Preserve the successful transition semantics: the prior VM remains stopped,
   its machine, connection, and VM-local data remain external to Shimmy, and
   `shimmy-default` becomes the running machine and default connection.
8. Preserve the existing compensation ordering. If activation fails after
   stopping the prior VM, its rollback restores that VM and prior default
   connection before shared-create rollback removes the stopped target. If
   restoration or exact target cleanup fails, retain and report the existing
   incomplete state/evidence instead of claiming complete rollback.
9. Preserve exact target collision preflight before configuration mutation.
   A pre-existing machine or rootless/rootful connection named
   `shimmy-default` remains a collision and is never routed through the
   alternate-machine transition.
10. Treat confirmation-before-interruption, non-interactive refusal, and
    exact-identity target removal as durable safety/ownership invariants. Add
    the lowest-cost route-specific assertions to the existing Darwin bootstrap
    and activation scenarios without creating redundant generic fixtures.

## Verified implementation inventory

This is a verified baseline, not permission to ignore dependencies newly found
during implementation.

- `commands/bootstrap.sh` exposes only `--shell` and `--no-startup`, installs
  cleanup traps, and delegates the complete lifecycle to
  `shimmy_profile_bootstrap_run`.
- `lib/install/lifecycle.sh` currently prepares the Darwin shared engine, then
  calls `shimmy_profile_activate` with restart and stop-running both false. It
  does not mark shared creation pending, although isolated create/clone already
  use that handoff pattern. Its cleanup invokes activation rollback before
  shared-create rollback, which is the required restoration/removal order.
- `lib/engine/registry.sh` currently performs the shared machine start, guest
  marker, drop-in installation, and projection before bootstrap activation.
  Its isolated preparation stops at the recorded/projection-prepared boundary.
- `lib/profile/activation.sh` already validates machine and connection
  metadata, identifies one alternate running VM, inventories its running
  containers, stops it only when allowed, starts a pending created target via
  the lifecycle primitive, installs target guest state, selects the target
  connection, and tracks enough state to restore the prior VM and connection
  on failure. It currently supports only boolean `--stop-running`
  acknowledgement and has no interactive bootstrap policy.
- `lib/engine/lifecycle.sh` already provides journal-first start, guest-mark,
  commit, and exact-identity rollback primitives. No lifecycle schema or
  ownership-format change is required.
- `tests/lib/profile-activation.sh` owns the generated fake Podman state machine
  used by lifecycle acceptance. It supports mutable machine-state files,
  workload output, machine stop/start failures, target cleanup, prior restart,
  and default-connection restoration. `commands/shim.sh` provides the nearby
  established pattern for terminal-gated prompting plus a narrow
  `SHIMMY_TEST_*` response seam.
- `tests/commands/lifecycle.sh` owns successful Darwin bootstrap, ordering,
  exact collision, image/start/init failures, exact machine rollback, and
  retained incomplete recovery evidence. Its bootstrap fixture currently has
  no alternate running VM and explicitly asserts that successful bootstrap did
  not issue a machine stop.
- `tests/lib/engine.sh` covers lifecycle primitives directly; the planned
  change does not alter their state schema or ownership rules.
- Behavior and contributor guidance are distributed across `AGENTS.md`,
  `CONTEXT.md`, `CONTRIBUTING.md`, `commands/CONTEXT.md`,
  `lib/engine/CONTEXT.md`, `lib/install/CONTEXT.md`, `tests/CONTEXT.md`,
  `tests/commands/CONTEXT.md`, `README.md`, `BOOTSTRAP.md`, `docs/podman.md`,
  `docs/prompt-shimmy-project.md`, and
  `plugins/shimmy/skills/shimmy-install/SKILL.md`.
- `plans/wip/shared-machine-rollback.md` covers ownership-safe rollback after
  ambiguous shared-machine creation, and
  `plans/wip/hybrid-podman-engine-lifecycle.md` records the broader engine
  architecture. They are related retained evidence, not authoritative plans
  for this behavior change, and must not be rewritten.
- Podman 5.8 documentation confirms that its default machine name is
  `podman-machine-default`, only one Podman-managed VM may be active, and
  starting another VM fails while one is running. Podman's machine-stop command
  stops the Linux VM in which its containers run, so Shimmy's existing
  workload interruption guard remains necessary.

## Unresolved

None.

## Progress Checklist

- Active chunk: None — Chunk 1 awaits implementation authorization.
- [ ] Chunk 1 — Route fresh shared-machine startup through compensated
  activation, prove idle-prior switching and rollback, and align guidance.

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

## Chunk 1 — Compensated bootstrap machine switch

### Goal

Allow macOS bootstrap to replace an active Podman VM with the new owned shared
VM automatically when idle or after explicit workload-interruption consent when
busy, while preserving exact ownership boundaries and failure restoration.

### Files

Primary implementation and acceptance surface:

- `lib/engine/registry.sh`
- `lib/install/lifecycle.sh`
- `lib/profile/activation.sh`
- `commands/bootstrap.sh`
- `tests/lib/profile-activation.sh`
- `tests/commands/lifecycle.sh`

Guidance and retained context surface:

- `AGENTS.md`
- `CONTEXT.md`
- `CONTRIBUTING.md`
- `commands/CONTEXT.md`
- `lib/engine/CONTEXT.md`
- `lib/install/CONTEXT.md`
- `tests/CONTEXT.md`
- `tests/commands/CONTEXT.md`
- `README.md`
- `BOOTSTRAP.md`
- `docs/podman.md`
- `docs/prompt-shimmy-project.md`
- `plugins/shimmy/skills/shimmy-install/SKILL.md`

This list identifies the verified primary surface and does not exclude a newly
discovered required consumer. Do not edit generated `.agents/skills` copies.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. The code change is compact, but machine
interruption, external-state restoration, and exact-identity rollback cross a
transaction boundary.

1. Refactor `shimmy_engine_registry_shared_create_prepare` to leave the new
   shared machine at `create|recorded` with its engine record and prepared
   projection. Keep shared-create rollback active from the existing
   journal-first point. Remove only the premature start/guest/projection work
   now owned by activation; do not change the lifecycle record format.
2. Mark Darwin shared creation pending before bootstrap activation, invoke the
   managed activation transaction with the private `prompt` workload policy,
   and retain the pending flag until shared creation commits. Reset transient
   state on every success/failure path without weakening the existing cleanup
   trap or bootstrap-root preservation logic. Profile create/clone/activate
   routes must explicitly retain the `require-flag` policy.
3. Keep exact `shimmy-default` collision checks ahead of configuration-root
   creation. Validate that a running alternate VM has valid machine metadata,
   a usable rootless connection, and a known workload count before any stop.
4. Reuse activation's existing stop/start bookkeeping. Do not infer ownership
   over the prior external VM, write Shimmy ownership evidence into it, delete
   it, or include it in shared-create rollback.
5. Add the terminal-gated confirmation path at the activation authority
   boundary. Print workload IDs/names and the interruption warning before
   reading a response; accept only `y`/`yes` case-insensitively; fail before
   stop on refusal, EOF, noninteractive input, or unavailable workload data.
   Keep profile operations on their explicit `--stop-running` path and never
   imply bootstrap accepts that option.
6. Extend the fake Podman fixture only as needed to model a mutable existing
   `podman-machine-default` alongside the newly created target and to observe
   default-connection restoration. Preserve existing scenario isolation.
7. Extend the existing Darwin bootstrap and focused activation scenarios to
   prove:
   - idle `podman-machine-default` is stopped before `shimmy-default` starts;
   - target activation and bootstrap complete successfully in the expected
     order;
   - the prior VM remains stopped and is not adopted or removed on success;
   - an injected later failure stops/removes the exact target, restarts the
     prior VM, restores its default connection, and removes the fresh config
     root when compensation is complete;
   - running workloads are listed and a declined or non-interactive prompt
     prevents the prior-machine stop and target start;
   - explicit test-seam confirmation permits the busy prior VM to stop and
     records acknowledged workload interruption for rollback diagnostics;
   - no prompt occurs for an idle prior VM, and no public bootstrap argument or
     production environment bypass is added.
8. Retain exact-collision, ambiguous-init, removal-failure, Linux bootstrap,
   isolated profile, and ordinary activation behavior. Update existing
   assertions whose old no-stop expectation is intentionally superseded; do
   not add absence tests unrelated to a durable safety or ownership invariant.
9. Update help, contexts, operator docs, reusable project guidance, and the
   canonical installation skill together. State that successful macOS
   bootstrap automatically stops one idle active VM and leaves it stopped;
   busy VMs require interactive confirmation after listing workloads;
   noninteractive or declined confirmation leaves the prior VM running;
   failure attempts restoration; and bootstrap still never accepts
   `--stop-running`.

### Verification checklist

- [ ] Inspect the rendered changes and confirm shared creation reaches
  `create|recorded` before activation performs any target start or guest
  mutation.
- [ ] Run focused groups with bounded parallelism:
  `./tests/test.sh --jobs 3 --group lib-engine --group lib-profile-activation --group commands-lifecycle-darwin-bootstrap`.
- [ ] Confirm the success trace orders target init, prior workload inventory,
  prior stop, target start, projection validation, and image preparation.
- [ ] Confirm injected post-switch failure restores the prior machine/default
  connection and removes only the exactly proven target and fresh config root.
- [ ] Confirm busy-machine coverage lists exact workload IDs/names, prompts
  before mutation, proceeds only on explicit affirmative confirmation, and
  refuses noninteractive/negative/EOF input without stopping the prior VM.
- [ ] Run the complete default bounded-parallel suite: `./tests/test.sh`.
- [ ] Run shell syntax checks through the repository suite and verify modified
  runnable shell files retain executable modes.
- [ ] Run `git diff --check` and inspect `git status --short` for unrelated or
  generated changes.
- [ ] Semantically compare canonical install guidance with all updated retained
  guidance; do not use byte-for-byte regeneration as a substitute for review.
- [ ] If a live macOS acceptance check is authorized separately, use only a
  disposable machine/configuration and record the prior/target states before
  and after. Do not stop the user's real VM merely to verify this chunk.

### Human review gate

The reviewer must confirm that bootstrap stops an observable idle prior VM
automatically, stops a busy prior VM only after listing workloads and receiving
explicit interactive consent, refuses unattended/declined interruption, never
adds `--stop-running`, leaves the prior external VM intact but stopped on
success, restores it on recoverable failure, removes only the exactly proven
new target, passes focused and full acceptance, and keeps all operator and agent
guidance consistent. Acceptance authorizes no further chunk because this is the
only implementation unit.

## Risk register

- **User workload interruption:** stopping a Podman VM interrupts its running
  containers. Mitigation: retain the observable workload inventory, auto-stop
  only when empty, and require an explicit terminal confirmation after listing
  busy workloads. Refusal and unattended execution fail before stop.
- **Prompt ambiguity or automation hangs:** prompting from a sourced or
  redirected shell can consume unintended input or block CI. Mitigation: use
  the repository's stdin/stderr TTY gate, default every ambiguous response to
  refusal, provide a test-only injection seam, and add no production bypass.
- **Unexpected external state change:** a successful bootstrap intentionally
  leaves the user's prior VM stopped. Mitigation: state this in help and docs,
  print the exact prior machine being stopped, and never adopt or delete it.
- **Rollback ordering:** restarting the prior VM while the target is still
  running conflicts with Podman's one-active-VM rule. Mitigation: activation
  rollback first stops the attempted target, then restarts the prior VM;
  shared-create rollback removes the stopped target afterward.
- **Double compensation:** an activation failure may already restore the prior
  VM before the outer bootstrap cleanup runs. Mitigation: preserve the existing
  transition-active gates and test both internal activation failure and later
  bootstrap failure paths.
- **Ambiguous or invalid metadata:** malformed machine lists, duplicate running
  machines, missing rootless connections, or unreadable workloads cannot be
  treated as idle. Mitigation: fail closed before stopping the prior VM and use
  existing incomplete-rollback evidence for any already-created exact target.
- **Scope widening:** the activation transaction is name-independent and will
  handle one custom-named idle active VM, not only `podman-machine-default`.
  This is intentional because Podman's one-active-VM constraint is likewise
  name-independent; documentation must describe an active prior VM rather than
  promise a name-only special case.

## Lessons learned

### Initial

- The reproduced failure occurs after target initialization when
  `shimmy_engine_registry_shared_create_prepare` starts `shimmy-default`; Podman
  documents that a second managed VM cannot start while another is active.
- Shimmy already has the required safe transition machinery in profile
  activation. The gap is that fresh shared creation starts the target before
  handing authority to activation, whereas isolated creation hands off at the
  recorded state.
- Bootstrap's no-`--stop-running` rule is compatible with automatic idle-VM
  switching and an explicit interactive busy-workload confirmation. Automation
  remains fail-closed rather than gaining a force flag.
- The existing cleanup order is suitable: activation restores prior engine
  selection before shared-create rollback deletes only the new owned target.

## Session bootstrap

Start by reading `AGENTS.md`, `CONTEXT.md`, `CONTRIBUTING.md`, this plan, the
child contexts listed in the file inventory, and the primary implementation and
test files for Chunk 1. Reconfirm that the worktree's unrelated state is
preserved and move this exact plan from `plans/notional/` to `plans/wip/`
before editing implementation files. Implement only Chunk 1. Do not add a
bootstrap `--stop-running` option or unattended confirmation bypass, do not
directly own/delete the prior VM, and do not alter lifecycle schemas. Run the
full verification checklist, update the progress and lessons sections, then
stop at the human review gate.
