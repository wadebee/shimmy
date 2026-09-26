#!/bin/sh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf

SHIMMY_ABA_PULL_ARG=
SHIMMY_ABA_TTY_ARG=
SHIMMY_ABA_CONNECTION_ARG=
SHIMMY_ABA_CONNECTION_VALUE=
SHIMMY_ABA_SSH_KEY_SOURCE=
SHIMMY_ABA_PULL_SECRET_SOURCE=
SHIMMY_ABA_MIRROR_DATA_SOURCE=

shimmy_aba_operational_invocation() {
  while [ "${1:-}" = --preview-shim ]; do
    shift
  done
  case "$#:${1:-}" in
    1:--help|1:-h) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_aba_gate_require() {
  case "${SHIMMY_ABA_PRIVILEGED:-}" in
    1) ;;
    *) printf '%s\n' 'ERROR: operational ABA commands require SHIMMY_ABA_PRIVILEGED=1.' >&2; return 1 ;;
  esac
  case "${SHIMMY_ABA_NETWORK:-}" in
    host) ;;
    *) printf '%s\n' 'ERROR: operational ABA commands require SHIMMY_ABA_NETWORK=host.' >&2; return 1 ;;
  esac
  case "${SHIMMY_PODMAN_PRIVILEGED:-}" in
    1) ;;
    *) printf '%s\n' 'ERROR: operational ABA commands require SHIMMY_PODMAN_PRIVILEGED=1.' >&2; return 1 ;;
  esac
}

shimmy_aba_file_prepare() {
  variable_name=$1
  variable_value=$2
  case "$variable_value" in
    /*) ;;
    *) printf 'ERROR: %s must name an absolute readable regular file: %s\n' "$variable_name" "$variable_value" >&2; return 1 ;;
  esac
  if [ ! -f "$variable_value" ] || [ ! -r "$variable_value" ]; then
    printf 'ERROR: %s must name an absolute readable regular file: %s\n' "$variable_name" "$variable_value" >&2
    return 1
  fi
}

shimmy_aba_mirror_data_prepare() {
  mirror_data_source=${SHIMMY_ABA_MIRROR_DATA_DIR:-}
  [ -n "$mirror_data_source" ] || return 0
  case "$mirror_data_source" in
    /*) ;;
    *) printf 'ERROR: SHIMMY_ABA_MIRROR_DATA_DIR must name an absolute existing writable directory: %s\n' "$mirror_data_source" >&2; return 1 ;;
  esac
  if [ ! -d "$mirror_data_source" ] || [ ! -w "$mirror_data_source" ]; then
    printf 'ERROR: SHIMMY_ABA_MIRROR_DATA_DIR must name an absolute existing writable directory: %s\n' "$mirror_data_source" >&2
    return 1
  fi
  SHIMMY_ABA_MIRROR_DATA_SOURCE=$mirror_data_source
}

if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

. "$SHIMMY_IMAGE_HELPER_FILE"

if shimmy_aba_operational_invocation "$@"; then
  shimmy_aba_gate_require
fi

if [ -n "${SHIMMY_ABA_SSH_KEY:-}" ]; then
  shimmy_aba_file_prepare SHIMMY_ABA_SSH_KEY "$SHIMMY_ABA_SSH_KEY"
  SHIMMY_ABA_SSH_KEY_SOURCE=$SHIMMY_ABA_SSH_KEY
fi
if [ -n "${SHIMMY_ABA_PULL_SECRET:-}" ]; then
  shimmy_aba_file_prepare SHIMMY_ABA_PULL_SECRET "$SHIMMY_ABA_PULL_SECRET"
  SHIMMY_ABA_PULL_SECRET_SOURCE=$SHIMMY_ABA_PULL_SECRET
fi
shimmy_aba_mirror_data_prepare

shimmy_podman_preflight_or_preview_require "the aba shim" "$@"

if [ -n "${SHIMMY_ABA_IMAGE:-}" ]; then
  SHIMMY_ABA_RUN_IMAGE=$SHIMMY_ABA_IMAGE
else
  SHIMMY_ABA_RUN_IMAGE=$(shimmy_local_image_ensure "$SHIMMY_IMAGE_CONFIG_FILE" "${SHIMMY_ABA_IMAGE_BUILD:-auto}")
fi

if [ -n "${SHIMMY_ABA_IMAGE:-}" ] && [ "${SHIMMY_ABA_IMAGE_PULL:-}" = always ]; then
  SHIMMY_ABA_PULL_ARG=--pull=always
fi

if shimmy_aba_operational_invocation "$@"; then
  if shimmy_podman_is_preview; then
    if [ -n "${SHIMMY_PODMAN_PRIVILEGED_CONNECTION:-}" ]; then
      SHIMMY_ABA_CONNECTION_ARG=--connection
      SHIMMY_ABA_CONNECTION_VALUE=$SHIMMY_PODMAN_PRIVILEGED_CONNECTION
    fi
  else
    shimmy_podman_privileged_connection_require "the aba shim"
    SHIMMY_ABA_CONNECTION_ARG=--connection
    SHIMMY_ABA_CONNECTION_VALUE=$SHIMMY_PODMAN_PRIVILEGED_CONNECTION
  fi
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_ABA_TTY_ARG=-it
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" \
  ${SHIMMY_ABA_CONNECTION_ARG:+"$SHIMMY_ABA_CONNECTION_ARG"} \
  ${SHIMMY_ABA_CONNECTION_VALUE:+"$SHIMMY_ABA_CONNECTION_VALUE"} \
  run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_ABA_PULL_ARG:+"$SHIMMY_ABA_PULL_ARG"} \
  ${SHIMMY_ABA_TTY_ARG:+"$SHIMMY_ABA_TTY_ARG"} \
  ${SHIMMY_ABA_CONNECTION_VALUE:+"--privileged"} \
  ${SHIMMY_ABA_CONNECTION_VALUE:+"--network"} \
  ${SHIMMY_ABA_CONNECTION_VALUE:+"host"} \
  -v "$PWD:/work" \
  -w /work \
  -e HOME=/work \
  ${SHIMMY_ABA_SSH_KEY_SOURCE:+"-v"} \
  ${SHIMMY_ABA_SSH_KEY_SOURCE:+"$SHIMMY_ABA_SSH_KEY_SOURCE:/tmp/shimmy-aba-ssh-key:ro"} \
  ${SHIMMY_ABA_PULL_SECRET_SOURCE:+"-v"} \
  ${SHIMMY_ABA_PULL_SECRET_SOURCE:+"$SHIMMY_ABA_PULL_SECRET_SOURCE:/work/.pull-secret.json:ro"} \
  ${SHIMMY_ABA_MIRROR_DATA_SOURCE:+"-v"} \
  ${SHIMMY_ABA_MIRROR_DATA_SOURCE:+"$SHIMMY_ABA_MIRROR_DATA_SOURCE:/work/mirror/data:rw"} \
  "$SHIMMY_ABA_RUN_IMAGE" \
  "$@"
