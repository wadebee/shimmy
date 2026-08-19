# Single-command clean Shimmy uninstall

**Status:** Chunk 1 human review

## Objective

Make ordinary and global uninstall complete their own registry-projection prerequisites:

- `shimmy uninstall` removes the invoking profile without a separate `profile redirect remove --all --detach`.
- `shimmy uninstall --global` cleans every owned profile before removing shared catalogs.
- Darwin cleanup handles running, stopped, and proven-missing deterministic machines, clears live registry-policy cache, and restores the initial machine/default-connection state.
- Preserve user-owned Podman machines and connections, sibling profiles during ordinary uninstall, bound checkouts, operator registry policy, and external skill exports.
- Continue failing closed for invalid manifests/configuration, foreign projections, unsafe paths, unavailable metadata, concurrent transactions, and incomplete rollback.

## Recorded design decisions

- Extend the public interface to:

  ```text
  shimmy uninstall [--global] [--stop-running]
  ```

- Startup cleanup is limited to the `startup_file` entries owned by each
  profile manifest. Uninstall rejects the install-only `--shell` and
  `--startup-file` selectors rather than accepting arbitrary cleanup targets.
- `--stop-running` uses the existing activation semantics: display affected containers and require explicit acknowledgment before any planned machine stop. Reject duplicate, install-time, or unnecessary use.
- Do not add `--dry-run`.
- Never create, adopt, rename, or delete Podman machines or connections.
- On Darwin:
  - A running attached machine is detached and restarted to clear cached registry policy.
  - A stopped attached machine is temporarily started, verified, detached, and returned to stopped state.
  - An alternate running machine is restored after cleanup; workloads block transitions unless acknowledged.
  - A proven-missing expected machine permits record-only cleanup.
  - Unreachable engines, invalid metadata, overrides, and absent/foreign/damaged remote links fail before profile removal.
- On Linux, retain exact-link cleanup and foreign-state refusal; no machine operations occur.
- Global uninstall acquires the activation lock first, then profile registry locks in deterministic `default`, `upstream` order. It revalidates all state under lock and detaches every projection before deleting any profile.
- Keep each valid config and projection record until external cleanup and engine restoration succeed. If pre-commit cleanup fails, reapply already-detached exact links, restore the initial machine/default state, retain all profiles/catalogs, and report incomplete rollback explicitly if necessary.
- Commit the Darwin projection transaction after every real projection record has been removed while every rollback backup still exists. Delete those backups only as post-commit cleanup so finalize failures and signal cleanup cannot invoke rollback with partially destroyed recovery material.
- The standalone `profile redirect remove --all --detach` behavior remains available and unchanged.
- No manifest or projection-record schema change is required.

## Verified implementation inventory

- `lib/install/uninstall.sh` now coordinates activation and registry locks, preflight, Darwin projection cleanup, engine restoration, local commit, and rollback for profile and global scope.
- Reusable prepare, detach, and rollback primitives in `lib/registries/registries.sh` preserve standalone redirect-removal behavior while allowing uninstall to retain its transaction locks.
- Projection cleanup now clears its transaction-active flag after all local records are removed and before deleting any rollback backup; post-commit finalization failures report the committed state without entering rollback.
- Cleanup-specific engine validation, switching, restart, and restoration support in `lib/profile/activation.sh` handles running and stopped deterministic machines without creating, adopting, renaming, or deleting them.
- Lifecycle, parser, help, registry, and activation tests cover single-command cleanup, rejection of install-only startup selectors, workload acknowledgment, failure injection, rollback, and preserved Linux/ownership behavior.
- Root and child contexts, README/command documentation, Podman/registry/testing documentation, and the canonical `shimmy-install` skill describe manual detach as recovery/debugging rather than an uninstall prerequisite.

## Unresolved

None.

## Progress Checklist

- [~] Chunk 1 — Implementation, documentation, and automated verification are complete; native macOS acceptance is deferred for explicit preparation at the human review gate.

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

