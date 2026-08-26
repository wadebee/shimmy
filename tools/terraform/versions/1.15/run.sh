#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh

SHIMMY_TF_AWS_CONFIG_DIR=
SHIMMY_TF_IMAGE_PULL=${SHIMMY_TF_IMAGE_PULL:-}
SHIMMY_TF_PLUGIN_CACHE_DIR=
SHIMMY_TF_PULL_ARG=
SHIMMY_TF_TTY_ARG=

if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"

SHIMMY_TF_IMAGE=${SHIMMY_TF_IMAGE:-$(shimmy_image_external_default_read "$SHIMMY_IMAGE_CONFIG_FILE")}

shimmy_podman_ca_bundle_prepare SSL_CERT_FILE

shimmy_podman_preflight_or_preview_require "the terraform shim" "$@"

if [ -n "${HOME:-}" ] && [ -d "$HOME/.aws" ]; then
  SHIMMY_TF_AWS_CONFIG_DIR=$HOME/.aws
fi

if [ -n "${HOME:-}" ] && [ -d "$HOME/.terraform.d/plugin-cache" ]; then
  SHIMMY_TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache
fi

if [ "$SHIMMY_TF_IMAGE_PULL" = "always" ]; then
  SHIMMY_TF_PULL_ARG=--pull=always
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_TF_TTY_ARG=-it
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_TF_PULL_ARG:+"$SHIMMY_TF_PULL_ARG"} \
  ${SHIMMY_TF_TTY_ARG:+"$SHIMMY_TF_TTY_ARG"} \
  -v "$PWD:/work" \
  -w /work \
  ${SHIMMY_TF_AWS_CONFIG_DIR:+"-v"} \
  ${SHIMMY_TF_AWS_CONFIG_DIR:+"$SHIMMY_TF_AWS_CONFIG_DIR:/root/.aws:ro"} \
  ${SHIMMY_TF_PLUGIN_CACHE_DIR:+"-v"} \
  ${SHIMMY_TF_PLUGIN_CACHE_DIR:+"$SHIMMY_TF_PLUGIN_CACHE_DIR:/root/.terraform.d/plugin-cache"} \
  -e AWS_* \
  -e TF_VAR_* \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"-v"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"$SHIMMY_PODMAN_CA_BUNDLE_SOURCE:$SHIMMY_PODMAN_CA_BUNDLE_TARGET:ro"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"-e"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"} \
  "$SHIMMY_TF_IMAGE" \
  "$@"
