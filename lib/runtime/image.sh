#!/bin/sh
# Image configuration, local build, and cache helpers.

SHIMMY_CUSTOM_IMAGE_LIB_DIR=${SHIMMY_RUNTIME_DIR:-}

if [ -z "$SHIMMY_CUSTOM_IMAGE_LIB_DIR" ]; then
  printf '%s\n' 'ERROR: SHIMMY_RUNTIME_DIR is required when sourcing lib/runtime/image.sh.' >&2
  exit 1
fi

# shellcheck source=lib/runtime/log.sh
. "$SHIMMY_CUSTOM_IMAGE_LIB_DIR/log.sh"
# shellcheck source=lib/runtime/podman.sh
. "$SHIMMY_CUSTOM_IMAGE_LIB_DIR/podman.sh"

shimmy_context_content_print() {
  context_dir=$1

  [ -d "$context_dir" ] || shimmy_custom_image_fail "missing image build context: $context_dir"
  [ -f "$context_dir/Containerfile" ] || shimmy_custom_image_fail "missing Containerfile: $context_dir/Containerfile"

  (
    cd -- "$context_dir"
    find . -type f | LC_ALL=C sort | while IFS= read -r context_file; do
      [ -n "$context_file" ] || continue
      printf 'FILE %s\n' "$context_file"
      cat "$context_file"
      printf '\n'
    done
  )
}

shimmy_context_hash_render() {
  context_dir=$1

  if command -v sha256sum >/dev/null 2>&1; then
    shimmy_context_content_print "$context_dir" | sha256sum | awk '{print substr($1, 1, 12)}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shimmy_context_content_print "$context_dir" | shasum -a 256 | awk '{print substr($1, 1, 12)}'
    return 0
  fi

  shimmy_custom_image_fail "missing hash helper for image build context: sha256sum or shasum"
}

shimmy_custom_image_fail() {
  shimmy_log_error "$*"
  exit 1
}

shimmy_image_config_allowed_key_contains() {
  allowed_keys=$1
  key_name=$2

  case "
$allowed_keys
" in
    *"
$key_name
"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

shimmy_image_config_digest_ref_validate() {
  image_ref=$1

  case "$image_ref" in
    *@sha256:*)
      ;;
    *)
      return 1
      ;;
  esac

  image_repo=${image_ref%@sha256:*}
  image_digest=${image_ref##*@sha256:}
  case "$image_repo" in
    */?*)
      ;;
    *)
      return 1
      ;;
  esac
  image_registry=${image_repo%%/*}
  case "$image_registry" in
    localhost|*.*|*:* )
      ;;
    *)
      return 1
      ;;
  esac
  image_repository_path=${image_repo#*/}
  case "$image_repository_path" in
    *[:@]*|'')
      return 1
      ;;
  esac
  [ "${#image_digest}" -eq 64 ] || return 1
  case "$image_digest" in
    *[!0-9a-f]*)
      return 1
      ;;
  esac

  case "$image_repo$image_digest" in
    *[!A-Za-z0-9._/:@-]*)
      return 1
      ;;
  esac
}

shimmy_image_config_fail() {
  config_file=$1
  shift
  printf 'ERROR: invalid image configuration %s: %s\n' "$config_file" "$*" >&2
  return 1
}

shimmy_image_config_key_count() {
  config_file=$1
  key_name=$2

  awk -F= -v key="$key_name" '$1 == key { count += 1 } END { print count + 0 }' "$config_file"
}

