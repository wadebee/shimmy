#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
COMMON_HELPER_FILE=$ROOT_DIR/lib/repo/shimmy-common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/lib/repo/shimmy-catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/lib/repo/shimmy-profile.sh
SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/lib/shims/custom-image.sh
DEFAULT_INSTALL_DIR=${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}
REQUESTED_INSTALL_DIR=
SHIMMY_PROFILE_REQUESTED=
OUTPUT_FORMAT=human
SHOW_AVAILABLE=0

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  fail "missing custom image helper: $SHIMMY_CUSTOM_IMAGE_HELPER_FILE"
fi

if [ ! -f "$CATALOG_HELPER_FILE" ]; then
  fail "missing catalog helper: $CATALOG_HELPER_FILE"
fi

if [ ! -f "$COMMON_HELPER_FILE" ]; then
  fail "missing common helper: $COMMON_HELPER_FILE"
fi

if [ ! -f "$PROFILE_HELPER_FILE" ]; then
  fail "missing profile helper: $PROFILE_HELPER_FILE"
fi

# shellcheck source=lib/repo/shimmy-common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=lib/repo/shimmy-catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=lib/repo/shimmy-profile.sh
. "$PROFILE_HELPER_FILE"
# shellcheck source=lib/shims/custom-image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"

install_dir_resolve() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(shimmy_trim_path_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(shimmy_trim_path_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

installed_shim_list() {
  manifest_file=$1
  shim_dir=$2

  if [ -f "$manifest_file" ]; then
    shimmy_read_manifest_shims "$manifest_file" || true
    return 0
  fi

  if [ -d "$shim_dir" ]; then
    find "$shim_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) | sort | while IFS= read -r shim_path; do
      [ -n "$shim_path" ] || continue
      basename "$shim_path"
    done
  fi
}

is_installed_shim() {
  shim_name=$1
  manifest_file=$2
  shim_dir=$3

  while IFS= read -r installed_shim; do
    [ -n "$installed_shim" ] || continue
    if [ "$installed_shim" = "$shim_name" ]; then
      return 0
    fi
  done <<EOF
$(installed_shim_list "$manifest_file" "$shim_dir")
EOF

  return 1
}

available_shim_list() {
  manifest_file=$1
  shim_dir=$2

  for supported_shim in $(shimmy_supported_shim_list); do
    if ! is_installed_shim "$supported_shim" "$manifest_file" "$shim_dir"; then
      printf '%s\n' "$supported_shim"
    fi
  done
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
    nmap)
      printf '%s\n' "${SHIMMY_NMAP_IMAGE:-docker.io/instrumentisto/nmap:7.98-r2}"
      ;;
    opnsense-mcp-admin)
      if [ -n "${SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE:-}" ]; then
        printf '%s\n' "$SHIMMY_OPNSENSE_MCP_ADMIN_IMAGE"
      else
        printf '%s\n' "$(local_image_ref "localhost/shimmy-opnsense-mcp-admin" "$images_dir/opnsense-mcp-admin")"
      fi
      ;;
    opnsense-mcp-read-only)
      if [ -n "${SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE:-}" ]; then
        printf '%s\n' "$SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE"
      else
        printf '%s\n' "$(local_image_ref "localhost/shimmy-opnsense-mcp-read-only" "$images_dir/opnsense-mcp-read-only")"
      fi
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

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    printed_any=1
    printf -- '- %s: %s\n' "$shim_name" "$(describe_shim_image "$shim_name" "$images_dir")"
  done <<EOF
$(installed_shim_list "$manifest_file" "$shim_dir")
EOF

  if [ "$printed_any" -eq 0 ]; then
    printf -- '- none\n'
  fi
}

print_available_shims() {
  manifest_file=$1
  shim_dir=$2
  printed_any=0

  printf 'available_shims:\n'

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    printed_any=1
    printf -- '- %s\n' "$shim_name"
  done <<EOF
$(available_shim_list "$manifest_file" "$shim_dir")
EOF

  if [ "$printed_any" -eq 0 ]; then
    printf -- '- none\n'
  fi
}

print_manifest_available_shims() {
  manifest_file=$1
  shim_dir=$2

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    printf 'shimmy_available_shim=%s\n' "$shim_name"
  done <<EOF
$(available_shim_list "$manifest_file" "$shim_dir")
EOF
}

