# Podman runtime

- `podman.sh` resolves Podman, host platform, preview behavior, and privileged
  connection checks.
- `image.sh` builds and hashes local container contexts.
- `log.sh` provides shared runtime logging.

Callers sourcing `image.sh` must set `SHIMMY_RUNTIME_DIR` to this directory so
its sibling modules resolve correctly.
