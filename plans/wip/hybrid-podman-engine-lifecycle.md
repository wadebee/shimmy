# Shimmy Hybrid Podman Engine Lifecycle

**Status:** Chunk 4 implemented and automated acceptance verified on 2026-08-23; the Podman 5.8 bootstrap incompatibility is fixed and native destructive acceptance has not been rerun; human review pending

## Objective

Refactor Shimmy's Podman lifecycle so a fresh macOS installation owns one shared Podman machine named shimmy, ordinary profiles use that shared engine, and explicitly isolated profiles use installation-owned machines named shimmy-<profile>. Preserve profile-scoped registry redirects in both modes while making shared-profile activation avoid Podman machine restarts.

The implementation must:

- Keep each profile's registries.conf authoritative.
- Apply a changed active registry policy by recycling only the rootless Podman API service inside the VM, leaving the VM and its containers running.
- Never use SIGHUP to reload Podman service configuration.
- Preserve existing Podman machines and migrate existing Shimmy profiles without renaming, adopting, deleting, or claiming those machines.
- Create, identify, validate, and remove new Shimmy-owned machines transactionally.
- Make ordinary uninstall remove every provably Shimmy-owned Podman machine by default.
- Prominently document that uninstall permanently destroys all containers, images, volumes, caches, and other VM-local data in those owned machines.
- Keep external, legacy, ambiguous, and host-local engines outside Shimmy's destructive authority.
- Preserve the POSIX shell architecture and keep lib/profile/activation.sh as the sole engine-activation authority.

Execution is gated after every chunk; do not begin Chunk 3 without explicit
human acceptance of Chunk 2.

## Target layout and terminology

Configuration state:

    <config-root>/
      active-profile.conf
      engines/
        shared/
          engine.conf
          registries.conf
          projection.conf
          lifecycle.conf
        profile-<name>/
          engine.conf
          registries.conf
          projection.conf
          lifecycle.conf
      profiles/
        <name>/
          profile.conf
          engine-binding.conf
          registries.conf

Terms:

- Profile policy: profiles/<name>/registries.conf. This remains the authoritative registry redirect policy for that profile.
- Engine: one Podman execution environment. On macOS this is a Podman machine and connection. On Linux it is the existing local rootless Podman service.
- Shared engine: engine ID shared. On macOS its machine and connection are named shimmy. On Linux it maps to the local rootless engine.
- Isolated engine: engine ID profile-<name>. A newly created macOS isolated engine is named shimmy-<profile>.
- Legacy-isolated engine: an existing profile's pre-refactor macOS machine. It is recorded for routing but remains externally owned.
- Engine binding: a strict, versioned profile record that selects shared, isolated, or legacy-isolated mode and an engine ID.
- Engine record: a strict, versioned record describing engine kind, name, connection, provider, origin, ownership evidence, and observed identity.
- Engine projection: the normalized registry policy currently staged for one engine.
- Loaded fingerprint: the projection fingerprint verified after the current Podman API service process started.
- Machine restart: stopping or starting a Podman VM. Normal shared-profile activation and registry mutation must not do this.
- Service recycle: stopping only the rootless podman.service inside the VM while leaving podman.socket active. The next remote request socket-activates a fresh service process.
- Owned machine: a machine created by the current Shimmy installation for which all host and guest ownership evidence still matches.
- External machine: a pre-existing, migrated, ambiguous, or otherwise unproved machine. Shimmy may route to it but never delete it.
- Lifecycle journal: durable state written before machine creation or removal and cleared only after the operation is fully committed.

The initial on-disk records are strict shell-assignment manifests with independent schema versions:

    shimmy_engine_binding_version=1
    profile=<profile>
    mode=shared|isolated|legacy-isolated
    engine=shared|profile-<profile>

    shimmy_engine_version=1
    engine=<engine-id>
    kind=darwin-machine|linux-rootless
    scope=installation|profile
    name=<machine-name-or-local>
    connection=<connection-name-or-local>
    provider=<observed-provider-or-none>
    origin=shimmy-created|legacy-external|host-local
    ownership_token=<token-or-empty>
    created_identity=<stable-inspect-fields-or-empty>

Exact fields and escaping rules must be finalized with the repository's existing manifest conventions during Chunk 1. Adding, removing, or changing these fields after Chunk 1 requires returning this plan to review because every producer, reader, validator, fixture, transaction, and rollback path must change together.

## Recorded design decisions

1. Fresh macOS bootstrap creates one installation-owned shared Podman machine and connection named shimmy. It does not install Podman.
2. A pre-existing machine or connection named shimmy is a collision. Bootstrap and migration fail before mutation and never adopt it.
3. Podman's configured/default machine provider is used. Shimmy does not hardcode AppleHV, QEMU, architecture, CPU, memory, disk, or image defaults. The observed provider is recorded after creation.
4. Ordinary profile create binds the new profile to the shared engine.
5. Profile create --isolated provisions an owned machine named shimmy-<profile> and binds only that profile to it.
6. A true profile clone is implemented as part of this plan. By default it preserves isolation intent: shared sources clone to shared; isolated and legacy-isolated sources clone to a newly created owned isolated machine. Mutually exclusive --shared and --isolated flags override that default.
7. Existing profiles are not silently migrated by status, sync, update, activation, or runtime execution. Migration is an explicit installation-wide command.
8. The new command surface is shimmy admin engine status and shimmy admin engine migrate [--dry-run]. Migration records all existing macOS profiles as legacy-isolated, preserves their current machine and connection identities, and provisions the shared shimmy machine for future shared profiles. It does not move any existing profile to that engine.
9. Until explicit migration, compatibility readers preserve the current schema-2 per-profile mapping. New shared or isolated creation is refused with a migration instruction. The update path must install dual-read controls everywhere before any engine registry or binding is written.
10. Linux uses one shared host-local rootless engine. Linux never creates or deletes Podman machines. --isolated is rejected because no durable Linux isolation boundary is designed in this plan.
11. Each profile's profiles/<name>/registries.conf remains authoritative in shared and isolated modes.
12. Each engine has a stable guest user drop-in:

        /var/home/core/.config/containers/registries.conf.d/shimmy-active-profile.conf
          -> <config-root>/engines/<engine-id>/registries.conf

    The host-mounted engine projection is atomically rendered from the active profile policy. Shimmy does not replace the user's main registries.conf.