print_manifest_status() {
  manifest_file=$1
  install_dir=$2
  shim_dir=$3
  images_dir=$4
  shim_lib_dir=$5
  root_manifest_file=$6

  root_bin_dir=$SHIMMY_INSTALL_BIN_DIR
  root_control_bin=$install_dir/bin/shimmy
  root_activate_file=$install_dir/activate.sh
  root_profile_default=default

  if [ -f "$root_manifest_file" ]; then
    manifest_bin_dir=$(shimmy_read_manifest_value "$root_manifest_file" bin_dir || true)
    manifest_control_bin=$(shimmy_read_manifest_value "$root_manifest_file" control_bin || true)
    manifest_activate_file=$(shimmy_read_manifest_value "$root_manifest_file" activate_file || true)
    manifest_profile_default=$(shimmy_read_manifest_value "$root_manifest_file" shimmy_profile_default || true)
    [ -z "$manifest_bin_dir" ] || root_bin_dir=$manifest_bin_dir
    [ -z "$manifest_control_bin" ] || root_control_bin=$manifest_control_bin
    [ -z "$manifest_activate_file" ] || root_activate_file=$manifest_activate_file
    [ -z "$manifest_profile_default" ] || root_profile_default=$manifest_profile_default
  fi

  printf 'shimmy_install_dir=%s\n' "$install_dir"
  printf 'shimmy_bin_dir=%s\n' "$root_bin_dir"
  printf 'shimmy_control_bin=%s\n' "$root_control_bin"
  printf 'shimmy_activate_file=%s\n' "$root_activate_file"
  printf 'shimmy_profile_default=%s\n' "$root_profile_default"
  printf 'shimmy_manifest_path=%s\n' "$root_manifest_file"
  if shimmy_profile_structure_validate "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"; then
    printf 'shimmy_installed=yes\n'
  else
    printf 'shimmy_installed=no\n'
  fi
  if path_contains "$root_bin_dir"; then
    printf 'shimmy_path_active=yes\n'
  else
    printf 'shimmy_path_active=no\n'
  fi
  shimmy_profile_structure_missing_print "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"

  printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_NAME"
  printf 'shimmy_profile_dir=%s\n' "$SHIMMY_PROFILE_DIR"
  printf 'shimmy_profile_manifest_path=%s\n' "$SHIMMY_PROFILE_MANIFEST_PATH"
  printf 'shimmy_profile_config_dir=%s\n' "$SHIMMY_PROFILE_CONFIG_DIR"
  printf 'shimmy_profile_implementation_dir=%s\n' "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
  printf 'shimmy_profile_images_dir=%s\n' "$images_dir"
  printf 'shimmy_profile_shim_lib_dir=%s\n' "$shim_lib_dir"

  if [ -f "$manifest_file" ]; then
    shim_source=$(shimmy_read_manifest_value "$manifest_file" shim_source || true)
    source_checkout=$(shimmy_read_manifest_value "$manifest_file" source_checkout || true)
    source_url=$(shimmy_read_manifest_value "$manifest_file" shimmy_source_url || true)
    source_ref=$(shimmy_read_manifest_value "$manifest_file" shimmy_source_ref || true)
    previous_source_ref=$(shimmy_read_manifest_value "$manifest_file" shimmy_previous_source_ref || true)
    [ -z "$shim_source" ] || printf 'shimmy_profile_shim_source=%s\n' "$shim_source"
    [ -z "$source_checkout" ] || printf 'shimmy_profile_source_checkout=%s\n' "$source_checkout"
    [ -z "$source_url" ] || printf 'shimmy_profile_source_url=%s\n' "$source_url"
    [ -z "$source_ref" ] || printf 'shimmy_profile_source_ref=%s\n' "$source_ref"
    [ -z "$previous_source_ref" ] || printf 'shimmy_profile_previous_source_ref=%s\n' "$previous_source_ref"
    while IFS= read -r shim_name; do
      [ -n "$shim_name" ] || continue
      printf 'shimmy_profile_shim=%s\n' "$shim_name"
    done <<EOF
$(shimmy_read_manifest_shims "$manifest_file" || true)
EOF
  fi

  if [ "$SHIMMY_PROFILE_NAME" = upstream ] && [ -f "$manifest_file" ]; then
    source_checkout=$(shimmy_read_manifest_value "$manifest_file" source_checkout || true)
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      printf 'shimmy_missing=%s\n' "$upstream_invalid_reason"
      printf 'shimmy_repair_hint=rerun ./shimmy install --profile upstream from the desired Shimmy checkout\n'
    fi
  fi

  if ! shimmy_profile_structure_validate "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"; then
    shimmy_profile_repair_hint_print "$SHIMMY_PROFILE_NAME"
  fi
}

