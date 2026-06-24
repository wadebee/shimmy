#!/bin/sh
# Refresh the Google Cloud CLI 573.0 runtime image when requested by shimmy update.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=tools/gcloud/versions/573.0/smoke.conf
. "$SCRIPT_DIR/smoke.conf"

case "${1:-}" in
  pull)
    SHIMMY_GCLOUD_IMAGE_PULL=always "$SCRIPT_DIR/run.sh" "$smoke_arg" >/dev/null </dev/null
    ;;
  build)
    ;;
  *)
    printf 'ERROR: unsupported refresh action: %s\n' "${1:-}" >&2
    printf '%s\n' 'Usage: refresh.sh pull|build' >&2
    exit 1
    ;;
esac
