#!/bin/sh
# Catalog helpers discover tool metadata from the source tree. No central
# tool-name or version case list is maintained.

SHIMMY_DEFAULT_KINDS='jq rg'
SHIMMY_CATALOG_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
SHIMMY_CATALOG_ROOT=$(cd -- "$SHIMMY_CATALOG_DIR/../.." && pwd)
SHIMMY_TOOLS_DIR=${SHIMMY_TOOLS_DIR:-$SHIMMY_CATALOG_ROOT/tools}

shimmy__tool_metadata_read() {
  tool_file=$1
  key=$2

  sed -n "s/^${key}=//p" "$tool_file" | sed -n '1p'
}

shimmy__tool_dir() {
  kind_name=$1
  printf '%s/%s\n' "$SHIMMY_TOOLS_DIR" "$kind_name"
}

shimmy__version_name_read() {
  version_dir=$1

  shimmy__tool_metadata_read "$version_dir/smoke.conf" shim_name
}

shimmy_default_kind_list() {
  printf '%s\n' "$SHIMMY_DEFAULT_KINDS"
}

shimmy_is_kind() {
  [ -f "$(shimmy__tool_dir "$1")/tool.conf" ]
}

shimmy_is_version() {
  shimmy_version_kind "$1" >/dev/null 2>&1
}

shimmy_kind_default_version() {
  kind_name=$1
  tool_file=$(shimmy__tool_dir "$kind_name")/tool.conf
  default_label=$(shimmy__tool_metadata_read "$tool_file" tool_default_version)

  shimmy_kind_version_for_label "$kind_name" "$default_label"
}

shimmy_kind_list() {
  for tool_file in "$SHIMMY_TOOLS_DIR"/*/tool.conf; do
    [ -f "$tool_file" ] || continue
    basename "$(dirname "$tool_file")"
  done | sort
}

shimmy_kind_selector_env() {
  kind_name=$1
  tool_file=$(shimmy__tool_dir "$kind_name")/tool.conf
  [ -f "$tool_file" ] || return 1
  shimmy__tool_metadata_read "$tool_file" tool_selector_env
}

shimmy_kind_version_for_label() {
  kind_name=$1
  version_label=$2
  version_dir=$(shimmy__tool_dir "$kind_name")/versions/$version_label

  [ -d "$version_dir" ] || return 1
  shimmy__version_name_read "$version_dir"
}

shimmy_kind_version_label_list() {
  kind_name=$1

  for version_dir in "$(shimmy__tool_dir "$kind_name")"/versions/*; do
    [ -d "$version_dir" ] || continue
    basename "$version_dir"
  done | sort
}

shimmy_kind_version_list() {
  kind_name=$1

  for version_label in $(shimmy_kind_version_label_list "$kind_name"); do
    shimmy_kind_version_for_label "$kind_name" "$version_label"
  done
}

shimmy_version_kind() {
  version_name=$1

  for kind_name in $(shimmy_kind_list); do
    for version_name_current in $(shimmy_kind_version_list "$kind_name"); do
      if [ "$version_name_current" = "$version_name" ]; then
        printf '%s\n' "$kind_name"
        return 0
      fi
    done
  done

  return 1
}

shimmy_version_label() {
  version_name=$1

  for kind_name in $(shimmy_kind_list); do
    for version_label in $(shimmy_kind_version_label_list "$kind_name"); do
      if [ "$(shimmy_kind_version_for_label "$kind_name" "$version_label")" = "$version_name" ]; then
        printf '%s\n' "$version_label"
        return 0
      fi
    done
  done

  return 1
}
