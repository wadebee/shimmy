# Library tests

- `runner.sh`: exact lifecycle scenario mappings, registry and option parsing,
  deterministic workers, timing-gated setup/group progress, failure/signal
  evidence, result integrity, and safe immutable-template copy helpers.
- `catalog.sh`: payload/header/fingerprint validation with display-padding-neutral
  header checks, immutable generation create/publish/rollback, pristine
  baseline, recovery, and collision safety.
- `codec.sh`: safe names, commits, SHA-256 vectors, manifest encoding/redaction.
- `profile-state.sh`: active/catalog/profile schema round trips and integrity.
- `ai-skill-state.sh`: bundle identity and cross-bundle profile validation.
- `lock.sh`: hierarchy, contention, stale-owner cleanup, signals, release.
- `transaction.sh`: same-filesystem and external compensation boundaries.
- `ai-skill-link.sh`: exact collision planning, mutation, preservation, rollback.
- `runtime.sh`: native platform, preview, dual-read profile affinity, POSIX syntax, modes,
  and unreachable guidance.
- `engine.sh`: strict published engine and uninstall-journal records, exact
  Podman routing, redundant ownership proof, lifecycle journals, arbitrary
  pending-to-preserved transitions, pre-init ambiguity retention, exact
  initialized rollback, projection transactions, and rootless service
  recycling.
- `profile-activation.sh`: generated fake-Podman init mutation boundaries plus
  Linux, legacy-Darwin, and managed shared/isolated Darwin engine and registry
  transition state.
- `registries.sh`: endpoint/config/record/link/edit ownership and rollback.

Use the lowest-cost proof for negative invariants and keep one authoritative
test for each durable rejection boundary.
