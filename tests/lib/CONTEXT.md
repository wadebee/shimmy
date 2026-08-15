# Shared-library test modules

These modules validate shared `lib/` catalog, runtime, and update behavior
without starting tool containers. They are sourced by `../test.sh` and use
`../support.sh` for fixtures and assertions.

## Files

- `catalog.sh` validates exact catalog schema rejection, metadata discovery,
  all-version native-platform previews, image configuration failures, and
  local cache identity.
- `runtime.sh` validates the shared Podman OS/architecture resolver, required
  platforms, fail-closed behavior, preview helpers, and installed Darwin
  profile-affinity enforcement.
- `profile-activation.sh` validates deterministic engine state, workload-aware
  Darwin switching, dry runs, commit-last connection selection, and
  failure-injected rollback reporting through a fake Podman command seam.
- `registries.sh` validates strict endpoint grammar, exact managed-file
  parsing/rendering, deterministic mutation, side-effect-free dry runs,
  adjacent locking, and exact rollback after injected post-commit failure.
- `update.sh` validates generic dispatch to version-local refresh hooks and the
  shared `pull`/`build` contract.
