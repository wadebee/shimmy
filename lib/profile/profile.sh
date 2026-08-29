#!/bin/sh
# Canonical arbitrary-name profile paths and schema-2 runtime identity.

shimmy_config_home_resolve() {
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    case "$XDG_CONFIG_HOME" in
      /*) shimmy_trim_path_trailing_slash "$XDG_CONFIG_HOME" ;;
      *) return 1 ;;
    esac
    return 0
  fi

  case "${HOME:-}" in
    /*) printf '%s/.config\n' "$(shimmy_trim_path_trailing_slash "$HOME")" ;;
    *) return 1 ;;
  esac
}

shimmy_config_root_resolve() {
  config_home=$(shimmy_config_home_resolve) || return 1
  shimmy_join_path "$config_home" shimmy
}

shimmy_profile_paths_resolve_name() {
  profile_name=$1
  shimmy_name_component_validate "$profile_name" || return 1

  SHIMMY_CONFIG_HOME=$(shimmy_config_home_resolve) || return 1
  SHIMMY_CONFIG_ROOT=$(shimmy_config_root_resolve) || return 1
  SHIMMY_PROFILES_ROOT=$SHIMMY_CONFIG_ROOT/profiles
  SHIMMY_PROFILE_NAME=$profile_name
  SHIMMY_PROFILE_ROOT=$SHIMMY_PROFILES_ROOT/$profile_name
  SHIMMY_PROFILE_MANIFEST_PATH=$SHIMMY_PROFILE_ROOT/install-manifest.txt
  SHIMMY_PROFILE_ENGINE_BINDING_PATH=$SHIMMY_PROFILE_ROOT/engine-binding.conf
  SHIMMY_PROFILE_REGISTRIES_PATH=$SHIMMY_PROFILE_ROOT/registries.conf
  SHIMMY_PROFILE_REGISTRIES_LOCK_PATH=$SHIMMY_PROFILE_ROOT/.registries.lock
  SHIMMY_REGISTRIES_CONFIG_DIR=$SHIMMY_CONFIG_HOME/containers
  SHIMMY_REGISTRIES_DROPIN_DIR=$SHIMMY_REGISTRIES_CONFIG_DIR/registries.conf.d
  SHIMMY_REGISTRIES_ACTIVE_LINK=$SHIMMY_REGISTRIES_DROPIN_DIR/shimmy-active-profile.conf
  SHIMMY_REGISTRIES_CLIENT_MOUNT_PATH=/etc/containers/registries.conf.d/shimmy-profile.conf
  SHIMMY_PROFILE_BIN_DIR=$SHIMMY_PROFILE_ROOT/bin
  SHIMMY_PROFILE_CONFIG_DIR=$SHIMMY_PROFILE_ROOT/config
  SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR=$SHIMMY_PROFILE_ROOT/tools
  shimmy_path_parent_chain_validate "$SHIMMY_PROFILE_ROOT"
}

shimmy_profile_paths_resolve() {
  profile_name=$1
  shimmy_profile_paths_resolve_name "$profile_name"
}

shimmy_profile_runtime_manifest_identity_validate() {
  manifest_file=$1
  profile_name=$2
  shimmy_name_component_validate "$profile_name" || return 1
  [ -f "$manifest_file" ] && [ ! -L "$manifest_file" ] || return 1
  [ "$(sed -n '1s/^shimmy_install_manifest_version=//p' "$manifest_file")" = 2 ] || return 1
  [ "$(sed -n '2s/^shimmy_install_layout=//p' "$manifest_file")" = profile-materialized-root ] || return 1
  [ "$(sed -n '3s/^shimmy_profile_manifest_version=//p' "$manifest_file")" = 2 ] || return 1
  [ "$(sed -n '4s/^shimmy_profile_name=//p' "$manifest_file")" = "$profile_name" ]
}
