# Podman runtime

`podman.sh` resolves Podman, normalizes supported Linux/Darwin CPU aliases to
native `linux/amd64` or `linux/arm64`, owns preview/privileged behavior, and
enforces schema-2 arbitrary-name installed-profile affinity. Darwin runs require
the active record, deterministic rootless connection, and current registry
projection; connection/registry overrides fail closed.

`image.sh` validates version-owned `image.conf`, supplies immutable external and
local-build defaults, hashes complete local build inputs, and removes stale
tagged images after rebuild. `log.sh` provides runtime logging.

Installed copies are self-contained below each profile and do not depend on the
source checkout. Source previews bypass installed-profile affinity.
