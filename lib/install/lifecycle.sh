#!/bin/sh
# Private bootstrap, profile creation, startup, and deletion lifecycle.

SHIMMY_PROFILE_LIFECYCLE_ERROR=
SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT=
SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT=
SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP=
SHIMMY_PROFILE_LIFECYCLE_IMAGE_ROOT=
SHIMMY_PROFILE_LIFECYCLE_IMAGE_PAIRS=
SHIMMY_PROFILE_LIFECYCLE_PRESERVE_NEW_ROOT=0
SHIMMY_PROFILE_LIFECYCLE_PRESERVE_BOOTSTRAP_ROOT=0
SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_PRESERVE_REPORTED=0

shimmy_profile_lifecycle_error_set() {
  SHIMMY_PROFILE_LIFECYCLE_ERROR=$*
  return 1
}

shimmy_profile_baseline_records_resolve() {
  shimmy_profile_baseline_records_catalog=$1
  SHIMMY_PROFILE_BASELINE_SHIMS=
  SHIMMY_PROFILE_BASELINE_VERSIONS=
  SHIMMY_PROFILE_BASELINE_PAIRS=
  shimmy_profile_baseline_records=$(shimmy_profile_baseline_render \
    "$shimmy_profile_baseline_records_catalog") || return 1
  while IFS='|' read -r shimmy_profile_baseline_records_tool shimmy_profile_baseline_records_version shimmy_profile_baseline_records_extra; do
    [ -n "$shimmy_profile_baseline_records_tool" ] || continue
    [ -z "$shimmy_profile_baseline_records_extra" ] || return 1
    SHIMMY_PROFILE_BASELINE_SHIMS=$(shimmy_append_line_list \
      "$SHIMMY_PROFILE_BASELINE_SHIMS" "$shimmy_profile_baseline_records_tool|tracking")
    SHIMMY_PROFILE_BASELINE_VERSIONS=$(shimmy_append_line_list \
      "$SHIMMY_PROFILE_BASELINE_VERSIONS" "$shimmy_profile_baseline_records_tool|$shimmy_profile_baseline_records_version|default")
    SHIMMY_PROFILE_BASELINE_PAIRS=$(shimmy_append_line_list \
      "$SHIMMY_PROFILE_BASELINE_PAIRS" "$shimmy_profile_baseline_records_tool|$shimmy_profile_baseline_records_version")
  done <<EOF
$shimmy_profile_baseline_records
EOF
  SHIMMY_PROFILE_BASELINE_SHIMS=$(shimmy_shim_sorted "$SHIMMY_PROFILE_BASELINE_SHIMS")
  SHIMMY_PROFILE_BASELINE_VERSIONS=$(shimmy_shim_sorted "$SHIMMY_PROFILE_BASELINE_VERSIONS")
  SHIMMY_PROFILE_BASELINE_PAIRS=$(shimmy_shim_sorted "$SHIMMY_PROFILE_BASELINE_PAIRS")
  shimmy_shim_records_validate "$SHIMMY_PROFILE_BASELINE_SHIMS" \
    "$SHIMMY_PROFILE_BASELINE_VERSIONS"
}

shimmy_profile_bootstrap_cleanup() {
  if [ "${SHIMMY_EXTERNAL_TRANSACTION_ACTIVE:-0}" -eq 1 ]; then
    shimmy_external_transaction_rollback 'lifecycle command interruption' 2>/dev/null || true
  fi
  if [ "${SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE:-0}" -eq 1 ]; then
    shimmy_profile_activation_rollback 'lifecycle command interruption' 2>/dev/null || true
    SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE=0
  fi
  shimmy_profile_candidate_stage_cleanup 2>/dev/null || true
  if [ "${SHIMMY_ENGINE_REGISTRY_SHARED_CREATE_ACTIVE:-0}" -eq 1 ] &&
    [ "${SHIMMY_PROFILE_LIFECYCLE_PRESERVE_BOOTSTRAP_ROOT:-0}" -eq 0 ]; then
    if [ -n "${SHIMMY_ENGINE_REGISTRY_SHARED_CONFIG:-}" ] &&
      shimmy_engine_registry_shared_create_rollback \
        "$SHIMMY_ENGINE_REGISTRY_SHARED_CONFIG" 2>/dev/null; then
      :
    else
      SHIMMY_PROFILE_LIFECYCLE_PRESERVE_BOOTSTRAP_ROOT=1
    fi
  fi
  if [ "${SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE:-0}" -eq 1 ] &&
    [ -n "${SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG:-}" ] &&
    [ -n "${SHIMMY_ENGINE_REGISTRY_ISOLATED_PROFILE:-}" ]; then
    if ! shimmy_engine_registry_isolated_create_rollback \
      "$SHIMMY_ENGINE_REGISTRY_ISOLATED_CONFIG" \
      "$SHIMMY_ENGINE_REGISTRY_ISOLATED_PROFILE" 2>/dev/null; then
      SHIMMY_PROFILE_LIFECYCLE_PRESERVE_NEW_ROOT=1
    fi
  fi
  if [ -n "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" ]; then
    case "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" in
      "$SHIMMY_CONFIG_ROOT"/.startup-backup.*)
        [ ! -e "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" ] ||
          rm -rf "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP"
        ;;
    esac
    SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP=
  fi
  if [ "${SHIMMY_PROFILE_LIFECYCLE_PRESERVE_NEW_ROOT:-0}" -eq 0 ]; then
    shimmy_profile_new_root_remove 2>/dev/null || true
  fi
  shimmy_locks_release_all 2>/dev/null || true
  if [ -n "$SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT" ]; then
    if [ "${SHIMMY_PROFILE_LIFECYCLE_PRESERVE_BOOTSTRAP_ROOT:-0}" -eq 0 ]; then
      case "$SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT" in
        /|"${HOME:-}"|"${HOME:-}"/|"${XDG_CONFIG_HOME:-}"|"${XDG_CONFIG_HOME:-}"/) ;;
        *)
          [ ! -e "$SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT" ] &&
            [ ! -L "$SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT" ] ||
            rm -rf "$SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT"
          ;;
      esac
    elif [ "${SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_PRESERVE_REPORTED:-0}" -eq 0 ]; then
      printf 'Rollback result: incomplete; retained bootstrap recovery root at %s and lifecycle journal at %s.\n' \
        "$SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT" \
        "$SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT/engines/shared/lifecycle.conf" >&2
      SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_PRESERVE_REPORTED=1
    fi
    SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT=
  fi
  return 0
}

