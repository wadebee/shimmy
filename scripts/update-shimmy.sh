#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/lib/shims/custom-image.sh
PODMAN_HELPER_FILE=$ROOT_DIR/lib/shims/shimmy-podman.sh
DEFAULT_INSTALL_DIR=$HOME/.config/shimmy
REQUESTED_INSTALL_DIR=
PULL_IMAGES=0
BUILD_IMAGES=0

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [ ! -f "$CUSTOM_IMAGE_HELPER_FILE" ]; then
  fail "missing custom image helper: $CUSTOM_IMAGE_HELPER_FILE"
fi

if [ ! -f "$PODMAN_HELPER_FILE" ]; then
  fail "missing Podman helper: $PODMAN_HELPER_FILE"
fi

# shellcheck source=lib/shims/custom-image.sh
. "$CUSTOM_IMAGE_HELPER_FILE"
# shellcheck source=lib/shims/shimmy-podman.sh
. "$PODMAN_HELPER_FILE"

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
    return 1
  fi

  sed -n 's/^shim=//p' "$manifest_file"
}

local_build_repo_for_shim() {
  case "$1" in
    netcat) printf 'localhost/shimmy-netcat\n' ;;
    task) printf 'localhost/shimmy-task\n' ;;
    textual) printf 'localhost/shimmy-textual\n' ;;
    *) return 1 ;;
  esac
}

cleanup_old_local_images() {
  shim_name=$1
  images_dir=$2
  image_repo=$(local_build_repo_for_shim "$shim_name" || true)

  [ -n "$image_repo" ] || return 0

  context_dir=$images_dir/$shim_name
  current_hash=$(shimmy_context_hash_render "$context_dir" 2>/dev/null || true)
  [ -n "$current_hash" ] || return 0

  current_ref=${image_repo}:$current_hash

  "$SHIMMY_PODMAN_BIN" images \
    --filter "label=io.wadebee.shimmy.image-repo=${image_repo}" \
    --format '{{.Repository}}:{{.Tag}}' | sort -u | while IFS= read -r image_ref; do
      [ -n "$image_ref" ] || continue
      case "$image_ref" in
        "<none>:<none>"|"<none>:"*|*":<none>")
          continue
          ;;
      esac
      if [ "$image_ref" = "$current_ref" ]; then
        continue
      fi

      if "$SHIMMY_PODMAN_BIN" image rm "$image_ref" >/dev/null 2>&1; then
        printf 'WARN: Removed stale shim image: %s\n' "$image_ref" >&2
      else
        printf 'WARN: Unable to remove stale shim image (possibly in use): %s\n' "$image_ref" >&2
      fi
    done
}

run_pull_refresh() {
  shim_dir=$1
  manifest_file=$2

  shimmy_podman_preflight_require "shimmy update --pull"

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    case "$shim_name" in
      aws)
        AWS_IMAGE_PULL=always "$shim_dir/aws" --version >/dev/null </dev/null
        ;;
      jq)
        JQ_IMAGE_PULL=always "$shim_dir/jq" --version >/dev/null </dev/null
        ;;
      rg)
        RG_IMAGE_PULL=always "$shim_dir/rg" --version >/dev/null </dev/null
        ;;
      terraform)
        TF_IMAGE_PULL=always "$shim_dir/terraform" version >/dev/null </dev/null
        ;;
    esac
  done <<EOF
$(manifest_shim_list "$manifest_file")
EOF
}

run_build_refresh() {
  shim_dir=$1
  images_dir=$2
  manifest_file=$3

  shimmy_podman_preflight_require "shimmy update --build"

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    case "$shim_name" in
      netcat)
        NETCAT_IMAGE_BUILD=always "$shim_dir/netcat" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      task)
        TASK_IMAGE_BUILD=always "$shim_dir/task" --version >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      textual)
        TEXTUAL_IMAGE_BUILD=always "$shim_dir/textual" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
    esac
  done <<EOF
$(manifest_shim_list "$manifest_file")
EOF
}

usage() {
  cat <<'EOF'
Refresh an existing shimmy installation from the current repository.

Usage:
  scripts/update-shimmy.sh [--install-dir <dir>] [--pull] [--build]

Options:
  --install-dir <dir>  Base install directory. Default: ~/.config/shimmy
  --pull               Pull newer remote images for installed remote-image shims.
  --build              Rebuild local images for installed local-build shims.
  -h, --help
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
      --pull)
        PULL_IMAGES=1
        shift
        ;;
      --build)
        BUILD_IMAGES=1
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

  install_dir=$(install_dir_resolve)
  manifest_file=$install_dir/install-manifest.txt

  if [ ! -f "$manifest_file" ]; then
    fail "no shimmy install manifest found at $manifest_file; run ./shimmy install first"
  fi

  manifest_install_dir=$(manifest_value "$manifest_file" install_dir || true)
  if [ -n "$manifest_install_dir" ]; then
    install_dir=$(trim_trailing_slash "$manifest_install_dir")
    manifest_file=$install_dir/install-manifest.txt
  fi

  set -- "$SCRIPT_DIR/install-shimmy.sh" --install-dir "$install_dir"
  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    set -- "$@" --shim "$shim_name"
  done <<EOF
$(manifest_shim_list "$manifest_file")
EOF
  "$@"

  shim_dir=$install_dir/shims
  images_dir=$install_dir/images

  if [ "$PULL_IMAGES" -eq 1 ]; then
    run_pull_refresh "$shim_dir" "$manifest_file"
  fi

  if [ "$BUILD_IMAGES" -eq 1 ]; then
    run_build_refresh "$shim_dir" "$images_dir" "$manifest_file"
  fi
}

main "$@"
