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
Darwin machine projection and tool-container mounting are not implemented yet.

## Parent context

- [shared library](../CONTEXT.md)