13. The engine projection record stores source profile, source path, source fingerprint, normalized effective fingerprint, and last successfully loaded fingerprint. It permits exact rollback and determines whether a service recycle is necessary.
14. Shared-to-shared activation stages the target engine projection first. If the normalized effective policy changed, activation stops only the rootless podman.service through machine SSH, leaves podman.socket and the VM running, then performs a remote Podman request to start and validate a fresh service. If policy is identical, no service recycle occurs.
15. Shimmy must not send SIGHUP to the Podman API service. Upstream removed that reload path because it could mutate shared runtime state concurrently and violate the Go memory model.
16. A service recycle may abort concurrent external Podman API requests. In-flight work may have used the old policy. The new-policy guarantee begins only after the new service process is validated and the activation transaction commits. Documentation must state this bounded interruption.
17. If the expected rootless systemd service/socket arrangement is absent, Shimmy fails closed with an unsupported-machine-image diagnostic. It does not silently restart the VM. --restart remains an explicit user-selected recovery path and retains workload safety checks.
18. Shared-to-isolated, isolated-to-shared, and isolated-to-isolated activation retain machine stop/start behavior because Podman supports one active macOS VM at a time in the current model. Target policy is staged before target start.
19. --stop-running authorizes stopping a VM that contains running containers. It is not required merely to recycle podman.service because workloads continue running.
20. Redirect set and delete for the active profile apply immediately. They update the profile source and engine projection transactionally, recycle podman.service only when effective policy changes, validate the new mapping, and roll both files and the service state back on failure.
21. Redirect changes for an inactive profile modify only its authoritative profile policy. Its policy is staged when that profile is next activated.
22. Registry validation uses Podman info and the exact active rootless connection to verify the effective registry mapping. Production activation does not require an external image pull.
23. Machine ownership is never inferred from a name, connection, profile binding, or origin string alone.
24. Before machine init, Shimmy proves the exact machine and connection are absent and writes a lifecycle journal. After init it generates a random ownership token, writes matching host state and a guest marker under the core user's state directory, and records stable inspect evidence including creation identity, provider, config directory, socket/connection URI, identity path, and rootful state.
25. Before every destructive machine operation, Shimmy revalidates the host record, guest marker token, exact machine and connection, and stable inspect evidence. Missing or mismatched evidence makes the machine external/ambiguous and preserves it.
26. Machines encountered during migration are recorded with origin legacy-external and an empty ownership token. Shimmy never upgrades those records to shimmy-created.
27. Fresh bootstrap creates shimmy without --now, restores the user's previous default Podman connection if init changes it, starts the target explicitly, establishes ownership and projection state, and commits the active profile last.
28. If machine creation later fails, compensation removes only the just-created machine whose complete ownership evidence still matches. If compensation cannot finish, Shimmy retains the minimal engine record and lifecycle journal needed for safe retry.
29. Profile deletion never removes the shared engine. Deleting a profile with an owned isolated engine removes that machine by default after a destructive warning and ownership preflight. Deleting a legacy/external profile preserves its machine.
30. Global shimmy admin uninstall removes every provably Shimmy-owned shared and isolated macOS machine by default. There is no preservation default for owned machines.
31. Uninstall prominently warns that deleting owned machines irreversibly deletes their containers, images, volumes, build cache, and all other VM-local data. External, legacy, ambiguous, and Linux host-local engines are preserved.
32. Uninstall preflights all engine identities and workload state before the first deletion. Owned machines without running workloads may be stopped automatically. An owned machine with running containers requires explicit --stop-running.
33. Uninstall writes a durable removal journal listing planned, completed, and pending engines. Owned isolated engines are removed first; the active/shared engine is removed last. Because deletion cannot be rolled back, partial failure retains the installation state and journal for idempotent retry and reports exact completed and pending work.
34. Only after all intended machine removals and other uninstall work succeed may Shimmy remove engine state, profile state, startup integration, installed skills, and installation configuration.
35. lib/profile/activation.sh remains the sole authority for changing active engine state. Engine modules provide state, ownership, projection, and Podman lifecycle primitives but do not independently activate profiles.
36. Active profile, active engine projection, default connection, installed skill links, and startup-visible state are commit-last outputs. Rollback restores the previous projection, recycles the service again when required, validates the prior mapping, restores engine/default state, and leaves the previous active record authoritative.
37. Status, list, migration dry-run, activation dry-run, redirect dry-run, profile-delete dry-run, and uninstall dry-run expose stable fields for binding mode, engine ID/name/kind/provider/origin, ownership state, machine state, projection source/fingerprint/state, service action, and deletion action.
38. Multiple shared engines, Linux managed machines, live movement of an existing profile's containers between engines, and adoption of pre-existing machines are deferred.
39. The pending plans/profile create-clone design is superseded by this plan for all unexecuted create and clone work because its hardcoded per-profile engine identity and no-provisioning assumptions conflict with this architecture.
40. The reviewed single-command uninstall work is a prerequisite baseline. This plan supersedes only its owned-machine preservation rule and extends its transaction after that plan is accepted or explicitly closed.

## Verified implementation inventory

Repository behavior:

- lib/profile/profile.sh currently derives Darwin machine and connection identity as shimmy-<profile>.
- lib/install/manifest.sh and lib/profile/state.sh currently validate strict profile schema 2 without engine-binding fields.
- active-profile.conf currently records profile and AI-skill root but no engine identity.
- commands/profile.sh currently supports create, list, status, sync, delete, activate, and redirect. It has no true clone command.
- lib/install/lifecycle.sh currently materializes default, expects shimmy-default to pre-exist, never provisions machines, prepares images on the prior engine, commits the profile, and then activates it.
- lib/profile/activation.sh currently validates one expected machine/connection, performs stop/start and projection/default changes transactionally, and is the sole engine authority.
- lib/profile/management.sh currently validates before and after locks and commits engine changes before active record and skill changes.
- lib/runtime/podman.sh currently enforces schema 2, invoking-profile affinity, expected machine identity, and a current registry projection. Shared engines must retain active-profile affinity even when two profiles use the same connection.
- lib/registries/registries.sh currently records a profile/machine-bound projection and treats a changed fingerprint as requiring a VM restart.
- lib/install/uninstall.sh currently uses strict allowlists and preserves Podman machines. Its allowlist must be extended deliberately for engines/ and lifecycle journals.
- lib/update/profile.sh currently runs part of first sync with old installed helpers while installing new controls. This creates a schema-migration ordering hazard.
- tests/lib/profile-activation.sh provides a fake Podman seam but does not yet model machine init/inspect/rm, guest ownership markers, or rootless service recycling.
- Relevant suites include lib-profile-state, lib-runtime, lib-profile-activation, lib-registries, commands-profile, commands-surface, and the indivisible commands-lifecycle group.
- User-facing surfaces include README.md, BOOTSTRAP.md, commands/README.md, docs/podman.md, docs/registries.md, docs/prompt-shimmy-project.md, root and child CONTEXT.md files, contributor guidance, plugins/shimmy/skills, canonical tools/<tool>/SKILL.md files, and the generic template.
- Generated .agents/skills copies are not authoritative and must not be edited.

