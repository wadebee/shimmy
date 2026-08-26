#!/bin/sh
# Refresh the Flux CLI 2.9 runtime image during shim synchronization.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
SMOKE_FILE=$SCRIPT_DIR/smoke.conf

case "${1:-}" in
  pull)
    set --
    while IFS= read -r smoke_line; do
      case "$smoke_line" in
        smoke_arg=*) set -- "$@" "${smoke_line#smoke_arg=}" ;;
      esac
    done < "$SMOKE_FILE"
    SHIMMY_FLUX_IMAGE_PULL=always "$SCRIPT_DIR/run.sh" "$@" >/dev/null </dev/null
    ;;
  build)
    ;;
  *)
    printf 'ERROR: unsupported refresh action: %s\n' "${1:-}" >&2
    printf '%s\n' 'Usage: refresh.sh pull|build' >&2
    exit 1
    ;;
esac
