#!/bin/sh
# Refresh the Task 3.45 local image during shim synchronization.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime

# shellcheck source=tools/task/versions/3.45/smoke.conf
. "$SCRIPT_DIR/smoke.conf"

case "${1:-}" in
  pull)
    ;;
  build)
    [ -z "${SHIMMY_TASK_IMAGE:-}" ] || exit 0
    SHIMMY_TASK_IMAGE_BUILD=always "$SCRIPT_DIR/run.sh" "$smoke_arg" >/dev/null </dev/null
    # shellcheck source=lib/runtime/image.sh
    . "$SHIMMY_RUNTIME_DIR/image.sh"
    if [ -n "${SHIMMY_TASK_VERSION:-}" ]; then
      shimmy_local_image_stale_cleanup "$SCRIPT_DIR/image.conf" \
        --build-arg "SHIMMY_TASK_VERSION=$SHIMMY_TASK_VERSION"
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