Independent live registry-reload spike:

- Tested with Podman client 5.8.1 and server 5.8.6 on the active AppleHV machine.
- The VM service user is core with home /var/home/core. The macOS host's /Users tree is mounted into the VM, so a user drop-in can resolve a host-owned projection file.
- A temporary user-level registries.conf.d drop-in redirected a reserved prefix to endpoint A.
- While the same Podman API service PID remained alive, the projection changed to endpoint B but pulls continued to use endpoint A, proving the service caches registry configuration.
- SIGHUP made that tested server process observe endpoint B without changing its PID, but this mechanism is rejected because upstream removed the reload implementation in commit a1afa58e2769c72e427ffb728d25d4a2b13d54e9.
- In the accepted spike, systemctl --user stop podman.service was run inside the VM while podman.socket stayed active.
- The next remote Podman request socket-activated a new service process and observed endpoint B.
- The VM boot ID remained unchanged.
- A sentinel container retained the same container ID and remained running.
- Restoring the prior projection and recycling the service again restored the prior registry behavior.
- Temporary drop-ins, files, endpoints, and the sentinel were removed, and the original Shimmy system projection link was unchanged.

Official evidence:

- Podman removal of SIGHUP configuration reload:
  https://github.com/containers/podman/commit/a1afa58e2769c72e427ffb728d25d4a2b13d54e9
- Podman system service:
  https://docs.podman.io/en/latest/markdown/podman-system-service.1.html
- Podman machine init:
  https://docs.podman.io/en/latest/markdown/podman-machine-init.1.html
- Podman machine inspect:
  https://docs.podman.io/en/latest/markdown/podman-machine-inspect.1.html
- Podman machine rm:
  https://docs.podman.io/en/latest/markdown/podman-machine-rm.1.html
- Registry configuration and user drop-in semantics:
  https://github.com/containers/image/blob/main/docs/containers-registries.conf.5.md

Retained-plan relationships:

- plans/wip/split-profile-create-clone.md is unstarted and overlaps this plan. It must be marked superseded when execution begins; no implementation should proceed from both plans.
- plans/complete/single-command-uninstall.md is completed, with native macOS acceptance explicitly deferred. Treat its implemented uninstall behavior as the baseline before this plan changes it.
- Older profile-name activation and registry-redirect plans are historical records. Add only narrow supersession notes if execution would otherwise leave their status ambiguous.
- Preserve the shared-execution-only boundary from the control-plane-centralization and catalog-profile-separation plans; this plan does not introduce a shared mutable control plane.

## Unresolved

None.

## Progress Checklist

- [x] Human accepts this plan and closes or accepts the single-command uninstall prerequisite.
- [x] Chunk 1: Safe engine and service lifecycle primitives are implemented and verified without public behavior or schema changes.
- [x] Human reviewed and explicitly accepted Chunk 1 on 2026-08-23.
- [x] Chunk 2 implemented and verified on 2026-08-23: Add engine state, explicit migration, shared bootstrap/create/activation, and profile-scoped registry projection.
- [x] Human explicitly accepted Chunk 2 by requesting Chunk 3 implementation on 2026-08-23.
- [x] Chunk 3 implemented and verified on 2026-08-23: Add owned isolated creation, true clone, cross-mode activation, and isolated profile deletion.
- [x] Human reviewed and explicitly accepted Chunk 3 on 2026-08-23.
- [~] Chunk 4 implemented and automated acceptance verified on 2026-08-23: global uninstall removes proven owned machines, preserves external or ambiguous engines, retains a forward-recovery journal, and ships updated documentation and canonical guidance. Native acceptance remains blocked before owned-machine creation because local Podman 5.8 rejects the existing `machine init --update-connection=false` bootstrap command.
- [x] Podman 5.8 compatibility follow-up removes the post-5.8 `machine init --update-connection=false` option while retaining explicit prior-default restoration. The focused engine and profile-activation groups pass; four directly relevant lifecycle scenarios passed before the user requested that the remaining lower-value broad workflow rerun be skipped.
- [ ] Human reviews and explicitly accepts Chunk 4.
- [ ] Record final lessons, resolve superseded plan state, and move this plan to the repository's completed-plan location.

## Execution protocol

1. Read AGENTS.md, CONTEXT.md, every child context on the path to each changed file, this plan, and the current chunk's target files.
2. Execute only the current chunk's scope.
3. Run the chunk verification checklist and record each item as [x], [ ], or [~] with notes.
4. Update the cumulative Lessons learned section.
5. Summarize changes, tests, failures, uncertainties, and risks.
6. Stop for human review and explicit acceptance before beginning the next chunk.

## Chunk 1: Safe engine and service lifecycle primitives

### Goal

Establish testable POSIX-shell primitives for engine identity, machine inspection, ownership evidence, lifecycle journals, atomic engine projections, and rootless Podman service recycling while preserving all current public profile behavior and schema.

This chunk is the mandatory go/no-go foundation. Re-run the live service-recycle acceptance before broad refactoring. If it does not preserve VM boot identity and a running sentinel container while loading the new registry policy, stop and return the plan to review.

### Files

- New lib/engine/CONTEXT.md.
- New narrowly scoped modules under lib/engine/ for state, ownership, Podman machine operations, lifecycle journals, and registry projection/service operations.
- lib/profile/activation.sh.
- lib/registries/registries.sh.
- The installed-control file manifests and source lists that load shared lib modules.
- tests/lib/profile-activation.sh.
- tests/lib/registries.sh.
- New or existing engine-focused test files under tests/lib/.
- Relevant root, lib, profile, registries, and tests CONTEXT.md files.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. Treat ownership proof, journal transitions, service recycling, and rollback as security and data-integrity boundaries.

