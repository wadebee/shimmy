# Shared-library test modules

These modules validate shared `lib/` catalog, runtime, and update behavior
without starting tool containers. They are sourced by `../test.sh` and use
`../support.sh` for fixtures and assertions.

## Files

- `runner.sh` directly validates canonical registry ordering, group selection,
  option rejection, timing record shape, and indivisible lifecycle grouping
  without recursively invoking the repository suite.
- `catalog.sh` validates exact catalog schema rejection, metadata discovery,
  all-version native-platform previews, image configuration failures, and
  local cache identity.
- `runtime.sh` validates the shared Podman OS/architecture resolver, required
  platforms, fail-closed behavior, preview helpers, and installed Darwin
  profile-affinity plus current registry-projection enforcement.
- `profile-activation.sh` validates deterministic engine state, workload-aware
  Darwin switching and registry projection, Linux registry-link transitions,
  dry runs, fixed root/rootless ordering, fingerprint freshness, explicit
  restart, commit-last selection, and failure-injected rollback reporting
  through a fake Podman command seam.
- `registries.sh` validates strict endpoint grammar, exact managed-file
  parsing/rendering, deterministic mutation, side-effect-free dry runs,
  adjacent locking, strict Darwin projection records, atomic replacement, and
  exact rollback after injected post-commit failure.
- `update.sh` validates generic dispatch to version-local refresh hooks and the
  shared `pull`/`build` contract.
