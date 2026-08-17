#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh

SHIMMY_NPX_IMAGE_PULL=${SHIMMY_NPX_IMAGE_PULL:-}
SHIMMY_NPX_PULL_ARG=
SHIMMY_NPX_TTY_ARG=

if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"

SHIMMY_NPX_IMAGE=${SHIMMY_NPX_IMAGE:-$(shimmy_image_external_default_read "$SHIMMY_IMAGE_CONFIG_FILE")}

shimmy_podman_preflight_or_preview_require "the npx shim" "$@"

if [ "$SHIMMY_NPX_IMAGE_PULL" = always ]; then
  SHIMMY_NPX_PULL_ARG=--pull=always
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_NPX_TTY_ARG=-t
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_NPX_PULL_ARG:+"$SHIMMY_NPX_PULL_ARG"} \
  -i \
  ${SHIMMY_NPX_TTY_ARG:+"$SHIMMY_NPX_TTY_ARG"} \
  -v "$PWD:/work:rw" \
  -w /work \
  --entrypoint npx \
  "$SHIMMY_NPX_IMAGE" \
  "$@"