shimmy_profile_bootstrap_run() {
  shimmy_profile_bootstrap_checkout=$1
  shimmy_profile_bootstrap_config=$2
  shimmy_profile_bootstrap_shell=$3
  shimmy_profile_bootstrap_startup=$4
  SHIMMY_PROFILE_LIFECYCLE_ERROR=
  SHIMMY_PROFILE_LIFECYCLE_PRESERVE_BOOTSTRAP_ROOT=0
  SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_PRESERVE_REPORTED=0
  shimmy_path_absolute_normalized_validate "$shimmy_profile_bootstrap_checkout" ||
    shimmy_profile_lifecycle_error_set 'bootstrap requires a normalized absolute checkout root' || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_profile_bootstrap_config" ||
    shimmy_profile_lifecycle_error_set 'bootstrap requires a normalized absolute configuration root' || return 1
  [ ! -e "$shimmy_profile_bootstrap_config" ] && [ ! -L "$shimmy_profile_bootstrap_config" ] ||
    shimmy_profile_lifecycle_error_set "bootstrap configuration root already exists: $shimmy_profile_bootstrap_config" || return 1
  shimmy_profile_bootstrap_home=${HOME:-}
  shimmy_path_absolute_normalized_validate "$shimmy_profile_bootstrap_home" ||
    shimmy_profile_lifecycle_error_set 'bootstrap requires a normalized absolute HOME' || return 1
  shimmy_profile_bootstrap_user_root=$shimmy_profile_bootstrap_home/.agents/skills
  shimmy_shell_name_normalize "$shimmy_profile_bootstrap_shell" >/dev/null || return 1
  shimmy_profile_bootstrap_shell=$(shimmy_shell_name_normalize "$shimmy_profile_bootstrap_shell") || return 1
  case "$shimmy_profile_bootstrap_startup" in 0|1) ;; *) return 1 ;; esac
  shimmy_engine_registry_host_os_resolve
  case "$SHIMMY_ENGINE_REGISTRY_HOST_OS" in
    darwin)
      shimmy_engine_podman_bin_require ||
        shimmy_profile_lifecycle_error_set 'Podman is required for macOS bootstrap' || return 1
      shimmy_profile_bootstrap_engine_name=shimmy-default
      shimmy_engine_podman_machine_absence_validate \
        "$shimmy_profile_bootstrap_engine_name" "$shimmy_profile_bootstrap_engine_name" ||
        shimmy_profile_lifecycle_error_set \
          "Podman machine or connection name collision: $shimmy_profile_bootstrap_engine_name; Shimmy will not adopt it" || return 1
      ;;
    linux) shimmy_profile_linux_engine_validate || return 1 ;;
    *)
      shimmy_profile_lifecycle_error_set \
        "unsupported host operating system for bootstrap: $SHIMMY_ENGINE_REGISTRY_HOST_OS"
      return 1
      ;;
  esac
  shimmy_catalog_checkout_validate "$shimmy_profile_bootstrap_checkout" ||
    shimmy_profile_lifecycle_error_set "$SHIMMY_CATALOG_AUTHORITY_ERROR" || return 1
  shimmy_profile_bootstrap_source_ref=$SHIMMY_CATALOG_PUBLICATION_HEAD
  shimmy_profile_bootstrap_source_url=$(git -C "$shimmy_profile_bootstrap_checkout" \
    config --get remote.origin.url 2>/dev/null || true)
  [ -n "$shimmy_profile_bootstrap_source_url" ] ||
    shimmy_profile_bootstrap_source_url=$shimmy_profile_bootstrap_checkout
  shimmy_scalar_value_validate "$shimmy_profile_bootstrap_source_url" || return 1
  if [ "$shimmy_profile_bootstrap_startup" -eq 1 ]; then
    shimmy_profile_bootstrap_startup_files=$(shimmy_startup_file_path_list_resolve \
      "$shimmy_profile_bootstrap_shell" "$shimmy_profile_bootstrap_home") || return 1
    shimmy_profile_bootstrap_startup_files=$(printf '%s\n' "$shimmy_profile_bootstrap_startup_files" | LC_ALL=C sort -u)
  else
    shimmy_profile_bootstrap_startup_files=
  fi

  mkdir -p "$shimmy_profile_bootstrap_config" "$shimmy_profile_bootstrap_user_root" || return 1
  SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT=$shimmy_profile_bootstrap_config
  shimmy_catalog_default_create "$shimmy_profile_bootstrap_config" \
    "$shimmy_profile_bootstrap_checkout" || return 1
  shimmy_catalog_tree_validate "$shimmy_profile_bootstrap_config" || return 1
  shimmy_profile_bootstrap_generation=$SHIMMY_CATALOG_GENERATION_CURRENT
  shimmy_profile_bootstrap_commit=$SHIMMY_CATALOG_SOURCE_COMMIT
  shimmy_profile_bootstrap_fingerprint=$SHIMMY_CATALOG_CONTENT_FINGERPRINT
  shimmy_profile_bootstrap_catalog_root=$SHIMMY_CATALOG_GENERATIONS_ROOT/$shimmy_profile_bootstrap_generation
  shimmy_profile_bootstrap_catalog_record=default\|$shimmy_profile_bootstrap_generation\|$shimmy_profile_bootstrap_commit\|$shimmy_profile_bootstrap_fingerprint
  [ "$shimmy_profile_bootstrap_commit" = "$shimmy_profile_bootstrap_source_ref" ] || return 1
  shimmy_profile_baseline_records_resolve "$shimmy_profile_bootstrap_catalog_root" || return 1
  shimmy_profile_materialization_prepare "$shimmy_profile_bootstrap_config" default git \
    "$shimmy_profile_bootstrap_checkout" "$shimmy_profile_bootstrap_source_url" \
    "$shimmy_profile_bootstrap_source_ref" "$shimmy_profile_bootstrap_catalog_record" \
    "$SHIMMY_PROFILE_BASELINE_SHIMS" "$SHIMMY_PROFILE_BASELINE_VERSIONS" \
    "$shimmy_profile_bootstrap_shell" "$shimmy_profile_bootstrap_startup_files" \
    '' '' '' shared || return 1
  shimmy_lock_acquire catalog "$shimmy_profile_bootstrap_config" || return 1
  shimmy_lock_acquire activation "$shimmy_profile_bootstrap_config" || return 1
  shimmy_catalog_tree_validate "$shimmy_profile_bootstrap_config" || return 1
  [ "$SHIMMY_CATALOG_GENERATION_CURRENT" = "$shimmy_profile_bootstrap_generation" ] || return 1
  shimmy_profile_new_root_prepare "$shimmy_profile_bootstrap_config" default || return 1
  shimmy_lock_acquire profile "$shimmy_profile_bootstrap_config" default || return 1
  shimmy_lock_acquire registry "$shimmy_profile_bootstrap_config" default || return 1
  shimmy_catalog_checkout_revalidate ||
    shimmy_profile_lifecycle_error_set 'bootstrap checkout changed during staging' || return 1
  shimmy_profile_new_candidate_commit default "$shimmy_profile_bootstrap_catalog_root" ||
    shimmy_profile_lifecycle_error_set 'unable to commit the default profile candidate' || return 1
  case "$SHIMMY_ENGINE_REGISTRY_HOST_OS" in
    darwin)
      mkdir "$shimmy_profile_bootstrap_config/engines" || return 1
      shimmy_engine_registry_shared_create_prepare "$shimmy_profile_bootstrap_config" \
        default || shimmy_profile_lifecycle_error_set \
          'unable to create the shared Podman engine' || return 1
      ;;
    linux)
      mkdir "$shimmy_profile_bootstrap_config/engines" || return 1
      shimmy_engine_paths_resolve "$shimmy_profile_bootstrap_config" shared || return 1
      mkdir "$SHIMMY_ENGINE_ROOT" || return 1
      shimmy_engine_record_write "$SHIMMY_ENGINE_RECORD_PATH" shared linux-rootless \
        installation local local none host-local '' '' || return 1
      ;;
  esac
  shimmy_profile_candidate_resolve "$shimmy_profile_bootstrap_config" default ||
    shimmy_profile_lifecycle_error_set \
      "unable to validate the default profile with its engine binding: ${SHIMMY_PROFILE_ERROR:-unknown}" || return 1

  SHIMMY_PROFILE_USER_SKILL_ROOT=$shimmy_profile_bootstrap_user_root
  shimmy_profile_ai_skill_prepare "$shimmy_profile_bootstrap_config" default \
    "$SHIMMY_PROFILE_CANDIDATE_ROOT" "$SHIMMY_PROFILE_CANDIDATE_GENERATION_ROOT" || return 1
  shimmy_profile_engine_context_resolve "$shimmy_profile_bootstrap_config" default || return 1
  SHIMMY_ACTIVATION_LOCK_EXTERNAL=1
  SHIMMY_REGISTRY_LOCK_EXTERNAL=1
  SHIMMY_PROFILE_ACTIVATION_DEFER_COMMIT=1
  SHIMMY_PROFILE_ACTIVATION_QUIET_SUCCESS=1
  shimmy_profile_activation_host_os_resolve
  case "$SHIMMY_PROFILE_HOST_OS" in
    darwin) shimmy_profile_bootstrap_restart=0 ;;
    linux) shimmy_profile_bootstrap_restart=0 ;;
    *)
      shimmy_profile_lifecycle_error_set \
        "unsupported host operating system for bootstrap activation: $SHIMMY_PROFILE_HOST_OS"
      return 1
      ;;
  esac
  shimmy_profile_activate "$shimmy_profile_bootstrap_restart" 0 0 || return 1
  SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE=1
  shimmy_external_transaction_begin || return 1
  shimmy_profile_initial_active_create "$shimmy_profile_bootstrap_config/active-profile.conf" \
    default "$shimmy_profile_bootstrap_user_root" ||
    shimmy_profile_lifecycle_activation_rollback 'unable to create initial active profile authority' || return 1
  shimmy_profile_images_prepare "$SHIMMY_PROFILE_CANDIDATE_ROOT" \
    "$SHIMMY_PROFILE_BASELINE_PAIRS" ||
    shimmy_profile_lifecycle_activation_rollback 'unable to prepare initial profile images' || return 1
  shimmy_ai_skill_reconcile_apply ||
    shimmy_profile_lifecycle_activation_rollback "${SHIMMY_AI_SKILL_ERROR:-unable to reconcile initial AI-skill links}" || return 1
  shimmy_startup_apply "$shimmy_profile_bootstrap_config" \
    "$shimmy_profile_bootstrap_startup_files" \
    "$shimmy_profile_bootstrap_config/profiles/default/shell-init.sh" ||
    shimmy_profile_lifecycle_activation_rollback 'unable to apply initial startup integration' || return 1
  shimmy_profile_activation_commit ||
    shimmy_profile_lifecycle_activation_rollback 'unable to finalize initial engine activation' || return 1
  if [ "$SHIMMY_PROFILE_HOST_OS" = darwin ]; then
    shimmy_engine_registry_shared_create_commit ||
      shimmy_profile_lifecycle_activation_rollback 'unable to finalize shared engine creation' || return 1
  fi
  shimmy_external_transaction_commit || return 1
  SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE=0
  shimmy_profile_startup_backup_cleanup || return 1
  SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT=
  shimmy_locks_release_all || return 1
  SHIMMY_PROFILE_LIFECYCLE_BOOTSTRAP_ROOT=
  printf 'Bootstrapped active Shimmy profile default at %s.\n' \
    "$shimmy_profile_bootstrap_config/profiles/default"
}

