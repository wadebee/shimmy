#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_PODMAN_HELPER_FILE=$ROOT_DIR/lib/runtime/podman.sh

SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/lib/runtime/image.sh
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_GH_CONFIG_DIR=
SHIMMY_GH_CONTAINER_CONFIG_DIR=/home/gh/.config/gh
SHIMMY_GH_IMAGE_PULL=${SHIMMY_GH_IMAGE_PULL:-}
SHIMMY_GH_PULL_ARG=
SHIMMY_GH_RUN_IMAGE=
SHIMMY_GH_TTY_ARG=

shimmy_gh_config_dir_resolve() {
  if [ -n "${GH_CONFIG_DIR:-}" ]; then
    SHIMMY_GH_CONFIG_DIR=$GH_CONFIG_DIR
    return 0
  fi

  if [ -n "${HOME:-}" ]; then
    SHIMMY_GH_CONFIG_DIR=$HOME/.config/gh
  fi
}

shimmy_gh_config_dir_ensure() {
  shimmy_gh_config_dir_resolve

  [ -n "$SHIMMY_GH_CONFIG_DIR" ] || return 0

  if [ -e "$SHIMMY_GH_CONFIG_DIR" ] && [ ! -d "$SHIMMY_GH_CONFIG_DIR" ]; then
    printf 'ERROR: gh config path exists but is not a directory: %s\n' "$SHIMMY_GH_CONFIG_DIR" >&2
    exit 1
  fi

  mkdir -p "$SHIMMY_GH_CONFIG_DIR"
}

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" >&2
  exit 1
fi

if [ ! -f "$SHIMMY_PODMAN_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_PODMAN_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"

shimmy_podman_preview_prepare "$@"

if ! shimmy_podman_is_preview; then
  shimmy_podman_preflight_require "the gh shim"
  shimmy_gh_config_dir_ensure
else
  shimmy_gh_config_dir_resolve
fi

if [ -n "${SHIMMY_GH_IMAGE:-}" ]; then
  SHIMMY_GH_RUN_IMAGE=$SHIMMY_GH_IMAGE
else
  if [ -n "${SHIMMY_GH_VERSION:-}" ]; then
    SHIMMY_GH_RUN_IMAGE=$(
      shimmy_local_image_ensure \
        "$SHIMMY_IMAGE_CONFIG_FILE" \
        "${SHIMMY_GH_IMAGE_BUILD:-auto}" \
        --build-arg "SHIMMY_GH_VERSION=$SHIMMY_GH_VERSION"
    )
  else
    SHIMMY_GH_RUN_IMAGE=$(
      shimmy_local_image_ensure \
        "$SHIMMY_IMAGE_CONFIG_FILE" \
        "${SHIMMY_GH_IMAGE_BUILD:-auto}"
    )
  fi
fi

if [ -n "${SHIMMY_GH_IMAGE:-}" ] && [ "$SHIMMY_GH_IMAGE_PULL" = "always" ]; then
  SHIMMY_GH_PULL_ARG=--pull=always
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_GH_TTY_ARG=-it
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_GH_PULL_ARG:+"$SHIMMY_GH_PULL_ARG"} \
  ${SHIMMY_GH_TTY_ARG:+"$SHIMMY_GH_TTY_ARG"} \
  -v "$PWD:/work" \
  -w /work \
  ${SHIMMY_GH_CONFIG_DIR:+"-v"} \
  ${SHIMMY_GH_CONFIG_DIR:+"$SHIMMY_GH_CONFIG_DIR:$SHIMMY_GH_CONTAINER_CONFIG_DIR:rw"} \
  -e GH_* \
  -e "GH_CONFIG_DIR=$SHIMMY_GH_CONTAINER_CONFIG_DIR" \
  "$SHIMMY_GH_RUN_IMAGE" \
  "$@"