- Define strict parsers and renderers for the proposed version-1 engine, binding, projection, and lifecycle records, but do not publish new profile records yet.
- Follow existing manifest quoting, path-validation, lock, and atomic-replacement conventions. Do not source untrusted state.
- Centralize exact Podman connection selection; every inspect, info, registry validation, workload check, and service action must target the intended engine explicitly.
- Add fake-Podman capabilities for machine absence/init/inspect/start/stop/rm, connection changes, guest marker operations, systemd user service state, socket activation, PID changes, boot ID, and running container identity.
- Make machine-init input noninteractive and preserve the prior default connection as a value that can be restored.
- Generate ownership tokens from an operating-system CSPRNG available on supported hosts. Never emit tokens in ordinary status/help output.
- Define stable inspect evidence narrowly enough to survive ordinary stop/start but strongly enough to distinguish replacement at the same name.
- Write lifecycle journal transitions before their corresponding external mutation.
- Render engine registries.conf through a temp file plus atomic rename on the same filesystem.
- Recycle only podman.service; explicitly confirm podman.socket remains active. Do not use daemon-reload, SIGHUP, system service units, or a VM restart.
- After stopping the service, force a new remote request, observe a changed service PID where inspectable, and validate the exact effective registry mapping through Podman info.
- Make rollback restore the prior projection, recycle again, and validate prior policy.
- Do not alter existing command behavior, schema 2, machine naming, or uninstall behavior in this chunk.
- Update contexts for the new module boundaries and ownership invariants.

### Verification checklist

- [x] POSIX syntax checks pass for every new or changed shell file.
- [x] Manifest round-trip, malformed-state, unsafe-path, and unknown-field tests prove the strict state boundary.
- [x] Ownership tests prove exact matching permits a planned destructive action and missing/mismatched host, guest, connection, or inspect evidence preserves the machine.
- [x] Journal tests prove an interrupted create/remove retains enough state for idempotent retry.
- [x] Projection tests prove atomic staging, equal-policy no-op, changed-policy service recycle, validation, and compensated rollback.
- [x] Existing lib-profile-activation and lib-registries behavior remains green.
- [x] Selected independent test groups run with the default bounded parallel runner or explicit --jobs 3; only one-group focused engine checks used `--serial`.
- [x] Live macOS acceptance proves endpoint A remains cached in one service process, service recycle loads endpoint B, VM boot ID is unchanged, and the same sentinel container remains running.
- [x] Live acceptance restores the original registry projection and removes all temporary state.
- [x] git diff confirms this chunk contains no public schema or command behavior change.

Verification evidence (2026-08-23):

- `./tests/test.sh --jobs 3 --group lib-engine --group lib-profile-activation --group lib-registries --group lib-runtime --group commands-surface` passed all 26 tests.
- `./tests/test.sh --jobs 3 --group commands-profile --group commands-surface --group commands-lifecycle` passed all 11 tests; the indivisible lifecycle group completed within its historical runtime envelope.
- Live Podman 5.8.1/5.8.6 acceptance on `shimmy-default` observed service PID `51024` cache endpoint A and PID `51445` load endpoint B. VM boot ID `1a6e92be-4d1a-454e-9c01-126cd8f754fd` and sentinel ID `7fcb0598f39ed3db1ef02ad39708752ac8ad00a55d9dd447e4b5bfecefaec79d` remained unchanged while the sentinel stayed running.
- Cleanup removed the exact labeled sentinel and unique user drop-in, recycled the service back to the original policy, verified the acceptance prefix absent, and verified the pre-existing system projection still targeted `/Users/wade/.config/shimmy/profiles/default/registries.conf`.

### Human review gate

Stop. Present the live proof, state formats, ownership evidence, service-recycle transaction, rollback behavior, tests, and remaining risks. Obtain explicit acceptance before Chunk 2.

## Chunk 2: Engine registry, migration, shared lifecycle, and registry policy

### Goal

Publish the engine/binding schema as one atomic compatibility unit, add explicit migration, make fresh macOS bootstrap and ordinary profile creation use the owned shared shimmy machine, and make shared-profile activation and redirect mutation use profile-scoped engine projections without VM restart.

### Files

- commands/admin.sh and its help/dispatch support.
- commands/bootstrap.sh.
- commands/profile.sh.
- lib/engine modules introduced in Chunk 1.
- lib/install/lifecycle.sh.
- lib/install/manifest.sh.
- lib/install/profile.sh and installed-control manifests.
- lib/profile/profile.sh.
- lib/profile/state.sh.
- lib/profile/management.sh.
- lib/profile/activation.sh.
- lib/runtime/podman.sh.
- lib/registries/registries.sh.
- lib/update/profile.sh.
- Relevant command, lib, runtime, update, profile, registry, install, startup, common, and test contexts.
- tests/lib/profile-state.sh.
- tests/lib/runtime.sh.
- tests/lib/profile-activation.sh.
- tests/lib/registries.sh.
- tests/commands/profile.sh.
- tests/commands/surface.sh.
- tests/commands/lifecycle.sh.
- README.md, BOOTSTRAP.md, commands/README.md, docs/podman.md, and docs/registries.md for behavior introduced in this chunk.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. The schema publication, update bridge, fresh bootstrap, migration, and activation transaction must be reviewed as one compatibility boundary.

- First update every installed and source reader to dual-read current schema 2 and the new engine/binding records. Only after all control assets are installed may migration write new records.
- Add shimmy admin engine status with human and manifest output. It must distinguish unmigrated, shared, isolated, legacy-external, owned, ambiguous, projection-current, and projection-stale states without mutation.
- Add shimmy admin engine migrate [--dry-run]. Dry-run performs all collision, current-profile, machine, connection, path, and write-set validation without machine creation.
- Migration records every current macOS profile against its existing machine as legacy-isolated, never claims it, then creates the shared shimmy engine transactionally for future profiles. Failure leaves old schema behavior authoritative or rolls back to it.
- Fresh bootstrap preflights the shimmy machine and connection, journals creation, initializes without --now or provider overrides, restores the prior default connection if needed, starts the machine, writes the guest marker and user drop-in, records observed identity/provider, stages default policy, activates default, and commits state last.
- Ordinary profile create writes a shared binding. Do not create a per-profile machine.
- Runtime affinity remains profile-scoped: a wrapper from inactive profile B must not run merely because active profile A uses the same shared engine.
- Shared-to-shared activation does not stop or start the VM. It stages the target policy, recycles podman.service only on an effective fingerprint change, validates registry state and rootless connection, then commits active record and skills.
- Redirect set/delete on the active profile applies and validates immediately. Inactive mutation changes only the source policy. Dry-run reports would_recycle_podman_service=yes or no.
- Preserve --restart only as explicit recovery. Its help must distinguish VM restart from normal service recycle.
- Keep --stop-running out of same-engine service recycle paths.
- Preserve the explicit-client registry mount boundary; do not broaden registry file mounts beyond existing supported consumers.
- On Linux, publish a shared host-local engine record, preserve the current local user-drop-in behavior, and reject managed isolation without adding machine operations.
- Update public documentation in the same chunk as new behavior. Include the bounded API interruption during service recycle and the fact that running containers and the VM remain up.
- Update canonical source guidance only. Do not edit .agents/skills.

