# Podman runtime

`podman.sh` resolves Podman, normalizes supported Linux/Darwin CPU aliases to
native `linux/amd64` or `linux/arm64`, owns preview/privileged behavior, and
dual-reads legacy schema-2 or published engine bindings while enforcing
invoking-profile affinity. Two profiles sharing one Darwin connection still
cannot run concurrently: the active record and current engine projection must
name the invoking profile. Connection/registry overrides fail closed.

`image.sh` validates version-owned `image.conf`, supplies immutable external and
local-build defaults, hashes complete local build inputs, and removes stale
tagged images after rebuild. `log.sh` provides runtime logging.

Installed copies are self-contained below each profile and do not depend on the
source checkout. Source previews bypass installed-profile affinity.
