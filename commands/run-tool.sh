#!/bin/sh
set -eu

# Resolve a tool and run its selected concrete version. This is used by
# both the source checkout and installed profile wrappers.

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
MATERIALIZATION_TOOLS_DIR=$ROOT_DIR/tools

tool_metadata_read() {
  metadata_file=$1
  key=$2

  sed -n "s/^${key}=//p" "$metadata_file" | sed -n '1p'
}

tool_name_validate() {
  tool_name=$1

  case "$tool_name" in
    ''|*/*|.*|*'..'*) return 1 ;;
    *) return 0 ;;
  esac
}

main() {
  tool_name=${1:?tool is required}
  shift

  tool_name_validate "$tool_name" || {
    printf 'ERROR: invalid tool: %s\n' "$tool_name" >&2
    exit 1
  }

  tool_dir=$MATERIALIZATION_TOOLS_DIR/$tool_name
  tool_file=$tool_dir/tool.conf
  [ -f "$tool_file" ] || {
    printf 'ERROR: unsupported Shimmy tool: %s\n' "$tool_name" >&2
    exit 1
  }

  default_version=$(tool_metadata_read "$tool_file" tool_default_version)
  selector_env=$(tool_metadata_read "$tool_file" tool_selector_env)
  selected_version=$default_version

  if [ -n "$selector_env" ]; then
    selector_value=$(printenv "$selector_env" 2>/dev/null || true)
    if [ -n "$selector_value" ]; then
      selected_version=$selector_value
    fi
  fi

  run_file=$tool_dir/versions/$selected_version/run.sh
  if [ ! -x "$run_file" ]; then
    available_versions=$(find "$tool_dir/versions" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$selector_env" ]; then
      printf 'ERROR: unsupported %s value: %s\n' "$selector_env" "$selected_version" >&2
    else
      printf 'ERROR: missing %s default version: %s\n' "$tool_name" "$selected_version" >&2
    fi
    printf 'Available %s versions: %s\n' "$tool_name" "$available_versions" >&2
    printf 'Default %s version: %s\n' "$tool_name" "$default_version" >&2
    exit 1
  fi

  exec "$run_file" "$@"
}

main "$@"
