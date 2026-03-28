#!/bin/sh
set -eu

DEFAULT_INSTALL_DIR=$HOME/.config/shimmy
REQUESTED_INSTALL_DIR=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

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

context_hash() {
  context_dir=$1

  [ -d "$context_dir" ] || return 1
  [ -f "$context_dir/Containerfile" ] || return 1

  if command -v sha256sum >/dev/null 2>&1; then
    tar \
      -C "$context_dir" \
      --sort=name \
      --mtime='UTC 1970-01-01' \
      --owner=0 \
      --group=0 \
      --numeric-owner \
      -cf - \
      . 2>/dev/null | sha256sum | awk '{print substr($1, 1, 12)}'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    tar \
      -C "$context_dir" \
      --sort=name \
      --mtime='UTC 1970-01-01' \
      --owner=0 \
      --group=0 \
      --numeric-owner \
      -cf - \
      . 2>/dev/null | shasum -a 256 | awk '{print substr($1, 1, 12)}'
    return 0
  fi

  return 1
}

local_image_ref() {
  image_repo=$1
  context_dir=$2
  image_hash=$(context_hash "$context_dir" || true)

  if [ -n "$image_hash" ]; then
    printf '%s:%s\n' "$image_repo" "$image_hash"
    return 0
  fi

  printf '%s\n' "$image_repo"
}

describe_shim_image() {
  shim_name=$1
  images_dir=$2

  case "$shim_name" in
    aws)
      printf '%s\n' "${AWS_IMAGE:-public.ecr.aws/aws-cli/aws-cli:2.31.21}"
      ;;
    jq)
      printf '%s\n' "${JQ_IMAGE:-docker.io/stedolan/jq:latest}"
      ;;
    netcat)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-netcat" "$images_dir/netcat")"
      ;;
    rg)
      printf '%s\n' "${RG_IMAGE:-docker.io/vszl/ripgrep:latest}"
      ;;
    task)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-task" "$images_dir/task")"
      ;;
    terraform)
      printf '%s\n' "${TF_IMAGE:-docker.io/hashicorp/terraform:latest}"
      ;;
    textual)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-textual" "$images_dir/textual")"
      ;;
    tessl)
      printf '%s\n' "$(local_image_ref "localhost/shimmy-tessl" "$images_dir/tessl")"
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

usage() {
  cat <<'EOF'
Print the current Shimmy install status.

Usage:
  scripts/status-shimmy.sh [--install-dir <dir>]
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
