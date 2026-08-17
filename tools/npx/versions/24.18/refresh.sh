#!/bin/sh
# Refresh the Node 24.18 image used by npx when requested by shimmy update.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=tools/npx/versions/24.18/smoke.conf
. "$SCRIPT_DIR/smoke.conf"

case "${1:-}" in
  pull)
    SHIMMY_NPX_IMAGE_PULL=always "$SCRIPT_DIR/run.sh" "$smoke_arg" >/dev/null </dev/null
    ;;
  build)
    ;;
  *)
    printf 'ERROR: unsupported refresh action: %s\n' "${1:-}" >&2
    printf '%s\n' 'Usage: refresh.sh pull|build' >&2
    exit 1
    ;;
esac
