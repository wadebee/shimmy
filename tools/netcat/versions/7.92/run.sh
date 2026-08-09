#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/lib/runtime/image.sh
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf

SHIMMY_NETCAT_PULL_ARG=

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"

shimmy_podman_preflight_or_preview_require "the netcat shim" "$@"

if [ -n "${SHIMMY_NETCAT_IMAGE:-}" ]; then
  SHIMMY_NETCAT_RUN_IMAGE=$SHIMMY_NETCAT_IMAGE
else
  SHIMMY_NETCAT_RUN_IMAGE=$(
    shimmy_local_image_ensure \
      "$SHIMMY_IMAGE_CONFIG_FILE" \
      "${SHIMMY_NETCAT_IMAGE_BUILD:-auto}"
  )
fi

if [ -n "${SHIMMY_NETCAT_IMAGE:-}" ] && [ "${SHIMMY_NETCAT_IMAGE_PULL:-}" = "always" ]; then
  SHIMMY_NETCAT_PULL_ARG=--pull=always
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm -i \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_NETCAT_PULL_ARG:+"$SHIMMY_NETCAT_PULL_ARG"} \
  -v "$PWD:/work:rw" \
  -w /work \
  "$SHIMMY_NETCAT_RUN_IMAGE" \
  "$@"