shimmy_image_config_keys_print() {
  config_file=$1

  awk -F= '
    /^[[:space:]]*($|#)/ { next }
    index($0, "=") == 0 { print ""; next }
    { print $1 }
  ' "$config_file"
}

shimmy_image_config_ref_validate() {
  image_ref=$1

  case "$image_ref" in
    *@sha256:*)
      shimmy_image_config_digest_ref_validate "$image_ref"
      return
      ;;
  esac

  case "$image_ref" in
    */*:* )
      ;;
    *)
      return 1
      ;;
  esac
  case "$image_ref" in
    *@*)
      return 1
      ;;
  esac
  image_registry=${image_ref%%/*}
  case "$image_registry" in
    localhost|*.*|*:*)
      ;;
    *)
      return 1
      ;;
  esac
  case "$image_ref" in
    *[!A-Za-z0-9._/:@-]*)
      return 1
      ;;
  esac
}

shimmy_image_config_scalar_read() {
  config_file=$1
  key_name=$2

  awk -F= -v key="$key_name" '
    $1 == key {
      value = substr($0, length($1) + 2)
      print value
    }
  ' "$config_file" | sed -n '1p'
}

shimmy_image_config_validate() {
  config_file=$1

  [ -f "$config_file" ] || shimmy_image_config_fail "$config_file" 'file is missing' || return 1

  schema_version=$(shimmy_image_config_scalar_read "$config_file" shimmy_image_config_version)
  [ "$schema_version" = 1 ] || shimmy_image_config_fail "$config_file" 'shimmy_image_config_version must equal 1' || return 1

  image_source=$(shimmy_image_config_scalar_read "$config_file" image_source)
  common_keys='shimmy_image_config_version
image_source
image_platform'
  case "$image_source" in
    external)
      allowed_keys="$common_keys
image_upstream_ref
image_default_ref
image_registry_access"
      ;;
    local-build)
      image_base_count=$(shimmy_image_config_scalar_read "$config_file" image_base_count)
      case "$image_base_count" in
        ''|0|*[!0-9]*)
          shimmy_image_config_fail "$config_file" 'image_base_count must be a positive decimal integer'
          return 1
          ;;
      esac
      allowed_keys="$common_keys
image_context
image_local_repo
image_base_count"
      image_base_index=1
      while [ "$image_base_index" -le "$image_base_count" ]; do
        allowed_keys="$allowed_keys
image_base_${image_base_index}_build_arg
image_base_${image_base_index}_upstream_ref
image_base_${image_base_index}_default_ref
image_base_${image_base_index}_registry_access"
        image_base_index=$((image_base_index + 1))
      done
      ;;
    *)
      shimmy_image_config_fail "$config_file" 'image_source must equal external or local-build'
      return 1
      ;;
  esac

  while IFS= read -r key_name; do
    [ -n "$key_name" ] || {
      shimmy_image_config_fail "$config_file" 'every metadata line must use key=value syntax'
      return 1
    }
    shimmy_image_config_allowed_key_contains "$allowed_keys" "$key_name" || {
      shimmy_image_config_fail "$config_file" "unknown or illegal key: $key_name"
      return 1
    }
  done <<EOF
$(shimmy_image_config_keys_print "$config_file")
EOF

  for key_name in $allowed_keys; do
    key_count=$(shimmy_image_config_key_count "$config_file" "$key_name")
    if [ "$key_name" = image_platform ]; then
      continue
    fi
    [ "$key_count" -le 1 ] || {
      shimmy_image_config_fail "$config_file" "duplicate scalar key: $key_name"
      return 1
    }
  done

  [ "$(shimmy_image_config_key_count "$config_file" shimmy_image_config_version)" -eq 1 ] || shimmy_image_config_fail "$config_file" 'shimmy_image_config_version is required exactly once' || return 1
  [ "$(shimmy_image_config_key_count "$config_file" image_source)" -eq 1 ] || shimmy_image_config_fail "$config_file" 'image_source is required exactly once' || return 1
  [ "$(shimmy_image_config_key_count "$config_file" image_platform)" -eq 2 ] || shimmy_image_config_fail "$config_file" 'image_platform must declare exactly two values' || return 1
  [ "$(shimmy_image_config_key_count "$config_file" image_platform)" -eq "$(awk -F= '$1 == "image_platform" { values[$2] = 1 } END { for (value in values) count += 1; print count + 0 }' "$config_file")" ] || shimmy_image_config_fail "$config_file" 'image_platform contains a duplicate value' || return 1
  [ "$(awk -F= '$1 == "image_platform" && $2 == "linux/amd64" { count += 1 } END { print count + 0 }' "$config_file")" -eq 1 ] || shimmy_image_config_fail "$config_file" 'image_platform must include linux/amd64' || return 1
  [ "$(awk -F= '$1 == "image_platform" && $2 == "linux/arm64" { count += 1 } END { print count + 0 }' "$config_file")" -eq 1 ] || shimmy_image_config_fail "$config_file" 'image_platform must include linux/arm64' || return 1

  if [ "$image_source" = external ]; then
    for key_name in image_upstream_ref image_default_ref image_registry_access; do
      [ "$(shimmy_image_config_key_count "$config_file" "$key_name")" -eq 1 ] || shimmy_image_config_fail "$config_file" "$key_name is required exactly once for an external image" || return 1
    done
    image_upstream_ref=$(shimmy_image_config_scalar_read "$config_file" image_upstream_ref)
    image_default_ref=$(shimmy_image_config_scalar_read "$config_file" image_default_ref)
    image_registry_access=$(shimmy_image_config_scalar_read "$config_file" image_registry_access)
    shimmy_image_config_ref_validate "$image_upstream_ref" || shimmy_image_config_fail "$config_file" 'image_upstream_ref must be a fully qualified tag or sha256 digest reference' || return 1
    shimmy_image_config_digest_ref_validate "$image_default_ref" || shimmy_image_config_fail "$config_file" 'image_default_ref must be a fully qualified sha256 digest reference' || return 1
    case "$image_registry_access" in public|authenticated) ;; *) shimmy_image_config_fail "$config_file" 'image_registry_access must equal public or authenticated'; return 1 ;; esac
    return 0
  fi

  for key_name in image_context image_local_repo image_base_count; do
    [ "$(shimmy_image_config_key_count "$config_file" "$key_name")" -eq 1 ] || shimmy_image_config_fail "$config_file" "$key_name is required exactly once for a local build" || return 1
  done
  image_context=$(shimmy_image_config_scalar_read "$config_file" image_context)
  case "$image_context" in ''|/*|.|..|../*|*/../*|*/..|*//*|*[!A-Za-z0-9._/-]*) shimmy_image_config_fail "$config_file" 'image_context must be a non-traversing relative path'; return 1 ;; esac
  image_local_repo=$(shimmy_image_config_scalar_read "$config_file" image_local_repo)
  case "$image_local_repo" in localhost/?*) ;; *) shimmy_image_config_fail "$config_file" 'image_local_repo must use the localhost/ namespace'; return 1 ;; esac
  case "${image_local_repo#localhost/}" in *[:@]*|*[!A-Za-z0-9._/-]*) shimmy_image_config_fail "$config_file" 'image_local_repo contains unsafe characters or a tag/digest'; return 1 ;; esac

  image_base_index=1
  while [ "$image_base_index" -le "$image_base_count" ]; do
    build_arg_key=image_base_${image_base_index}_build_arg
    upstream_key=image_base_${image_base_index}_upstream_ref
    default_key=image_base_${image_base_index}_default_ref
    access_key=image_base_${image_base_index}_registry_access
    [ "$(shimmy_image_config_key_count "$config_file" "$build_arg_key")" -eq 1 ] || shimmy_image_config_fail "$config_file" "$build_arg_key is required exactly once" || return 1
    [ "$(shimmy_image_config_key_count "$config_file" "$default_key")" -eq 1 ] || shimmy_image_config_fail "$config_file" "$default_key is required exactly once" || return 1
    build_arg_name=$(shimmy_image_config_scalar_read "$config_file" "$build_arg_key")
    case "$build_arg_name" in SHIMMY_?*) ;; *) shimmy_image_config_fail "$config_file" "$build_arg_key must be a SHIMMY_-prefixed POSIX variable name"; return 1 ;; esac
    case "$build_arg_name" in *[!A-Z0-9_]*) shimmy_image_config_fail "$config_file" "$build_arg_key must be a SHIMMY_-prefixed POSIX variable name"; return 1 ;; esac
    default_ref=$(shimmy_image_config_scalar_read "$config_file" "$default_key")
    if [ "$default_ref" = scratch ]; then
      [ "$(shimmy_image_config_key_count "$config_file" "$upstream_key")" -eq 0 ] || shimmy_image_config_fail "$config_file" "$upstream_key must be omitted for scratch" || return 1
      [ "$(shimmy_image_config_key_count "$config_file" "$access_key")" -eq 0 ] || shimmy_image_config_fail "$config_file" "$access_key must be omitted for scratch" || return 1
    else
      [ "$(shimmy_image_config_key_count "$config_file" "$upstream_key")" -eq 1 ] || shimmy_image_config_fail "$config_file" "$upstream_key is required exactly once" || return 1
      [ "$(shimmy_image_config_key_count "$config_file" "$access_key")" -eq 1 ] || shimmy_image_config_fail "$config_file" "$access_key is required exactly once" || return 1
      upstream_ref=$(shimmy_image_config_scalar_read "$config_file" "$upstream_key")
      registry_access=$(shimmy_image_config_scalar_read "$config_file" "$access_key")
      shimmy_image_config_ref_validate "$upstream_ref" || shimmy_image_config_fail "$config_file" "$upstream_key must be a fully qualified tag or sha256 digest reference" || return 1
      shimmy_image_config_digest_ref_validate "$default_ref" || shimmy_image_config_fail "$config_file" "$default_key must be a fully qualified sha256 digest reference" || return 1
      case "$registry_access" in public|authenticated) ;; *) shimmy_image_config_fail "$config_file" "$access_key must equal public or authenticated"; return 1 ;; esac
    fi
    image_base_index=$((image_base_index + 1))
  done
}

