# Registry redirects

`registries.sh` owns the strict, profile-specific containers/image version-2
registry configuration at `<profile-root>/registries.conf`. The file is a
regular non-symlink with exact profile and format markers and contains only
prefix-sorted `[[registry]]` tables with `prefix` and replacement `location`.
It never emits fallback-capable mirrors, search settings, credentials, or TLS
policy.

Redirect edits validate the complete existing file, use the adjacent registry
lock, stage a non-`.conf` regular file in the profile, set mode `0644`, and
replace the authoritative file atomically. Dry runs render the full candidate
without locking or mutation and report the shared-engine service action.
Inactive edits change only their profile source. Active edits compensate the
source and engine projection together.

On Linux, activation owns only
`<config-home>/containers/registries.conf.d/shimmy-active-profile.conf`, an
absolute symlink to one canonical safe-name profile config. Link creation/switching and
active edits validate fresh local-rootless Podman processes and restore exact
prior state on failure. Detach and uninstall remove only the exact invoking
profile link. Foreign, dangling, unsafe, or masking state fails closed.

On Darwin, migrated shared and newly owned isolated engines use a stable guest-user drop-in targeting
the host-mounted `<config-root>/engines/<id>/registries.conf`. The engine
projection records source profile/path and source/effective/loaded
fingerprints. Changed effective policy recycles only rootless
`podman.service`; equal policy is a no-op, and rollback restores both source and
loaded projection. Legacy-unmigrated and legacy-isolated activation retains the
exact root-managed VM symlink
`/etc/containers/registries.conf.d/shimmy-profile.conf` and strict local
`<profile-root>/machine-projection.txt` record. A fixed
root SSH script accepts only a normalized safe-name profile path with regular,
non-symlink parent/profile/config state, while a separate
rootless SSH process validates same-path source visibility, exact link target,
readability, and fingerprint. Projection precedes engine validation; record
creation and global default selection follow it. Rollback covers link and
record state. Stale running policy requires explicit restart. Standalone
detach accepts only exact owned state or a valid record with a machine proven
absent; stopped, unreachable, foreign, and damaged state fails without
mutation. Internal prepare/remove/rollback/finalize primitives let uninstall
retain records through external cleanup, handle stopped machines through the
activation transaction, and reproject exact links after a later failure.

The registry-client resolver recognizes only canonical materialized profiles.
It omits a mount when no Shimmy activation exists, returns the invoking
profile's authoritative config for current Linux or Darwin state, and fails
closed on sibling, damaged, unsafe, stale, or registry-overridden state.
Clients require the installation active record to name the invoking arbitrary
profile. Profile orchestration may supply an already-held registry lock;
standalone redirect mutation owns the adjacent lock directly.

The engine projection primitive normalizes canonical entries independently of
the profile ownership header and atomically stages an engine-local copy. Managed
shared/isolated activation and active redirect commands route through it.
Skopeo is the only initial consumer and mounts the result read-only at the
same fixed container drop-in path; image verification inherits that behavior
through the active profile's Skopeo runtime.

## Parent context

- [shared library](../CONTEXT.md)
