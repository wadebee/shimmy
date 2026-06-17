shimmy_profile_install_hint() {
  profile_name=$1

  case "$profile_name" in
    upstream)
      printf '%s\n' 'shimmy install --profile upstream'
      ;;
    *)
      printf '%s\n' 'shimmy install'
      ;;
  esac
}

shimmy_profile_repair_hint_print() {
  profile_name=$1

  case "$profile_name" in
    upstream)
      printf 'shimmy_repair_hint=shimmy install --profile upstream\n'
      printf 'shimmy_repair_hint=shimmy update --profile upstream\n'
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

  shimmy_read_manifest_values "$root_manifest_file" profile || true
}

shimmy_root_manifest_path_resolve() {
  install_dir=$1

  shimmy_join_path "$install_dir" install-manifest.txt
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
    lib/repo/shimmy-common.sh \
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

shimmy_profile_name_resolve() {
  profile_requested=${1:-}
  profile_active=${2:-}

  if [ -n "$profile_requested" ]; then
    shimmy_profile_name_validate "$profile_requested" || return 1
    printf '%s\n' "$profile_requested"
    return 0
  fi

  if [ -n "$profile_active" ]; then
    shimmy_profile_name_validate "$profile_active" || return 1
    printf '%s\n' "$profile_active"
    return 0
  fi

  printf '%s\n' default
}

shimmy_profile_name_validate() {
  profile_name=${1:-}

  case "$profile_name" in
    default|upstream)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

shimmy_profile_install_dir_resolve() {
  requested_install_dir=${1:-}

  if [ -n "$requested_install_dir" ]; then
    shimmy_trim_path_trailing_slash "$requested_install_dir"
    return 0
  fi

  shimmy_trim_path_trailing_slash "${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}"
}

shimmy_profile_paths_resolve() {
  profile_name=$1
  requested_install_dir=${2:-}
  source_root_dir=${3:-}

  SHIMMY_PROFILE_NAME=$(shimmy_profile_name_resolve "$profile_name" "${SHIMMY_PROFILE_ACTIVE:-}") || return 1
  SHIMMY_PROFILE_INSTALL_DIR=$(shimmy_profile_install_dir_resolve "$requested_install_dir")
  SHIMMY_INSTALL_BIN_DIR=$(shimmy_join_path "$SHIMMY_PROFILE_INSTALL_DIR" bin)
  SHIMMY_INSTALL_CORE_DIR=$(shimmy_join_path "$SHIMMY_PROFILE_INSTALL_DIR" core)

  case "$SHIMMY_PROFILE_NAME" in
    default)
      SHIMMY_PROFILE_DIR=$(shimmy_join_path "$SHIMMY_PROFILE_INSTALL_DIR" p/default)
      SHIMMY_PROFILE_SOURCE_CHECKOUT=
      ;;
    upstream)
      SHIMMY_PROFILE_DIR=$(shimmy_trim_path_trailing_slash "${SHIMMY_UPSTREAM_DIR:-$(shimmy_join_path "$SHIMMY_PROFILE_INSTALL_DIR" p/upstream)}")
      upstream_checkout_dir=${SHIMMY_UPSTREAM_CHECKOUT_DIR:-$source_root_dir}
      SHIMMY_PROFILE_SOURCE_CHECKOUT=$(shimmy_resolve_path_absolute "$upstream_checkout_dir") || return 1
      ;;
  esac

  SHIMMY_PROFILE_CONFIG_DIR=$(shimmy_join_path "$SHIMMY_PROFILE_DIR" config)
  SHIMMY_PROFILE_MANIFEST_PATH=$(shimmy_join_path "$SHIMMY_PROFILE_DIR" install-manifest.txt)
  SHIMMY_PROFILE_IMPLEMENTATION_DIR=$(shimmy_join_path "$SHIMMY_PROFILE_DIR" bin)

  if [ "$SHIMMY_INSTALL_BIN_DIR" = "$SHIMMY_PROFILE_IMPLEMENTATION_DIR" ]; then
    return 1
  fi
}