shimmy_image_external_default_read() {
  config_file=$1

  shimmy_image_config_validate "$config_file" || return 1
  [ "$(shimmy_image_config_scalar_read "$config_file" image_source)" = external ] || shimmy_image_config_fail "$config_file" 'external image configuration is required' || return 1
  shimmy_image_config_scalar_read "$config_file" image_default_ref
}

shimmy_local_image_build_args_append() {
  config_file=$1
  shift

  shimmy_local_image_build_args_validate "$@" || return 1

  image_base_count=$(shimmy_image_config_scalar_read "$config_file" image_base_count)
  image_base_index=1
  while [ "$image_base_index" -le "$image_base_count" ]; do
    build_arg_name=$(shimmy_image_config_scalar_read "$config_file" "image_base_${image_base_index}_build_arg")
    default_ref=$(shimmy_image_config_scalar_read "$config_file" "image_base_${image_base_index}_default_ref")
    eval "override_value=\${$build_arg_name-}"
    if [ -n "$override_value" ]; then
      build_arg_value=$override_value
    else
      build_arg_value=$default_ref
    fi
    set -- "$@" --build-arg "$build_arg_name=$build_arg_value"
    image_base_index=$((image_base_index + 1))
  done

  shimmy_local_image_build_args_file=$SHIMMY_LOCAL_IMAGE_ARGS_FILE
  : > "$shimmy_local_image_build_args_file"
  for build_arg_token do
    printf '%s\n' "$build_arg_token" >> "$shimmy_local_image_build_args_file"
  done
}

