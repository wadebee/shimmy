shimmy_manifest_value() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file" | sed -n '1p'
}

shimmy_manifest_values() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file"
}

shimmy_profile_install_hint() {
  mode_value=$1

  case "$mode_value" in
    upstream)
      printf '%s\n' 'shimmy install --mode upstream'
      ;;
    *)
      printf '%s\n' 'shimmy install'
      ;;
  esac
}

shimmy_profile_repair_hint_print() {
  mode_value=$1

  case "$mode_value" in
    upstream)
      printf 'shimmy_repair_hint=shimmy install --mode upstream\n'
      printf 'shimmy_repair_hint=shimmy update --mode upstream\n'
      ;;
    *)
      printf 'shimmy_repair_hint=shimmy install\n'
      printf 'shimmy_repair_hint=shimmy update\n'
      ;;
  esac
}

shimmy_profile_structure_missing_print() {
  manifest_file=$1
  implementation_dir=$2

  if [ ! -f "$manifest_file" ]; then
    printf 'shimmy_missing=profile_manifest\n'
  fi

  if [ ! -d "$implementation_dir" ]; then
    printf 'shimmy_missing=profile_implementation_dir\n'
  fi
}

shimmy_profile_structure_validate() {
  manifest_file=$1
  implementation_dir=$2

  [ -f "$manifest_file" ] || return 1
  [ -d "$implementation_dir" ] || return 1
}

shimmy_root_installed_profile_list() {
  root_manifest_file=$1

  if [ ! -f "$root_manifest_file" ]; then
    return 0
  fi

  shimmy_manifest_values "$root_manifest_file" profile || true
}

shimmy_root_manifest_path_resolve() {
  install_dir=$1

  shimmy_path_append "$install_dir" install-manifest.txt
}

shimmy_upstream_checkout_invalid_reason() {
  checkout_dir=${1:-}
  shim_name=${2:-}

  if [ -z "$checkout_dir" ]; then
    printf '%s\n' missing_source_checkout
    return 0
  fi

  if [ ! -d "$checkout_dir" ]; then
    printf '%s\n' stale_source_checkout
    return 0
  fi

  if [ ! -x "$checkout_dir/shimmy" ]; then
    printf '%s\n' invalid_source_checkout_missing_shimmy
    return 0
  fi

  for required_dir in scripts shims lib/repo lib/shims; do
    if [ ! -d "$checkout_dir/$required_dir" ]; then
      printf 'invalid_source_checkout_missing_%s\n' "$(printf '%s' "$required_dir" | tr / _)"
      return 0
    fi
  done

  for required_file in \
    scripts/install-shimmy.sh \
    scripts/update-shimmy.sh \
    scripts/dispatch-shimmy.sh \
    scripts/status-shimmy.sh \
    lib/repo/shimmy-profile.sh \
    lib/repo/shimmy-catalog.sh
  do
    if [ ! -f "$checkout_dir/$required_file" ]; then
      printf 'invalid_source_checkout_missing_%s\n' "$(printf '%s' "$required_file" | tr / _ | tr . _)"
      return 0
    fi
  done

  if [ -n "$shim_name" ] && [ ! -f "$checkout_dir/shims/$shim_name" ]; then
    printf '%s\n' missing_upstream_shim_source
    return 0
  fi

  return 1
}

shimmy_upstream_checkout_validate() {
  checkout_dir=${1:-}
  shim_name=${2:-}

  ! shimmy_upstream_checkout_invalid_reason "$checkout_dir" "$shim_name" >/dev/null
}

shimmy_mode_resolve() {
  requested_mode=${1:-}
  environment_mode=${2:-}

  if [ -n "$requested_mode" ]; then
    shimmy_mode_validate "$requested_mode" || return 1
    printf '%s\n' "$requested_mode"
    return 0
  fi

  if [ -n "$environment_mode" ]; then
    shimmy_mode_validate "$environment_mode" || return 1
    printf '%s\n' "$environment_mode"
    return 0
  fi

  printf '%s\n' default
}

