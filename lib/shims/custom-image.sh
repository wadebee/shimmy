#!/usr/bin/env bash

CUSTOM_IMAGE_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/shims/shimmy-log.sh
source "$CUSTOM_IMAGE_LIB_DIR/shimmy-log.sh"
# shellcheck source=lib/shims/shimmy-podman.sh
source "$CUSTOM_IMAGE_LIB_DIR/shimmy-podman.sh"

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

  if [[ -z "${SHIMMY_PODMAN_BIN:-}" ]]; then
    shimmy_podman_bin_require "local shim image builds"
  fi

  if [[ "$build_mode" == "always" ]] || ! "$SHIMMY_PODMAN_BIN" image exists "$image_ref" >/dev/null 2>&1; then
    shimmy::log info "Building local shim image: $image_ref"
    "$SHIMMY_PODMAN_BIN" build \
      --label "io.wadebee.shimmy.image-repo=${image_repo}" \
      --label "io.wadebee.shimmy.context-hash=${context_hash}" \
      -f "$context_dir/Containerfile" \
      -t "$image_ref" \
      "$@" \
      "$context_dir" >&2
  fi

  printf '%s\n' "$image_ref"
}