### Verification checklist

- [x] Update-first tests prove old installed controls can transition only through the dual-read bridge and never encounter a partially published schema.
- [x] Fresh disposable macOS bootstrap creates exactly shimmy, records complete ownership evidence, preserves the prior default connection where applicable, and activates default on the shared engine.
- [x] An exact pre-existing shimmy machine or connection causes a pre-mutation collision failure and is never adopted.
- [x] Explicit migration records existing profiles as legacy-external without renaming, stopping, starting, deleting, or claiming their machines.
- [x] Migration failure and interruption restore or retain an authoritative retryable state.
- [x] Ordinary profile create binds shared and does not call podman machine init.
- [x] Shared-to-shared activation changes active profile and profile-scoped redirect policy without changing VM boot ID or sentinel container identity/state.
- [x] Equal normalized registry policies switch profiles without service recycle.
- [x] Active redirect set/delete applies immediately and rollback restores source, projection, service, and active state after injected failure.
- [x] Inactive redirect mutation does not change the active engine projection.
- [x] Runtime tests preserve active-profile affinity across two profiles sharing one engine.
- [x] Linux tests preserve host-local behavior and perform no machine lifecycle action.
- [x] Help, human status, manifest status, and dry-run outputs expose the recorded stable fields.
- [x] Relevant independent groups run with default bounded parallel execution or --jobs 3; commands-lifecycle remains indivisible.
- [x] Documentation accurately distinguishes profile policy, engine projection, API service recycle, and VM restart.

Verification evidence (2026-08-23):

- `./tests/test.sh --jobs 3 --group lib-engine --group lib-profile-state --group lib-profile-activation --group lib-registries --group lib-runtime --group commands-surface --group commands-profile` passed all 37 tests.
- Focused reruns passed all 5 `lib-engine` tests, all 8 `lib-profile-activation` tests, and both `commands-surface` tests after the final journal, shared-activation, and help changes.
- `./tests/test.sh --serial --group commands-lifecycle` passed all 3 indivisible lifecycle scenarios after a serial diagnostic rerun: disposable Darwin shared bootstrap/collision, explicit migration/compensation/retry, and the public Linux lifecycle covering shared create, sync binding preservation, delete, and host-local uninstall.
- `./tests/context-tree.sh`, POSIX syntax checks for all changed shell files, and `git diff --check` passed.
- Native Chunk 1 service-recycle evidence remains the live proof for unchanged VM boot and sentinel identity. Chunk 2 did not migrate or provision against the user's real installation because that would be an external lifecycle mutation; live shared-profile switching remains a review-gate follow-up if the human requires it.

### Human review gate

Stop. Present migration compatibility, fresh-bootstrap ownership evidence, shared activation traces, live no-restart registry proof, public output, documentation, tests, and remaining risks. Obtain explicit acceptance before Chunk 3.

## Chunk 3: Isolated profiles, clone, transitions, and profile deletion

### Goal

Add installation-owned isolated machines, implement true profile clone semantics, safely transition between shared and isolated engines, and make profile deletion remove an owned isolated engine while preserving external machines.

### Files

- commands/profile.sh and profile help.
- lib/engine modules.
- lib/install/lifecycle.sh.
- lib/profile/profile.sh.
- lib/profile/state.sh.
- lib/profile/management.sh.
- lib/profile/activation.sh.
- lib/runtime/podman.sh.
- lib/registries/registries.sh.
- lib/install/uninstall.sh for profile-scoped deletion only.
- Relevant contexts.
- tests/lib/profile-state.sh.
- tests/lib/profile-activation.sh.
- tests/lib/runtime.sh.
- tests/lib/registries.sh.
- tests/commands/profile.sh.
- tests/commands/surface.sh.
- tests/commands/lifecycle.sh.
- README.md, commands/README.md, docs/podman.md, and docs/registries.md.
- plans/wip/split-profile-create-clone.md for a supersession note only.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. Isolated provisioning and deletion cross an irreversible ownership boundary; clone also changes established lifecycle ordering.

- Add profile create <name> --isolated. Preflight name, machine, connection, profile path, engine path, and ownership-journal collisions before mutation.
- Create shimmy-<profile> with the same init, default-connection restoration, ownership proof, guest marker, projection, and compensation protocol used for the shared machine.
- Activate the isolated target before preparing target images. Do not prepare images on the source engine and then commit a target that cannot use them.
- Implement true profile clone <source> <target>. Copy the supported profile-owned configuration and selection state defined by the retained clone plan, excluding runtime locks, transient journals, active records, ownership tokens, and engine identity.
- Default clone binding follows isolation intent: shared to shared; isolated or legacy-isolated to a new owned isolated engine. --shared and --isolated are mutually exclusive overrides.
- Never clone or transfer machine ownership evidence from the source.
- Shared-to-isolated, isolated-to-shared, and isolated-to-isolated activation stages target registry policy before start, applies existing workload guards, changes engine/default connection transactionally, validates the target, and commits profile/skills last.
- Rollback must restore the exact prior engine state, default connection, projection, active record, and skills. A newly created target is compensated only if its full ownership evidence matches.
- Profile delete for a shared profile removes only profile-owned state.
- Profile delete for an owned isolated profile prominently warns of VM-local data destruction, preflights ownership and workloads, requires --stop-running for running containers, journals the removal, deletes the machine, then removes profile state.
- If machine deletion succeeds but later cleanup fails, retain a removal-pending journal and enough profile/engine state for idempotent retry.
- Profile delete for legacy-external or ambiguous engines preserves the machine and reports that preservation.
- Mark plans/wip/split-profile-create-clone.md superseded; do not execute or rewrite its historical design.
- Update canonical public guidance and tests in the same chunk.

### Verification checklist

