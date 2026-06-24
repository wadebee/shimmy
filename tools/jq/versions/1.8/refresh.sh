#!/bin/sh
# Refresh the jq 1.8 runtime image when requested by shimmy update.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=tools/jq/versions/1.8/smoke.conf
. "$SCRIPT_DIR/smoke.conf"

case "${1:-}" in
  pull)
    SHIMMY_JQ_IMAGE_PULL=always "$SCRIPT_DIR/run.sh" "$smoke_arg" >/dev/null </dev/null
    ;;
  build)
    ;;
  *)
    printf 'ERROR: unsupported refresh action: %s\n' "${1:-}" >&2
    printf '%s\n' 'Usage: refresh.sh pull|build' >&2
    exit 1
    ;;
esac
