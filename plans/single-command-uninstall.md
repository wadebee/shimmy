# Single-command clean Shimmy uninstall

**Status:** Review

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
  shimmy uninstall [--global] [--stop-running] [--shell <name>] [--startup-file <path> ...]
  ```

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
- The standalone `profile redirect remove --all --detach` behavior remains available and unchanged.
- No manifest or projection-record schema change is required.

## Verified implementation inventory

- `lib/install/uninstall.sh` currently rejects any valid Darwin projection record; global uninstall has the same refusal.
- Darwin detach and rollback are implemented in `lib/registries/registries.sh`, but stopped machines are rejected and the helper releases its registry lock before uninstall could reacquire it.
- Machine discovery, workload guarding, transitions, and restoration are owned by `lib/profile/activation.sh`, which the uninstall control path does not currently load.
- Current lifecycle tests explicitly require profile/global uninstall refusal and must be replaced with single-command cleanup coverage.
- Normative refusal/manual-detach guidance exists in root and child contexts, README/command documentation, Podman/registry documentation, and the canonical `shimmy-install` skill.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Implement, verify, and document transactional single-command uninstall cleanup.

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

- [ ] Ordinary Darwin uninstall succeeds from an exact running projection, logs detach plus restart, removes the profile, and leaves no VM link or local record.
- [ ] Stopped-profile cleanup performs start → verify → detach → stop and restores the original default connection.
- [ ] An idle alternate machine is stopped and restored; containers block this without `--stop-running`, while acknowledged execution succeeds with a warning.
- [ ] Proven-missing machines use record-only cleanup without provisioning.
- [ ] Invalid records/configuration, foreign or absent links, overrides, unavailable workload inspection, unreachable engines, and held locks fail before profile deletion.
- [ ] Injected start, stop, detach, restart, restoration, and default-connection failures exercise complete and incomplete rollback reporting while retaining recoverable profile state.
- [ ] Global uninstall detaches both profiles before deleting either, restores initial machine/default state, and removes catalogs only after profile cleanup succeeds.
- [ ] A later global detach failure reprojects earlier detached profiles and leaves both profiles and catalogs intact.
- [ ] Linux exact-link cleanup, sibling isolation, operator policy preservation, startup cleanup, source-checkout preservation, and external-skill preservation remain covered.
- [ ] Help and parser tests cover `--stop-running`, duplicates, invalid combinations, and the absence of manual prerequisite guidance.
- [ ] Run targeted groups:

  ```sh
  ./tests/test.sh --serial \
    --group lib-profile-activation \
    --group lib-registries \
    --group commands-lifecycle \
    --group commands-install \
    --group commands-management \
    --group commands-profile
  ```

- [ ] Run the complete default suite with `./tests/test.sh`.
- [ ] Perform native macOS acceptance only against explicitly prepared disposable profiles and pre-existing deterministic machines; record before/after machine, connection, workload, VM-link, record, profile, and catalog state.

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

## Session bootstrap

Read `AGENTS.md`, root `CONTEXT.md`, this plan, the install/profile/registry/test child contexts, and the core lifecycle files listed above. Confirm the worktree remains free of unrelated overlapping changes. Implement only Chunk 1, preserve POSIX shell architecture and generated-adapter boundaries, update the checklist and lessons with evidence, and stop at the human review gate.