shimmy_profile_create_dry_run() {
  shimmy_profile_create_dry_config=$1
  shimmy_profile_create_dry_name=$2
  shimmy_profile_create_dry_invoking_root=$3
  shimmy_profile_create_dry_catalog=$4
  shimmy_profile_create_dry_pairs=$5
  shimmy_profile_create_dry_restart=$6
  shimmy_profile_create_dry_stop=$7
  shimmy_profile_create_dry_mode=$8
  shimmy_profile_activation_host_os_resolve
  case "$shimmy_profile_create_dry_mode" in
    shared)
      shimmy_engine_paths_resolve "$shimmy_profile_create_dry_config" shared || return 1
      shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
      SHIMMY_PROFILE_EXPECTED_MACHINE=$SHIMMY_ENGINE_RECORD_NAME
      SHIMMY_PROFILE_EXPECTED_CONNECTION=$SHIMMY_ENGINE_RECORD_CONNECTION
      SHIMMY_PROFILE_ENGINE_ID=shared
      ;;
    isolated)
      shimmy_engine_registry_isolated_preflight "$shimmy_profile_create_dry_config" \
        "$shimmy_profile_create_dry_name" || return 1
      SHIMMY_PROFILE_EXPECTED_MACHINE=shimmy-$shimmy_profile_create_dry_name
      SHIMMY_PROFILE_EXPECTED_CONNECTION=$SHIMMY_PROFILE_EXPECTED_MACHINE
      SHIMMY_PROFILE_ENGINE_ID=profile-$shimmy_profile_create_dry_name
      ;;
    *) return 1 ;;
  esac
  SHIMMY_PROFILE_ENGINE_BINDING_MODE=$shimmy_profile_create_dry_mode
  case "$SHIMMY_PROFILE_HOST_OS" in
    linux)
      [ "$shimmy_profile_create_dry_restart" -eq 0 ] || {
        shimmy_profile_lifecycle_error_set '--restart is not supported for local Linux profile creation'
        return 1
      }
      [ "$shimmy_profile_create_dry_stop" -eq 0 ] || {
        shimmy_profile_lifecycle_error_set '--stop-running is not supported for local Linux profile creation'
        return 1
      }
      ;;
    darwin) ;;
    *)
      shimmy_profile_lifecycle_error_set "unsupported host operating system for profile creation: $SHIMMY_PROFILE_HOST_OS"
      return 1
      ;;
  esac
  printf 'dry_run=yes\nwould_create_profile=%s\n' \
    "$shimmy_profile_create_dry_config/profiles/$shimmy_profile_create_dry_name"
  printf 'would_copy_control_from=%s\nwould_pin_catalog=%s\n' \
    "$shimmy_profile_create_dry_invoking_root" "$shimmy_profile_create_dry_catalog"
  shimmy_profile_image_plan_render "$shimmy_profile_create_dry_catalog" \
    "$shimmy_profile_create_dry_pairs" || return 1
  printf 'would_activate_profile=%s\nwould_restart=%s\nwould_stop_running=%s\n' \
    "$shimmy_profile_create_dry_name" "$shimmy_profile_create_dry_restart" \
      "$shimmy_profile_create_dry_stop"
  printf 'would_use_engine=%s\nwould_use_connection=%s\n' \
    "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_PROFILE_EXPECTED_CONNECTION"
  printf 'would_bind_engine=%s|%s\n' "$SHIMMY_PROFILE_ENGINE_BINDING_MODE" \
    "$SHIMMY_PROFILE_ENGINE_ID"
  if [ "$shimmy_profile_create_dry_mode" = isolated ]; then
    printf 'would_create_machine=%s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE"
  fi
  printf 'would_write_active_profile=%s/active-profile.conf\n' "$shimmy_profile_create_dry_config"
  shimmy_profile_create_dry_control=$shimmy_profile_create_dry_invoking_root/ai-skills/control
  shimmy_ai_skill_bundle_read "$shimmy_profile_create_dry_control" control || return 1
  shimmy_profile_create_dry_names=$(printf '%s\n' "$SHIMMY_AI_SKILL_RECORDS" | sed -n 's/|.*//p')
  while IFS='|' read -r shimmy_profile_create_dry_tool shimmy_profile_create_dry_version shimmy_profile_create_dry_extra; do
    [ -n "$shimmy_profile_create_dry_tool" ] || continue
    [ -z "$shimmy_profile_create_dry_extra" ] || return 1
    shimmy_profile_create_dry_names=$(shimmy_append_line_list \
      "$shimmy_profile_create_dry_names" "shimmy-tool-$shimmy_profile_create_dry_tool")
  done <<EOF