usage() {
  cat <<'EOF'
Print the current Shimmy install status.

Usage:
  scripts/status-shimmy.sh [--install-dir <dir>] [--profile default|upstream] [--available] [--format human|manifest]
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
      --profile)
        [ "$#" -ge 2 ] || fail "missing value for --profile"
        SHIMMY_PROFILE_REQUESTED=$2
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
      --available)
        SHOW_AVAILABLE=1
        shift
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

  if ! shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$(install_dir_resolve)" "$ROOT_DIR"; then
    fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
  fi

  install_dir=$SHIMMY_PROFILE_INSTALL_DIR
  manifest_file=$SHIMMY_PROFILE_MANIFEST_PATH
  root_manifest_file=$install_dir/install-manifest.txt
  shim_dir=$SHIMMY_PROFILE_IMPLEMENTATION_DIR
  images_dir=$SHIMMY_PROFILE_DIR/images
  shim_lib_dir=$SHIMMY_PROFILE_DIR/lib/shims

  if [ -f "$root_manifest_file" ]; then
    manifest_install_dir=$(shimmy_read_manifest_value "$root_manifest_file" install_dir || true)
    if [ -n "$manifest_install_dir" ]; then
      install_dir=$(shimmy_trim_path_trailing_slash "$manifest_install_dir")
      shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$install_dir" "$ROOT_DIR" || fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
      manifest_file=$SHIMMY_PROFILE_MANIFEST_PATH
      root_manifest_file=$install_dir/install-manifest.txt
      shim_dir=$SHIMMY_PROFILE_IMPLEMENTATION_DIR
      images_dir=$SHIMMY_PROFILE_DIR/images
      shim_lib_dir=$SHIMMY_PROFILE_DIR/lib/shims
    fi
  fi

  if [ -f "$manifest_file" ]; then
    manifest_source_checkout=$(shimmy_read_manifest_value "$manifest_file" source_checkout || true)
    if [ "$SHIMMY_PROFILE_NAME" = upstream ] && [ -n "$manifest_source_checkout" ]; then
      SHIMMY_PROFILE_SOURCE_CHECKOUT=$manifest_source_checkout
    fi
  fi

  if [ "$OUTPUT_FORMAT" = manifest ]; then
    print_manifest_status "$manifest_file" "$install_dir" "$shim_dir" "$images_dir" "$shim_lib_dir" "$root_manifest_file"
    if [ "$SHOW_AVAILABLE" -eq 1 ]; then
      print_manifest_available_shims "$manifest_file" "$shim_dir"
    fi
    return 0
  fi

  printf 'Shimmy Status\n'
  printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_NAME"
  if shimmy_profile_structure_validate "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"; then
    printf 'installed: yes\n'
  else
    printf 'installed: no\n'
  fi
  printf 'install_dir=%s\n' "$install_dir"
  printf 'profile_dir=%s\n' "$SHIMMY_PROFILE_DIR"
  printf 'config_dir=%s\n' "$SHIMMY_PROFILE_CONFIG_DIR"
  printf 'bin_dir=%s\n' "$SHIMMY_INSTALL_BIN_DIR"
  printf 'manifest_path=%s\n' "$SHIMMY_PROFILE_MANIFEST_PATH"
  printf 'profile_implementation_dir=%s\n' "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
  if [ -n "$SHIMMY_PROFILE_SOURCE_CHECKOUT" ]; then
    printf 'source_checkout=%s\n' "$SHIMMY_PROFILE_SOURCE_CHECKOUT"
  fi
  printf 'images_dir=%s\n' "$images_dir"
  printf 'shim_lib_dir=%s\n' "$shim_lib_dir"
  if path_contains "$SHIMMY_INSTALL_BIN_DIR"; then
    printf 'path_active: yes\n'
  else
    printf 'path_active: no\n'
  fi
  print_installed_shims "$manifest_file" "$shim_dir" "$images_dir"
  if [ "$SHOW_AVAILABLE" -eq 1 ]; then
    print_available_shims "$manifest_file" "$shim_dir"
  fi
}

main "$@"
