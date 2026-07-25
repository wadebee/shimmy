#!/bin/sh
set -eu

SCRIPT_DIR=$(\
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/core/runtime
SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/core/runtime/image.sh

SHIMMY_LOGMINE_IMAGES_DIR=$SCRIPT_DIR/container
SHIMMY_LOGMINE_PULL_ARG=
SHIMMY_LOGMINE_TTY_ARG=

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=core/runtime/image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"

shimmy_podman_preflight_or_preview_require "the logmine shim" "$@"

if [ -n "${SHIMMY_LOGMINE_IMAGE:-}" ]; then
  SHIMMY_LOGMINE_RUN_IMAGE=$SHIMMY_LOGMINE_IMAGE
else
  if [ -n "${SHIMMY_LOGMINE_BASE_IMAGE:-}" ] && [ -n "${SHIMMY_LOGMINE_VERSION:-}" ]; then
    SHIMMY_LOGMINE_RUN_IMAGE=$(\
      shimmy_local_image_ensure \
        "localhost/shimmy-logmine-0_1" \
        "$SHIMMY_LOGMINE_IMAGES_DIR" \
        "${SHIMMY_LOGMINE_IMAGE_BUILD:-auto}" \
        --build-arg "SHIMMY_LOGMINE_BASE_IMAGE=$SHIMMY_LOGMINE_BASE_IMAGE" \
        --build-arg "SHIMMY_LOGMINE_VERSION=$SHIMMY_LOGMINE_VERSION"
    )
  elif [ -n "${SHIMMY_LOGMINE_BASE_IMAGE:-}" ]; then
    SHIMMY_LOGMINE_RUN_IMAGE=$(\
      shimmy_local_image_ensure \
        "localhost/shimmy-logmine-0_1" \
        "$SHIMMY_LOGMINE_IMAGES_DIR" \
        "${SHIMMY_LOGMINE_IMAGE_BUILD:-auto}" \
        --build-arg "SHIMMY_LOGMINE_BASE_IMAGE=$SHIMMY_LOGMINE_BASE_IMAGE"
    )
  elif [ -n "${SHIMMY_LOGMINE_VERSION:-}" ]; then
    SHIMMY_LOGMINE_RUN_IMAGE=$(\
      shimmy_local_image_ensure \
        "localhost/shimmy-logmine-0_1" \
        "$SHIMMY_LOGMINE_IMAGES_DIR" \
        "${SHIMMY_LOGMINE_IMAGE_BUILD:-auto}" \
        --build-arg "SHIMMY_LOGMINE_VERSION=$SHIMMY_LOGMINE_VERSION"
    )
  else
    SHIMMY_LOGMINE_RUN_IMAGE=$(\
      shimmy_local_image_ensure \
        "localhost/shimmy-logmine-0_1" \
        "$SHIMMY_LOGMINE_IMAGES_DIR" \
        "${SHIMMY_LOGMINE_IMAGE_BUILD:-auto}"
    )
  fi
fi

if [ -n "${SHIMMY_LOGMINE_IMAGE:-}" ] && [ "${SHIMMY_LOGMINE_IMAGE_PULL:-}" = "always" ]; then
  SHIMMY_LOGMINE_PULL_ARG=--pull=always
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_LOGMINE_TTY_ARG=-it
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_LOGMINE_TTY_ARG:+"$SHIMMY_LOGMINE_TTY_ARG"} \
  ${SHIMMY_LOGMINE_PULL_ARG:+"$SHIMMY_LOGMINE_PULL_ARG"} \
  -v "$PWD:$PWD:rw" \
  -v "$PWD:/work:rw" \
  -w "$PWD" \
  "$SHIMMY_LOGMINE_RUN_IMAGE" \
  "$@"