$shimmy_profile_create_dry_pairs
EOF
  shimmy_profile_create_dry_names=$(printf '%s\n' "$shimmy_profile_create_dry_names" | sed '/^$/d' | LC_ALL=C sort -u)
  while IFS= read -r shimmy_profile_create_dry_name_entry; do
    [ -n "$shimmy_profile_create_dry_name_entry" ] || continue
    case "$shimmy_profile_create_dry_name_entry" in shimmy-tool-*) shimmy_profile_create_dry_kind=shims ;; *) shimmy_profile_create_dry_kind=control ;; esac
    shimmy_profile_create_dry_expected=$shimmy_profile_create_dry_config/profiles/$shimmy_profile_create_dry_name/ai-skills/$shimmy_profile_create_dry_kind/skills/$shimmy_profile_create_dry_name_entry
    shimmy_ai_skill_link_target_classify \
      "$SHIMMY_PROFILE_USER_SKILL_ROOT/$shimmy_profile_create_dry_name_entry" \
      "$shimmy_profile_create_dry_config/profiles" "$shimmy_profile_create_dry_name_entry" \
      "$shimmy_profile_create_dry_expected" || return 1
    printf 'would_reconcile_ai_skill=%s|%s|%s\n' "$shimmy_profile_create_dry_name_entry" \
      "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" \
      "$(shimmy_manifest_value_encode "$shimmy_profile_create_dry_expected")"
  done <<EOF
$shimmy_profile_create_dry_names
EOF
}

