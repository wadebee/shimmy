#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/shimmy-env.sh
source "$SCRIPT_DIR/lib/shimmy-env.sh"

shimmy_log_init
shimmy_init_home_vars "$HOME"

detect_shimmy_install_dir() {
  local path_entry

  IFS=':' read -r -a path_entries <<< "${PATH:-}"
  for path_entry in "${path_entries[@]}"; do
    if [[ "$path_entry" == */shims && -e "$path_entry/task" ]]; then
      dirname "$path_entry"
      return 0
    fi
  done

  return 1
}

shimmy_init_install_vars "${SHIMMY_INSTALL_DIR:-$(detect_shimmy_install_dir || printf '%s\n' "$DEFAULT_INSTALL_DIR")}"

PULL_IMAGES=0
BUILD_IMAGES=0
UPDATE_ARGS=()

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

  if [[ ! -f "$INSTALL_MANIFEST_FILE" ]]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$INSTALL_MANIFEST_FILE" | head -n 1
}

manifest_values() {
  local key="$1"

  if [[ ! -f "$INSTALL_MANIFEST_FILE" ]]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$INSTALL_MANIFEST_FILE"
}

load_update_args_from_manifest() {
  local install_dir install_mode update_bashrc bashrc_file bash_profile_file bash_shimmy_file shim_name

  install_dir="$(manifest_value install_dir)" || return 1
  install_mode="$(manifest_value install_mode || true)"
  update_bashrc="$(manifest_value update_bashrc || true)"
  bashrc_file="$(manifest_value bashrc_file || true)"
  bash_profile_file="$(manifest_value bash_profile_file || true)"
  bash_shimmy_file="$(manifest_value bash_shimmy_file || true)"

  UPDATE_ARGS=( --install-dir "$install_dir" )

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
  local shim_dir shim_name

  shim_dir="$(manifest_value install_dir)/shims"
  [[ -d "$shim_dir" ]] || return 0

  while IFS= read -r shim_name; do
    case "$shim_name" in
      aws) AWS_IMAGE_PULL=always "$shim_dir/aws" --version >/dev/null ;;
      jq) JQ_IMAGE_PULL=always "$shim_dir/jq" --version >/dev/null ;;
      rg) RG_IMAGE_PULL=always "$shim_dir/rg" --version >/dev/null ;;
      terraform) TF_IMAGE_PULL=always "$shim_dir/terraform" version >/dev/null ;;
    esac
  done < <(find "$shim_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -printf '%f\n' | sort)
}

run_build_refresh() {
  local shim_dir shim_name

  shim_dir="$(manifest_value install_dir)/shims"
  [[ -d "$shim_dir" ]] || return 0

  while IFS= read -r shim_name; do
    case "$shim_name" in
      netcat) NETCAT_IMAGE_BUILD=always "$shim_dir/netcat" --help >/dev/null ;;
      task) TASK_IMAGE_BUILD=always "$shim_dir/task" --version >/dev/null ;;
      tessl) TESSL_IMAGE_BUILD=always "$shim_dir/tessl" --help >/dev/null ;;
      textual) TEXTUAL_IMAGE_BUILD=always "$shim_dir/textual" --help >/dev/null ;;
    esac
  done < <(find "$shim_dir" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) -printf '%f\n' | sort)
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
    printf 'ERROR: no shimmy install manifest found at %s; run task install first\n' "$INSTALL_MANIFEST_FILE" >&2
    return 1
  fi

  load_update_args_from_manifest
  bash "$SCRIPT_DIR/install-shimmy.sh" "${UPDATE_ARGS[@]}"

  if [[ "$PULL_IMAGES" -eq 1 ]]; then
    run_pull_refresh
  fi
  if [[ "$BUILD_IMAGES" -eq 1 ]]; then
    run_build_refresh
  fi
}

main "$@"
