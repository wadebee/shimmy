#!/bin/sh
# Refresh the OPNsense read-only MCP 0.4 local image when requested by shimmy update.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/core/runtime

# shellcheck source=core/runtime/image.sh
. "$SHIMMY_RUNTIME_DIR/image.sh"

case "${1:-}" in
  pull)
    ;;
  build)
    [ -z "${SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE:-}" ] || exit 0
    shimmy_podman_preflight_require "shimmy update --build"
    if [ -n "${SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF:-}" ]; then
      shimmy_local_image_ensure \
        "localhost/shimmy-opnsense-mcp-read-only-0_4" \
        "$SCRIPT_DIR/container" \
        always \
        --build-arg "SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF=$SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF" >/dev/null
    else
      shimmy_local_image_ensure \
        "localhost/shimmy-opnsense-mcp-read-only-0_4" \
        "$SCRIPT_DIR/container" \
        always >/dev/null
    fi
    shimmy_local_image_stale_cleanup "localhost/shimmy-opnsense-mcp-read-only-0_4" "$SCRIPT_DIR/container"
    ;;
  *)
    printf 'ERROR: unsupported refresh action: %s\n' "${1:-}" >&2
    printf '%s\n' 'Usage: refresh.sh pull|build' >&2
    exit 1
    ;;
esac
