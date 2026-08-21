#!/bin/sh
# Refresh the OPNsense read-only MCP 0.4 local image during shim synchronization.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_RUNTIME_DIR/image.sh"

case "${1:-}" in
  pull)
    ;;
  build)
    [ -z "${SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE:-}" ] || exit 0
    shimmy_podman_preflight_require "shimmy shim sync"
    if [ -n "${SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF:-}" ]; then
      shimmy_local_image_ensure \
        "$SCRIPT_DIR/image.conf" \
        always \
        --build-arg "SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF=$SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF" >/dev/null
      shimmy_local_image_stale_cleanup "$SCRIPT_DIR/image.conf" \
        --build-arg "SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF=$SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF"
    else
      shimmy_local_image_ensure \
        "$SCRIPT_DIR/image.conf" \
        always >/dev/null
      shimmy_local_image_stale_cleanup "$SCRIPT_DIR/image.conf"
    fi
    ;;
  *)
    printf 'ERROR: unsupported refresh action: %s\n' "${1:-}" >&2
    printf '%s\n' 'Usage: refresh.sh pull|build' >&2
    exit 1
    ;;
esac
