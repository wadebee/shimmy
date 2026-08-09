#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh

SHIMMY_AWS_IMAGE_PULL=${SHIMMY_AWS_IMAGE_PULL:-}
SHIMMY_AWS_CONFIG_DIR=
SHIMMY_AWS_PULL_ARG=
SHIMMY_AWS_TTY_ARG=

if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"

SHIMMY_AWS_IMAGE=${SHIMMY_AWS_IMAGE:-$(shimmy_image_external_default_read "$SHIMMY_IMAGE_CONFIG_FILE")}

shimmy_podman_preflight_or_preview_require "the aws shim" "$@"

if [ -n "${HOME:-}" ] && [ -d "$HOME/.aws" ]; then
  SHIMMY_AWS_CONFIG_DIR=$HOME/.aws
fi

if [ "$SHIMMY_AWS_IMAGE_PULL" = "always" ]; then
  SHIMMY_AWS_PULL_ARG=--pull=always
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_AWS_TTY_ARG=-it
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_AWS_PULL_ARG:+"$SHIMMY_AWS_PULL_ARG"} \
  ${SHIMMY_AWS_TTY_ARG:+"$SHIMMY_AWS_TTY_ARG"} \
  -v "$PWD:/work" \
  -w /work \
  ${SHIMMY_AWS_CONFIG_DIR:+"-v"} \
  ${SHIMMY_AWS_CONFIG_DIR:+"$SHIMMY_AWS_CONFIG_DIR:/root/.aws:ro"} \
  -e AWS_* \
  "$SHIMMY_AWS_IMAGE" \
  "$@"