shimmy_profile_create_run() {
  shimmy_profile_create_config=$1
  shimmy_profile_create_invoking=$2
  shimmy_profile_create_name=$3
  shimmy_profile_create_restart=$4
  shimmy_profile_create_stop=$5
  shimmy_profile_create_dry=$6
  shimmy_profile_create_mode=${7:-shared}
  SHIMMY_PROFILE_LIFECYCLE_ERROR=
  shimmy_name_component_validate "$shimmy_profile_create_invoking" || return 1
  shimmy_name_component_validate "$shimmy_profile_create_name" || return 1
  case "$shimmy_profile_create_restart:$shimmy_profile_create_stop:$shimmy_profile_create_dry" in
    [01]:[01]:[01]) ;; *) return 1 ;;
  esac
  case "$shimmy_profile_create_mode" in shared|isolated) ;; *) return 1 ;; esac
  shimmy_profile_installation_context_resolve "$shimmy_profile_create_config" || return 1
  shimmy_profile_create_prior_active=$SHIMMY_PROFILE_ACTIVE_NAME
  shimmy_profile_create_user_root=$SHIMMY_PROFILE_USER_SKILL_ROOT
  shimmy_engine_installation_schema_state_read "$shimmy_profile_create_config" ||
    shimmy_profile_lifecycle_error_set 'invalid or partially published engine registry state' || return 1
  [ "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" = migrated ] ||
    shimmy_profile_lifecycle_error_set \
      'profile creation requires engine migration; run shimmy admin engine migrate --dry-run, then shimmy admin engine migrate' || return 1
  shimmy_profile_active_engine_validate "$shimmy_profile_create_config" \
    "$shimmy_profile_create_prior_active" || return 1
  shimmy_profile_state_paths_resolve "$shimmy_profile_create_config" "$shimmy_profile_create_name" || return 1
  [ ! -e "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ] ||
    shimmy_profile_lifecycle_error_set "profile already exists: $shimmy_profile_create_name" || return 1
  if [ "$shimmy_profile_create_mode" = isolated ]; then
    shimmy_engine_registry_isolated_preflight "$shimmy_profile_create_config" \
      "$shimmy_profile_create_name" ||
      shimmy_profile_lifecycle_error_set \
        "unable to preflight isolated engine shimmy-$shimmy_profile_create_name" || return 1
  fi
  shimmy_profile_candidate_resolve "$shimmy_profile_create_config" \
    "$shimmy_profile_create_invoking" || return 1
  shimmy_profile_create_invoking_root=$SHIMMY_PROFILE_CANDIDATE_ROOT
  shimmy_profile_create_source_url=$SHIMMY_PROFILE_CANDIDATE_SOURCE_URL
  shimmy_profile_create_source_ref=$SHIMMY_PROFILE_CANDIDATE_SOURCE_REF
  shimmy_profile_create_catalog_record=$SHIMMY_PROFILE_CANDIDATE_CATALOG
  shimmy_profile_create_invoking_manifest=$shimmy_profile_create_invoking_root/install-manifest.txt
  shimmy_profile_create_invoking_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_profile_create_invoking_manifest") || return 1
  shimmy_catalog_pin_validate "$shimmy_profile_create_catalog_record" || return 1
  shimmy_profile_create_generation=$shimmy_catalog_pin_generation
  shimmy_profile_create_catalog_root=$SHIMMY_CATALOG_GENERATIONS_ROOT/$shimmy_profile_create_generation
  shimmy_profile_baseline_records_resolve "$shimmy_profile_create_catalog_root" || return 1
  if [ "$shimmy_profile_create_dry" -eq 1 ]; then
    shimmy_profile_create_dry_run "$shimmy_profile_create_config" \
      "$shimmy_profile_create_name" "$shimmy_profile_create_invoking_root" \
      "$shimmy_profile_create_catalog_root" "$SHIMMY_PROFILE_BASELINE_PAIRS" \
      "$shimmy_profile_create_restart" "$shimmy_profile_create_stop" \
      "$shimmy_profile_create_mode"
    return $?
  fi

  shimmy_profile_materialization_prepare "$shimmy_profile_create_config" \
    "$shimmy_profile_create_name" installed "$shimmy_profile_create_invoking_root" \
    "$shimmy_profile_create_source_url" "$shimmy_profile_create_source_ref" \
    "$shimmy_profile_create_catalog_record" "$SHIMMY_PROFILE_BASELINE_SHIMS" \
    "$SHIMMY_PROFILE_BASELINE_VERSIONS" '' '' '' \
    "$shimmy_profile_create_invoking_root/ai-skills/control" '' \
    "$shimmy_profile_create_mode" || return 1
  shimmy_lock_acquire catalog "$shimmy_profile_create_config" || return 1
  shimmy_lock_acquire activation "$shimmy_profile_create_config" || return 1
  shimmy_profile_new_root_prepare "$shimmy_profile_create_config" \
    "$shimmy_profile_create_name" || return 1
  shimmy_profile_create_lock_names=$(printf '%s\n%s\n' "$shimmy_profile_create_invoking" \
    "$shimmy_profile_create_name" | LC_ALL=C sort -u)
  while IFS= read -r shimmy_profile_create_lock_name; do
    shimmy_lock_acquire profile "$shimmy_profile_create_config" \
      "$shimmy_profile_create_lock_name" || return 1
  done <<EOF
$shimmy_profile_create_lock_names
EOF
  shimmy_lock_acquire registry "$shimmy_profile_create_config" \
    "$shimmy_profile_create_name" || return 1
  shimmy_profile_installation_context_resolve "$shimmy_profile_create_config" || return 1
  [ "$SHIMMY_PROFILE_ACTIVE_NAME" = "$shimmy_profile_create_prior_active" ] &&
    [ "$SHIMMY_PROFILE_USER_SKILL_ROOT" = "$shimmy_profile_create_user_root" ] || return 1
  shimmy_profile_candidate_resolve "$shimmy_profile_create_config" \
    "$shimmy_profile_create_invoking" || return 1
  [ "$SHIMMY_PROFILE_CANDIDATE_SOURCE_REF" = "$shimmy_profile_create_source_ref" ] &&
    [ "$SHIMMY_PROFILE_CANDIDATE_CATALOG" = "$shimmy_profile_create_catalog_record" ] &&
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_PROFILE_CANDIDATE_ROOT/install-manifest.txt")" = \
      "$shimmy_profile_create_invoking_fingerprint" ] || return 1
  shimmy_profile_new_candidate_commit "$shimmy_profile_create_name" \
    "$shimmy_profile_create_catalog_root" || return 1
  SHIMMY_PROFILE_LIFECYCLE_IMAGE_ROOT=$shimmy_profile_create_config/profiles/$shimmy_profile_create_name
  SHIMMY_PROFILE_LIFECYCLE_IMAGE_PAIRS=$SHIMMY_PROFILE_BASELINE_PAIRS
  if [ "$shimmy_profile_create_mode" = isolated ]; then
    shimmy_engine_registry_isolated_create_prepare "$shimmy_profile_create_config" \
      "$shimmy_profile_create_name" || return 1
    SHIMMY_PROFILE_ENGINE_CREATE_PENDING=1
  fi
  shimmy_profile_candidate_resolve "$shimmy_profile_create_config" \
    "$shimmy_profile_create_name" || return 1
  shimmy_profile_lifecycle_activate_locked "$shimmy_profile_create_config" \
    "$shimmy_profile_create_prior_active" "$shimmy_profile_create_name" \
    "$shimmy_profile_create_user_root" "$shimmy_profile_create_restart" \
    "$shimmy_profile_create_stop" || return 1
  SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT=
  SHIMMY_PROFILE_LIFECYCLE_IMAGE_ROOT=
  SHIMMY_PROFILE_LIFECYCLE_IMAGE_PAIRS=
  SHIMMY_PROFILE_ENGINE_CREATE_PENDING=0
  SHIMMY_PROFILE_LIFECYCLE_PRESERVE_NEW_ROOT=0
  shimmy_locks_release_all || return 1
  printf 'Created and activated Shimmy profile %s.\n' "$shimmy_profile_create_name"
  shimmy_profile_create_shell=$(shimmy_quote_shell_word \
    "$shimmy_profile_create_config/profiles/$shimmy_profile_create_name/shell-init.sh") || return 1
  printf 'Select it in the current shell with: . %s\n' "$shimmy_profile_create_shell"
}

shimmy_profile_image_pairs_resolve() {
  shimmy_profile_image_pairs_versions=${1:-}
  SHIMMY_PROFILE_IMAGE_PAIRS=
  while IFS='|' read -r shimmy_profile_image_pairs_tool \
    shimmy_profile_image_pairs_version shimmy_profile_image_pairs_role \
    shimmy_profile_image_pairs_extra; do
    [ -n "$shimmy_profile_image_pairs_tool" ] || continue
    [ -n "$shimmy_profile_image_pairs_version" ] &&
      [ -n "$shimmy_profile_image_pairs_role" ] &&
      [ -z "$shimmy_profile_image_pairs_extra" ] || return 1
    SHIMMY_PROFILE_IMAGE_PAIRS=$(shimmy_append_line_list \
      "$SHIMMY_PROFILE_IMAGE_PAIRS" \
      "$shimmy_profile_image_pairs_tool|$shimmy_profile_image_pairs_version")
  done <<EOF
$shimmy_profile_image_pairs_versions
EOF
  SHIMMY_PROFILE_IMAGE_PAIRS=$(printf '%s\n' "$SHIMMY_PROFILE_IMAGE_PAIRS" |
    sed '/^$/d' | LC_ALL=C sort -u)
}