- [x] Isolated create provisions shimmy-<profile>, records independent ownership proof, stages policy before start, prepares images on the target, and commits last.
- [x] Isolated create failure compensates only an exactly matched just-created machine and preserves retry evidence when cleanup fails.
- [x] Clone shared-to-shared reuses the shared engine and copies only supported profile-owned configuration.
- [x] Clone from isolated and legacy-isolated creates a new owned isolated engine without copying source ownership.
- [x] --shared and --isolated overrides produce the documented binding and lifecycle behavior.
- [x] Cross-mode activation enforces running-workload authorization, stages target policy, and rolls every committed surface back after injected failure.
- [x] Shared profile deletion leaves the shared engine and other shared profiles usable.
- [x] Owned isolated profile deletion removes its exact machine and records destructive consent; external/legacy/ambiguous deletion preserves the machine.
- [x] Interrupted isolated deletion is retryable from the journal, including partial local profile cleanup.
- [x] Runtime and registry affinity remain profile-scoped after clone and cross-mode transitions.
- [x] Relevant independent groups ran with `--jobs 3`; `commands-lifecycle` remained indivisible and ran serially.
- [~] Disposable fake-Podman macOS acceptance covers shared/isolated workloads, transitions, ownership, clone, and deletion. Native machine creation/deletion was not run because it would mutate the user's external Podman installation.
- [x] Documentation prominently identifies which profile operations delete VM-local data.

Verification evidence (2026-08-23):

- The seven focused `--jobs 3` groups passed all 37 tests: `lib-profile-state`, `lib-runtime`, `lib-engine`, `lib-profile-activation`, `lib-registries`, `commands-profile`, and `commands-surface`.
- The lock-order extension passed all 3 `lib-lock` tests, including lexical acquisition and reverse release of multiple profile registry locks.
- The indivisible serial `commands-lifecycle` group passed all 4 scenarios. Its Darwin acceptance proves compensated isolated-create workload refusal, owned isolated creation, shared/isolated transitions, default isolated clone with a fresh ownership token, shared override planning, exact isolated removal, partial-cleanup retry, and preservation of the shared engine. The retained migration and public Linux lifecycle scenarios also passed.
- POSIX syntax checks, `git diff --check`, and `./tests/context-tree.sh` passed before the retained plan evidence update; final structural checks are repeated after it.
- Non-mutating local inspection found Podman 5.8.1 with the AppleHV provider; `shimmy-default` was running and `podman-machine-default` was stopped. No real machine lifecycle operation was performed.
- Native macOS machine creation and deletion remain a human review follow-up because this implementation session did not mutate the user's real Podman installation.

### Human review gate

Stop. Present ownership records, provisioning/deletion traces, clone behavior, transition rollback, destructive warnings, tests, live acceptance, and remaining risks. Obtain explicit acceptance before Chunk 4.

## Chunk 4: Destructive global uninstall and final integration

### Goal

Extend the reviewed single-command uninstall transaction so ordinary uninstall removes all and only provably Shimmy-owned machines by default, survives partial irreversible failure, and ships complete documentation and canonical AI guidance.

### Files

- commands/admin.sh and uninstall help.
- lib/install/uninstall.sh.
- lib/engine state, ownership, Podman, and lifecycle modules.
- lib/profile/activation.sh where active-engine shutdown coordination is required.
- Installed-control manifests and uninstall allowlists.
- Relevant root, commands, install, engine, profile, common, startup, AI-skill, and test contexts.
- tests/commands/lifecycle.sh.
- tests/commands/surface.sh.
- Engine ownership/journal tests under tests/lib/.
- README.md.
- BOOTSTRAP.md.
- commands/README.md.
- docs/podman.md.
- docs/registries.md.
- docs/prompt-shimmy-project.md.
- CONTRIBUTING.md and AGENTS.md only where repository policy must reflect the new owned-machine lifecycle.
- plugins/shimmy/skills/shimmy-install/SKILL.md.
- plugins/shimmy/skills/shimmy-init/SKILL.md where engine recovery guidance changes.
- Canonical tools/<tool>/SKILL.md files and docs/templates/generic-shim/ only where they currently describe user-managed per-profile machines.
- plans/complete/single-command-uninstall.md and other overlapping historical plans for narrow completion/supersession notes only.

### Implementation requirements and suggested reasoning level

Suggested reasoning level: high. Global uninstall intentionally crosses an irreversible destructive boundary and must fail closed on ambiguous ownership.

- Make standard shimmy admin uninstall plan removal of all engine records whose complete current evidence proves origin shimmy-created.
- Present the destructive warning before mutation in help, interactive/command output, README, uninstall docs, and canonical install skill. State exactly that containers, images, volumes, build caches, and all other VM-local data will not be preserved.
- Preserve legacy-external, ambiguous, mismatched, and Linux host-local engines. Report each preserved engine and reason.
- Preflight the complete uninstall write/delete set, ownership evidence, machine state, running containers, startup paths, skill links, and allowlists before the first deletion.
- Require --stop-running if any owned target machine has running containers. Do not infer this authority from a prior profile activation flag or unrelated command.
- Write one durable uninstall journal with planned order, completed engines, pending engines, and current phase before stopping or deleting the first machine.
- Remove inactive owned isolated machines first. Remove the active owned isolated or shared machine last.
- Revalidate complete ownership evidence immediately before each stop and rm. A changed identity converts that item to preserved/ambiguous and prevents false success.
- Do not attempt transactional rollback of a deleted VM. On partial failure, retain installation commands, engine/profile records, ownership evidence, and journal; print an exact retry command and completed/pending summary.
- Make retry skip already completed deletions only when the journal and absence evidence agree. Unexpected reappearance at the same name is a collision, not proof that deletion failed.
- Remove configuration, startup integration, installed skill links, and engine state only after all planned owned machine removals and existing uninstall phases succeed.
- Extend strict path allowlists for engines/ and lifecycle journals without broad recursive deletion authority.
- Update canonical skill sources, then use the repository's supported reconciliation/generation checks. Never edit generated .agents/skills.
- Resolve retained plan state accurately: accept/close the prerequisite uninstall plan, mark the split create/clone plan superseded, and add narrow notes to stale overlapping plans without rewriting history.

### Verification checklist

