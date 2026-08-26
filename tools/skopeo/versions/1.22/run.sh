#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh
SHIMMY_COMMON_HELPER_FILE=$ROOT_DIR/lib/common/common.sh
SHIMMY_PROFILE_HELPER_FILE=$ROOT_DIR/lib/profile/profile.sh
SHIMMY_REGISTRIES_HELPER_FILE=$ROOT_DIR/lib/registries/registries.sh

SHIMMY_SKOPEO_AUTH_SECRET=${SHIMMY_SKOPEO_AUTH_SECRET:-}
SHIMMY_SKOPEO_CONTAINER_AUTH_FILE=/run/secrets/skopeo-auth.json
SHIMMY_SKOPEO_IMAGE_PULL=${SHIMMY_SKOPEO_IMAGE_PULL:-}
SHIMMY_SKOPEO_IO_ARG=-i
SHIMMY_SKOPEO_PULL_ARG=
SHIMMY_SKOPEO_REGISTRY_MOUNT_ARG=
SHIMMY_SKOPEO_SECRET_ARG=

for helper_file in \
  "$SHIMMY_COMMON_HELPER_FILE" \
  "$SHIMMY_PROFILE_HELPER_FILE" \
  "$SHIMMY_REGISTRIES_HELPER_FILE" \
  "$SHIMMY_IMAGE_HELPER_FILE"
do
  if [ ! -f "$helper_file" ]; then
    printf 'ERROR: missing shim helper: %s\n' "$helper_file" >&2
    exit 1
  fi
done

# shellcheck source=lib/common/common.sh
. "$SHIMMY_COMMON_HELPER_FILE"
# shellcheck source=lib/profile/profile.sh
. "$SHIMMY_PROFILE_HELPER_FILE"
# shellcheck source=lib/registries/registries.sh
. "$SHIMMY_REGISTRIES_HELPER_FILE"
# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"

SHIMMY_SKOPEO_IMAGE=${SHIMMY_SKOPEO_IMAGE:-$(shimmy_image_external_default_read "$SHIMMY_IMAGE_CONFIG_FILE")}

shimmy_podman_ca_bundle_prepare SSL_CERT_FILE

shimmy_podman_preflight_or_preview_require "the skopeo shim" "$@"
SHIMMY_SKOPEO_REGISTRY_MOUNT_ARG=$(shimmy_registries_client_mount_resolve) || exit 1

if [ "$SHIMMY_SKOPEO_IMAGE_PULL" = "always" ]; then
  SHIMMY_SKOPEO_PULL_ARG=--pull=always
fi

if [ -n "$SHIMMY_SKOPEO_AUTH_SECRET" ]; then
  SHIMMY_SKOPEO_SECRET_ARG=$SHIMMY_SKOPEO_AUTH_SECRET,target=skopeo-auth.json
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_SKOPEO_IO_ARG=-it
fi

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_SKOPEO_PULL_ARG:+"$SHIMMY_SKOPEO_PULL_ARG"} \
  "$SHIMMY_SKOPEO_IO_ARG" \
  -v "$PWD:/work" \
  -w /work \
  ${SHIMMY_SKOPEO_REGISTRY_MOUNT_ARG:+"-v"} \
  ${SHIMMY_SKOPEO_REGISTRY_MOUNT_ARG:+"$SHIMMY_SKOPEO_REGISTRY_MOUNT_ARG"} \
  ${SHIMMY_SKOPEO_SECRET_ARG:+"--secret"} \
  ${SHIMMY_SKOPEO_SECRET_ARG:+"$SHIMMY_SKOPEO_SECRET_ARG"} \
  ${SHIMMY_SKOPEO_SECRET_ARG:+"-e"} \
  ${SHIMMY_SKOPEO_SECRET_ARG:+"REGISTRY_AUTH_FILE=$SHIMMY_SKOPEO_CONTAINER_AUTH_FILE"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"-v"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_SOURCE:+"$SHIMMY_PODMAN_CA_BUNDLE_SOURCE:$SHIMMY_PODMAN_CA_BUNDLE_TARGET:ro"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"-e"} \
  ${SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT:+"$SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT"} \
  "$SHIMMY_SKOPEO_IMAGE" \
  "$@"
