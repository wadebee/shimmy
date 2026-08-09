#!/bin/sh
# Report installed and available metadata-driven Shimmy tools.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
COMMON_HELPER_FILE=$ROOT_DIR/lib/common/common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/lib/catalog/catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/lib/profile/profile.sh
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh
OUTPUT_FORMAT=human
SHOW_AVAILABLE=0

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

. "$COMMON_HELPER_FILE"
. "$CATALOG_HELPER_FILE"
. "$IMAGE_HELPER_FILE"
. "$PROFILE_HELPER_FILE"

usage() {
  cat <<'EOF'
Usage: shimmy status [--available] [--format human|manifest]
EOF
}

kind_installed() {
  manifest_file=$1
  kind_name=$2
  shimmy_contains_manifest_kind "$manifest_file" "$kind_name"
}

version_image_description() {
  kind_name=$1
  version_name=$2
  version_dir=$(shimmy_version_dir "$version_name") || fail "missing version directory for $kind_name: $version_name"
  image_config_file=$(shimmy_version_image_config_file "$version_name") || fail "missing image configuration path for $kind_name: $version_name"
  shimmy_image_config_validate "$image_config_file" || exit 1
  image_source=$(shimmy_image_config_scalar_read "$image_config_file" image_source)

  case "$image_source" in
    local-build)
      image_context_dir=$(shimmy_local_image_context_dir_resolve "$image_config_file")
      printf 'local-build:%s\n' "$image_context_dir"
      ;;
    external)
      shimmy_image_config_scalar_read "$image_config_file" image_default_ref
      ;;
  esac
}

print_kind_human() {
  manifest_file=$1
  kind_name=$2
  default_version=$(shimmy_kind_default_version "$kind_name")
  default_label=$(shimmy_version_label "$default_version")
  printf -- '- %s\n' "$kind_name"
  printf '  default: %s (%s)\n' "$default_label" "$default_version"
  for version_name in $(shimmy_kind_version_list "$kind_name"); do
    version_label=$(shimmy_version_label "$version_name")
    version_description=$(version_image_description "$kind_name" "$version_name") || return 1
    printf '  version: %s (%s) %s\n' "$version_label" "$version_name" "$version_description"
  done
}

print_status() {
  manifest_file=$1

  if [ "$OUTPUT_FORMAT" = manifest ]; then
    printf 'shimmy_profile_root=%s\n' "$SHIMMY_PROFILE_ROOT"
    printf 'shimmy_manifest_path=%s\n' "$manifest_file"
    printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_NAME"
    if shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME"; then
      printf 'shimmy_installed=yes\n'
    else
      printf 'shimmy_installed=no\n'
    fi
  else
    printf 'Shimmy Status\n'
    printf 'profile: %s\n' "$SHIMMY_PROFILE_NAME"
    printf 'profile_root: %s\n' "$SHIMMY_PROFILE_ROOT"
  fi

  for kind_name in $(shimmy_kind_list); do
    if kind_installed "$manifest_file" "$kind_name"; then
      if [ "$OUTPUT_FORMAT" = manifest ]; then
        printf 'shimmy_profile_kind=%s\n' "$kind_name"
        for version_name in $(shimmy_kind_version_list "$kind_name"); do
          printf 'shimmy_profile_kind_version=%s|%s|%s\n' "$kind_name" "$(shimmy_version_label "$version_name")" "$version_name"
        done
      else
        print_kind_human "$manifest_file" "$kind_name"
      fi
    elif [ "$SHOW_AVAILABLE" -eq 1 ]; then
      if [ "$OUTPUT_FORMAT" = manifest ]; then
        printf 'shimmy_available_kind=%s\n' "$kind_name"
      else
        printf 'available: %s\n' "$kind_name"
      fi
    fi
  done
}

main() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --available) SHOW_AVAILABLE=1; shift ;;
      --format) OUTPUT_FORMAT=${2:?missing value for --format}; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown argument: $1" ;;
    esac
  done

  case "$OUTPUT_FORMAT" in human|manifest) ;; *) fail "unsupported status format: $OUTPUT_FORMAT" ;; esac
  shimmy_profile_context_resolve "$ROOT_DIR" || fail "installed launcher is outside a canonical profile root"
  shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_PROFILE_NAME" || exit 1
  print_status "$SHIMMY_PROFILE_MANIFEST_PATH"
}

main "$@"
