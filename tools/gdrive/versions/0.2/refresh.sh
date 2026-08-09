#!/bin/sh
# Refresh the Google Drive MCP 0.2 local image when requested by shimmy update.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime

# shellcheck source=tools/gdrive/versions/0.2/smoke.conf
. "$SCRIPT_DIR/smoke.conf"

case "${1:-}" in
  pull)
    ;;
  build)
    [ -z "${SHIMMY_GDRIVE_IMAGE:-}" ] || exit 0
    SHIMMY_GDRIVE_IMAGE_BUILD=always "$SCRIPT_DIR/run.sh" "$smoke_arg" >/dev/null </dev/null
    # shellcheck source=lib/runtime/image.sh
    . "$SHIMMY_RUNTIME_DIR/image.sh"
    if [ -n "${SHIMMY_GDRIVE_SOURCE_REF:-}" ]; then
      shimmy_local_image_stale_cleanup "$SCRIPT_DIR/image.conf" \
        --build-arg "SHIMMY_GDRIVE_SOURCE_REF=$SHIMMY_GDRIVE_SOURCE_REF"
    else
      shimmy_local_image_stale_cleanup "$SCRIPT_DIR/image.conf"
    fi
    ;;
  *)
    printf 'ERROR: unsupported refresh action: %s\n' "${1:-}" >&2
    printf '%s\n' 'Usage: refresh.sh pull|build' >&2
    exit 1
    ;;
esac