- [x] Uninstall dry-run lists exact owned deletion targets, preserved external targets, service/stop actions, running-workload requirements, and irreversible data scope without mutation.
- [x] Standard uninstall removes an idle owned isolated machine and owned shared machine without an extra machine-deletion flag.
- [x] Running workloads cause a pre-mutation refusal unless --stop-running is explicitly supplied.
- [x] Complete matching ownership evidence permits removal; missing or mismatched stable inspect evidence is covered by the global acceptance and host, guest-token, connection, provider, and inspect mismatches remain covered by the engine ownership unit.
- [x] Legacy-migrated and Linux host-local engines survive uninstall.
- [x] Partial failure after one deletion leaves a valid installation and journal; retry completes pending work and refuses a replacement at the reused name.
- [x] Strict allowlist tests cover safe engine/journal paths and reject traversal, foreign engine state, and overlapping journal authority.
- [~] The default three-worker full suite ran. Chunk 4's complete lifecycle group and eight focused engine/journal/surface tests pass. The independent `lib-catalog` group reproducibly fails an unrelated 2026-08-21 literal `TOOL DEFAULT VERSIONS` assertion because the human table pads columns; no Chunk 4 assertion remains failing.
- [x] POSIX shell syntax, `git diff --check`, executable modes, source/rendered surface assets, canonical-skill validation, and modified documentation paths pass. The modified documentation adds no new links.
- [~] Native macOS acceptance created a stopped external fixture in an isolated empty `HOME`/`XDG_CONFIG_HOME`, then stopped before owned-machine creation because local Podman 5.8 rejects the pre-existing bootstrap flag `machine init --update-connection=false`. Compensation left no Shimmy installation or owned machine. The exact external fixture was removed and the isolated namespace was verified empty.
- [~] Native destructive authorization was limited to disposable fixture state in the isolated configuration. Existing `shimmy-default` and `podman-machine-default` were outside that namespace and unchanged; the blocked gate never selected an owned fixture or workload for deletion.
- [x] Final terminology search classified current README/help/ownership text, explicitly historical retained-plan inventory, and legacy schema-2 compatibility assertions. Canonical skills no longer direct users or agents to provision per-profile machines manually.
- [x] `git diff --check` passes and status contains the user-authored Chunk 4 commit plus only intended follow-up implementation, test, and retained-plan evidence changes.

### Chunk 4 acceptance evidence

- `./tests/test.sh --group commands-lifecycle`: all five public lifecycle scenarios pass. The global scenario removes `shared` before active `profile-isolated-one`, preserves `profile-external:external-origin` and `profile-ambiguous:inspect-mismatch`, retains exact pending state after an injected removal failure, rejects a same-name replacement, and completes retry.
- `./tests/test.sh --jobs 3 --group lib-engine --group commands-surface`: all eight tests pass, including ownership proof, uninstall-journal partitioning, strict engine allowlists, help, executable modes, and rendered-source identity.
- A targeted runner-registry acceptance for `test_commands_lifecycle_global_owned_uninstall` also passes independently after fixing active-binding resolution, fresh-process Podman initialization, and the exact reused-name collision diagnostic.
- The default full suite's only independent baseline failure is `lib-catalog`'s whitespace-sensitive human-table header assertion; an isolated `./tests/test.sh --group lib-catalog` reproduces it.
- Native gate evidence: disposable root `/private/tmp/shimmy-chunk4-native.X1AuWz` initially exposed no machines, `chunk4-external` was created stopped, bootstrap failed before `shimmy` creation on Podman 5.8's unknown `--update-connection` flag, only `chunk4-external` remained, and cleanup removed it and the disposable root. The final isolated machine list was empty.
- Podman 5.8 compatibility follow-up: `machine init <name>` replaces the newer flag without changing the existing connection snapshot/restore transaction. `./tests/test.sh --jobs 3 --group lib-engine --group lib-profile-activation` passes all 14 tests. A lifecycle rerun recorded passes for Darwin bootstrap, owned isolated creation/deletion, migration, and global uninstall/retry before the user requested that the remaining lower-value broad workflow scenario be skipped; the runner was then intentionally interrupted.

### Human review gate

Stop. Present exact machines removed and preserved in disposable acceptance, journal/retry evidence, destructive documentation, full test results, canonical guidance changes, superseded-plan updates, failures, uncertainties, and residual risks. Obtain explicit final acceptance before moving this plan to complete.

## Risk register

| Risk | Consequence | Mitigation and acceptance evidence |
| --- | --- | --- |
| Podman changes its user service/socket arrangement | Registry changes cannot be loaded without a VM restart | Detect exact rootless units, fail closed, document supported machine images, and gate on native acceptance; never silently fall back to a restart |
| Service recycle interrupts another client's API call | A concurrent pull/build/command may fail even though workloads stay running | Disclose the bounded interruption, serialize Shimmy operations, validate the new service before commit, and define the policy guarantee boundary |
| An in-flight operation uses the prior policy | Registry behavior briefly straddles activation | Commit active profile only after recycle/validation and document that pre-commit operations may use prior policy |
| Same-name machine is replaced | Shimmy could delete user data | Require matching host token, guest marker, connection identity, and stable inspect evidence immediately before deletion; ambiguity preserves |
| Machine creation partially succeeds | Orphaned VM or lost ownership proof | Journal before init, publish minimal evidence early, compensate only exact matches, retain retry state on cleanup failure |
| Machine deletion partially succeeds | Uninstall cannot roll back | Journal completed/pending work, retain the installation for retry, order deletions deliberately, never report full success early |
| Init changes the user's default connection | Unrelated Podman workflows switch unexpectedly | Capture before init and restore explicitly; test success and compensation paths |
| Old installed controls read new records | Update/bootstrap becomes unusable | Install dual-read controls before publishing records and test old-to-new transition as one chunk |
| Shared engine weakens profile runtime affinity | A shim from an inactive profile runs against shared state | Continue enforcing active profile identity independently of engine connection |
| Registry projection leaks between shared profiles | Wrong mirror/redirect policy is used | One authoritative policy per profile, one explicit engine projection, normalized fingerprints, service validation, commit-last activation |
| User drop-in conflicts with user configuration | Registry semantics become surprising | Use a uniquely named drop-in, document precedence, inspect conflicting exact paths, and never replace the main user registries.conf |
| Provider-specific inspect fields are unstable | Valid owned machines become ambiguous | Record only fields demonstrated stable across stop/start; ambiguity causes preservation rather than deletion |
| Uninstall warning is missed | Unexpected permanent data loss | Repeat warning in help, command output, README/docs, and canonical install guidance; list exact target machines in dry-run/preflight |
| Clone copies transient or ownership state | Corruption or accidental authority transfer | Maintain an explicit clone allowlist and test that new isolated engines receive fresh ownership proof |
| Test doubles diverge from native Podman | Unit tests pass while lifecycle fails | Keep a native macOS gate for service recycling, creation, transitions, and destructive disposable uninstall |
| Overlapping retained plans are executed concurrently | Conflicting naming, provisioning, or uninstall behavior lands | Make prerequisite and supersession state explicit before Chunk 1 and stop if another plan is active in overlapping files |

## Lessons learned

### Initial

