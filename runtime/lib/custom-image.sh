#!/usr/bin/env bash

shimmy_fail() {
  echo "Error: $*" >&2
  exit 1
}

shimmy_compute_context_hash() {
  local context_dir="$1"

  [[ -d "$context_dir" ]] || shimmy_fail "missing image build context: $context_dir"
  [[ -f "$context_dir/Containerfile" ]] || shimmy_fail "missing Containerfile: $context_dir/Containerfile"

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

shimmy_ensure_local_image() {
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
      shimmy_fail "unsupported image build mode: $build_mode"
      ;;
  esac

  context_hash="$(shimmy_compute_context_hash "$context_dir")"
  image_ref="${image_repo}:${context_hash}"

  if [[ "$build_mode" == "always" ]] || ! podman image exists "$image_ref" >/dev/null 2>&1; then
    echo "Building local shim image: $image_ref" >&2
    podman build \
      --label "io.wadebee.shimmy.image-repo=${image_repo}" \
      --label "io.wadebee.shimmy.context-hash=${context_hash}" \
      -f "$context_dir/Containerfile" \
      -t "$image_ref" \
      "$@" \
      "$context_dir"
  fi

  printf '%s\n' "$image_ref"
}
