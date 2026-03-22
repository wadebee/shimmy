#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/repo/shimmy-env.sh
source "$SCRIPT_DIR/../lib/repo/shimmy-env.sh"

shimmy_init_home_vars "$HOME"
shimmy_discover_install_layout "${SHIMMY_INSTALL_DIR:-}"

if [[ -f "$SHIMMY_SHIM_LIB_DIR/custom-image.sh" ]]; then
  # shellcheck source=lib/shims/custom-image.sh
  source "$SHIMMY_SHIM_LIB_DIR/custom-image.sh"
fi

path_contains() {
  local needle="$1"
  local path_value="${SHIMMY_HOST_PATH:-${PATH:-}}"

  case ":$path_value:" in
    *":$needle:"*) return 0 ;;
    *) return 1 ;;
  esac
}

local_image_ref() {
  local image_repo="$1"
  local context_dir="$2"

  if [[ ! -d "$context_dir" || ! -f "$context_dir/Containerfile" ]]; then
    printf '%s\n' "$image_repo"
    return 0
  fi

  printf '%s:%s\n' "$image_repo" "$(shimmy_compute_context_hash "$context_dir")"
}

describe_shim_image() {
  local shim_name="$1"

  case "$shim_name" in
    aws)
      printf '%s\n' "${AWS_IMAGE:-docker.io/amazon/aws-cli:2.15.0}"
      ;;
    jq)
      printf '%s\n' "${JQ_IMAGE:-docker.io/stedolan/jq:latest}"
      ;;
    rg)
      printf '%s\n' "${RG_IMAGE:-docker.io/vszl/ripgrep:latest}"
      ;;
    terraform)
      printf '%s\n' "${TF_IMAGE:-docker.io/hashicorp/terraform:latest}"
      ;;
    netcat)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-netcat" "$SHIMMY_IMAGES_DIR/netcat")"
      ;;
    task)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-task" "$SHIMMY_IMAGES_DIR/task")"
      ;;
    tessl)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-tessl" "$SHIMMY_IMAGES_DIR/tessl")"
      ;;
    textual)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-textual" "$SHIMMY_IMAGES_DIR/textual")"
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

print_paths() {
  printf 'SHIMMY_INSTALL_DIR=%s\n' "$SHIMMY_INSTALL_DIR"
  printf 'SHIMMY_SHIM_DIR=%s\n' "$SHIMMY_SHIM_DIR"
  printf 'SHIMMY_IMAGES_DIR=%s\n' "$SHIMMY_IMAGES_DIR"
  printf 'SHIMMY_SHIM_LIB_DIR=%s\n' "$SHIMMY_SHIM_LIB_DIR"
  printf 'Shimmy Startup Profile: %s\n' "$SHIMMY_BASH_FILE"
  if path_contains "$SHIMMY_SHIM_DIR"; then
    printf 'path_active: yes\n'
  else
    printf 'path_active: no\n'
  fi
}

print_installed_shims() {
  local shim_path shim_name

  if [[ ! -d "$SHIMMY_SHIM_DIR" ]]; then
    printf 'installed_shims:\n'
    printf -- '- none\n'
    return 0
  fi

  printf 'installed_shims:\n'
  while IFS= read -r shim_path; do
    shim_name="$(basename "$shim_path")"
    printf -- '- %s: %s\n' "$shim_name" "$(describe_shim_image "$shim_name")"
  done < <(find "$SHIMMY_SHIM_DIR" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) | sort)
}

main() {
  printf 'Shimmy Status\n'
  if [[ -d "$SHIMMY_INSTALL_DIR" ]]; then
    printf 'installed: yes\n'
  else
    printf 'installed: no\n'
  fi
  print_paths
  print_installed_shims
}

main "$@"
