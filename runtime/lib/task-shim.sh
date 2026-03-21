#!/usr/bin/env bash

TASK_SHIM_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=runtime/lib/custom-image.sh
source "$TASK_SHIM_LIB_DIR/custom-image.sh"

shimmy_task_resolve_image() {
  local images_dir="${1:?shimmy images dir is required}"
  local -a build_args=()

  if [[ -n "${TASK_IMAGE:-}" ]]; then
    printf '%s\n' "$TASK_IMAGE"
    return 0
  fi

  if [[ -n "${TASK_BASE_IMAGE:-}" ]]; then
    build_args+=( --build-arg "TASK_BASE_IMAGE=$TASK_BASE_IMAGE" )
  fi
  if [[ -n "${TASK_VERSION:-}" ]]; then
    build_args+=( --build-arg "TASK_VERSION=$TASK_VERSION" )
  fi

  shimmy_ensure_local_image \
    "localhost/shimmy-task" \
    "$images_dir/task" \
    "${TASK_IMAGE_BUILD:-auto}" \
    "${build_args[@]}"
}

shimmy_task_should_use_tty() {
  [[ -t 0 && -t 1 ]]
}

shimmy_task_append_default_run_opts() {
  local -n podman_opts_ref="$1"

  podman_opts_ref+=( -v "$PWD":"$PWD":rw )
  podman_opts_ref+=( -v "$PWD":/work:rw )
  podman_opts_ref+=( -w "$PWD" )

  if [[ -n "${HOME:-}" && -d "${HOME:-}" ]]; then
    podman_opts_ref+=( -e "HOME=$HOME" )
    podman_opts_ref+=( -v "$HOME":"$HOME":rw )
  fi

  if [[ -d /tmp ]]; then
    podman_opts_ref+=( -v /tmp:/tmp:rw )
  fi

  if [[ -n "${CONTAINER_HOST:-}" ]]; then
    case "$CONTAINER_HOST" in
      unix://*)
        local socket_path="${CONTAINER_HOST#unix://}"
        if [[ -S "$socket_path" ]]; then
          podman_opts_ref+=( -e "CONTAINER_HOST=$CONTAINER_HOST" )
          podman_opts_ref+=( -v "$socket_path":"$socket_path" )
        fi
        ;;
      *)
        podman_opts_ref+=( -e "CONTAINER_HOST=$CONTAINER_HOST" )
        ;;
    esac
  fi
}
