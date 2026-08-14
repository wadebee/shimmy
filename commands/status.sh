#!/bin/sh
# Report installed and available metadata-driven Shimmy tools.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_CONTROL_ROOT=$ROOT_DIR
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
Show installed tools, versions, catalog provenance, and profile details.

Usage:
  shimmy status [--available] [--format human|manifest]

Options:
  --available              Include catalog tools that are not installed.
  --format human|manifest  Select output format. Default: human.
  -h, --help               Show this help.

Examples:
  shimmy status
  shimmy status --available
  shimmy status --format manifest
EOF
}

tool_installed() {
  manifest_file=$1
  tool_name=$2
  shimmy_manifest_tool_contains "$manifest_file" "$tool_name"
}

profile_version_image_description() {
  tool_name=$1
  version_label=$2
  version_name=$3
  version_dir=$SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR/$tool_name/versions/$version_label
  image_config_file=$version_dir/image.conf
  [ -d "$version_dir" ] && [ ! -L "$version_dir" ] || fail "missing materialized version directory for $tool_name: $version_name"
  [ -f "$image_config_file" ] && [ ! -L "$image_config_file" ] || fail "missing materialized image configuration for $tool_name: $version_name"
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

print_tool_human() {
  manifest_file=$1
  tool_name=$2
  default_version=
  default_label=
  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    entry_tool=${tool_version_entry%%|*}
    [ "$entry_tool" = "$tool_name" ] || continue
    entry_remainder=${tool_version_entry#*|}
    entry_label=${entry_remainder%%|*}
    entry_version=${entry_remainder#*|}
    if [ "$entry_label" = default ]; then
      default_version=$entry_version
    elif [ -z "$default_label" ] && [ "$entry_version" = "$default_version" ]; then
      default_label=$entry_label
    fi
  done <<EOF
$(shimmy_manifest_tool_version_list_read "$manifest_file")
EOF
  [ -n "$default_version" ] || fail "profile manifest has no default concrete version for installed tool: $tool_name"
  [ -n "$default_label" ] || default_label=default
  printf -- '- %s\n' "$tool_name"
  printf '  default: %s (%s)\n' "$default_label" "$default_version"
  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    entry_tool=${tool_version_entry%%|*}
    [ "$entry_tool" = "$tool_name" ] || continue
    entry_remainder=${tool_version_entry#*|}
    entry_label=${entry_remainder%%|*}
    entry_version=${entry_remainder#*|}
    [ "$entry_label" != default ] || continue
    version_description=$(profile_version_image_description "$tool_name" "$entry_label" "$entry_version") || return 1
    printf '  version: %s (%s) %s\n' "$entry_label" "$entry_version" "$version_description"
  done <<EOF
$(shimmy_manifest_tool_version_list_read "$manifest_file")
EOF
}

print_status() {
  manifest_file=$1

  if [ "$OUTPUT_FORMAT" = manifest ]; then
    printf 'shimmy_profile_root=%s\n' "$SHIMMY_PROFILE_ROOT"
    printf 'shimmy_manifest_path=%s\n' "$manifest_file"
    printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_NAME"
    printf 'shimmy_catalog_name=%s\n' "$SHIMMY_CATALOG_NAME"
    printf 'shimmy_catalog_source_type=%s\n' "$SHIMMY_CATALOG_SOURCE_TYPE"
    printf 'shimmy_catalog_source=%s\n' "$SHIMMY_CATALOG_SOURCE_PATH"
    printf 'shimmy_catalog_generation=%s\n' "$SHIMMY_CATALOG_GENERATION"
    printf 'shimmy_catalog_source_commit=%s\n' "$SHIMMY_CATALOG_SOURCE_COMMIT"
    printf 'shimmy_catalog_content_fingerprint=%s\n' "$SHIMMY_CATALOG_CONTENT_FINGERPRINT"
    printf 'shimmy_catalog_schema=%s\n' "$SHIMMY_CATALOG_SCHEMA"
    printf 'shimmy_catalog_health=%s\n' "$SHIMMY_CATALOG_HEALTH"
    if shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME"; then
      printf 'shimmy_installed=yes\n'
    else
      printf 'shimmy_installed=no\n'
    fi
  else
    printf 'Shimmy Status\n'
    printf 'profile: %s\n' "$SHIMMY_PROFILE_NAME"
    printf 'profile_root: %s\n' "$SHIMMY_PROFILE_ROOT"
    printf 'catalog: %s\n' "$SHIMMY_CATALOG_NAME"
    printf 'catalog_source_type: %s\n' "$SHIMMY_CATALOG_SOURCE_TYPE"
    printf 'catalog_source: %s\n' "$SHIMMY_CATALOG_SOURCE_PATH"
    [ -z "$SHIMMY_CATALOG_GENERATION" ] || printf 'catalog_generation: %s\n' "$SHIMMY_CATALOG_GENERATION"
    printf 'catalog_source_commit: %s\n' "$SHIMMY_CATALOG_SOURCE_COMMIT"
    printf 'catalog_content_fingerprint: %s\n' "$SHIMMY_CATALOG_CONTENT_FINGERPRINT"
    printf 'catalog_schema: %s\n' "$SHIMMY_CATALOG_SCHEMA"
    printf 'catalog_health: %s\n' "$SHIMMY_CATALOG_HEALTH"
  fi

  for tool_name in $(shimmy_manifest_tool_list_read "$manifest_file"); do
    if [ "$OUTPUT_FORMAT" = manifest ]; then
      printf 'shimmy_profile_tool=%s\n' "$tool_name"
      while IFS= read -r tool_version_entry; do
        [ -n "$tool_version_entry" ] || continue
        entry_tool=${tool_version_entry%%|*}
        [ "$entry_tool" = "$tool_name" ] || continue
        entry_remainder=${tool_version_entry#*|}
        entry_label=${entry_remainder%%|*}
        [ "$entry_label" != default ] || continue
        printf 'shimmy_profile_tool_version=%s\n' "$tool_version_entry"
      done <<EOF
$(shimmy_manifest_tool_version_list_read "$manifest_file")
EOF
    else
      print_tool_human "$manifest_file" "$tool_name"
    fi
  done

  [ "$SHOW_AVAILABLE" -eq 1 ] || return 0
  for tool_name in $(shimmy_tool_list); do
    if ! tool_installed "$manifest_file" "$tool_name"; then
      if [ "$OUTPUT_FORMAT" = manifest ]; then
        printf 'shimmy_available_tool=%s\n' "$tool_name"
      else
        printf 'available: %s\n' "$tool_name"
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
  if ! shimmy_catalog_profile_resolve "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_CONFIG_ROOT"; then
    SHIMMY_CATALOG_NAME=$(shimmy_read_manifest_value "$SHIMMY_PROFILE_MANIFEST_PATH" catalog || true)
    if [ "$OUTPUT_FORMAT" = manifest ]; then
      printf 'shimmy_catalog_name=%s\n' "$SHIMMY_CATALOG_NAME"
      printf 'shimmy_catalog_health=invalid\n'
      printf 'shimmy_catalog_error=%s\n' "$SHIMMY_CATALOG_ERROR"
    else
      printf 'catalog: %s\n' "$SHIMMY_CATALOG_NAME"
      printf 'catalog_health: invalid\n'
      printf 'catalog_error: %s\n' "$SHIMMY_CATALOG_ERROR"
    fi
    exit 1
  fi
  print_status "$SHIMMY_PROFILE_MANIFEST_PATH"
}

main "$@"