- registries.conf is process-cached by the remote Podman API service; changing or relinking the file alone does not make a live service process use the new policy.
- A rootless podman.service recycle with podman.socket retained is materially different from a Podman machine restart: the tested VM boot ID and running container identity/state remained unchanged.
- SIGHUP behavior observed in an older server is not a safe design contract because upstream removed the reload implementation over concurrency and memory-safety concerns.
- containers.conf file-location documentation does not define registries.conf reload behavior. The registry policy belongs to containers/image and must be validated through the actual Podman service boundary.
- A stable user drop-in plus an atomically replaced host-mounted engine projection preserves profile-scoped authority while avoiding guest file mutation on every shared-profile switch.
- Machine names describe routing, not ownership. Destructive authority requires redundant, current, installation-specific proof.
- Irreversible machine deletion requires a forward-recovery journal; ordinary activation and file publication still require compensated rollback.
- Existing update ordering means a schema migration cannot be introduced by changing only the source checkout. Installed readers must become compatible before new state is published.
- Shared execution must not collapse profile identity: active-profile affinity and profile-owned policy remain separate from engine reuse.

### Chunk 1

- The stable machine identity fingerprint can exclude dynamic state while still covering the destructive boundary: name, provider, creation timestamp, config directory, forwarded socket path, exact rootless connection URI, SSH identity path/user, and rootful state were stable and independently observable.
- A fresh Podman installation may have no prior default connection. Machine creation must preserve an exact prior default when present and accept `none` without manufacturing a restoration target.
- Lifecycle phases must record intent before start, stop, guest-marker, and remove mutations. Retaining `initial_machine_state` makes a stopped-machine verification start and an interrupted removal safely retryable.
- Stopped owned machines require a journaled temporary start to verify guest ownership evidence before removal; host records and inspect evidence alone never authorize deletion.
- Podman info exposed the cached registry mapping directly: changing the user drop-in did not affect PID `51024`, while recycling only `podman.service` produced PID `51445` and loaded the new mapping without changing VM boot or sentinel identity.
- The Chunk 1 modules remain unpublished primitives. Existing schema-2 profiles, per-profile machine naming, activation, redirect mutation, help, and uninstall behavior remain unchanged until the compatibility unit in Chunk 2 is reviewed and authorized.

### Chunk 2

- An unbound profile must continue resolving through the schema-2 mapping while migration prepares engine records; installation-wide schema validation remains ambiguous until every binding exists, so create and other schema-dependent mutations fail closed.
- Migration needs its own durable installation-level journal in addition to the machine-create journal. A fresh retry process must re-resolve Podman before compensating retained external machine state.
- POSIX shell module variables are process-global. Any operation that validates other engine records must re-resolve the intended shared engine paths before committing or clearing its lifecycle journal.
- The stable guest drop-in belongs to the engine, while source policy belongs to the profile. Keeping those ownership boundaries separate makes inactive redirect edits source-only and lets active edits compensate source, projection, and service state together.
- Owned shared-machine removal remains deliberately outside Chunk 2. Darwin global uninstall fails closed rather than discard ownership evidence before the durable destructive transaction in Chunk 4 exists.

### Chunk 3

- Target image preparation must follow engine activation for every create and clone mode. A shared target can still differ from the currently active isolated engine, so binding mode alone cannot decide whether early preparation is safe.
- True clone needs lexical locks for both source and target registry policy. The common lock hierarchy therefore permits multiple rank-40 registry locks only in canonical profile-name order, matching its existing multi-profile rule.
- A stopped owned machine cannot supply live guest evidence during deletion preflight. Host ownership may authorize a journaled verification start, but the machine is removed only after the running guest marker is revalidated.
- An irreversible machine removal journal must outlive partial profile cleanup. Retry accepts either a partially removed or absent profile root, removes only the known allowlist, and finalizes engine evidence after the local profile is gone.
- Registry redirects must be parsed under the source identity and re-rendered under the clone identity. Copying bytes would preserve a foreign ownership header even when the policy entries are valid.
- Fake Podman state must model the post-transition running machine and default connection explicitly. Persisting the prior shared default in a later command correctly causes active-engine validation to fail.

### Chunk 4

- A complete global destructive preflight must advance every intended engine through journaled guest verification and a revalidated stopped state before the first machine removal. Per-item verification immediately before each deletion is insufficient for the installation-wide preflight contract.
- Profile path resolution does not resolve an engine binding. Global uninstall must explicitly resolve the active profile's binding before ordering inactive engines and the active engine; otherwise stale process-global engine state can put the active engine first.
- A fresh retry process that reads an existing Darwin uninstall journal must re-resolve the Podman binary before any machine or connection query. Initial-plan setup is not retained across commands.
- A same-name replacement detected from a pending lifecycle journal is safely preserved only when the refusal also reaches the user as an explicit collision diagnostic. A generic retained-journal error is operationally safe but does not provide the exact recovery evidence the contract requires.
- The global journal must distinguish planned order from completed, pending, and skipped/preserved partitions. Moving a newly ambiguous target out of pending requires an arbitrary-item transition rather than assuming only the head can change disposition.
- The original native acceptance failed before the chunk's destructive boundary because Podman 5.8 rejected `machine init --update-connection=false`. The compatibility follow-up now uses `machine init <name>` and retains explicit prior-default restoration; destructive native acceptance remains intentionally pending.
- Full-suite evidence must distinguish chunk regressions from a reproducible baseline assertion. The catalog human-table test currently assumes single header spaces even though formatting pads columns for long tool names; Chunk 4's focused and lifecycle groups pass independently.

## Session bootstrap

For each execution session:

1. Read the repository root AGENTS.md, CONTRIBUTING.md, root CONTEXT.md, this plan, and every retained child CONTEXT.md on the path to files in the current chunk.
2. Inspect git status and preserve unrelated user changes. At plan creation, unrelated plan moves already existed; do not normalize or revert them.
3. Confirm the prior chunk and human review gate are explicitly accepted. For Chunk 1, confirm this plan and the single-command uninstall prerequisite state.
4. Confirm no overlapping retained plan is active. In particular, do not execute plans/wip/split-profile-create-clone.md in parallel.
5. Reinspect current Podman client/server versions and supported machine provider without mutation.
6. Use the repository test runner's default bounded parallel execution; specify --jobs 3 when an explicit concurrency value is useful. Use serial execution only for the documented exceptions.
7. Use live Podman only for bounded, explicitly identified acceptance. Destructive native tests must target machines created as disposable fixtures by the current test and must never infer ownership from names.
8. Update this plan's checklist and Lessons learned as work proceeds.
9. Follow the six-step Execution protocol and stop at the current human review gate.
