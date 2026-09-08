#!/bin/sh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh

SHIMMY_KEEPASSXC_IMAGE_PULL=${SHIMMY_KEEPASSXC_IMAGE_PULL:-}
SHIMMY_KEEPASSXC_PULL_ARG=

if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"

SHIMMY_KEEPASSXC_IMAGE=${SHIMMY_KEEPASSXC_IMAGE:-$(shimmy_image_external_default_read "$SHIMMY_IMAGE_CONFIG_FILE")}

shimmy_podman_preflight_or_preview_require "the keepassxc shim" "$@"

if [ "$SHIMMY_KEEPASSXC_IMAGE_PULL" = always ]; then
  SHIMMY_KEEPASSXC_PULL_ARG=--pull=always
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm -i \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_KEEPASSXC_PULL_ARG:+"$SHIMMY_KEEPASSXC_PULL_ARG"} \
  -v "$PWD:/work:rw" \
  -w /work \
  --entrypoint keepassxc-cli \
  "$SHIMMY_KEEPASSXC_IMAGE" \
  "$@"
