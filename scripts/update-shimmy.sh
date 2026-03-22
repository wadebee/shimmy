#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/shimmy-env.sh
source "$SCRIPT_DIR/lib/shimmy-env.sh"

shimmy_log_init
shimmy_init_home_vars "$HOME"
shimmy_discover_install_layout "${SHIMMY_INSTALL_DIR:-}"

if [[ -f "$SHIMMY_RUNTIME_DIR/lib/custom-image.sh" ]]; then
  # shellcheck source=runtime/lib/custom-image.sh
  source "$SHIMMY_RUNTIME_DIR/lib/custom-image.sh"
fi

PULL_IMAGES=0
BUILD_IMAGES=0
UPDATE_ARGS=()
UPDATE_ENV_VARS=()

usage() {
  cat <<'EOF'
Refresh an existing shimmy installation from the current repository.

Usage:
  scripts/update-shimmy.sh [--pull] [--build]

Options:
  --pull   Pull newer remote images for installed remote-image shims.
  --build  Rebuild local images for installed local-build shims.
  -h, --help
EOF
}

manifest_value() {
  local key="$1"

  shimmy_manifest_value "$INSTALL_MANIFEST_FILE" "$key"
}

manifest_values() {
  local key="$1"

  if [[ ! -f "$INSTALL_MANIFEST_FILE" ]]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$INSTALL_MANIFEST_FILE"
}

load_update_args_from_manifest() {
  local install_dir
  local shim_dir
  local images_dir
  local runtime_dir
  local install_mode
  local update_bashrc
  local bashrc_file
  local bash_profile_file
  local bash_shimmy_file
  local shim_name

  install_dir="$(manifest_value install_dir)" || return 1
  shim_dir="$(manifest_value shim_dir || true)"
  images_dir="$(manifest_value images_dir || true)"
  runtime_dir="$(manifest_value runtime_dir || true)"
  install_mode="$(manifest_value install_mode || true)"
  update_bashrc="$(manifest_value update_bashrc || true)"
  bashrc_file="$(manifest_value bashrc_file || true)"
  bash_profile_file="$(manifest_value bash_profile_file || true)"
  bash_shimmy_file="$(manifest_value bash_shimmy_file || true)"

  UPDATE_ARGS=( --install-dir "$install_dir" )
  UPDATE_ENV_VARS=( "SHIMMY_INSTALL_DIR=$install_dir" )

  if [[ -n "$shim_dir" ]]; then
    UPDATE_ENV_VARS+=( "SHIMMY_SHIM_DIR=$shim_dir" )
  fi
  if [[ -n "$images_dir" ]]; then
    UPDATE_ENV_VARS+=( "SHIMMY_IMAGES_DIR=$images_dir" )
  fi
  if [[ -n "$runtime_dir" ]]; then
    UPDATE_ENV_VARS+=( "SHIMMY_RUNTIME_DIR=$runtime_dir" )
  fi

  case "$install_mode" in
    symlink) UPDATE_ARGS+=( --symlink ) ;;
    ""|copy) UPDATE_ARGS+=( --copy ) ;;
  esac

  case "$update_bashrc" in
    0) UPDATE_ARGS+=( --no-update-bashrc ) ;;
    ""|1) UPDATE_ARGS+=( --update-bashrc ) ;;
  esac

  if [[ -n "$bashrc_file" ]]; then
    UPDATE_ARGS+=( --bashrc-file "$bashrc_file" )
  fi
  if [[ -n "$bash_profile_file" ]]; then
    UPDATE_ARGS+=( --bash-profile-file "$bash_profile_file" )
  fi
  if [[ -n "$bash_shimmy_file" ]]; then
    UPDATE_ARGS+=( --bash-shimmy-file "$bash_shimmy_file" )
  fi

  while IFS= read -r shim_name; do
    [[ -n "$shim_name" ]] || continue
    UPDATE_ARGS+=( --shim "$shim_name" )
  done < <(manifest_values requested_shim || true)
}