## Chunk 1 — Transactional uninstall cleanup

### Goal

Make projection teardown, live-cache clearing, machine-state restoration, and local profile removal one guarded uninstall operation for both profile and global scope.

### Files

- Core lifecycle: `lib/install/{install,request,uninstall}.sh`, `lib/profile/activation.sh`, and `lib/registries/registries.sh`.
- Behavioral coverage: profile-activation, registry, install-request, management-help, and lifecycle test modules.
- Guidance: applicable `CONTEXT.md` files, README and command reference, Podman/registry/testing documentation, and `plugins/shimmy/skills/shimmy-install/SKILL.md`. Do not edit generated `.agents/skills/` adapters.

### Implementation requirements

- Load and initialize profile-activation cleanup support from the installed uninstall path; ensure EXIT/signal traps release activation and registry locks without masking failures.
- Refactor projection detach into internal prepare/commit/rollback primitives usable by both redirect removal and uninstall. Uninstall-specific detach must not empty `registries.conf` or recursively invoke the profile launcher.
- Build a complete uninstall preflight before mutation:
  - Validate manifests, registries, projection records, catalog ownership, lock paths, deterministic machine/connection metadata, overrides, workloads, and planned restoration.
  - Revalidate ownership and live state after acquiring locks.
- Execute Darwin cleanup as a transaction:
  - Snapshot initial running machine and default connection.
  - Detach only the exact recorded link.
  - Restart initially running projected machines after detach to clear cache.
  - Temporarily start stopped projected machines for verification/detach and return them to stopped state.
  - Restore the initial running machine and default connection before local deletion.
  - Warn that acknowledged workloads may not resume automatically.
- For global uninstall, retain rollback data for every profile until all projections are detached and the initial engine state is restored. Only then remove records, profiles, and finally shared catalogs.
- Preserve existing ownership boundaries and Linux behavior. Unsupported hosts may remove profiles without projection records but must refuse a retained Darwin record they cannot safely clean.
- Update help and user guidance so manual detach is recovery/debugging functionality, not a normal uninstall prerequisite.

### Verification checklist

- [x] Ordinary Darwin uninstall succeeds from an exact running projection, logs detach plus restart, removes the profile, and leaves no VM link or local record.
- [x] Stopped-profile cleanup performs start → verify → detach → stop and restores the original default connection.
- [x] An idle alternate machine is stopped and restored; containers block this without `--stop-running`, while acknowledged execution succeeds with a warning.
- [x] Proven-missing machines use record-only cleanup without provisioning.
- [x] Invalid records/configuration, foreign or absent links, overrides, unavailable workload inspection, unreachable engines, and held locks fail before profile deletion.
- [x] Injected start, stop, detach, restart, restoration, and default-connection failures exercise complete and incomplete rollback reporting while retaining recoverable profile state.
- [x] Global uninstall detaches both profiles before deleting either, restores initial machine/default state, and removes catalogs only after profile cleanup succeeds.
- [x] A later global detach failure reprojects earlier detached profiles and leaves both profiles and catalogs intact.
- [x] A second-profile backup-finalize failure and INT/TERM cleanup after the first backup is deleted do not invoke rollback, retain the committed record removals, and permit a clean retry.
- [x] Linux exact-link cleanup, sibling isolation, operator policy preservation, startup cleanup, source-checkout preservation, and external-skill preservation remain covered.
- [x] Help and parser tests cover `--stop-running`, duplicates, rejection of
  `--shell` and `--startup-file`, invalid combinations, and the absence of
  manual prerequisite guidance.
- [x] Run targeted groups (after removing the uninstall startup selectors,
  `commands-lifecycle`, `commands-management`, and `commands-install` passed
  all 24 tests):

  ```sh
  ./tests/test.sh --serial \
    --group lib-profile-activation \
    --group lib-registries \
    --group commands-lifecycle \
    --group commands-install \
    --group commands-management \
    --group commands-profile
  ```

