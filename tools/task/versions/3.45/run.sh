#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/lib/runtime/image.sh
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf

SHIMMY_TASK_CONTAINER_HOST_SOCKET=
SHIMMY_TASK_CONTAINER_HOST_VALUE=
SHIMMY_TASK_HOME_DIR=
SHIMMY_TASK_PULL_ARG=
SHIMMY_TASK_TMP_DIR=
SHIMMY_TASK_TTY_ARG=

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"

shimmy_podman_ca_bundle_prepare SSL_CERT_FILE

shimmy_podman_preflight_or_preview_require "the task shim" "$@"

if [ -n "${SHIMMY_TASK_IMAGE:-}" ]; then
  SHIMMY_TASK_RUN_IMAGE=$SHIMMY_TASK_IMAGE
else
  if [ -n "${SHIMMY_TASK_VERSION:-}" ]; then
    SHIMMY_TASK_RUN_IMAGE=$(
      shimmy_local_image_ensure \
        "$SHIMMY_IMAGE_CONFIG_FILE" \
        "${SHIMMY_TASK_IMAGE_BUILD:-auto}" \
        --build-arg "SHIMMY_TASK_VERSION=$SHIMMY_TASK_VERSION"
    )
  else
    SHIMMY_TASK_RUN_IMAGE=$(
      shimmy_local_image_ensure \
        "$SHIMMY_IMAGE_CONFIG_FILE" \
        "${SHIMMY_TASK_IMAGE_BUILD:-auto}"
    )
  fi
fi

if [ -n "${SHIMMY_TASK_IMAGE:-}" ] && [ "${SHIMMY_TASK_IMAGE_PULL:-}" = "always" ]; then
  SHIMMY_TASK_PULL_ARG=--pull=always
fi

if [ -n "${HOME:-}" ] && [ -d "$HOME" ]; then
  SHIMMY_TASK_HOME_DIR=$HOME
fi

if [ -n "${CONTAINER_HOST:-}" ]; then
  case "$CONTAINER_HOST" in
    unix://*)
      if [ -S "${CONTAINER_HOST#unix://}" ]; then
        SHIMMY_TASK_CONTAINER_HOST_VALUE=$CONTAINER_HOST
        SHIMMY_TASK_CONTAINER_HOST_SOCKET=${CONTAINER_HOST#unix://}
      fi
      ;;
    *)
      SHIMMY_TASK_CONTAINER_HOST_VALUE=$CONTAINER_HOST
      ;;
  esac
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_TASK_TTY_ARG=-it
fi

if [ -d /tmp ]; then
  SHIMMY_TASK_TMP_DIR=/tmp
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_TASK_TTY_ARG:+"$SHIMMY_TASK_TTY_ARG"} \
  ${SHIMMY_TASK_PULL_ARG:+"$SHIMMY_TASK_PULL_ARG"} \
  -v "$PWD:$PWD:rw" \
  -v "$PWD:/work:rw" \
  -w "$PWD" \
  ${SHIMMY_TASK_HOME_DIR:+"-e"} \
  ${SHIMMY_TASK_HOME_DIR:+"HOME=$HOME"} \
  ${SHIMMY_TASK_HOME_DIR:+"-v"} \
  ${SHIMMY_TASK_HOME_DIR:+"$HOME:$HOME:rw"} \
  ${PATH:+"-e"} \
  ${PATH:+"SHIMMY_HOST_PATH=$PATH"} \
  ${SHIMMY_TASK_CONTAINER_HOST_VALUE:+"-e"} \
  ${SHIMMY_TASK_CONTAINER_HOST_VALUE:+"CONTAINER_HOST=$SHIMMY_TASK_CONTAINER_HOST_VALUE"} \
  ${SHIMMY_TASK_CONTAINER_HOST_SOCKET:+"-v"} \
  ${SHIMMY_TASK_CONTAINER_HOST_SOCKET:+"$SHIMMY_TASK_CONTAINER_HOST_SOCKET:$SHIMMY_TASK_CONTAINER_HOST_SOCKET"} \
  ${SHIMMY_TASK_TMP_DIR:+"-v"} \
  ${SHIMMY_TASK_TMP_DIR:+"$SHIMMY_TASK_TMP_DIR:$SHIMMY_TASK_TMP_DIR:rw"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"-v"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"$SHIMMY_PODMAN_CA_BUNDLE_SOURCE:$SHIMMY_PODMAN_CA_BUNDLE_TARGET:ro"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"-e"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"} \
  "$SHIMMY_TASK_RUN_IMAGE" \
  "$@"
