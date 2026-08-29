#!/bin/sh
# Published engine registry and profile-bound status.

SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=0
SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE=0

shimmy_engine_registry_host_os_resolve() {
  if [ "${SHIMMY_TEST_PROFILE_OS+x}" = x ]; then
    shimmy_engine_registry_os=$SHIMMY_TEST_PROFILE_OS
  else
    shimmy_engine_registry_os=$(uname -s 2>/dev/null) || shimmy_engine_registry_os=
  fi
  case "$shimmy_engine_registry_os" in
    Darwin|darwin) SHIMMY_ENGINE_REGISTRY_HOST_OS=darwin ;;
    Linux|linux) SHIMMY_ENGINE_REGISTRY_HOST_OS=linux ;;
    *) SHIMMY_ENGINE_REGISTRY_HOST_OS=unsupported ;;
  esac
}

shimmy_engine_registry_profile_names_render() {
  shimmy_engine_registry_profiles=$1
  [ -d "$shimmy_engine_registry_profiles" ] &&
    [ ! -L "$shimmy_engine_registry_profiles" ] || return 1
  for shimmy_engine_registry_profile_root in "$shimmy_engine_registry_profiles"/*; do
    [ -e "$shimmy_engine_registry_profile_root" ] ||
      [ -L "$shimmy_engine_registry_profile_root" ] || continue
    shimmy_engine_registry_profile=$(basename -- "$shimmy_engine_registry_profile_root")
    shimmy_name_component_validate "$shimmy_engine_registry_profile" &&
      [ -d "$shimmy_engine_registry_profile_root" ] &&
      [ ! -L "$shimmy_engine_registry_profile_root" ] || return 1
    printf '%s\n' "$shimmy_engine_registry_profile"
  done | LC_ALL=C sort
}

shimmy_engine_registry_linux_shared_publish() {
  shimmy_engine_registry_linux_config=$1
  shimmy_engine_registry_linux_profile=$2
  shimmy_engine_paths_resolve "$shimmy_engine_registry_linux_config" shared || return 1
  mkdir -p "$SHIMMY_ENGINE_ROOT" || return 1
  [ -d "$SHIMMY_ENGINE_ROOT" ] && [ ! -L "$SHIMMY_ENGINE_ROOT" ] || return 1
  if [ ! -e "$SHIMMY_ENGINE_RECORD_PATH" ] && [ ! -L "$SHIMMY_ENGINE_RECORD_PATH" ]; then
    shimmy_engine_record_write "$SHIMMY_ENGINE_RECORD_PATH" shared linux-rootless \
      installation local local none host-local '' '' || return 1
  else
    shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
    [ "$SHIMMY_ENGINE_RECORD_ID|$SHIMMY_ENGINE_RECORD_KIND|$SHIMMY_ENGINE_RECORD_ORIGIN" = \
      'shared|linux-rootless|host-local' ] || return 1
  fi
  shimmy_engine_binding_write \
    "$shimmy_engine_registry_linux_config/profiles/$shimmy_engine_registry_linux_profile/engine-binding.conf" \
    "$shimmy_engine_registry_linux_profile" shared shared
}

shimmy_engine_registry_shared_create_prepare() {
  shimmy_engine_registry_shared_config=$1
  shimmy_engine_registry_shared_profile=$2
  shimmy_engine_registry_shared_name=$3
  shimmy_name_component_validate "$shimmy_engine_registry_shared_name" || return 1
  SHIMMY_ENGINE_REGISTRY_SHARED_CONFIG=$shimmy_engine_registry_shared_config
  shimmy_engine_paths_resolve "$shimmy_engine_registry_shared_config" shared || return 1
  mkdir -p "$SHIMMY_ENGINE_ROOT" || return 1
  [ -d "$SHIMMY_ENGINE_ROOT" ] && [ ! -L "$SHIMMY_ENGINE_ROOT" ] || return 1
  shimmy_engine_podman_bin_require || return 1
  shimmy_engine_machine_create_prepare shared "$shimmy_engine_registry_shared_name" \
    "$shimmy_engine_registry_shared_name" "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=1
  shimmy_engine_machine_create_initialize "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_machine_create_record "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
    "$SHIMMY_ENGINE_RECORD_PATH" installation || return 1
  shimmy_engine_projection_prepare shared "$SHIMMY_ENGINE_ROOT" \
    "$shimmy_engine_registry_shared_profile" \
    "$shimmy_engine_registry_shared_config/profiles/$shimmy_engine_registry_shared_profile/registries.conf" \
    "$shimmy_engine_registry_shared_name" || return 1
  shimmy_engine_machine_create_start "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_podman_projection_dropin_install "$shimmy_engine_registry_shared_name" \
    "$SHIMMY_ENGINE_REGISTRIES_PATH" || return 1
  shimmy_engine_machine_create_guest_mark "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_projection_apply "$shimmy_engine_registry_shared_name" || return 1
  shimmy_engine_projection_commit || return 1
}

shimmy_engine_registry_shared_create_commit() {
  [ "${SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE:-0}" -eq 1 ] || return 1
  shimmy_engine_paths_resolve "$SHIMMY_ENGINE_REGISTRY_SHARED_CONFIG" shared || return 1
  if [ "${SHIMMY_ENGINE_PROJECTION_APPLIED:-0}" -eq 1 ]; then
    shimmy_engine_projection_commit || return 1
  fi
  shimmy_engine_machine_create_commit "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=0
}

shimmy_engine_registry_shared_create_rollback() {
  shimmy_engine_registry_shared_rollback_config=$1
  shimmy_engine_paths_resolve "$shimmy_engine_registry_shared_rollback_config" shared || return 1
  shimmy_engine_lifecycle_read "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_registry_shared_rollback_name=$SHIMMY_ENGINE_LIFECYCLE_NAME
  shimmy_engine_projection_rollback \
    "$shimmy_engine_registry_shared_rollback_name" >/dev/null 2>&1 || true
  shimmy_engine_podman_projection_dropin_remove \
    "$shimmy_engine_registry_shared_rollback_name" \
    "$SHIMMY_ENGINE_REGISTRIES_PATH" >/dev/null 2>&1 || true
  shimmy_engine_machine_create_rollback "$SHIMMY_ENGINE_RECORD_PATH" \
    "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  rm -f "$SHIMMY_ENGINE_REGISTRIES_PATH" "$SHIMMY_ENGINE_PROJECTION_PATH" || return 1
  rmdir "$SHIMMY_ENGINE_ROOT" 2>/dev/null || true
  rmdir "$SHIMMY_ENGINES_ROOT" 2>/dev/null || true
  SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE=0
}

shimmy_engine_registry_isolated_preflight() {
  shimmy_engine_registry_isolated_preflight_config=$1
  shimmy_engine_registry_isolated_preflight_profile=$2
  shimmy_name_component_validate "$shimmy_engine_registry_isolated_preflight_profile" || return 1
  shimmy_engine_registry_host_os_resolve
  [ "$SHIMMY_ENGINE_REGISTRY_HOST_OS" = darwin ] || {
    printf '%s\n' 'ERROR: isolated profiles require a managed macOS Podman machine' >&2
    return 1
  }
  shimmy_engine_registry_isolated_preflight_id=profile-$shimmy_engine_registry_isolated_preflight_profile
  shimmy_engine_registry_isolated_preflight_name=shimmy-$shimmy_engine_registry_isolated_preflight_profile
  shimmy_engine_paths_resolve "$shimmy_engine_registry_isolated_preflight_config" \
    "$shimmy_engine_registry_isolated_preflight_id" || return 1
  [ ! -e "$SHIMMY_ENGINE_ROOT" ] && [ ! -L "$SHIMMY_ENGINE_ROOT" ] || {
    printf 'ERROR: isolated engine state already exists: %s\n' "$SHIMMY_ENGINE_ROOT" >&2
    return 1
  }
  shimmy_engine_podman_bin_require || return 1
  shimmy_engine_podman_machine_absence_validate \
    "$shimmy_engine_registry_isolated_preflight_name" \
    "$shimmy_engine_registry_isolated_preflight_name" || {
    printf 'ERROR: Podman machine or connection name collision: %s; Shimmy will not adopt it\n' \
      "$shimmy_engine_registry_isolated_preflight_name" >&2
    return 1
  }
}

shimmy_engine_registry_isolated_create_prepare() {
  shimmy_engine_registry_isolated_config=$1
  shimmy_engine_registry_isolated_profile=$2
  shimmy_engine_registry_isolated_preflight \
    "$shimmy_engine_registry_isolated_config" \
    "$shimmy_engine_registry_isolated_profile" || return 1
  SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG=$shimmy_engine_registry_isolated_config
  SHIMMY_ENGINE_REGISTRY_ISOLATED_PROFILE=$shimmy_engine_registry_isolated_profile
  SHIMMY_ENGINE_REGISTRY_ISOLATED_ID=profile-$shimmy_engine_registry_isolated_profile
  SHIMMY_ENGINE_REGISTRY_ISOLATED_NAME=shimmy-$shimmy_engine_registry_isolated_profile
  shimmy_engine_paths_resolve "$SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_ID" || return 1
  mkdir -p "$SHIMMY_ENGINE_ROOT" || return 1
  [ -d "$SHIMMY_ENGINE_ROOT" ] && [ ! -L "$SHIMMY_ENGINE_ROOT" ] || return 1
  if ! shimmy_engine_machine_create_prepare "$SHIMMY_ENGINE_REGISTRY_ISOLATED_ID" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_NAME" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_NAME" \
    "$SHIMMY_ENGINE_LIFECYCLE_PATH"; then
    rmdir "$SHIMMY_ENGINE_ROOT" 2>/dev/null || true
    return 1
  fi
  SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE=1
  shimmy_engine_machine_create_initialize "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  shimmy_engine_machine_create_record "$SHIMMY_ENGINE_LIFECYCLE_PATH" \
    "$SHIMMY_ENGINE_RECORD_PATH" profile || return 1
  shimmy_engine_projection_prepare "$SHIMMY_ENGINE_REGISTRY_ISOLATED_ID" \
    "$SHIMMY_ENGINE_ROOT" "$SHIMMY_ENGINE_REGISTRY_ISOLATED_PROFILE" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG/profiles/$SHIMMY_ENGINE_REGISTRY_ISOLATED_PROFILE/registries.conf" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_NAME"
}

shimmy_engine_registry_isolated_create_commit() {
  [ "${SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE:-0}" -eq 1 ] || return 1
  shimmy_engine_paths_resolve "$SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG" \
    "$SHIMMY_ENGINE_REGISTRY_ISOLATED_ID" || return 1
  if [ "${SHIMMY_ENGINE_PROJECTION_APPLIED:-0}" -eq 1 ]; then
    shimmy_engine_projection_commit || return 1
  fi
  shimmy_engine_machine_create_commit "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE=0
}

shimmy_engine_registry_isolated_create_rollback() {
  shimmy_engine_registry_isolated_rollback_config=$1
  shimmy_engine_registry_isolated_rollback_profile=$2
  shimmy_engine_registry_isolated_rollback_id=profile-$shimmy_engine_registry_isolated_rollback_profile
  shimmy_engine_registry_isolated_rollback_name=shimmy-$shimmy_engine_registry_isolated_rollback_profile
  shimmy_engine_paths_resolve "$shimmy_engine_registry_isolated_rollback_config" \
    "$shimmy_engine_registry_isolated_rollback_id" || return 1
  shimmy_engine_projection_rollback \
    "$shimmy_engine_registry_isolated_rollback_name" >/dev/null 2>&1 || true
  shimmy_engine_podman_projection_dropin_remove \
    "$shimmy_engine_registry_isolated_rollback_name" \
    "$SHIMMY_ENGINE_REGISTRIES_PATH" >/dev/null 2>&1 || true
  shimmy_engine_machine_create_rollback "$SHIMMY_ENGINE_RECORD_PATH" \
    "$SHIMMY_ENGINE_LIFECYCLE_PATH" || return 1
  rm -f "$SHIMMY_ENGINE_REGISTRIES_PATH" "$SHIMMY_ENGINE_PROJECTION_PATH" || return 1
  rmdir "$SHIMMY_ENGINE_ROOT" 2>/dev/null || true
  SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE=0
}

shimmy_engine_registry_status_render() {
  shimmy_engine_registry_status_config=$1
  shimmy_engine_registry_status_format=${2:-human}
  case "$shimmy_engine_registry_status_format" in human|manifest) ;; *) return 1 ;; esac
  shimmy_profile_installation_context_resolve "$shimmy_engine_registry_status_config" || return 1
  shimmy_engine_registry_host_os_resolve
  if [ "$shimmy_engine_registry_status_format" = manifest ]; then
    printf 'shimmy_engine_schema=1\nshimmy_engine_host_os=%s\n' \
      "$SHIMMY_ENGINE_REGISTRY_HOST_OS"
  else
    printf 'Engine schema: 1\nHost OS: %s\n' "$SHIMMY_ENGINE_REGISTRY_HOST_OS"
  fi
  shimmy_engine_registry_status_profiles=$(shimmy_engine_registry_profile_names_render \
    "$shimmy_engine_registry_status_config/profiles") || return 1
  while IFS= read -r shimmy_engine_registry_status_profile; do
    [ -n "$shimmy_engine_registry_status_profile" ] || continue
    if ! shimmy_engine_profile_binding_resolve "$shimmy_engine_registry_status_config" \
      "$shimmy_engine_registry_status_profile"; then
      if [ "$shimmy_engine_registry_status_format" = manifest ]; then
        printf 'shimmy_engine_profile=%s|invalid|-|-|invalid|ambiguous|stale\n' \
          "$shimmy_engine_registry_status_profile"
      else
        printf 'Profile %s: mode=invalid engine=- name=- origin=invalid ownership=ambiguous projection=stale\n' \
          "$shimmy_engine_registry_status_profile"
      fi
      continue
    fi
    shimmy_engine_registry_status_ownership=external
    shimmy_engine_registry_status_projection=not-applicable
    if [ "$SHIMMY_PROFILE_ENGINE_ORIGIN" = shimmy-created ]; then
      shimmy_engine_ownership_state_read "$SHIMMY_PROFILE_ENGINE_RECORD_PATH"
      shimmy_engine_registry_status_ownership=$SHIMMY_ENGINE_OWNERSHIP_STATE
      shimmy_engine_paths_resolve "$shimmy_engine_registry_status_config" \
        "$SHIMMY_PROFILE_ENGINE_ID" || return 1
      if [ -e "$SHIMMY_ENGINE_PROJECTION_PATH" ] || [ -L "$SHIMMY_ENGINE_PROJECTION_PATH" ]; then
        if shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_PATH" &&
          [ "$SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE" = "$shimmy_engine_registry_status_profile" ] &&
          [ "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" = \
            "$SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT" ]; then
          shimmy_engine_registry_status_projection=current
        else
          shimmy_engine_registry_status_projection=stale
        fi
      else
        shimmy_engine_registry_status_projection=stale
      fi
    elif [ "$SHIMMY_PROFILE_ENGINE_ORIGIN" = host-local ]; then
      shimmy_engine_registry_status_ownership=host-local
    fi
    if [ "$shimmy_engine_registry_status_format" = manifest ]; then
      printf 'shimmy_engine_profile=%s|%s|%s|%s|%s|%s|%s\n' \
        "$shimmy_engine_registry_status_profile" "$SHIMMY_PROFILE_ENGINE_BINDING_MODE" \
        "$SHIMMY_PROFILE_ENGINE_ID" \
        "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_PROFILE_ENGINE_ORIGIN" \
        "$shimmy_engine_registry_status_ownership" \
        "$shimmy_engine_registry_status_projection"
    else
      printf 'Profile %s: mode=%s engine=%s name=%s origin=%s ownership=%s projection=%s\n' \
        "$shimmy_engine_registry_status_profile" "$SHIMMY_PROFILE_ENGINE_BINDING_MODE" \
        "$SHIMMY_PROFILE_ENGINE_ID" "$SHIMMY_PROFILE_EXPECTED_MACHINE" \
        "$SHIMMY_PROFILE_ENGINE_ORIGIN" \
        "$shimmy_engine_registry_status_ownership" "$shimmy_engine_registry_status_projection"
    fi
  done <<EOF
$shimmy_engine_registry_status_profiles
EOF
}

shimmy_engine_registry_projection_state_read() {
  shimmy_engine_registry_projection_config=$1
  shimmy_engine_registry_projection_profile=$2
  shimmy_engine_registry_projection_id=$3
  SHIMMY_ENGINE_REGISTRY_PROJECTION_STATE=stale
  shimmy_engine_paths_resolve "$shimmy_engine_registry_projection_config" \
    "$shimmy_engine_registry_projection_id" || return 1
  [ -f "$SHIMMY_ENGINE_REGISTRIES_PATH" ] &&
    [ ! -L "$SHIMMY_ENGINE_REGISTRIES_PATH" ] || return 0
  shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_PATH" || return 0
  [ "$SHIMMY_ENGINE_PROJECTION_ID" = "$shimmy_engine_registry_projection_id" ] || return 0
  [ "$SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE" = \
    "$shimmy_engine_registry_projection_profile" ] || return 0
  shimmy_engine_registry_projection_source=$shimmy_engine_registry_projection_config/profiles/$shimmy_engine_registry_projection_profile/registries.conf
  [ "$SHIMMY_ENGINE_PROJECTION_SOURCE_PATH" = \
    "$shimmy_engine_registry_projection_source" ] || return 0
  shimmy_registries_config_validate "$shimmy_engine_registry_projection_source" \
    "$shimmy_engine_registry_projection_profile" || return 0
  [ "$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_engine_registry_projection_source")" = \
    "$SHIMMY_ENGINE_PROJECTION_SOURCE_FINGERPRINT" ] || return 0
  shimmy_engine_registry_projection_entries=$(shimmy_registries_config_entries_read \
    "$shimmy_engine_registry_projection_source" \
    "$shimmy_engine_registry_projection_profile") || return 0
  [ "$(shimmy_engine_projection_effective_fingerprint_render \
    "$shimmy_engine_registry_projection_entries")" = \
    "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" ] || return 0
  [ "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" = \
    "$SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT" ] || return 0
  SHIMMY_ENGINE_REGISTRY_PROJECTION_STATE=current
}

shimmy_engine_registry_projection_action_plan() {
  shimmy_engine_registry_plan_config=$1
  shimmy_engine_registry_plan_profile=$2
  shimmy_engine_registry_plan_id=$3
  shimmy_engine_paths_resolve "$shimmy_engine_registry_plan_config" \
    "$shimmy_engine_registry_plan_id" || return 1
  shimmy_engine_registry_plan_source=$shimmy_engine_registry_plan_config/profiles/$shimmy_engine_registry_plan_profile/registries.conf
  shimmy_registries_config_validate "$shimmy_engine_registry_plan_source" \
    "$shimmy_engine_registry_plan_profile" || return 1
  shimmy_engine_registry_plan_entries=$(shimmy_registries_config_entries_read \
    "$shimmy_engine_registry_plan_source" "$shimmy_engine_registry_plan_profile") || return 1
  SHIMMY_ENGINE_REGISTRY_PLANNED_FINGERPRINT=$(shimmy_engine_projection_effective_fingerprint_render \
    "$shimmy_engine_registry_plan_entries") || return 1
  SHIMMY_ENGINE_REGISTRY_PLANNED_SERVICE_ACTION=recycle-podman-service
  if [ -f "$SHIMMY_ENGINE_PROJECTION_PATH" ] &&
    [ ! -L "$SHIMMY_ENGINE_PROJECTION_PATH" ] &&
    shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_PATH" &&
    [ "$SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT" = \
      "$SHIMMY_ENGINE_REGISTRY_PLANNED_FINGERPRINT" ]; then
    SHIMMY_ENGINE_REGISTRY_PLANNED_SERVICE_ACTION=none
  fi
}
