# Podman runtime

- `podman.sh` resolves Podman, normalizes supported Linux/Darwin host CPU
  aliases to the native `linux/amd64` or `linux/arm64` image platform, exposes
  that required-platform set, and owns preview and privileged-connection checks.
- `image.sh` validates version-owned `image.conf` metadata, supplies configured
  external defaults and local base-image build arguments, hashes complete local
  image inputs, and removes stale tagged images after a version-owned rebuild.
- `log.sh` provides shared runtime logging.

Callers sourcing `image.sh` must set `SHIMMY_RUNTIME_DIR` to this directory so
its sibling modules resolve correctly. Installed copies live in each flat
profile's `lib/runtime/` directory and do not depend on a shared payload.
