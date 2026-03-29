#!/bin/sh

SHIMMY_CUSTOM_IMAGE_LIB_DIR=$(
  cd -- "$(dirname -- "$0")/../lib/shims" && pwd
)

# shellcheck source=lib/shims/shimmy-log.sh
. "$SHIMMY_CUSTOM_IMAGE_LIB_DIR/shimmy-log.sh"
# shellcheck source=lib/shims/shimmy-podman.sh
. "$SHIMMY_CUSTOM_IMAGE_LIB_DIR/shimmy-podman.sh"

shimmy_context_hash_render() {
  context_dir=$1

  [ -d "$context_dir" ] || shimmy_custom_image_fail "missing image build context: $context_dir"
  [ -f "$context_dir/Containerfile" ] || shimmy_custom_image_fail "missing Containerfile: $context_dir/Containerfile"

  if command -v sha256sum >/dev/null 2>&1; then
    (
      cd -- "$context_dir"
      find . -type f | LC_ALL=C sort | while IFS= read -r context_file; do
        [ -n "$context_file" ] || continue
        printf 'FILE %s\n' "$context_file"
        cat "$context_file"
        printf '\n'
      done
    ) | sha256sum | awk '{print substr($1, 1, 12)}'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    (
      cd -- "$context_dir"
      find . -type f | LC_ALL=C sort | while IFS= read -r context_file; do
        [ -n "$context_file" ] || continue
        printf 'FILE %s\n' "$context_file"
        cat "$context_file"
        printf '\n'
      done
    ) | shasum -a 256 | awk '{print substr($1, 1, 12)}'
    return 0
  fi

  shimmy_custom_image_fail "missing hash helper for image build context: sha256sum or shasum"
}

shimmy_custom_image_fail() {
  shimmy_log_error "$*"
  exit 1
}

shimmy_local_image_ensure() {
  image_repo=$1
  context_dir=$2
  build_mode=$3
  shift 3

  case "$build_mode" in
    auto|always)
      ;;
    *)
      shimmy_custom_image_fail "unsupported image build mode: $build_mode"
      ;;
  esac

  context_hash=$(shimmy_context_hash_render "$context_dir")
  image_ref=${image_repo}:$context_hash

  shimmy_podman_preflight_require "local shim image builds" || return 1

  if [ "$build_mode" = "always" ] || ! "$SHIMMY_PODMAN_BIN" image exists "$image_ref" >/dev/null 2>&1; then
    shimmy_log_info "Building local shim image: $image_ref"
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