shimmy_local_image_build_args_validate() {
  while [ "$#" -gt 0 ]; do
    [ "$1" = --build-arg ] || shimmy_image_config_fail '<runtime-build-arguments>' "unsupported local image build option: $1" || return 1
    [ "$#" -ge 2 ] || shimmy_image_config_fail '<runtime-build-arguments>' 'missing value after --build-arg' || return 1
    build_arg_entry=$2
    case "$build_arg_entry" in
      *=*)
        ;;
      *)
        shimmy_image_config_fail '<runtime-build-arguments>' "build argument must use SHIMMY_NAME=value syntax: $build_arg_entry"
        return 1
        ;;
    esac
    build_arg_name=${build_arg_entry%%=*}
    case "$build_arg_name" in SHIMMY_?*) ;; *) shimmy_image_config_fail '<runtime-build-arguments>' "build argument name must use the SHIMMY_ prefix: $build_arg_name"; return 1 ;; esac
    case "$build_arg_name" in *[!A-Z0-9_]*) shimmy_image_config_fail '<runtime-build-arguments>' "build argument name is not POSIX-safe: $build_arg_name"; return 1 ;; esac
    shift 2
  done
}

shimmy_local_image_context_dir_resolve() {
  config_file=$1
  version_dir=$(cd -- "$(dirname -- "$config_file")" && pwd -P) || shimmy_custom_image_fail "unable to resolve image configuration directory: $config_file"
  image_context=$(shimmy_image_config_scalar_read "$config_file" image_context)
  context_candidate=$version_dir/$image_context
  [ -d "$context_candidate" ] || shimmy_custom_image_fail "missing image build context: $context_candidate"
  context_dir=$(cd -- "$context_candidate" && pwd -P) || shimmy_custom_image_fail "unable to resolve image build context: $context_candidate"
  case "$context_dir" in
    "$version_dir"/*)
      ;;
    *)
      shimmy_custom_image_fail "image build context resolves outside its version directory: $context_candidate"
      ;;
  esac
  [ -f "$context_dir/Containerfile" ] || shimmy_custom_image_fail "missing Containerfile: $context_dir/Containerfile"
  printf '%s\n' "$context_dir"
}

shimmy_local_image_identity_hash_render() {
  config_file=$1
  context_dir=$2
  shift 2

  if command -v sha256sum >/dev/null 2>&1; then
    {
      printf '%s\n' 'IMAGE_CONFIG'
      cat "$config_file"
      printf '\n%s\n' 'CONTEXT'
      shimmy_context_content_print "$context_dir"
      printf '%s\n' 'BUILD_ARGUMENT_VECTOR'
      for build_arg_token do
        printf 'ARG %s\n' "$build_arg_token"
      done
    } | sha256sum | awk '{print substr($1, 1, 12)}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    {
      printf '%s\n' 'IMAGE_CONFIG'
      cat "$config_file"
      printf '\n%s\n' 'CONTEXT'
      shimmy_context_content_print "$context_dir"
      printf '%s\n' 'BUILD_ARGUMENT_VECTOR'
      for build_arg_token do
        printf 'ARG %s\n' "$build_arg_token"
      done
    } | shasum -a 256 | awk '{print substr($1, 1, 12)}'
    return 0
  fi
  shimmy_custom_image_fail 'missing hash helper for local image identity: sha256sum or shasum'
}

shimmy_local_image_ref_render() {
  config_file=$1
  shift

  shimmy_image_config_validate "$config_file" || return 1
  [ "$(shimmy_image_config_scalar_read "$config_file" image_source)" = local-build ] || shimmy_image_config_fail "$config_file" 'local-build image configuration is required' || return 1
  context_dir=$(shimmy_local_image_context_dir_resolve "$config_file")
  image_repo=$(shimmy_image_config_scalar_read "$config_file" image_local_repo)
  SHIMMY_LOCAL_IMAGE_ARGS_FILE=$(mktemp "${TMPDIR:-/tmp}/shimmy-image-args.XXXXXX") || shimmy_custom_image_fail 'unable to create local image argument file'
  shimmy_local_image_build_args_append "$config_file" "$@"
  set --
  while IFS= read -r build_arg_token; do
    set -- "$@" "$build_arg_token"
  done < "$SHIMMY_LOCAL_IMAGE_ARGS_FILE"
  rm -f "$SHIMMY_LOCAL_IMAGE_ARGS_FILE"
  image_hash=$(shimmy_local_image_identity_hash_render "$config_file" "$context_dir" "$@")
  shimmy_podman_platform_resolve || return 1
  platform_tag=$(shimmy_podman_platform_tag_render "$SHIMMY_PODMAN_PLATFORM")
  printf '%s:%s-%s\n' "$image_repo" "$image_hash" "$platform_tag"
}

shimmy_local_image_ensure() {
  config_file=$1
  build_mode=$2
  shift 2

  case "$build_mode" in
    auto|always)
      ;;
    *)
      shimmy_custom_image_fail "unsupported image build mode: $build_mode"
      ;;
  esac

  shimmy_image_config_validate "$config_file" || return 1
  context_dir=$(shimmy_local_image_context_dir_resolve "$config_file")
  image_repo=$(shimmy_image_config_scalar_read "$config_file" image_local_repo)
  SHIMMY_LOCAL_IMAGE_ARGS_FILE=$(mktemp "${TMPDIR:-/tmp}/shimmy-image-args.XXXXXX") || shimmy_custom_image_fail 'unable to create local image argument file'
  shimmy_local_image_build_args_append "$config_file" "$@"
  set --
  while IFS= read -r build_arg_token; do
    set -- "$@" "$build_arg_token"
  done < "$SHIMMY_LOCAL_IMAGE_ARGS_FILE"
  rm -f "$SHIMMY_LOCAL_IMAGE_ARGS_FILE"
  image_hash=$(shimmy_local_image_identity_hash_render "$config_file" "$context_dir" "$@")
  shimmy_podman_platform_resolve || return 1
  platform_tag=$(shimmy_podman_platform_tag_render "$SHIMMY_PODMAN_PLATFORM")
  image_ref=${image_repo}:${image_hash}-${platform_tag}

  if shimmy_podman_is_preview; then
    printf '%s\n' "$image_ref"
    return 0
  fi

  shimmy_podman_preflight_require "local shim image builds" || return 1

  if [ "$build_mode" = "always" ] || ! "$SHIMMY_PODMAN_BIN" image exists "$image_ref" >/dev/null 2>&1; then
    shimmy_log_info "Building local shim image: $image_ref"
    "$SHIMMY_PODMAN_BIN" build \
      --platform "$SHIMMY_PODMAN_PLATFORM" \
      --label "io.wadebee.shimmy.image-repo=${image_repo}" \
      --label "io.wadebee.shimmy.image-input-hash=${image_hash}" \
      --label "io.wadebee.shimmy.platform=${SHIMMY_PODMAN_PLATFORM}" \
      -f "$context_dir/Containerfile" \
      -t "$image_ref" \
      "$@" \
      "$context_dir" >&2
  fi

  printf '%s\n' "$image_ref"
}

shimmy_local_image_stale_cleanup() {
  config_file=$1
  shift

  shimmy_image_config_validate "$config_file" || return 1
  image_repo=$(shimmy_image_config_scalar_read "$config_file" image_local_repo)
  current_ref=$(shimmy_local_image_ref_render "$config_file" "$@") || return 1

  shimmy_podman_preflight_require "local shim image cleanup" || return 1

  "$SHIMMY_PODMAN_BIN" images \
    --filter "label=io.wadebee.shimmy.image-repo=${image_repo}" \
    --format '{{.Repository}}:{{.Tag}}' | sort -u | while IFS= read -r image_ref; do
      [ -n "$image_ref" ] || continue
      case "$image_ref" in
        "<none>:<none>"|"<none>:"*|*":<none>")
          continue
          ;;
      esac
      [ "$image_ref" != "$current_ref" ] || continue

      if "$SHIMMY_PODMAN_BIN" image rm "$image_ref" >/dev/null 2>&1; then
        shimmy_log_warn "Removed stale shim image: $image_ref"
      else
        shimmy_log_warn "Unable to remove stale shim image (possibly in use): $image_ref"
      fi
    done
}
