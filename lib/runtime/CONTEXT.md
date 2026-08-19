# Podman runtime

- `podman.sh` resolves Podman, normalizes supported Linux/Darwin host CPU
  aliases to the native `linux/amd64` or `linux/arm64` image platform, exposes
  that required-platform set, and owns preview, privileged-connection, and
  installed Darwin profile-affinity checks. Real installed tool runs require
  the invoking profile's rootless connection to be the reachable global
  default and require a valid, current Darwin registry projection whose VM
  link, rootless-visible fingerprint, and local record match the authoritative
  profile config. Registry and connection overrides fail closed. Installed
  affinity consumes the shared profile state reader and recommendation resolver
  so recovery guidance uses the exact safe activation or restart command
  without duplicating engine discovery. Source
  previews retain their behavior. Successful Darwin registry affinity leaves
  current-state evidence for the shared registry-client mount resolver so a
  Skopeo run does not repeat remote projection inspection.
- `image.sh` validates version-owned `image.conf` metadata, supplies configured
  external defaults and local base-image build arguments, hashes complete local
  image inputs, and removes stale tagged images after a version-owned rebuild.
- `log.sh` provides shared runtime logging.

Callers sourcing `image.sh` must set `SHIMMY_RUNTIME_DIR` to this directory so
its sibling modules resolve correctly. Installed copies live in each
materialized profile's `lib/runtime/` directory and do not depend on a shared
payload.