shimmy_mode_validate() {
  mode_value=${1:-}

  case "$mode_value" in
    default|upstream)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

shimmy_path_absolute_resolve() {
  path_value=${1:-}

  if [ -z "$path_value" ]; then
    return 1
  fi

  path_value=$(shimmy_path_trim_trailing_slash "$path_value")

  if [ -d "$path_value" ]; then
    (
      cd -- "$path_value" && pwd -P
    )
    return 0
  fi

  path_dir=$(dirname "$path_value")
  path_base=$(basename "$path_value")

  if [ -d "$path_dir" ]; then
    (
      cd -- "$path_dir" && printf '%s/%s\n' "$(pwd -P)" "$path_base"
    )
    return 0
  fi

  case "$path_value" in
    /*)
      printf '%s\n' "$path_value"
      ;;
    *)
      printf '%s/%s\n' "$(pwd -P)" "$path_value"
      ;;
  esac
}

shimmy_path_append() {
  base_path=$1
  path_suffix=$2

  printf '%s/%s\n' "$(shimmy_path_trim_trailing_slash "$base_path")" "$path_suffix"
}

shimmy_path_trim_trailing_slash() {
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

shimmy_profile_install_dir_resolve() {
  requested_install_dir=${1:-}

  if [ -n "$requested_install_dir" ]; then
    shimmy_path_trim_trailing_slash "$requested_install_dir"
    return 0
  fi

  shimmy_path_trim_trailing_slash "${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}"
}

shimmy_profile_paths_resolve() {
  mode_value=$1
  requested_install_dir=${2:-}
  source_root_dir=${3:-}

  SHIMMY_PROFILE_MODE=$(shimmy_mode_resolve "$mode_value" "${SHIMMY_MODE:-}") || return 1
  SHIMMY_PROFILE_INSTALL_DIR=$(shimmy_profile_install_dir_resolve "$requested_install_dir")
  SHIMMY_PROFILE_DISPATCHER_DIR=$(shimmy_path_append "$SHIMMY_PROFILE_INSTALL_DIR" shims)
  SHIMMY_PROFILE_CONTROL_BIN_DIR=$(shimmy_path_append "$SHIMMY_PROFILE_INSTALL_DIR" bin)
  SHIMMY_PROFILE_CONTROL_LIBEXEC_DIR=$(shimmy_path_append "$SHIMMY_PROFILE_INSTALL_DIR" libexec/shimmy)

  case "$SHIMMY_PROFILE_MODE" in
    default)
      SHIMMY_PROFILE_DIR=$(shimmy_path_append "$SHIMMY_PROFILE_INSTALL_DIR" profiles/default)
      SHIMMY_PROFILE_SOURCE_CHECKOUT=
      ;;
    upstream)
      SHIMMY_PROFILE_DIR=$(shimmy_path_trim_trailing_slash "${SHIMMY_UPSTREAM_DIR:-$(shimmy_path_append "$SHIMMY_PROFILE_INSTALL_DIR" profiles/upstream)}")
      upstream_checkout_dir=${SHIMMY_UPSTREAM_CHECKOUT_DIR:-$source_root_dir}
      SHIMMY_PROFILE_SOURCE_CHECKOUT=$(shimmy_path_absolute_resolve "$upstream_checkout_dir") || return 1
      ;;
  esac

  SHIMMY_PROFILE_BIN_DIR=$(shimmy_path_append "$SHIMMY_PROFILE_DIR" shims)
  SHIMMY_PROFILE_CONFIG_DIR=$(shimmy_path_append "$SHIMMY_PROFILE_DIR" config)
  SHIMMY_PROFILE_MANIFEST_PATH=$(shimmy_path_append "$SHIMMY_PROFILE_DIR" install-manifest.txt)
  SHIMMY_PROFILE_IMPLEMENTATION_DIR=$SHIMMY_PROFILE_BIN_DIR

  if [ "$SHIMMY_PROFILE_DISPATCHER_DIR" = "$SHIMMY_PROFILE_IMPLEMENTATION_DIR" ]; then
    return 1
  fi
}
