#!/bin/sh
# Report installed and available metadata-driven Shimmy tools.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
COMMON_HELPER_FILE=$ROOT_DIR/core/common/common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/core/catalog/catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/core/profile/profile.sh
REQUESTED_INSTALL_DIR=
SHIMMY_PROFILE_REQUESTED=
OUTPUT_FORMAT=human
SHOW_AVAILABLE=0

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

. "$COMMON_HELPER_FILE"
. "$CATALOG_HELPER_FILE"
. "$PROFILE_HELPER_FILE"

usage() {
  cat <<'EOF'
Usage: commands/status.sh [--install-dir <dir>] [--profile default|upstream] [--available] [--format human|manifest]
EOF
}

install_dir_resolve() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    shimmy_trim_path_trailing_slash "$REQUESTED_INSTALL_DIR"
    return 0
  fi
  shimmy_profile_install_dir_resolve ""
}

kind_installed() {
  manifest_file=$1
  kind_name=$2
  shimmy_contains_manifest_kind "$manifest_file" "$kind_name"
}

version_runtime_path() {
  kind_name=$1
  version_name=$2
  version_label=$(shimmy_version_label "$version_name")
  printf '%s/tools/%s/versions/%s/run.sh\n' "$ROOT_DIR" "$kind_name" "$version_label"
}

version_image_description() {
  kind_name=$1
  version_name=$2
  version_label=$(shimmy_version_label "$version_name")
  version_dir=$ROOT_DIR/tools/$kind_name/versions/$version_label

  if [ -d "$version_dir/container" ]; then
    printf 'local-build:%s\n' "$version_dir/container"
    return 0
  fi

  image_value=$(sed -n 's/^SHIMMY_[A-Z0-9_]*_IMAGE=${[^}]*:-\([^}]*\)}$/\1/p' "$version_dir/run.sh" | sed -n '1p')
  if [ -n "$image_value" ]; then
    printf '%s\n' "$image_value"
  else
    printf 'runtime:%s\n' "$version_dir/run.sh"
  fi
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
    printf '  version: %s (%s) %s\n' "$version_label" "$version_name" "$(version_image_description "$kind_name" "$version_name")"
  done
}

print_status() {
  install_dir=$1
  manifest_file=$2

  if [ "$OUTPUT_FORMAT" = manifest ]; then
    printf 'shimmy_install_dir=%s\n' "$install_dir"
    printf 'shimmy_manifest_path=%s\n' "$manifest_file"
    printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_NAME"
    if shimmy_profile_structure_validate "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"; then
      printf 'shimmy_installed=yes\n'
    else
      printf 'shimmy_installed=no\n'
    fi
  else
    printf 'Shimmy Status\n'
    printf 'profile: %s\n' "$SHIMMY_PROFILE_NAME"
    printf 'install_dir: %s\n' "$install_dir"
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
      --install-dir) REQUESTED_INSTALL_DIR=${2:?missing value for --install-dir}; shift 2 ;;
      --profile) SHIMMY_PROFILE_REQUESTED=${2:?missing value for --profile}; shift 2 ;;
      --available) SHOW_AVAILABLE=1; shift ;;
      --format) OUTPUT_FORMAT=${2:?missing value for --format}; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown argument: $1" ;;
    esac
  done

  case "$OUTPUT_FORMAT" in human|manifest) ;; *) fail "unsupported status format: $OUTPUT_FORMAT" ;; esac
  shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$(install_dir_resolve)" "$ROOT_DIR" || fail "unsupported Shimmy profile"
  install_dir=$SHIMMY_PROFILE_INSTALL_DIR
  root_manifest_file=$install_dir/install-manifest.txt
  shimmy_install_layout_validate "$root_manifest_file" || fail "legacy Shimmy install layout detected; uninstall and reinstall"
  print_status "$install_dir" "$SHIMMY_PROFILE_MANIFEST_PATH"
}

main "$@"
