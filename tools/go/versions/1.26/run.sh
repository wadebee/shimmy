#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh

SHIMMY_GO_IMAGE_PULL=${SHIMMY_GO_IMAGE_PULL:-}
SHIMMY_GO_PULL_ARG=

if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"

SHIMMY_GO_IMAGE=${SHIMMY_GO_IMAGE:-$(shimmy_image_external_default_read "$SHIMMY_IMAGE_CONFIG_FILE")}

shimmy_podman_ca_bundle_prepare SSL_CERT_FILE

shimmy_podman_preflight_or_preview_require "the go shim" "$@"

if [ "$SHIMMY_GO_IMAGE_PULL" = "always" ]; then
  SHIMMY_GO_PULL_ARG=--pull=always
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_GO_PULL_ARG:+"$SHIMMY_GO_PULL_ARG"} \
  -i \
  -v "$PWD:/work" \
  -w /work \
  --entrypoint go \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"-v"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"$SHIMMY_PODMAN_CA_BUNDLE_SOURCE:$SHIMMY_PODMAN_CA_BUNDLE_TARGET:ro"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"-e"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"} \
  "$SHIMMY_GO_IMAGE" \
  "$@"
