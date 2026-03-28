#!/bin/sh

shimmy_podman_bin_resolve() {
  if command -v podman >/dev/null 2>&1; then
    SHIMMY_PODMAN_BIN=$(command -v podman)
    return 0
  fi

  if [ -x /opt/podman/bin/podman ]; then
    SHIMMY_PODMAN_BIN=/opt/podman/bin/podman
    return 0
  fi

  SHIMMY_PODMAN_BIN=
  return 1
}

shimmy_podman_bin_require() {
  context_label=${1:-shimmy}

  if ! shimmy_podman_bin_resolve; then
    shimmy_podman_failure_print_missing "$context_label"
    return 1
  fi

  shimmy_podman_path_activate "$SHIMMY_PODMAN_BIN"
  export SHIMMY_PODMAN_BIN
}

shimmy_podman_failure_print_missing() {
  context_label=${1:-shimmy}

  printf 'ERROR: podman is required for %s.\n' "$context_label" >&2
  printf '%s\n' 'Install Podman and ensure the binary is available on PATH.' >&2
  printf '%s\n' 'Shimmy also checks /opt/podman/bin/podman for the macOS pkg installer.' >&2
}

shimmy_podman_failure_print_unreachable() {
  context_label=${1:-shimmy}
  podman_bin=${2:-podman}

  printf 'ERROR: podman was found at %s but could not talk to the engine for %s.\n' "$podman_bin" "$context_label" >&2
  printf '%s\n' 'Verify that `podman info` succeeds in your shell.' >&2
  printf '%s\n' 'On macOS, start the engine with: podman machine start' >&2
  printf '%s\n' 'If you use a non-default connection, review: podman system connection list' >&2
  if [ -n "${CONTAINER_HOST:-}" ]; then
    printf 'Current CONTAINER_HOST=%s\n' "$CONTAINER_HOST" >&2
    printf '%s\n' 'Confirm that CONTAINER_HOST points at a reachable Podman service or unset it to use the default connection.' >&2
  else
    printf '%s\n' 'If you use CONTAINER_HOST, confirm it points at a reachable Podman service.' >&2
  fi
}

shimmy_podman_path_activate() {
  podman_bin=${1:?podman binary path is required}
  podman_dir=$(dirname -- "$podman_bin")

  case ":${PATH:-}:" in
    *":$podman_dir:"*)
      ;;
    *)
      PATH=$podman_dir${PATH:+":$PATH"}
      export PATH
      ;;
  esac
}

shimmy_podman_preflight_require() {
  context_label=${1:-shimmy}

  shimmy_podman_bin_require "$context_label" || return 1

  if ! "$SHIMMY_PODMAN_BIN" info >/dev/null 2>&1; then
    shimmy_podman_failure_print_unreachable "$context_label" "$SHIMMY_PODMAN_BIN"
    return 1
  fi
}
