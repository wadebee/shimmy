#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_PODMAN_HELPER_FILE=$ROOT_DIR/lib/runtime/podman.sh

SHIMMY_RG_IMAGE=${SHIMMY_RG_IMAGE:-docker.io/vszl/ripgrep:latest}
SHIMMY_RG_IMAGE_PULL=${SHIMMY_RG_IMAGE_PULL:-}
SHIMMY_RG_PULL_ARG=

if [ ! -f "$SHIMMY_PODMAN_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_PODMAN_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/podman.sh
. "$SHIMMY_PODMAN_HELPER_FILE"

shimmy_podman_preflight_or_preview_require "the rg shim" "$@"

if [ "$SHIMMY_RG_IMAGE_PULL" = "always" ]; then
  SHIMMY_RG_PULL_ARG=--pull=always
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm -i \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_RG_PULL_ARG:+"$SHIMMY_RG_PULL_ARG"} \
  -v "$PWD:/work" \
  -w /work \
  "$SHIMMY_RG_IMAGE" \
  "$@"
