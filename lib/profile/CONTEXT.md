# Profiles

`profile.sh` resolves canonical XDG installation/profile paths for arbitrary
safe names and preserves the legacy `shimmy-<profile>` mapping for unbound
schema-2 profiles. Published bindings route migrated profiles through the
engine registry.

`state.sh` reads/renders mode-0644 active records and schema-2 profile manifests,
then validates profile, catalog generation, shim/version, startup, and AI-skill
bundle state as one read-only authority.

`management.sh` implements installation-wide list, invoking-profile status,
create/activate/delete routing, and redirects. Activation validates candidate
materialization, holds activation then lexical profile/registry locks, defers
engine commit, and compensates active-record and exact user-skill link changes.
Same-profile activation lets the target activation layer validate and repair
its own inactive engine or registry state. A cross-profile transition still
requires the recorded active profile to be fully active before planning and
again after locks are acquired so it remains a validated rollback source.

`activation.sh` owns deterministic engine discovery, read-only status, dry-run,
Linux registry-link selection and local-rootless validation, shared Darwin
policy projection/service recycle, legacy workload-guarded transitions,
commit-last default selection, and rollback. Fresh shared provisioning remains
an install lifecycle operation, not an activation side effect.

The schema-1 modules under `lib/engine/` provide machine identity, ownership,
journal, service-recycle, projection, registry, and migration primitives. They
do not activate profiles; this module remains the sole active-engine authority.

`transaction.sh` is the external compensation journal. It restores registered
Shimmy state in reverse and reports overwritten foreign skill content as
irrecoverable rather than claiming recovery.
