# Podman runtime

`podman.sh` resolves Podman, normalizes supported Linux/Darwin CPU aliases to
native `linux/amd64` or `linux/arm64`, owns preview/privileged behavior, and
requires the invoking profile's strict published engine binding while enforcing
profile affinity. Two profiles sharing one Darwin connection still
cannot run concurrently: the active record and current engine projection must
name the invoking profile. Shared and isolated bindings retain the same
profile-scoped authority; connection/registry overrides fail closed.

`image.sh` validates version-owned `image.conf`, supplies immutable external and
local-build defaults, hashes complete local build inputs, and removes stale
tagged images after rebuild. `log.sh` provides runtime logging.

`preflight-review.sh` contains dormant extraction seams for source-only timing
and call-ownership review. No production runtime sources it. Its context and
reachability split mirrors the current `podman.sh` preflight but does not alter
the live call graph or select a future runtime policy.

Installed copies are self-contained below each profile and do not depend on the
source checkout. Source previews bypass installed-profile affinity.
