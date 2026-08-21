#!/bin/sh
# Refresh the Skopeo 1.22 runtime image during shim synchronization.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=tools/skopeo/versions/1.22/smoke.conf
. "$SCRIPT_DIR/smoke.conf"

case "${1:-}" in
  pull)
    SHIMMY_SKOPEO_IMAGE_PULL=always "$SCRIPT_DIR/run.sh" "$smoke_arg" >/dev/null </dev/null
    ;;
  build)
    ;;
  *)
    printf 'ERROR: unsupported refresh action: %s\n' "${1:-}" >&2
    printf '%s\n' 'Usage: refresh.sh pull|build' >&2
    exit 1
    ;;
esac
