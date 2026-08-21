# Profiles

`profile.sh` resolves canonical XDG installation/profile paths for arbitrary
safe names, maps engine identity to `shimmy-<profile>`, and validates schema-2
runtime identity.

`state.sh` reads/renders mode-0644 active records and schema-2 profile manifests,
then validates profile, catalog generation, shim/version, startup, and AI-skill
bundle state as one read-only authority.

`management.sh` implements installation-wide list, invoking-profile status,
create/activate/delete routing, and redirects. Activation validates candidate
materialization, holds activation then lexical profile/registry locks, defers
engine commit, and compensates active-record and exact user-skill link changes.

`activation.sh` owns deterministic engine discovery, read-only status, dry-run,
Linux registry-link selection and local-rootless validation, workload-guarded
Darwin transitions, same-path registry projection, commit-last default
selection, and rollback. It never provisions or removes a VM.

`transaction.sh` is the external compensation journal. It restores registered
Shimmy state in reverse and reports overwritten foreign skill content as
irrecoverable rather than claiming recovery.