run_pull_refresh() {
  local shim_name
  local -a shim_names

  [[ -d "$SHIMMY_SHIM_DIR" ]] || return 0

  mapfile -t shim_names < <(find "$SHIMMY_SHIM_DIR" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -printf '%f\n' | sort)

  for shim_name in "${shim_names[@]}"; do
    case "$shim_name" in
      aws) AWS_IMAGE_PULL=always "$SHIMMY_SHIM_DIR/aws" --version >/dev/null </dev/null ;;
      jq) JQ_IMAGE_PULL=always "$SHIMMY_SHIM_DIR/jq" --version >/dev/null </dev/null ;;
      rg) RG_IMAGE_PULL=always "$SHIMMY_SHIM_DIR/rg" --version >/dev/null </dev/null ;;
      terraform) TF_IMAGE_PULL=always "$SHIMMY_SHIM_DIR/terraform" version >/dev/null </dev/null ;;
    esac
  done
}

run_build_refresh() {
  local shim_name
  local -a shim_names

  [[ -d "$SHIMMY_SHIM_DIR" ]] || return 0

  mapfile -t shim_names < <(find "$SHIMMY_SHIM_DIR" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -printf '%f\n' | sort)

  for shim_name in "${shim_names[@]}"; do
    case "$shim_name" in
      netcat)
        NETCAT_IMAGE_BUILD=always "$SHIMMY_SHIM_DIR/netcat" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name"
        ;;
      task)
        TASK_IMAGE_BUILD=always "$SHIMMY_SHIM_DIR/task" --version >/dev/null </dev/null
        cleanup_old_local_images "$shim_name"
        ;;
      tessl)
        TESSL_IMAGE_BUILD=always "$SHIMMY_SHIM_DIR/tessl" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name"
        ;;
      textual)
        TEXTUAL_IMAGE_BUILD=always "$SHIMMY_SHIM_DIR/textual" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name"
        ;;
    esac
  done
}

local_build_repo_for_shim() {
  case "$1" in
    netcat) printf 'localhost/shimmy-netcat\n' ;;
    task) printf 'localhost/shimmy-task\n' ;;
    tessl) printf 'localhost/shimmy-tessl\n' ;;
    textual) printf 'localhost/shimmy-textual\n' ;;
    *) return 1 ;;
  esac
}

local_build_context_for_shim() {
  printf '%s/%s\n' "$SHIMMY_IMAGES_DIR" "$1"
}

cleanup_old_local_images() {
  local shim_name="$1"
  local image_repo context_dir current_ref image_ref

  image_repo="$(local_build_repo_for_shim "$shim_name")" || return 0
  context_dir="$(local_build_context_for_shim "$shim_name")"
  [[ -d "$context_dir" ]] || return 0

  current_ref="${image_repo}:$(shimmy_compute_context_hash "$context_dir")"

  while IFS= read -r image_ref; do
    [[ -n "$image_ref" ]] || continue
    if [[ "$image_ref" == "<none>:<none>" || "$image_ref" == "<none>:"* || "$image_ref" == *":<none>" ]]; then
      continue
    fi
    if [[ "$image_ref" == "$current_ref" ]]; then
      continue
    fi

    if podman image rm "$image_ref" >/dev/null 2>&1; then
      shimmy_log warn "Removed stale shim image: $image_ref"
    else
      shimmy_log warn "Unable to remove stale shim image (possibly in use): $image_ref"
    fi
  done < <(
    podman images \
      --filter "label=io.wadebee.shimmy.image-repo=${image_repo}" \
      --format '{{.Repository}}:{{.Tag}}' | sort -u
  )

  return 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
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
        return 0
        ;;
      *)
        printf 'ERROR: unknown argument: %s\n' "$1" >&2
        return 1
        ;;
    esac
  done

  if [[ ! -f "$INSTALL_MANIFEST_FILE" ]]; then
    printf 'ERROR: no shimmy install manifest found at %s; run ./shimmy install first\n' "$INSTALL_MANIFEST_FILE" >&2
    return 1
  fi

  load_update_args_from_manifest
  env "${UPDATE_ENV_VARS[@]}" bash "$SCRIPT_DIR/install-shimmy.sh" "${UPDATE_ARGS[@]}"
  shimmy_apply_install_layout_from_manifest "$INSTALL_MANIFEST_FILE" || true

  if [[ "$PULL_IMAGES" -eq 1 ]]; then
    run_pull_refresh
  fi
  if [[ "$BUILD_IMAGES" -eq 1 ]]; then
    run_build_refresh
  fi
}

main "$@"
