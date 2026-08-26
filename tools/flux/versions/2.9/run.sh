#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh

SHIMMY_FLUX_IMAGE_PULL=${SHIMMY_FLUX_IMAGE_PULL:-}
SHIMMY_FLUX_KUBECONFIG_SOURCE=
SHIMMY_FLUX_KUBECONFIG_TARGET=
SHIMMY_FLUX_KUBECONFIG_ENV_ASSIGNMENT=
SHIMMY_FLUX_PULL_ARG=
SHIMMY_FLUX_TTY_ARG=

if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"

SHIMMY_FLUX_IMAGE=${SHIMMY_FLUX_IMAGE:-$(shimmy_image_external_default_read "$SHIMMY_IMAGE_CONFIG_FILE")}

shimmy_flux_kubeconfig_prepare() {
  kubeconfig_source=${SHIMMY_FLUX_KUBECONFIG:-}
  [ -n "$kubeconfig_source" ] || return 0

  case "$kubeconfig_source" in
    /*)
      ;;
    *)
      printf 'ERROR: SHIMMY_FLUX_KUBECONFIG must name an absolute readable kubeconfig file: %s\n' \
        "$kubeconfig_source" >&2
      return 1
      ;;
  esac

  if [ ! -f "$kubeconfig_source" ] || [ ! -r "$kubeconfig_source" ]; then
    printf 'ERROR: SHIMMY_FLUX_KUBECONFIG must name an absolute readable kubeconfig file: %s\n' \
      "$kubeconfig_source" >&2
    return 1
  fi

  SHIMMY_FLUX_KUBECONFIG_SOURCE=$kubeconfig_source
  SHIMMY_FLUX_KUBECONFIG_TARGET=/tmp/shimmy-flux-kubeconfig
  SHIMMY_FLUX_KUBECONFIG_ENV_ASSIGNMENT=KUBECONFIG=$SHIMMY_FLUX_KUBECONFIG_TARGET
}

shimmy_flux_kubeconfig_prepare
shimmy_podman_ca_bundle_prepare SSL_CERT_FILE

shimmy_podman_preflight_or_preview_require "the flux shim" "$@"

if [ "$SHIMMY_FLUX_IMAGE_PULL" = always ]; then
  SHIMMY_FLUX_PULL_ARG=--pull=always
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_FLUX_TTY_ARG=-t
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_FLUX_PULL_ARG:+"$SHIMMY_FLUX_PULL_ARG"} \
  -i \
  ${SHIMMY_FLUX_TTY_ARG:+"$SHIMMY_FLUX_TTY_ARG"} \
  -v "$PWD:/work" \
  -w /work \
  ${SHIMMY_FLUX_KUBECONFIG_SOURCE:+"-v"} \
  ${SHIMMY_FLUX_KUBECONFIG_SOURCE:+"$SHIMMY_FLUX_KUBECONFIG_SOURCE:$SHIMMY_FLUX_KUBECONFIG_TARGET:ro"} \
  ${SHIMMY_FLUX_KUBECONFIG_ENV_ASSIGNMENT:+"-e"} \
  ${SHIMMY_FLUX_KUBECONFIG_ENV_ASSIGNMENT:+"$SHIMMY_FLUX_KUBECONFIG_ENV_ASSIGNMENT"} \
  ${FLUX_NS_FOLLOWS_KUBE_CONTEXT:+-e FLUX_NS_FOLLOWS_KUBE_CONTEXT} \
  ${GITHUB_TOKEN:+-e GITHUB_TOKEN} \
  ${GITLAB_TOKEN:+-e GITLAB_TOKEN} \
  ${BITBUCKET_TOKEN:+-e BITBUCKET_TOKEN} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"-v"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"$SHIMMY_PODMAN_CA_BUNDLE_SOURCE:$SHIMMY_PODMAN_CA_BUNDLE_TARGET:ro"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"-e"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"} \
  "$SHIMMY_FLUX_IMAGE" \
  "$@"
