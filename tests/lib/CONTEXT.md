# Library tests

- `runner.sh`: registry, option parsing, deterministic workers, signals, result
  integrity, and safe copy helpers.
- `catalog.sh`: payload/header/fingerprint validation, immutable generation
  create/publish/rollback, pristine baseline, recovery, and collision safety.
- `codec.sh`: safe names, commits, SHA-256 vectors, manifest encoding/redaction.
- `profile-state.sh`: active/catalog/profile schema round trips and integrity.
- `ai-skill-state.sh`: bundle identity and cross-bundle profile validation.
- `lock.sh`: hierarchy, contention, stale-owner cleanup, signals, release.
- `transaction.sh`: same-filesystem and external compensation boundaries.
- `ai-skill-link.sh`: exact collision planning, mutation, preservation, rollback.
- `runtime.sh`: native platform, preview, schema-2 affinity, POSIX syntax, modes,
  and unreachable guidance.
- `engine.sh`: strict unpublished engine records, exact Podman routing,
  redundant ownership proof, lifecycle journals, projection transactions, and
  rootless service recycling.
- `profile-activation.sh`: Linux/Darwin engine and registry transition state.
- `registries.sh`: endpoint/config/record/link/edit ownership and rollback.

Use the lowest-cost proof for negative invariants and keep one authoritative
test for each durable rejection boundary.