shimmy_profile_clone_run() {
  shimmy_profile_clone_config=$1
  shimmy_profile_clone_source=$2
  shimmy_profile_clone_target=$3
  shimmy_profile_clone_override=$4
  shimmy_profile_clone_restart=$5
  shimmy_profile_clone_stop=$6
  shimmy_profile_clone_dry=$7
  SHIMMY_PROFILE_LIFECYCLE_ERROR=
  shimmy_name_component_validate "$shimmy_profile_clone_source" || return 1
  shimmy_name_component_validate "$shimmy_profile_clone_target" || return 1
  [ "$shimmy_profile_clone_source" != "$shimmy_profile_clone_target" ] ||
    shimmy_profile_lifecycle_error_set 'profile clone source and target must differ' || return 1
  case "$shimmy_profile_clone_override" in default|shared|isolated) ;; *) return 1 ;; esac
  case "$shimmy_profile_clone_restart:$shimmy_profile_clone_stop:$shimmy_profile_clone_dry" in
    [01]:[01]:[01]) ;; *) return 1 ;;
  esac

  shimmy_profile_installation_context_resolve "$shimmy_profile_clone_config" || return 1
  shimmy_profile_clone_prior_active=$SHIMMY_PROFILE_ACTIVE_NAME
  shimmy_profile_clone_user_root=$SHIMMY_PROFILE_USER_SKILL_ROOT
  shimmy_engine_installation_schema_state_read "$shimmy_profile_clone_config" || return 1
  [ "$SHIMMY_ENGINE_INSTALLATION_SCHEMA_STATE" = migrated ] ||
    shimmy_profile_lifecycle_error_set \
      'profile clone requires a completely migrated engine registry' || return 1
  shimmy_profile_active_engine_validate "$shimmy_profile_clone_config" \
    "$shimmy_profile_clone_prior_active" || return 1
  shimmy_profile_candidate_resolve "$shimmy_profile_clone_config" \
    "$shimmy_profile_clone_source" || return 1
  shimmy_profile_clone_source_root=$SHIMMY_PROFILE_CANDIDATE_ROOT
  shimmy_profile_clone_source_url=$SHIMMY_PROFILE_CANDIDATE_SOURCE_URL
  shimmy_profile_clone_source_ref=$SHIMMY_PROFILE_CANDIDATE_SOURCE_REF
  shimmy_profile_clone_catalog_record=$SHIMMY_PROFILE_CANDIDATE_CATALOG
  shimmy_profile_clone_shims=$SHIMMY_PROFILE_CANDIDATE_SHIMS
  shimmy_profile_clone_versions=$SHIMMY_PROFILE_CANDIDATE_VERSIONS
  shimmy_profile_clone_source_mode=$SHIMMY_PROFILE_CANDIDATE_ENGINE_BINDING_MODE
  shimmy_profile_clone_manifest_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_profile_clone_source_root/install-manifest.txt") || return 1
  shimmy_profile_clone_registries_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_profile_clone_source_root/registries.conf") || return 1
  shimmy_profile_clone_binding_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_profile_clone_source_root/engine-binding.conf") || return 1
  shimmy_catalog_pin_validate "$shimmy_profile_clone_catalog_record" || return 1
  shimmy_profile_clone_catalog_root=$SHIMMY_CATALOG_GENERATIONS_ROOT/$shimmy_catalog_pin_generation
  shimmy_profile_image_pairs_resolve "$shimmy_profile_clone_versions" || return 1
  shimmy_profile_clone_pairs=$SHIMMY_PROFILE_IMAGE_PAIRS
  case "$shimmy_profile_clone_override" in
    shared|isolated) shimmy_profile_clone_mode=$shimmy_profile_clone_override ;;
    default)
      case "$shimmy_profile_clone_source_mode" in
        shared) shimmy_profile_clone_mode=shared ;;
        isolated|legacy-isolated) shimmy_profile_clone_mode=isolated ;;
        *) return 1 ;;
      esac
      ;;
  esac
  shimmy_profile_state_paths_resolve "$shimmy_profile_clone_config" \
    "$shimmy_profile_clone_target" || return 1
  [ ! -e "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ] ||
    shimmy_profile_lifecycle_error_set \
      "profile already exists: $shimmy_profile_clone_target" || return 1
  if [ "$shimmy_profile_clone_mode" = isolated ]; then
    shimmy_engine_registry_isolated_preflight "$shimmy_profile_clone_config" \
      "$shimmy_profile_clone_target" ||
      shimmy_profile_lifecycle_error_set \
        "unable to preflight isolated engine shimmy-$shimmy_profile_clone_target" || return 1
  fi
  if [ "$shimmy_profile_clone_dry" -eq 1 ]; then
    shimmy_profile_create_dry_run "$shimmy_profile_clone_config" \
      "$shimmy_profile_clone_target" "$shimmy_profile_clone_source_root" \
      "$shimmy_profile_clone_catalog_root" "$shimmy_profile_clone_pairs" \
      "$shimmy_profile_clone_restart" "$shimmy_profile_clone_stop" \
      "$shimmy_profile_clone_mode" || return 1
    printf 'would_clone_profile=%s\nwould_clone_binding=%s|%s\n' \
      "$shimmy_profile_clone_source" "$shimmy_profile_clone_mode" \
      "$(if [ "$shimmy_profile_clone_mode" = shared ]; then printf shared; else printf 'profile-%s' "$shimmy_profile_clone_target"; fi)"
    return 0
  fi

  shimmy_profile_materialization_prepare "$shimmy_profile_clone_config" \
    "$shimmy_profile_clone_target" installed "$shimmy_profile_clone_source_root" \
    "$shimmy_profile_clone_source_url" "$shimmy_profile_clone_source_ref" \
    "$shimmy_profile_clone_catalog_record" "$shimmy_profile_clone_shims" \
    "$shimmy_profile_clone_versions" '' '' \
    "$shimmy_profile_clone_source_root/registries.conf" \
    "$shimmy_profile_clone_source_root/ai-skills/control" '' \
    "$shimmy_profile_clone_mode" "$shimmy_profile_clone_source" || return 1
  shimmy_lock_acquire catalog "$shimmy_profile_clone_config" || return 1
  shimmy_lock_acquire activation "$shimmy_profile_clone_config" || return 1
  shimmy_profile_new_root_prepare "$shimmy_profile_clone_config" \
    "$shimmy_profile_clone_target" || return 1
  shimmy_profile_clone_lock_names=$(printf '%s\n%s\n' \
    "$shimmy_profile_clone_source" "$shimmy_profile_clone_target" | LC_ALL=C sort -u)
  while IFS= read -r shimmy_profile_clone_lock_name; do
    shimmy_lock_acquire profile "$shimmy_profile_clone_config" \
      "$shimmy_profile_clone_lock_name" || return 1
  done <<EOF
$shimmy_profile_clone_lock_names
EOF
  while IFS= read -r shimmy_profile_clone_lock_name; do
    shimmy_lock_acquire registry "$shimmy_profile_clone_config" \
      "$shimmy_profile_clone_lock_name" || return 1
  done <<EOF
$shimmy_profile_clone_lock_names
EOF
  shimmy_profile_installation_context_resolve "$shimmy_profile_clone_config" || return 1
  [ "$SHIMMY_PROFILE_ACTIVE_NAME" = "$shimmy_profile_clone_prior_active" ] &&
    [ "$SHIMMY_PROFILE_USER_SKILL_ROOT" = "$shimmy_profile_clone_user_root" ] || return 1
  shimmy_profile_candidate_resolve "$shimmy_profile_clone_config" \
    "$shimmy_profile_clone_source" || return 1
  [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_PROFILE_CANDIDATE_ROOT/install-manifest.txt")" = \
      "$shimmy_profile_clone_manifest_fingerprint" ] &&
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_PROFILE_CANDIDATE_ROOT/registries.conf")" = \
      "$shimmy_profile_clone_registries_fingerprint" ] &&
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_PROFILE_CANDIDATE_ROOT/engine-binding.conf")" = \
      "$shimmy_profile_clone_binding_fingerprint" ] || return 1
  shimmy_profile_new_candidate_commit "$shimmy_profile_clone_target" \
    "$shimmy_profile_clone_catalog_root" || return 1
  SHIMMY_PROFILE_LIFECYCLE_IMAGE_ROOT=$shimmy_profile_clone_config/profiles/$shimmy_profile_clone_target
  SHIMMY_PROFILE_LIFECYCLE_IMAGE_PAIRS=$shimmy_profile_clone_pairs
  if [ "$shimmy_profile_clone_mode" = isolated ]; then
    shimmy_engine_registry_isolated_create_prepare "$shimmy_profile_clone_config" \
      "$shimmy_profile_clone_target" || return 1
    SHIMMY_PROFILE_ENGINE_CREATE_PENDING=1
  fi
  shimmy_profile_candidate_resolve "$shimmy_profile_clone_config" \
    "$shimmy_profile_clone_target" || return 1
  shimmy_profile_lifecycle_activate_locked "$shimmy_profile_clone_config" \
    "$shimmy_profile_clone_prior_active" "$shimmy_profile_clone_target" \
    "$shimmy_profile_clone_user_root" "$shimmy_profile_clone_restart" \
    "$shimmy_profile_clone_stop" || return 1
  SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT=
  SHIMMY_PROFILE_LIFECYCLE_IMAGE_ROOT=
  SHIMMY_PROFILE_LIFECYCLE_IMAGE_PAIRS=
  SHIMMY_PROFILE_ENGINE_CREATE_PENDING=0
  SHIMMY_PROFILE_LIFECYCLE_PRESERVE_NEW_ROOT=0
  shimmy_locks_release_all || return 1
  printf 'Cloned Shimmy profile %s to %s and activated it.\n' \
    "$shimmy_profile_clone_source" "$shimmy_profile_clone_target"
  shimmy_profile_clone_shell=$(shimmy_quote_shell_word \
    "$shimmy_profile_clone_config/profiles/$shimmy_profile_clone_target/shell-init.sh") || return 1
  printf 'Select it in the current shell with: . %s\n' "$shimmy_profile_clone_shell"
}

