#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/lib/shims/custom-image.sh
DEFAULT_INSTALL_DIR=$HOME/.config/shimmy
REQUESTED_INSTALL_DIR=
OUTPUT_FORMAT=human

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  fail "missing custom image helper: $SHIMMY_CUSTOM_IMAGE_HELPER_FILE"
fi

# shellcheck source=lib/shims/custom-image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"

trim_trailing_slash() {
  path_value=${1:-}

  case "$path_value" in
    ''|/)
      printf '%s\n' "$path_value"
      ;;
    */)
      printf '%s\n' "${path_value%/}"
      ;;
    *)
      printf '%s\n' "$path_value"
      ;;
  esac
}

install_dir_resolve() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(trim_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(trim_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

manifest_value() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file" | sed -n '1p'
}

manifest_shim_list() {
  manifest_file=$1

  if [ ! -f "$manifest_file" ]; then
    return 0
  fi

  sed -n 's/^shim=//p' "$manifest_file"
}

path_contains() {
  needle=$1
  path_value=${PATH:-}

  case ":$path_value:" in
    *":$needle:"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

local_image_ref() {
  image_repo=$1
  context_dir=$2
  image_hash=$(shimmy_context_hash_render "$context_dir" 2>/dev/null || true)

  if [ -n "$image_hash" ]; then
    shimmy_podman_platform_resolve
    platform_tag=$(shimmy_podman_platform_tag_render "$SHIMMY_PODMAN_PLATFORM")
    printf '%s:%s-%s\n' "$image_repo" "$image_hash" "$platform_tag"
    return 0
  fi

  printf '%s\n' "$image_repo"
}

describe_shim_image() {
  shim_name=$1
  images_dir=$2

  case "$shim_name" in
    aws)
      printf '%s\n' "${SHIMMY_AWS_IMAGE:-public.ecr.aws/aws-cli/aws-cli:2.31.21}"
      ;;
    go)
      printf '%s\n' "${SHIMMY_GO_IMAGE:-docker.io/library/golang:latest}"
      ;;
    jq)
      printf '%s\n' "${SHIMMY_JQ_IMAGE:-ghcr.io/jqlang/jq:1.8.1}"
      ;;
    netcat)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-netcat" "$images_dir/netcat")"
      ;;
    opnsense-mcp-server)
      printf '%s\n' "${SHIMMY_OPNSENSE_MCP_IMAGE:-docker.io/uhlenheide/opnsense-mcp-server}"
      ;;
    rg)
      printf '%s\n' "${SHIMMY_RG_IMAGE:-docker.io/vszl/ripgrep:latest}"
      ;;
    task)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-task" "$images_dir/task")"
      ;;
    terraform)
      printf '%s\n' "${SHIMMY_TF_IMAGE:-docker.io/hashicorp/terraform:latest}"
      ;;
    textual)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-textual" "$images_dir/textual")"
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

print_installed_shims() {
  manifest_file=$1
  shim_dir=$2
  images_dir=$3
  printed_any=0

  printf 'installed_shims:\n'

  if [ -f "$manifest_file" ]; then
    while IFS= read -r shim_name; do
      [ -n "$shim_name" ] || continue
      printed_any=1
      printf -- '- %s: %s\n' "$shim_name" "$(describe_shim_image "$shim_name" "$images_dir")"
    done <<EOF
$(manifest_shim_list "$manifest_file")
EOF
  elif [ -d "$shim_dir" ]; then
    while IFS= read -r shim_path; do
      [ -n "$shim_path" ] || continue
      printed_any=1
      shim_name=$(basename "$shim_path")
      printf -- '- %s: %s\n' "$shim_name" "$(describe_shim_image "$shim_name" "$images_dir")"
    done <<EOF
$(find "$shim_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) | sort)
EOF
  fi

  if [ "$printed_any" -eq 0 ]; then
    printf -- '- none\n'
  fi
}

print_manifest_status() {
  manifest_file=$1
  install_dir=$2
  shim_dir=$3
  images_dir=$4
  shim_lib_dir=$5

  if [ -f "$manifest_file" ] || [ -d "$shim_dir" ]; then
    printf 'installed=yes\n'
  else
    printf 'installed=no\n'
  fi
  printf 'install_dir=%s\n' "$install_dir"
  printf 'shim_dir=%s\n' "$shim_dir"
  printf 'images_dir=%s\n' "$images_dir"
  printf 'shim_lib_dir=%s\n' "$shim_lib_dir"
  if path_contains "$shim_dir"; then
    printf 'path_active=yes\n'
  else
    printf 'path_active=no\n'
  fi

  if [ -f "$manifest_file" ]; then
    while IFS= read -r manifest_line; do
      case "$manifest_line" in
        install_dir=*|shim_dir=*|images_dir=*|shim_lib_dir=*)
          ;;
        *)
          printf '%s\n' "$manifest_line"
          ;;
      esac
    done < "$manifest_file"
  elif [ -d "$shim_dir" ]; then
    while IFS= read -r shim_path; do
      [ -n "$shim_path" ] || continue
      printf 'shim=%s\n' "$(basename "$shim_path")"
    done <<EOF
$(find "$shim_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) | sort)
EOF
  fi
}

usage() {
  cat <<'EOF'
Print the current Shimmy install status.

Usage:
  scripts/status-shimmy.sh [--install-dir <dir>] [--format human|manifest]
EOF
}

main() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
        shift 2
        ;;
      --format)
        [ "$#" -ge 2 ] || fail "missing value for --format"
        case "$2" in
          human|manifest)
            OUTPUT_FORMAT=$2
            ;;
          *)
            fail "unsupported status format: $2"
            ;;
        esac
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done

  install_dir=$(install_dir_resolve)
  manifest_file=$install_dir/install-manifest.txt

  if [ -f "$manifest_file" ]; then
    manifest_install_dir=$(manifest_value "$manifest_file" install_dir || true)
    if [ -n "$manifest_install_dir" ]; then
      install_dir=$(trim_trailing_slash "$manifest_install_dir")
      manifest_file=$install_dir/install-manifest.txt
    fi
  fi

  shim_dir=$install_dir/shims
  images_dir=$install_dir/images
  shim_lib_dir=$install_dir/lib/shims

  if [ "$OUTPUT_FORMAT" = manifest ]; then
    print_manifest_status "$manifest_file" "$install_dir" "$shim_dir" "$images_dir" "$shim_lib_dir"
    return 0
  fi

  printf 'Shimmy Status\n'
  if [ -f "$manifest_file" ] || [ -d "$shim_dir" ]; then
    printf 'installed: yes\n'
  else
    printf 'installed: no\n'
  fi
  printf 'install_dir=%s\n' "$install_dir"
  printf 'shim_dir=%s\n' "$shim_dir"
  printf 'images_dir=%s\n' "$images_dir"
  printf 'shim_lib_dir=%s\n' "$shim_lib_dir"
  if path_contains "$shim_dir"; then
    printf 'path_active: yes\n'
  else
    printf 'path_active: no\n'
  fi
  print_installed_shims "$manifest_file" "$shim_dir" "$images_dir"
}

main "$@"
