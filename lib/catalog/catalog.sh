#!/bin/sh
# Catalog helpers discover tool metadata from the source tree. No central
# tool-name or version case list is maintained.

SHIMMY_CATALOG_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
SHIMMY_CATALOG_ROOT=$(cd -- "$SHIMMY_CATALOG_DIR/../.." && pwd)
SHIMMY_TOOLS_DIR=${SHIMMY_TOOLS_DIR:-$SHIMMY_CATALOG_ROOT/tools}

shimmy__tool_metadata_read() {
  tool_file=$1
  key=$2

  sed -n "s/^${key}=//p" "$tool_file" | sed -n '1p'
}

shimmy__tool_dir() {
  tool_name=$1
  printf '%s/%s\n' "$SHIMMY_TOOLS_DIR" "$tool_name"
}

shimmy__version_name_read() {
  version_dir=$1

  shimmy__tool_metadata_read "$version_dir/smoke.conf" shim_name
}

shimmy_tool_exists() {
  [ -f "$(shimmy__tool_dir "$1")/tool.conf" ]
}

shimmy_is_version() {
  shimmy_tool_version_tool "$1" >/dev/null 2>&1
}

shimmy_tool_version_default() {
  tool_name=$1
  tool_file=$(shimmy__tool_dir "$tool_name")/tool.conf
  default_label=$(shimmy__tool_metadata_read "$tool_file" tool_default_version)

  shimmy_tool_version_label_resolve "$tool_name" "$default_label"
}

shimmy_tool_list() {
  for tool_file in "$SHIMMY_TOOLS_DIR"/*/tool.conf; do
    [ -f "$tool_file" ] || continue
    basename "$(dirname "$tool_file")"
  done | sort
}

shimmy_tool_selector_env() {
  tool_name=$1
  tool_file=$(shimmy__tool_dir "$tool_name")/tool.conf
  [ -f "$tool_file" ] || return 1
  shimmy__tool_metadata_read "$tool_file" tool_selector_env
}

shimmy_tool_version_label_resolve() {
  tool_name=$1
  version_label=$2
  version_dir=$(shimmy__tool_dir "$tool_name")/versions/$version_label

  [ -d "$version_dir" ] || return 1
  shimmy__version_name_read "$version_dir"
}

shimmy_tool_version_label_list() {
  tool_name=$1

  for version_dir in "$(shimmy__tool_dir "$tool_name")"/versions/*; do
    [ -d "$version_dir" ] || continue
    basename "$version_dir"
  done | sort
}

shimmy_tool_version_list() {
  tool_name=$1

  for version_label in $(shimmy_tool_version_label_list "$tool_name"); do
    shimmy_tool_version_label_resolve "$tool_name" "$version_label"
  done
}

shimmy_version_dir() {
  version_name=$1
  tool_name=$(shimmy_tool_version_tool "$version_name") || return 1
  version_label=$(shimmy_version_label "$version_name") || return 1

  printf '%s/%s/versions/%s\n' "$SHIMMY_TOOLS_DIR" "$tool_name" "$version_label"
}

shimmy_version_image_config_file() {
  version_name=$1
  version_dir=$(shimmy_version_dir "$version_name") || return 1

  printf '%s/image.conf\n' "$version_dir"
}

shimmy_tool_version_tool() {
  version_name=$1

  for tool_name in $(shimmy_tool_list); do
    for version_name_current in $(shimmy_tool_version_list "$tool_name"); do
      if [ "$version_name_current" = "$version_name" ]; then
        printf '%s\n' "$tool_name"
        return 0
      fi
    done
  done

  return 1
}

shimmy_version_label() {
  version_name=$1

  for tool_name in $(shimmy_tool_list); do
    for version_label in $(shimmy_tool_version_label_list "$tool_name"); do
      if [ "$(shimmy_tool_version_label_resolve "$tool_name" "$version_label")" = "$version_name" ]; then
        printf '%s\n' "$version_label"
        return 0
      fi
    done
  done

  return 1
}
