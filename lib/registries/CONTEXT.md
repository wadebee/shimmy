# Registry redirects

`registries.sh` owns the strict, profile-specific containers/image version-2
registry configuration at `<profile-root>/registries.conf`. The file is a
regular non-symlink with exact profile and format markers and contains only
prefix-sorted `[[registry]]` tables with `prefix` and replacement `location`.
It never emits fallback-capable mirrors, search settings, credentials, or TLS
policy.

Redirect edits validate the complete existing file, use the adjacent
`.registries.lock` directory, stage a non-`.conf` regular file in the profile,
set mode `0644`, and replace the authoritative file atomically. Dry runs render
the full candidate without locking or mutation.

On Linux, activation owns only
`<config-home>/containers/registries.conf.d/shimmy-active-profile.conf`, an
absolute symlink to one canonical profile config. Link creation/switching and
active edits validate fresh local-rootless Podman processes and restore exact
prior state on failure. Detach and uninstall remove only the exact invoking
profile link. Foreign, dangling, unsafe, or masking state fails closed.

On Darwin, activation owns only the exact root-managed VM symlink
`/etc/containers/registries.conf.d/shimmy-profile.conf` and the strict local
`<profile-root>/machine-projection.txt` identity/fingerprint record. A fixed
root SSH script accepts only validated action/path arguments, while a separate
rootless SSH process validates same-path source visibility, exact link target,
readability, and fingerprint. Projection precedes engine validation; record
creation and global default selection follow it. Rollback covers link and
record state. Stale running policy requires explicit restart. Detach accepts
only exact owned state or a valid record with a machine proven absent; stopped,
unreachable, foreign, and damaged state fails without mutation. Uninstall
refuses any retained valid record. Tool-container policy mounting remains
unimplemented.

## Parent context

- [shared library](../CONTEXT.md)
