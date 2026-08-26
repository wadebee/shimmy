#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/lib/runtime/image.sh
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf

SHIMMY_TESSL_CONFIG_DIR=
SHIMMY_TESSL_PULL_ARG=
SHIMMY_TESSL_TTY_ARG=

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"

shimmy_podman_ca_bundle_prepare NODE_EXTRA_CA_CERTS

shimmy_podman_preflight_or_preview_require "the tessl shim" "$@"

if [ -n "${SHIMMY_TESSL_IMAGE:-}" ]; then
  SHIMMY_TESSL_RUN_IMAGE=$SHIMMY_TESSL_IMAGE
else
  SHIMMY_TESSL_RUN_IMAGE=$(
    shimmy_local_image_ensure \
      "$SHIMMY_IMAGE_CONFIG_FILE" \
      "${SHIMMY_TESSL_IMAGE_BUILD:-auto}"
  )
fi

if [ -n "${HOME:-}" ] && [ -d "$HOME/.tessl" ]; then
  SHIMMY_TESSL_CONFIG_DIR=$HOME/.tessl
fi

if [ -n "${SHIMMY_TESSL_IMAGE:-}" ] && [ "${SHIMMY_TESSL_IMAGE_PULL:-}" = "always" ]; then
  SHIMMY_TESSL_PULL_ARG=--pull=always
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_TESSL_TTY_ARG=-it
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_TESSL_TTY_ARG:+"$SHIMMY_TESSL_TTY_ARG"} \
  -m 300M \
  --memory-swap 1G \
  ${SHIMMY_TESSL_PULL_ARG:+"$SHIMMY_TESSL_PULL_ARG"} \
  -v "$PWD:/work:rw" \
  ${SHIMMY_TESSL_CONFIG_DIR:+"-v"} \
  ${SHIMMY_TESSL_CONFIG_DIR:+"$SHIMMY_TESSL_CONFIG_DIR:/root/.tessl"} \
  -e SHIMMY_TESSL_* \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"-v"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"$SHIMMY_PODMAN_CA_BUNDLE_SOURCE:$SHIMMY_PODMAN_CA_BUNDLE_TARGET:ro"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"-e"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"} \
  "$SHIMMY_TESSL_RUN_IMAGE" \
  "$@"
