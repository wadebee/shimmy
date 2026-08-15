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
the full candidate without locking or mutation. Chunk 3 data is preparation
only: no host link, machine projection, Podman validation, or registry-client
mount consumes it yet.

## Parent context

- [shared library](../CONTEXT.md)
