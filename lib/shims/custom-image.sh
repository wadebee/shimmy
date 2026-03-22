#!/usr/bin/env bash

shimmy::_log_level_value() {
  case "${1:-info}" in
    debug) printf '10\n' ;;
    info) printf '20\n' ;;
    warn|warning) printf '30\n' ;;
    error) printf '40\n' ;;
    silent|quiet|none) printf '50\n' ;;
    *) printf '20\n' ;;
  esac
}

shimmy::_log_normalize_level() {
  case "${1:-info}" in
    debug) printf 'debug\n' ;;
    info) printf 'info\n' ;;
    warn|warning) printf 'warn\n' ;;
    error) printf 'error\n' ;;
    silent|quiet|none) printf 'silent\n' ;;
    *) printf 'info\n' ;;
  esac
}

shimmy::_is_log_level_enabled() {
  local message_level="${1:?message level is required}"
  local configured_level

  configured_level="$(shimmy::_log_normalize_level "${LOG_LEVEL:-info}")"
  [[ "$(shimmy::_log_level_value "$message_level")" -ge "$(shimmy::_log_level_value "$configured_level")" ]]
}

shimmy::log() {
  local level="${1:?log level is required}"
  shift

  shimmy::_is_log_level_enabled "$level" || return 0

  printf '%s: %s\n' "$(tr '[:lower:]' '[:upper:]' <<< "$level")" "$*" >&2
}

shimmy::_fail() {
  shimmy::log error "$*"
  exit 1
}

shimmy::compute_context_hash() {
  local context_dir="$1"

  [[ -d "$context_dir" ]] || shimmy::_fail "missing image build context: $context_dir"
  [[ -f "$context_dir/Containerfile" ]] || shimmy::_fail "missing Containerfile: $context_dir/Containerfile"

  tar \
    -C "$context_dir" \
    --sort=name \
    --mtime='UTC 1970-01-01' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -cf - \
    . | sha256sum | awk '{print substr($1, 1, 12)}'
}

shimmy::ensure_local_image() {
  local image_repo="$1"
  local context_dir="$2"
  local build_mode="$3"
  shift 3

  local context_hash
  local image_ref

  case "$build_mode" in
    auto|always)
      ;;
    *)
      shimmy::_fail "unsupported image build mode: $build_mode"
      ;;
  esac

  context_hash="$(shimmy::compute_context_hash "$context_dir")"
  image_ref="${image_repo}:${context_hash}"

  if [[ "$build_mode" == "always" ]] || ! podman image exists "$image_ref" >/dev/null 2>&1; then
    shimmy::log info "Building local shim image: $image_ref"
    podman build \
      --label "io.wadebee.shimmy.image-repo=${image_repo}" \
      --label "io.wadebee.shimmy.context-hash=${context_hash}" \
      -f "$context_dir/Containerfile" \
      -t "$image_ref" \
      "$@" \
      "$context_dir" >&2
  fi

  printf '%s\n' "$image_ref"
}
