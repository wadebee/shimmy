# Shared-library test modules

These modules validate shared `lib/` catalog, runtime, and update behavior
without starting tool containers. They are sourced by `../test.sh` and use
`../support.sh` for fixtures and assertions.

## Files

- `runner.sh` directly validates canonical registry ordering, group selection,
  option rejection, timing record shape, indivisible lifecycle grouping,
  bounded one-, two-, and three-worker scheduling, deterministic replay and
  count aggregation, injected worker failures, missing and mismatched results,
  recorded-PID signal cleanup, the background-group kernel-SIGINT guard, and
  fixture-tree clone selection, portable fallback, target boundaries, metadata
  preservation, and mutation independence without recursively invoking the
  repository suite.
- `catalog.sh` validates exact catalog schema rejection, metadata discovery,
  all-version native-platform previews, image configuration failures, and
  local cache identity.
- `target-codec.sh` validates fixed target name, commit, SHA-256, generation,
  manifest encoding/decoding, and diagnostic-redaction vectors.
- `target-profile-state.sh` validates deterministic active, catalog-registry,
  generation, and profile-manifest target formats plus disposable roots and
  durable cross-record integrity failures, including two-field shim policy and
  sole-default version ownership.
- `target-ai-skill-state.sh` validates both target bundle kinds, exact content
  fingerprints, complete profile consistency, bundle drift, source/pin
  mismatch, and cross-bundle collision rejection.
- `target-lock.sh` validates the target lock hierarchy, lexical profile order,
  atomic owner claims, reverse release, live concurrency rejection, classified
  stale-owner cleanup, exact ownership checks, and signal cleanup.
- `target-transaction.sh` failure-injects private same-filesystem candidates,
  under-lock authority revalidation, atomic replacement and exact rollback,
  plus complete/incomplete external compensation and honest foreign-content
  reporting.
- `target-ai-skill-link.sh` classifies exact bundle destinations without
  mutation, overwrites declared file/directory/link collisions, preserves
  unrelated sibling bytes and the user root itself, rejects undeclared names,
  and restores recognized Shimmy links.
- `target-catalog.sh` validates canonical skill alignment and fingerprint
  inputs, then exercises private default-catalog creation, local inspection,
  clean-main publication, repeat publication, rollback, invalid-current
  recovery, immutable retention, and publication authority failures.
- `runtime.sh` validates the executable root `bootstrap.sh` and minimal source
  checkout contract, shared Podman OS/architecture resolver, required
  platforms, fail-closed behavior, preview helpers, and installed Darwin
  profile-affinity plus current registry-projection enforcement and exact
  shared activation or restart recovery guidance.
- `profile-activation.sh` validates deterministic engine state, workload-aware
  Darwin switching and registry projection, Linux registry-link transitions,
  side-effect-free conservative recommendations, dry runs, fixed root/rootless
  ordering, fingerprint freshness, explicit
  restart, cleanup start/stop/restoration primitives, commit-last selection,
  and failure-injected rollback reporting through a fake Podman command seam.
- `registries.sh` validates strict endpoint grammar, exact managed-file
  parsing/rendering, deterministic mutation, side-effect-free dry runs,
  adjacent locking, strict Darwin projection records and detach primitives,
  atomic replacement, and exact rollback after injected post-commit failure.
- `update.sh` validates generic dispatch to version-local refresh hooks and the
  shared `pull`/`build` contract.