- [x] Run the complete default suite with `./tests/test.sh` (165 tests passed
  after the uninstall startup-selector removal and background-group SIGINT
  guard; exit status 0).
- [~] Perform native macOS acceptance only against explicitly prepared disposable profiles and pre-existing deterministic machines; record before/after machine, connection, workload, VM-link, record, profile, and catalog state.
  - Passed: the stateful fake-Podman acceptance seam covers running, stopped, alternate, missing, workload, rollback, and global ordering cases in the automated suite.
  - Remaining: exercise the same matrix against native Podman machines and capture before/after state.
  - Reason: no disposable profiles or pre-existing deterministic machines were explicitly prepared for this implementation session; using developer state would violate the acceptance constraint.
  - Impact: this does not block source review or automated acceptance, but native macOS/Podman behavior remains unconfirmed and must not be claimed as accepted.
  - Next action: the reviewer either prepares the disposable profiles/machines for native acceptance or explicitly accepts deferral before closing Chunk 1.

### Human review gate

Confirm single-command profile/global cleanup, workload acknowledgment, live-cache clearing, exact ownership, rollback behavior, machine/default restoration, documentation consistency, and native macOS evidence. Acceptance authorizes only this implementation unit.

## Risk register

- **Workload interruption:** Restart-based cache clearing can stop containers. Mitigate with enumeration, explicit `--stop-running`, and post-transition warnings.
- **Cross-profile partial cleanup:** Global detach spans external and local state. Mitigate with deterministic locks, retained records/configs, detach-all-before-delete ordering, and reprojection rollback.
- **Machine restoration failure:** A failed restart may leave Podman state changed. Keep profiles intact, attempt bounded restoration, and report incomplete rollback without stronger machine operations.
- **Concurrent lifecycle changes:** Revalidate under activation and profile locks; never remove or bypass an existing lock.
- **Ownership mistakes:** Continue accepting only canonical profiles, strict records, exact VM links, and deterministic rootless connections.

## Lessons learned

### Initial

- The current refusal was intentional protection against dangling external VM links; automatic cleanup must preserve that ownership guarantee.
- Existing detach, registry, activation, and uninstall operations use different lock boundaries. Reusing the public detach command directly would create a race and cannot handle stopped machines.
- Clearing persistent projection state and clearing a running service's cached policy are separate operations; the selected behavior requires guarded restart and restoration.

### Chunk 1

- A valid projection record must remain the recovery anchor until remote detach and machine/default restoration have both succeeded; deleting it earlier makes exact rollback unverifiable.
- Recovery backups must remain complete until every local projection record has been removed and the transaction is atomically marked committed; destroying backups while rollback remains armed creates an unrecoverable signal/failure window.
- Test groups run as background processes even with `--serial`; POSIX child shells can inherit SIGINT as ignored, so signal-boundary group tests must invoke the installed cleanup handler directly. The runner now rejects kernel-level SIGINT delivery inside groups before it can hang or falsely pass.
- Stopped-machine cleanup is safe only when temporary engine transitions and registry mutation remain within the same activation-plus-profile-lock transaction.
- Global cleanup must hold the shared catalog lock across profile commit and catalog removal so another lifecycle operation cannot observe a partially committed ownership state.
- Stateful failure tests must model whether a projection was actually changed; otherwise rollback assertions can pass while exercising an impossible external state.
- Uninstall startup cleanup must derive exclusively from manifest ownership;
  exposing install-time startup selectors on uninstall creates a misleading and
  unnecessarily broad deletion surface.

## Session bootstrap

Chunk 1 is at its human review gate. Review the implementation and automated evidence above, then either prepare disposable native macOS profiles/machines for the remaining acceptance item or explicitly accept its deferral. Do not begin another implementation unit without explicit acceptance.