shimmy_profile_initial_active_remove() {
  shimmy_profile_initial_active_path=$1
  shimmy_profile_initial_active_name=$2
  shimmy_profile_initial_active_root=$3
  shimmy_active_profile_read "$shimmy_profile_initial_active_path" || return 1
  [ "$SHIMMY_ACTIVE_PROFILE_NAME" = "$shimmy_profile_initial_active_name" ] &&
    [ "$SHIMMY_ACTIVE_AI_SKILL_ROOT" = "$shimmy_profile_initial_active_root" ] || return 1
  rm -f "$shimmy_profile_initial_active_path"
}

shimmy_profile_initial_active_create() {
  shimmy_profile_initial_active_path=$1
  shimmy_profile_initial_active_name=$2
  shimmy_profile_initial_active_root=$3
  [ "$SHIMMY_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  [ ! -e "$shimmy_profile_initial_active_path" ] && [ ! -L "$shimmy_profile_initial_active_path" ] || return 1
  shimmy_profile_initial_active_stage=$(dirname -- "$shimmy_profile_initial_active_path")/.active-profile.initial.$$
  shimmy_active_profile_render "$shimmy_profile_initial_active_name" \
    "$shimmy_profile_initial_active_root" > "$shimmy_profile_initial_active_stage" || return 1
  chmod 0644 "$shimmy_profile_initial_active_stage" || return 1
  shimmy_external_rollback_register "$shimmy_profile_initial_active_path" \
    shimmy_profile_initial_active_remove "$shimmy_profile_initial_active_name" \
    "$shimmy_profile_initial_active_root" 'remove initial active profile authority' || return 1
  mv "$shimmy_profile_initial_active_stage" "$shimmy_profile_initial_active_path"
}

shimmy_profile_lifecycle_activate_locked() {
  shimmy_profile_lifecycle_activate_config=$1
  shimmy_profile_lifecycle_activate_prior=$2
  shimmy_profile_lifecycle_activate_name=$3
  shimmy_profile_lifecycle_activate_user_root=$4
  shimmy_profile_lifecycle_activate_restart=$5
  shimmy_profile_lifecycle_activate_stop=$6
  shimmy_lock_held activation || return 1
  shimmy_lock_held profile "$shimmy_profile_lifecycle_activate_name" || return 1
  shimmy_lock_held registry "$shimmy_profile_lifecycle_activate_name" || return 1
  shimmy_profile_candidate_resolve "$shimmy_profile_lifecycle_activate_config" \
    "$shimmy_profile_lifecycle_activate_name" || return 1
  shimmy_profile_ai_skill_prepare "$shimmy_profile_lifecycle_activate_config" \
    "$shimmy_profile_lifecycle_activate_name" "$SHIMMY_PROFILE_CANDIDATE_ROOT" \
    "$SHIMMY_PROFILE_CANDIDATE_GENERATION_ROOT" || return 1
  SHIMMY_ACTIVATION_LOCK_EXTERNAL=1
  SHIMMY_REGISTRY_LOCK_EXTERNAL=1
  SHIMMY_PROFILE_ACTIVATION_DEFER_COMMIT=1
  SHIMMY_PROFILE_ACTIVATION_QUIET_SUCCESS=1
  shimmy_profile_engine_context_resolve "$shimmy_profile_lifecycle_activate_config" \
    "$shimmy_profile_lifecycle_activate_name" || return 1
  shimmy_profile_activate "$shimmy_profile_lifecycle_activate_restart" \
    "$shimmy_profile_lifecycle_activate_stop" 0 || return 1
  SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE=1
  if [ -n "${SHIMMY_PROFILE_LIFECYCLE_IMAGE_ROOT:-}" ]; then
    shimmy_profile_images_prepare "$SHIMMY_PROFILE_LIFECYCLE_IMAGE_ROOT" \
      "${SHIMMY_PROFILE_LIFECYCLE_IMAGE_PAIRS:-}" ||
      shimmy_profile_lifecycle_activation_rollback \
        'unable to prepare images on the target engine' || return 1
  fi
  shimmy_external_transaction_begin || return 1
  shimmy_active_profile_replace "$shimmy_profile_lifecycle_activate_name" \
    "$shimmy_profile_lifecycle_activate_user_root" ||
    shimmy_profile_lifecycle_activation_rollback 'unable to replace active profile authority' || return 1
  shimmy_ai_skill_reconcile_apply ||
    shimmy_profile_lifecycle_activation_rollback "${SHIMMY_AI_SKILL_ERROR:-unable to reconcile active AI-skill links}" || return 1
  shimmy_profile_activation_commit ||
    shimmy_profile_lifecycle_activation_rollback 'unable to finalize profile engine activation' || return 1
  if [ "${SHIMMY_ENGINE_REGISTRY_ISOLATED_CREATE_ACTIVE:-0}" -eq 1 ]; then
    shimmy_engine_registry_isolated_create_commit ||
      shimmy_profile_lifecycle_activation_rollback \
        'unable to finalize isolated engine creation' || return 1
  fi
  shimmy_external_transaction_commit || return 1
  SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE=0
}

shimmy_profile_lifecycle_activation_rollback() {
  shimmy_profile_lifecycle_rollback_reason=$1
  [ "$SHIMMY_EXTERNAL_TRANSACTION_ACTIVE" -eq 0 ] ||
    shimmy_external_transaction_rollback "$shimmy_profile_lifecycle_rollback_reason" || true
  [ "$SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE" -eq 0 ] ||
    shimmy_profile_activation_rollback "$shimmy_profile_lifecycle_rollback_reason" || true
  SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE=0
  shimmy_profile_lifecycle_error_set "$shimmy_profile_lifecycle_rollback_reason"
}

shimmy_profile_new_candidate_commit() {
  shimmy_profile_new_candidate_name=$1
  shimmy_profile_new_candidate_catalog=$2
  [ -n "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT" ] || return 1
  [ "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT" = "$SHIMMY_PROFILES_ROOT/$shimmy_profile_new_candidate_name" ] || return 1
  shimmy_lock_held profile "$shimmy_profile_new_candidate_name" || return 1
  shimmy_lock_held registry "$shimmy_profile_new_candidate_name" || return 1
  for shimmy_profile_new_candidate_entry in ai-skills bin commands config lib tools \
    engine-binding.conf registries.conf shell-init.sh; do
    mv "$SHIMMY_PROFILE_CANDIDATE_STAGE/$shimmy_profile_new_candidate_entry" \
      "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT/$shimmy_profile_new_candidate_entry" || return 1
  done
  mv "$SHIMMY_PROFILE_CANDIDATE_STAGE/install-manifest.txt" \
    "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT/install-manifest.txt" || return 1
  rmdir "$SHIMMY_PROFILE_CANDIDATE_STAGE" || return 1
  SHIMMY_PROFILE_CANDIDATE_STAGE=
  shimmy_shim_materialization_validate "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT" \
    "$shimmy_profile_new_candidate_catalog"
}

shimmy_profile_new_root_prepare() {
  shimmy_profile_new_config=$1
  shimmy_profile_new_name=$2
  shimmy_profile_state_paths_resolve "$shimmy_profile_new_config" "$shimmy_profile_new_name" || return 1
  [ ! -e "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ] || return 1
  mkdir "$SHIMMY_PROFILE_ROOT" || return 1
  SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT=$SHIMMY_PROFILE_ROOT
}

shimmy_profile_new_root_remove() {
  [ -n "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT" ] || return 0
  case "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT" in
    "$SHIMMY_PROFILES_ROOT"/*) ;;
    *) return 1 ;;
  esac
  shimmy_profile_new_root_name=$(basename -- "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT")
  shimmy_name_component_validate "$shimmy_profile_new_root_name" || return 1
  for shimmy_profile_new_root_entry in ai-skills bin commands config lib tools \
    engine-binding.conf install-manifest.txt machine-projection.txt registries.conf shell-init.sh; do
    shimmy_profile_new_root_path=$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT/$shimmy_profile_new_root_entry
    if [ -d "$shimmy_profile_new_root_path" ] && [ ! -L "$shimmy_profile_new_root_path" ]; then
      rm -rf "$shimmy_profile_new_root_path"
    elif [ -e "$shimmy_profile_new_root_path" ] || [ -L "$shimmy_profile_new_root_path" ]; then
      rm -f "$shimmy_profile_new_root_path"
    fi
  done
  shimmy_locks_release_all || return 1
  rmdir "$SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT" 2>/dev/null || true
  SHIMMY_PROFILE_LIFECYCLE_NEW_ROOT=
}

shimmy_profile_startup_backup_cleanup() {
  [ -n "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" ] || return 0
  case "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" in
    "$SHIMMY_CONFIG_ROOT"/.startup-backup.*) rm -rf "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" ;;
    *) return 1 ;;
  esac
  SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP=
}

shimmy_startup_apply() {
  shimmy_startup_config=$1
  shimmy_startup_files=${2:-}
  shimmy_startup_shell_init=$3
  [ "$SHIMMY_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  [ -n "$shimmy_startup_files" ] || return 0
  shimmy_path_absolute_normalized_validate "$shimmy_startup_shell_init" || return 1
  shimmy_profile_home=${HOME:-}
  shimmy_path_absolute_normalized_validate "$shimmy_profile_home" || return 1
  SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP=$shimmy_startup_config/.startup-backup.$$
  [ ! -e "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" ] &&
    [ ! -L "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" ] || return 1
  mkdir "$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP" || return 1
  shimmy_startup_block=$(shimmy_shell_init_source_block_render "$shimmy_startup_shell_init") || return 1
  shimmy_startup_sequence=0
  while IFS= read -r shimmy_startup_file; do
    [ -n "$shimmy_startup_file" ] || continue
    shimmy_path_absolute_normalized_validate "$shimmy_startup_file" || return 1
    case "$shimmy_startup_file" in "$shimmy_profile_home"/.*) ;; *) return 1 ;; esac
    shimmy_startup_sequence=$((shimmy_startup_sequence + 1))
    shimmy_startup_backup=$SHIMMY_PROFILE_LIFECYCLE_STARTUP_BACKUP/$shimmy_startup_sequence
    if [ -e "$shimmy_startup_file" ] || [ -L "$shimmy_startup_file" ]; then
      [ -f "$shimmy_startup_file" ] && [ ! -L "$shimmy_startup_file" ] || return 1
      cp "$shimmy_startup_file" "$shimmy_startup_backup" || return 1
      shimmy_external_rollback_register "$shimmy_startup_file" \
        shimmy_startup_restore "$shimmy_startup_backup" present \
        'restore prior startup file bytes' || return 1
    else
      shimmy_external_rollback_register "$shimmy_startup_file" \
        shimmy_startup_restore absent created 'remove newly created startup file' || return 1
    fi
    shimmy_startup_file_update "$shimmy_startup_file" "$shimmy_startup_block" || return 1
  done <<EOF
$shimmy_startup_files
EOF
}

shimmy_startup_restore() {
  shimmy_startup_restore_file=$1
  shimmy_startup_restore_prior=$2
  shimmy_startup_restore_committed=$3
  case "$shimmy_startup_restore_prior" in
    absent)
      [ "$shimmy_startup_restore_committed" = created ] || return 1
      [ ! -L "$shimmy_startup_restore_file" ] || return 1
      if [ -e "$shimmy_startup_restore_file" ]; then
        [ -f "$shimmy_startup_restore_file" ] || return 1
        rm -f "$shimmy_startup_restore_file"
      fi
      ;;
    *)
      [ "$shimmy_startup_restore_committed" = present ] || return 1
      [ -f "$shimmy_startup_restore_prior" ] && [ ! -L "$shimmy_startup_restore_prior" ] || return 1
      [ ! -L "$shimmy_startup_restore_file" ] || return 1
      cp "$shimmy_startup_restore_prior" "$shimmy_startup_restore_file"
      ;;
  esac
}
