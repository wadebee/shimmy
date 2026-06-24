#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/core/runtime
SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/core/runtime/image.sh

SHIMMY_NETCAT_IMAGES_DIR=$SCRIPT_DIR/container
SHIMMY_NETCAT_PULL_ARG=

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=core/runtime/image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"

shimmy_podman_preflight_or_preview_require "the netcat shim" "$@"

if [ -n "${SHIMMY_NETCAT_IMAGE:-}" ]; then
  SHIMMY_NETCAT_RUN_IMAGE=$SHIMMY_NETCAT_IMAGE
else
  if [ -n "${SHIMMY_NETCAT_BASE_IMAGE:-}" ]; then
    SHIMMY_NETCAT_RUN_IMAGE=$(
      shimmy_local_image_ensure \
        "localhost/shimmy-netcat-7_92" \
        "$SHIMMY_NETCAT_IMAGES_DIR" \
        "${SHIMMY_NETCAT_IMAGE_BUILD:-auto}" \
        --build-arg "SHIMMY_NETCAT_BASE_IMAGE=$SHIMMY_NETCAT_BASE_IMAGE"
    )
  else
    SHIMMY_NETCAT_RUN_IMAGE=$(
      shimmy_local_image_ensure \
        "localhost/shimmy-netcat-7_92" \
        "$SHIMMY_NETCAT_IMAGES_DIR" \
        "${SHIMMY_NETCAT_IMAGE_BUILD:-auto}"
    )
  fi
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
