#!/bin/sh
# Private target profile identity, activation, redirect, and status behavior.

SHIMMY_TARGET_PROFILE_ERROR=
SHIMMY_TARGET_PROFILE_ENGINE_TRANSITION_ACTIVE=0

shimmy_target_profile_error_set() {
  SHIMMY_TARGET_PROFILE_ERROR=$*
  return 1
}

shimmy_target_profile_engine_context_resolve() {
  shimmy_target_profile_engine_config=$1
  shimmy_target_profile_engine_name=$2
  shimmy_target_profile_paths_resolve "$shimmy_target_profile_engine_config" "$shimmy_target_profile_engine_name" ||
    shimmy_target_profile_error_set "invalid target profile identity: $shimmy_target_profile_engine_name" || return 1
  SHIMMY_CONFIG_ROOT=$SHIMMY_TARGET_CONFIG_ROOT
  SHIMMY_CONFIG_HOME=$(dirname -- "$SHIMMY_CONFIG_ROOT")
  SHIMMY_PROFILES_ROOT=$SHIMMY_TARGET_PROFILES_ROOT
  SHIMMY_PROFILE_NAME=$SHIMMY_TARGET_PROFILE_NAME
  SHIMMY_PROFILE_ROOT=$SHIMMY_TARGET_PROFILE_ROOT
  SHIMMY_PROFILE_MANIFEST_PATH=$SHIMMY_TARGET_PROFILE_MANIFEST_PATH
  SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH=$SHIMMY_TARGET_PROFILE_MACHINE_PROJECTION_PATH
  SHIMMY_PROFILE_REGISTRIES_PATH=$SHIMMY_TARGET_PROFILE_REGISTRIES_PATH
  SHIMMY_PROFILE_REGISTRIES_LOCK_PATH=$SHIMMY_PROFILE_ROOT/.registries.lock
  SHIMMY_REGISTRIES_CONFIG_DIR=$SHIMMY_CONFIG_HOME/containers
  SHIMMY_REGISTRIES_DROPIN_DIR=$SHIMMY_REGISTRIES_CONFIG_DIR/registries.conf.d
  SHIMMY_REGISTRIES_ACTIVE_LINK=$SHIMMY_REGISTRIES_DROPIN_DIR/shimmy-active-profile.conf
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK=/etc/containers/registries.conf.d/shimmy-profile.conf
  SHIMMY_PROFILE_BIN_DIR=$SHIMMY_PROFILE_ROOT/bin
  SHIMMY_PROFILE_CONFIG_DIR=$SHIMMY_PROFILE_ROOT/config
  SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR=$SHIMMY_PROFILE_ROOT/tools
  SHIMMY_PROFILE_ACTIVATION_TARGET_REQUIRED=1
  shimmy_path_parent_chain_validate "$SHIMMY_PROFILE_ROOT" ||
    shimmy_target_profile_error_set "unsafe target profile path: $SHIMMY_PROFILE_ROOT"
}

shimmy_target_profile_candidate_resolve() {
  shimmy_target_profile_candidate_config=$1
  shimmy_target_profile_candidate_name=$2
  SHIMMY_TARGET_PROFILE_ERROR=
  shimmy_target_catalog_tree_validate "$shimmy_target_profile_candidate_config" ||
    shimmy_target_profile_error_set "$SHIMMY_TARGET_CATALOG_ERROR" || return 1
  shimmy_target_profile_paths_resolve "$shimmy_target_profile_candidate_config" "$shimmy_target_profile_candidate_name" ||
    shimmy_target_profile_error_set "invalid target profile name: $shimmy_target_profile_candidate_name" || return 1
  [ -d "$SHIMMY_TARGET_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_TARGET_PROFILE_ROOT" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_TARGET_PROFILE_ROOT" ||
    shimmy_target_profile_error_set "unsafe or missing target profile root: $SHIMMY_TARGET_PROFILE_ROOT" || return 1
  shimmy_target_profile_manifest_read "$SHIMMY_TARGET_PROFILE_MANIFEST_PATH" ||
    shimmy_target_profile_error_set "invalid target profile manifest: $SHIMMY_TARGET_PROFILE_MANIFEST_PATH" || return 1
  [ "$SHIMMY_TARGET_PROFILE_NAME" = "$shimmy_target_profile_candidate_name" ] ||
    shimmy_target_profile_error_set "target profile manifest identity mismatch: $shimmy_target_profile_candidate_name" || return 1
  SHIMMY_TARGET_PROFILE_CANDIDATE_NAME=$SHIMMY_TARGET_PROFILE_NAME
  SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT=$SHIMMY_TARGET_PROFILE_ROOT
  SHIMMY_TARGET_PROFILE_CANDIDATE_SOURCE_URL=$SHIMMY_TARGET_PROFILE_SOURCE_URL
  SHIMMY_TARGET_PROFILE_CANDIDATE_SOURCE_REF=$SHIMMY_TARGET_PROFILE_SOURCE_REF
  SHIMMY_TARGET_PROFILE_CANDIDATE_CATALOG=$SHIMMY_TARGET_PROFILE_CATALOG_RECORD
  SHIMMY_TARGET_PROFILE_CANDIDATE_SHIMS=$SHIMMY_TARGET_PROFILE_SHIM_RECORDS
  SHIMMY_TARGET_PROFILE_CANDIDATE_VERSIONS=$SHIMMY_TARGET_PROFILE_SHIM_VERSION_RECORDS
  SHIMMY_TARGET_PROFILE_CANDIDATE_STARTUP_SHELL=$SHIMMY_TARGET_PROFILE_STARTUP_SHELL
  SHIMMY_TARGET_PROFILE_CANDIDATE_STARTUP_FILES=$SHIMMY_TARGET_PROFILE_STARTUP_FILES
  shimmy_target_catalog_pin_validate "$SHIMMY_TARGET_PROFILE_CANDIDATE_CATALOG" || return 1
  SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION=$shimmy_target_catalog_pin_generation
  SHIMMY_TARGET_PROFILE_CANDIDATE_CATALOG_COMMIT=$shimmy_target_catalog_pin_commit
  SHIMMY_TARGET_PROFILE_CANDIDATE_CATALOG_FINGERPRINT=$shimmy_target_catalog_pin_fingerprint
  SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION_ROOT=$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION
  shimmy_target_shim_materialization_validate "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT" "$SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION_ROOT" ||
    shimmy_target_profile_error_set "invalid target shim materialization: $SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT" || return 1
  shimmy_registries_config_validate "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/registries.conf" "$SHIMMY_TARGET_PROFILE_CANDIDATE_NAME" ||
    shimmy_target_profile_error_set "invalid target registry configuration: $SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/registries.conf" || return 1
  shimmy_target_profile_launcher_validate "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/bin/shimmy" \
    "$shimmy_target_profile_candidate_config" "$SHIMMY_TARGET_PROFILE_CANDIDATE_NAME" ||
    shimmy_target_profile_error_set "invalid target profile launcher: $SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/bin/shimmy" || return 1
  shimmy_target_profile_shell_init_validate "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/shell-init.sh" \
    "$shimmy_target_profile_candidate_config" "$SHIMMY_TARGET_PROFILE_CANDIDATE_NAME" ||
    shimmy_target_profile_error_set "invalid target shell initialization: $SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/shell-init.sh" || return 1
  for shimmy_target_profile_candidate_dir in commands lib ai-skills; do
    [ -d "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/$shimmy_target_profile_candidate_dir" ] &&
      [ ! -L "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/$shimmy_target_profile_candidate_dir" ] ||
      shimmy_target_profile_error_set "missing target profile asset directory: $SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/$shimmy_target_profile_candidate_dir" || return 1
  done
  [ -x "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/commands/profile-target.sh" ] &&
    [ ! -L "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/commands/profile-target.sh" ] ||
    shimmy_target_profile_error_set "missing target profile command: $SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT/commands/profile-target.sh" || return 1
  shimmy_target_ai_skill_supported_bundles_validate "$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT" \
    "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH" "$SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION_ROOT" ||
    shimmy_target_profile_error_set 'supported target AI-skill bundle consistency validation failed'
}

shimmy_target_profile_installation_context_resolve() {
  shimmy_target_profile_installation_config=$1
  SHIMMY_TARGET_PROFILE_ERROR=
  shimmy_target_catalog_tree_validate "$shimmy_target_profile_installation_config" ||
    shimmy_target_profile_error_set "$SHIMMY_TARGET_CATALOG_ERROR" || return 1
  shimmy_target_installation_paths_resolve "$shimmy_target_profile_installation_config" || return 1
  [ -d "$SHIMMY_TARGET_PROFILES_ROOT" ] && [ ! -L "$SHIMMY_TARGET_PROFILES_ROOT" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_TARGET_PROFILES_ROOT" ||
    shimmy_target_profile_error_set "unsafe target profiles root: $SHIMMY_TARGET_PROFILES_ROOT" || return 1
  [ -d "$SHIMMY_TARGET_PROFILES_ROOT/default" ] && [ ! -L "$SHIMMY_TARGET_PROFILES_ROOT/default" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_TARGET_PROFILES_ROOT/default" ||
    shimmy_target_profile_error_set "target installation is missing its canonical default profile: $SHIMMY_TARGET_PROFILES_ROOT/default" || return 1
  shimmy_target_active_profile_read "$SHIMMY_TARGET_ACTIVE_PROFILE_PATH" ||
    shimmy_target_profile_error_set "invalid target active profile record: $SHIMMY_TARGET_ACTIVE_PROFILE_PATH" || return 1
  SHIMMY_TARGET_PROFILE_ACTIVE_NAME=$SHIMMY_TARGET_ACTIVE_PROFILE_NAME
  SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT=$SHIMMY_TARGET_ACTIVE_AI_SKILL_ROOT
  shimmy_target_profile_home=${HOME:-}
  shimmy_path_absolute_normalized_validate "$shimmy_target_profile_home" ||
    shimmy_target_profile_error_set 'target profile activation requires a normalized absolute HOME' || return 1
  [ "$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT" = "$shimmy_target_profile_home/.agents/skills" ] ||
    shimmy_target_profile_error_set "recorded AI-skill root does not match the current installation context: $SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT" || return 1
  [ -d "$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT" ] && [ ! -L "$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT" ||
    shimmy_target_profile_error_set "unsafe recorded AI-skill root: $SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT" || return 1
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_installation_config" "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" || return 1
  SHIMMY_TARGET_PROFILE_ACTIVE_ROOT=$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT
}

shimmy_target_profile_ai_skill_prepare() {
  shimmy_target_profile_ai_config=$1
  shimmy_target_profile_ai_name=$2
  shimmy_target_profile_ai_root=$3
  shimmy_target_profile_ai_generation_root=$4
  SHIMMY_TARGET_AI_SKILL_ACTIVE_NAME=$shimmy_target_profile_ai_name
  SHIMMY_TARGET_AI_SKILL_USER_ROOT=$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT
  SHIMMY_TARGET_AI_SKILL_PROFILE_ROOT=$shimmy_target_profile_ai_root
  SHIMMY_TARGET_PROFILES_ROOT=$shimmy_target_profile_ai_config/profiles
  shimmy_target_ai_skill_reconcile_preflight "$shimmy_target_profile_ai_root" \
    "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH" "$shimmy_target_profile_ai_generation_root" ||
    shimmy_target_profile_error_set "$SHIMMY_TARGET_AI_SKILL_ERROR"
}

shimmy_target_profile_active_engine_validate() {
  shimmy_target_profile_active_engine_config=$1
  shimmy_target_profile_active_engine_name=$2
  shimmy_target_profile_engine_context_resolve "$shimmy_target_profile_active_engine_config" "$shimmy_target_profile_active_engine_name" || return 1
  shimmy_profile_activation_expected_resolve || return 1
  shimmy_profile_state_read
  [ "$SHIMMY_PROFILE_ACTIVATION_STATE" = active ] ||
    shimmy_target_profile_error_set "active record and engine/registry state disagree for $shimmy_target_profile_active_engine_name: $SHIMMY_PROFILE_ACTIVATION_STATE"
}

shimmy_target_active_profile_rollback() {
  shimmy_target_active_rollback_path=$1
  shimmy_target_active_rollback_prior=$2
  shimmy_target_active_rollback_committed=$3
  shimmy_target_active_rollback_config=$(dirname -- "$shimmy_target_active_rollback_path")
  [ "$shimmy_target_active_rollback_path" = "$shimmy_target_active_rollback_config/active-profile.conf" ] || return 1
  shimmy_target_active_rollback_prior_name=${shimmy_target_active_rollback_prior%%|*}
  shimmy_target_active_rollback_prior_root=${shimmy_target_active_rollback_prior#*|}
  shimmy_target_active_rollback_committed_name=${shimmy_target_active_rollback_committed%%|*}
  shimmy_target_active_rollback_committed_root=${shimmy_target_active_rollback_committed#*|}
  shimmy_target_active_profile_read "$shimmy_target_active_rollback_path" || return 1
  if [ "$SHIMMY_TARGET_ACTIVE_PROFILE_NAME|$SHIMMY_TARGET_ACTIVE_AI_SKILL_ROOT" = "$shimmy_target_active_rollback_prior" ]; then
    return 0
  fi
  [ "$SHIMMY_TARGET_ACTIVE_PROFILE_NAME" = "$shimmy_target_active_rollback_committed_name" ] &&
    [ "$SHIMMY_TARGET_ACTIVE_AI_SKILL_ROOT" = "$shimmy_target_active_rollback_committed_root" ] || return 1
  shimmy_target_active_rollback_stage=$shimmy_target_active_rollback_config/.active-profile.rollback.$$
  [ ! -e "$shimmy_target_active_rollback_stage" ] && [ ! -L "$shimmy_target_active_rollback_stage" ] || return 1
  shimmy_target_active_profile_render "$shimmy_target_active_rollback_prior_name" "$shimmy_target_active_rollback_prior_root" > "$shimmy_target_active_rollback_stage" || return 1
  chmod 0644 "$shimmy_target_active_rollback_stage" || { rm -f "$shimmy_target_active_rollback_stage"; return 1; }
  mv "$shimmy_target_active_rollback_stage" "$shimmy_target_active_rollback_path"
}

shimmy_target_active_profile_replace() {
  shimmy_target_active_replace_name=$1
  shimmy_target_active_replace_root=$2
  shimmy_target_lock_held activation || return 1
  shimmy_target_active_profile_read "$SHIMMY_TARGET_ACTIVE_PROFILE_PATH" || return 1
  shimmy_target_active_replace_prior=$SHIMMY_TARGET_ACTIVE_PROFILE_NAME\|$SHIMMY_TARGET_ACTIVE_AI_SKILL_ROOT
  shimmy_target_active_replace_committed=$shimmy_target_active_replace_name\|$shimmy_target_active_replace_root
  [ "$shimmy_target_active_replace_prior" != "$shimmy_target_active_replace_committed" ] || return 0
  shimmy_target_external_rollback_register "$SHIMMY_TARGET_ACTIVE_PROFILE_PATH" \
    shimmy_target_active_profile_rollback "$shimmy_target_active_replace_prior" \
    "$shimmy_target_active_replace_committed" 'restore prior active profile authority' || return 1
  shimmy_target_active_replace_stage=$SHIMMY_TARGET_CONFIG_ROOT/.active-profile.tmp.$$
  [ ! -e "$shimmy_target_active_replace_stage" ] && [ ! -L "$shimmy_target_active_replace_stage" ] || return 1
  shimmy_target_active_profile_render "$shimmy_target_active_replace_name" "$shimmy_target_active_replace_root" > "$shimmy_target_active_replace_stage" || return 1
  chmod 0644 "$shimmy_target_active_replace_stage" || { rm -f "$shimmy_target_active_replace_stage"; return 1; }
  shimmy_target_active_profile_read "$shimmy_target_active_replace_stage" || { rm -f "$shimmy_target_active_replace_stage"; return 1; }
  mv "$shimmy_target_active_replace_stage" "$SHIMMY_TARGET_ACTIVE_PROFILE_PATH" || return 1
  if [ "${SHIMMY_TARGET_TEST_MODE:-0}" -eq 1 ] && [ "${SHIMMY_TARGET_TEST_PROFILE_FAILURE:-}" = after-active-record ]; then
    shimmy_target_profile_error_set 'injected target profile failure after active record replacement'
    return 1
  fi
}

shimmy_target_profile_locks_acquire() {
  shimmy_target_profile_locks_config=$1
  shimmy_target_profile_locks_prior=$2
  shimmy_target_profile_locks_target=$3
  shimmy_target_lock_acquire activation "$shimmy_target_profile_locks_config" || return 1
  shimmy_target_profile_lock_names=$(printf '%s\n%s\n' "$shimmy_target_profile_locks_prior" "$shimmy_target_profile_locks_target" | LC_ALL=C sort -u)
  while IFS= read -r shimmy_target_profile_lock_name; do
    [ -n "$shimmy_target_profile_lock_name" ] || continue
    shimmy_target_lock_acquire profile "$shimmy_target_profile_locks_config" "$shimmy_target_profile_lock_name" || return 1
  done <<EOF
$shimmy_target_profile_lock_names
EOF
  shimmy_target_lock_acquire registry "$shimmy_target_profile_locks_config" "$shimmy_target_profile_locks_target"
}

shimmy_target_profile_activate_failure() {
  shimmy_target_profile_activate_reason=$1
  shimmy_target_profile_activate_engine_changed=$2
  if [ "$SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ]; then
    shimmy_target_external_transaction_rollback "$shimmy_target_profile_activate_reason" || true
  fi
  if [ "$shimmy_target_profile_activate_engine_changed" -eq 1 ]; then
    shimmy_profile_activation_rollback "$shimmy_target_profile_activate_reason" || true
  fi
  SHIMMY_TARGET_PROFILE_ENGINE_TRANSITION_ACTIVE=0
  shimmy_target_locks_release_all || true
  shimmy_target_profile_error_set "$shimmy_target_profile_activate_reason"
}

shimmy_target_profile_activate() {
  shimmy_target_profile_activate_config=$1
  shimmy_target_profile_activate_name=$2
  shimmy_target_profile_activate_restart=$3
  shimmy_target_profile_activate_stop_running=$4
  shimmy_target_profile_activate_dry_run=$5
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_activate_config" || return 1
  shimmy_target_profile_activate_prior=$SHIMMY_TARGET_PROFILE_ACTIVE_NAME
  shimmy_target_profile_activate_user_root=$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT
  shimmy_target_profile_active_engine_validate "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_prior" || return 1
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_name" || return 1
  shimmy_target_profile_activate_target_root=$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT
  shimmy_target_profile_activate_generation_root=$SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION_ROOT
  shimmy_target_profile_ai_skill_prepare "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_name" \
    "$shimmy_target_profile_activate_target_root" "$shimmy_target_profile_activate_generation_root" || return 1
  shimmy_target_ai_skill_reconcile_plan_render human || return 1

  SHIMMY_TARGET_ACTIVATION_LOCK_EXTERNAL=1
  SHIMMY_TARGET_REGISTRY_LOCK_EXTERNAL=1
  SHIMMY_PROFILE_ACTIVATION_DEFER_COMMIT=1
  SHIMMY_PROFILE_ACTIVATION_QUIET_SUCCESS=1
  shimmy_target_profile_engine_context_resolve "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_name" || return 1
  if [ "$shimmy_target_profile_activate_dry_run" -eq 1 ]; then
    shimmy_profile_activate "$shimmy_target_profile_activate_restart" "$shimmy_target_profile_activate_stop_running" 1 || return 1
    printf 'would_write_active_profile=%s\n' "$SHIMMY_TARGET_ACTIVE_PROFILE_PATH"
    printf 'would_activate_profile=%s\n' "$shimmy_target_profile_activate_name"
    shimmy_target_ai_skill_reconcile_plan_render manifest
    return $?
  fi

  shimmy_target_profile_locks_acquire "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_prior" \
    "$shimmy_target_profile_activate_name" || { shimmy_target_locks_release_all || true; return 1; }
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_activate_config" || {
    shimmy_target_locks_release_all || true
    return 1
  }
  [ "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" = "$shimmy_target_profile_activate_prior" ] &&
    [ "$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT" = "$shimmy_target_profile_activate_user_root" ] || {
      shimmy_target_locks_release_all || true
      shimmy_target_profile_error_set 'active profile authority changed during target activation'
      return 1
    }
  shimmy_target_profile_active_engine_validate "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_prior" || {
    shimmy_target_locks_release_all || true
    return 1
  }
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_name" || {
    shimmy_target_locks_release_all || true
    return 1
  }
  shimmy_target_profile_activate_target_root=$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT
  shimmy_target_profile_activate_generation_root=$SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION_ROOT
  shimmy_target_profile_ai_skill_prepare "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_name" \
    "$shimmy_target_profile_activate_target_root" "$shimmy_target_profile_activate_generation_root" || {
    shimmy_target_locks_release_all || true
    return 1
  }
  shimmy_target_profile_engine_context_resolve "$shimmy_target_profile_activate_config" "$shimmy_target_profile_activate_name" || {
    shimmy_target_locks_release_all || true
    return 1
  }
  shimmy_profile_activate "$shimmy_target_profile_activate_restart" "$shimmy_target_profile_activate_stop_running" 0 || {
    shimmy_target_locks_release_all || true
    return 1
  }
  shimmy_target_profile_activate_engine_changed=1
  SHIMMY_TARGET_PROFILE_ENGINE_TRANSITION_ACTIVE=1
  shimmy_target_external_transaction_begin ||
    shimmy_target_profile_activate_failure 'unable to begin profile integration transaction' "$shimmy_target_profile_activate_engine_changed" || return 1
  shimmy_target_active_profile_replace "$shimmy_target_profile_activate_name" "$shimmy_target_profile_activate_user_root" ||
    shimmy_target_profile_activate_failure "${SHIMMY_TARGET_PROFILE_ERROR:-unable to replace active profile authority}" "$shimmy_target_profile_activate_engine_changed" || return 1
  if ! shimmy_target_ai_skill_reconcile_apply; then
    shimmy_target_profile_activate_failure "${SHIMMY_TARGET_AI_SKILL_ERROR:-unable to reconcile active AI-skill links}" "$shimmy_target_profile_activate_engine_changed"
    return 1
  fi
  shimmy_profile_activation_commit ||
    shimmy_target_profile_activate_failure 'unable to finalize profile engine activation' "$shimmy_target_profile_activate_engine_changed" || return 1
  shimmy_target_external_transaction_commit || {
    shimmy_target_locks_release_all || true
    return 1
  }
  SHIMMY_TARGET_PROFILE_ENGINE_TRANSITION_ACTIVE=0
  shimmy_target_locks_release_all || return 1
  printf 'Activated Shimmy profile %s.\n' "$shimmy_target_profile_activate_name"
  shimmy_target_profile_activate_shell_init=$(shimmy_quote_shell_word "$shimmy_target_profile_activate_target_root/shell-init.sh") || return 1
  printf 'Select it in the current shell with: . %s\n' "$shimmy_target_profile_activate_shell_init"
}

shimmy_target_profile_cleanup() {
  if [ "${SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE:-0}" -eq 1 ]; then
    shimmy_target_external_transaction_rollback 'target profile command interruption' 2>/dev/null || true
  fi
  if [ "${SHIMMY_TARGET_PROFILE_ENGINE_TRANSITION_ACTIVE:-0}" -eq 1 ]; then
    shimmy_profile_activation_rollback 'target profile command interruption' 2>/dev/null || true
    SHIMMY_TARGET_PROFILE_ENGINE_TRANSITION_ACTIVE=0
  fi
  shimmy_target_locks_release_all 2>/dev/null || true
}

shimmy_target_profile_list_render() {
  shimmy_target_profile_list_config=$1
  shimmy_target_profile_list_format=${2:-human}
  case "$shimmy_target_profile_list_format" in human|manifest) ;; *) return 1 ;; esac
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_list_config" || return 1
  shimmy_target_profile_list_active=$SHIMMY_TARGET_PROFILE_ACTIVE_NAME
  shimmy_target_profile_list_names=
  for shimmy_target_profile_list_path in "$SHIMMY_TARGET_PROFILES_ROOT"/*; do
    [ -e "$shimmy_target_profile_list_path" ] || [ -L "$shimmy_target_profile_list_path" ] || continue
    shimmy_target_profile_list_name=$(basename -- "$shimmy_target_profile_list_path")
    shimmy_name_component_validate "$shimmy_target_profile_list_name" &&
      [ -d "$shimmy_target_profile_list_path" ] && [ ! -L "$shimmy_target_profile_list_path" ] ||
      shimmy_target_profile_error_set "unsafe target profile entry: $shimmy_target_profile_list_path" || return 1
    shimmy_target_profile_list_names=$(shimmy_append_line_list "$shimmy_target_profile_list_names" "$shimmy_target_profile_list_name")
  done
  shimmy_target_profile_list_names=$(printf '%s\n' "$shimmy_target_profile_list_names" | sed '/^$/d' | LC_ALL=C sort)
  [ -n "$shimmy_target_profile_list_names" ] || return 1
  [ "$shimmy_target_profile_list_format" != human ] || printf 'PROFILE ACTIVE CONTROL CATALOG STATE\n'
  while IFS= read -r shimmy_target_profile_list_name; do
    [ -n "$shimmy_target_profile_list_name" ] || continue
    shimmy_target_profile_list_is_active=no
    [ "$shimmy_target_profile_list_name" != "$shimmy_target_profile_list_active" ] || shimmy_target_profile_list_is_active=yes
    if shimmy_target_profile_candidate_resolve "$shimmy_target_profile_list_config" "$shimmy_target_profile_list_name"; then
      shimmy_target_profile_list_state=valid
      shimmy_target_profile_list_source=$SHIMMY_TARGET_PROFILE_CANDIDATE_SOURCE_REF
      shimmy_target_profile_list_generation=$SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION
    else
      shimmy_target_profile_list_state=invalid
      shimmy_target_profile_list_source=-
      shimmy_target_profile_list_generation=-
    fi
    if [ "$shimmy_target_profile_list_format" = manifest ]; then
      printf 'shimmy_profile=%s|%s|%s|%s|%s\n' "$shimmy_target_profile_list_name" \
        "$shimmy_target_profile_list_is_active" "$shimmy_target_profile_list_source" \
        "$shimmy_target_profile_list_generation" "$shimmy_target_profile_list_state"
    else
      printf '%s %s %s %s %s\n' "$shimmy_target_profile_list_name" "$shimmy_target_profile_list_is_active" \
        "$shimmy_target_profile_list_source" "$shimmy_target_profile_list_generation" "$shimmy_target_profile_list_state"
    fi
  done <<EOF
$shimmy_target_profile_list_names
EOF
}

shimmy_target_profile_status_link_counts_resolve() {
  shimmy_target_profile_status_links_root=$1
  shimmy_target_profile_status_links_kind=$2
  shimmy_target_profile_status_links_active=$3
  SHIMMY_TARGET_PROFILE_STATUS_LINK_CURRENT=not-applicable
  SHIMMY_TARGET_PROFILE_STATUS_LINK_EXPECTED=not-applicable
  [ "$shimmy_target_profile_status_links_active" = yes ] || return 0

  shimmy_target_profile_status_links_bundle=$shimmy_target_profile_status_links_root/ai-skills/$shimmy_target_profile_status_links_kind
  shimmy_target_ai_skill_bundle_probe "$shimmy_target_profile_status_links_bundle" \
    "$shimmy_target_profile_status_links_kind" "$SHIMMY_TARGET_PROFILE_NAME" || return 1
  if [ "$SHIMMY_TARGET_AI_SKILL_PROBE_UNSUPPORTED" -eq 1 ]; then
    SHIMMY_TARGET_PROFILE_STATUS_LINK_CURRENT=0
    SHIMMY_TARGET_PROFILE_STATUS_LINK_EXPECTED=0
    return 0
  fi
  case "$SHIMMY_TARGET_AI_SKILL_PROBE_STATUS" in valid|empty) ;; *) return 1 ;; esac
  shimmy_target_profile_status_links_records=$SHIMMY_TARGET_AI_SKILL_PROBE_RECORDS
  SHIMMY_TARGET_PROFILE_STATUS_LINK_CURRENT=0
  SHIMMY_TARGET_PROFILE_STATUS_LINK_EXPECTED=0
  while IFS= read -r shimmy_target_profile_status_links_record; do
    [ -n "$shimmy_target_profile_status_links_record" ] || continue
    shimmy_target_profile_status_links_name=${shimmy_target_profile_status_links_record%%|*}
    shimmy_target_ai_skill_link_plan "$SHIMMY_TARGET_PROFILE_USER_SKILL_ROOT" "$SHIMMY_TARGET_PROFILES_ROOT" \
      "$shimmy_target_profile_status_links_bundle" "$shimmy_target_profile_status_links_name" || return 1
    SHIMMY_TARGET_PROFILE_STATUS_LINK_EXPECTED=$((SHIMMY_TARGET_PROFILE_STATUS_LINK_EXPECTED + 1))
    [ "$SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION" != shimmy-link-current ] ||
      SHIMMY_TARGET_PROFILE_STATUS_LINK_CURRENT=$((SHIMMY_TARGET_PROFILE_STATUS_LINK_CURRENT + 1))
  done <<EOF
$shimmy_target_profile_status_links_records
EOF
}

shimmy_target_profile_status_render() {
  shimmy_target_profile_status_config=$1
  shimmy_target_profile_status_name=$2
  shimmy_target_profile_status_format=${3:-human}
  case "$shimmy_target_profile_status_format" in human|manifest) ;; *) return 1 ;; esac
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_status_config" || return 1
  shimmy_target_profile_status_active=no
  [ "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" != "$shimmy_target_profile_status_name" ] || shimmy_target_profile_status_active=yes
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_status_config" "$shimmy_target_profile_status_name" || return 1
  shimmy_target_profile_status_root=$SHIMMY_TARGET_PROFILE_CANDIDATE_ROOT
  shimmy_target_profile_status_source_url=$SHIMMY_TARGET_PROFILE_CANDIDATE_SOURCE_URL
  shimmy_target_profile_status_source_ref=$SHIMMY_TARGET_PROFILE_CANDIDATE_SOURCE_REF
  shimmy_target_profile_status_catalog=$SHIMMY_TARGET_PROFILE_CANDIDATE_CATALOG
  shimmy_target_profile_status_generation=$SHIMMY_TARGET_PROFILE_CANDIDATE_GENERATION
  shimmy_target_profile_status_shims=$SHIMMY_TARGET_PROFILE_CANDIDATE_SHIMS
  shimmy_target_profile_status_versions=$SHIMMY_TARGET_PROFILE_CANDIDATE_VERSIONS
  shimmy_target_profile_status_control_bundle=$SHIMMY_TARGET_AI_SKILL_CONTROL_STATUS
  shimmy_target_profile_status_control_reason=$SHIMMY_TARGET_AI_SKILL_CONTROL_REASON
  shimmy_target_profile_status_shims_bundle=$SHIMMY_TARGET_AI_SKILL_SHIMS_STATUS
  shimmy_target_profile_status_shims_reason=$SHIMMY_TARGET_AI_SKILL_SHIMS_REASON
  shimmy_target_profile_status_startup_shell=${SHIMMY_TARGET_PROFILE_CANDIDATE_STARTUP_SHELL:--}
  shimmy_target_profile_status_startup_files=$SHIMMY_TARGET_PROFILE_CANDIDATE_STARTUP_FILES
  shimmy_target_profile_status_link_counts_resolve "$shimmy_target_profile_status_root" control \
    "$shimmy_target_profile_status_active" || return 1
  shimmy_target_profile_status_control_link_current=$SHIMMY_TARGET_PROFILE_STATUS_LINK_CURRENT
  shimmy_target_profile_status_control_link_expected=$SHIMMY_TARGET_PROFILE_STATUS_LINK_EXPECTED
  shimmy_target_profile_status_link_counts_resolve "$shimmy_target_profile_status_root" shims \
    "$shimmy_target_profile_status_active" || return 1
  shimmy_target_profile_status_shims_link_current=$SHIMMY_TARGET_PROFILE_STATUS_LINK_CURRENT
  shimmy_target_profile_status_shims_link_expected=$SHIMMY_TARGET_PROFILE_STATUS_LINK_EXPECTED
  shimmy_target_profile_engine_context_resolve "$shimmy_target_profile_status_config" "$shimmy_target_profile_status_name" || return 1
  shimmy_profile_state_read
  shimmy_target_catalog_registry_read "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH" || return 1
  shimmy_target_profile_status_catalog_name=${shimmy_target_profile_status_catalog%%|*}
  shimmy_target_profile_status_catalog_current=$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT
  shimmy_target_profile_status_catalog_drift=no
  [ "$shimmy_target_profile_status_generation" = "$shimmy_target_profile_status_catalog_current" ] || shimmy_target_profile_status_catalog_drift=yes
  if [ "$shimmy_target_profile_status_format" = manifest ]; then
    printf 'shimmy_profile_name=%s\n' "$shimmy_target_profile_status_name"
    printf 'shimmy_profile_root=%s\n' "$(shimmy_manifest_value_encode "$shimmy_target_profile_status_root")"
    printf 'shimmy_profile_active=%s\n' "$shimmy_target_profile_status_active"
    printf 'shimmy_profile_source_url=%s\n' "$(shimmy_manifest_value_encode "$shimmy_target_profile_status_source_url")"
    printf 'shimmy_profile_source_tracking_ref=refs/heads/main\n'
    printf 'shimmy_profile_source_ref=%s\n' "$shimmy_target_profile_status_source_ref"
    printf 'shimmy_profile_catalog=%s|%s|%s|%s|ok\n' "$shimmy_target_profile_status_catalog_name" \
      "$shimmy_target_profile_status_generation" "$shimmy_target_profile_status_catalog_current" \
      "$shimmy_target_profile_status_catalog_drift"
    while IFS= read -r shimmy_target_profile_status_shim; do [ -z "$shimmy_target_profile_status_shim" ] || printf 'shimmy_profile_shim=%s\n' "$shimmy_target_profile_status_shim"; done <<EOF
$shimmy_target_profile_status_shims
EOF
    while IFS= read -r shimmy_target_profile_status_version; do [ -z "$shimmy_target_profile_status_version" ] || printf 'shimmy_profile_shim_version=%s\n' "$shimmy_target_profile_status_version"; done <<EOF
$shimmy_target_profile_status_versions
EOF
    printf 'shimmy_profile_ai_skill_bundle=control|%s|%s\n' "$shimmy_target_profile_status_control_bundle" "$(shimmy_manifest_value_encode "$shimmy_target_profile_status_control_reason")"
    printf 'shimmy_profile_ai_skill_bundle=shims|%s|%s\n' "$shimmy_target_profile_status_shims_bundle" "$(shimmy_manifest_value_encode "$shimmy_target_profile_status_shims_reason")"
    printf 'shimmy_profile_ai_skill_links=control|%s|%s\n' "$shimmy_target_profile_status_control_link_current" "$shimmy_target_profile_status_control_link_expected"
    printf 'shimmy_profile_ai_skill_links=shims|%s|%s\n' "$shimmy_target_profile_status_shims_link_current" "$shimmy_target_profile_status_shims_link_expected"
    printf 'shimmy_profile_startup_shell=%s\n' "$shimmy_target_profile_status_startup_shell"
    while IFS= read -r shimmy_target_profile_status_startup; do [ -z "$shimmy_target_profile_status_startup" ] || printf 'shimmy_profile_startup_file=%s\n' "$(shimmy_manifest_value_encode "$shimmy_target_profile_status_startup")"; done <<EOF
$shimmy_target_profile_status_startup_files
EOF
    printf 'shimmy_engine_profile=%s\n' "$SHIMMY_PROFILE_NAME"
    printf 'shimmy_engine_host_os=%s\n' "$SHIMMY_PROFILE_HOST_OS"
    printf 'shimmy_engine_type=%s\n' "$SHIMMY_PROFILE_ENGINE_TYPE"
    printf 'shimmy_engine_expected=%s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE"
    printf 'shimmy_engine_expected_connection=%s\n' "$SHIMMY_PROFILE_EXPECTED_CONNECTION"
    printf 'shimmy_engine_default_connection=%s\n' "$SHIMMY_PROFILE_DEFAULT_CONNECTION"
    printf 'shimmy_engine_machine_state=%s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE"
    printf 'shimmy_engine_alternate_running_machine=%s\n' "$SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE"
    printf 'shimmy_engine_running_container_count=%s\n' "$SHIMMY_PROFILE_RUNNING_CONTAINER_COUNT"
    printf 'shimmy_engine_connection_override=%s\n' "$SHIMMY_PROFILE_CONNECTION_OVERRIDE"
    printf 'shimmy_engine_machine_metadata=%s\n' "$SHIMMY_PROFILE_MACHINE_METADATA"
    printf 'shimmy_engine_connection_metadata=%s\n' "$SHIMMY_PROFILE_CONNECTION_METADATA"
    printf 'shimmy_engine_reachable=%s\n' "$SHIMMY_PROFILE_ENGINE_REACHABLE"
    printf 'shimmy_engine_activation=%s\n' "$SHIMMY_PROFILE_ACTIVATION_STATE"
    return 0
  fi
  printf 'PROFILE\nName: %s\nRoot: %s\nActive: %s\nControl: %s\n\n' "$shimmy_target_profile_status_name" \
    "$shimmy_target_profile_status_root" "$shimmy_target_profile_status_active" "$shimmy_target_profile_status_source_ref"
  printf 'ENGINE\nTYPE EXPECTED CONNECTION DEFAULT STATE REACHABLE ACTIVATION\n'
  printf '%s %s %s %s %s %s %s\n\n' "$SHIMMY_PROFILE_ENGINE_TYPE" "$SHIMMY_PROFILE_EXPECTED_MACHINE" \
    "$SHIMMY_PROFILE_EXPECTED_CONNECTION" "$SHIMMY_PROFILE_DEFAULT_CONNECTION" \
    "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" "$SHIMMY_PROFILE_ENGINE_REACHABLE" "$SHIMMY_PROFILE_ACTIVATION_STATE"
  printf 'CATALOG\nCATALOG PINNED CURRENT DRIFT HEALTH\n'
  printf '%s %s %s %s ok\n\n' "$shimmy_target_profile_status_catalog_name" "$shimmy_target_profile_status_generation" \
    "$shimmy_target_profile_status_catalog_current" "$shimmy_target_profile_status_catalog_drift"
  printf 'SHIMS\nSHIM DEFAULT MODE VERSIONS\n'
  if [ -z "$shimmy_target_profile_status_shims" ]; then
    printf '%s\n' 'none - - -'
  else
    while IFS='|' read -r shimmy_target_profile_status_shim_name shimmy_target_profile_status_shim_mode shimmy_target_profile_status_shim_extra; do
      [ -n "$shimmy_target_profile_status_shim_name" ] || continue
      [ -z "$shimmy_target_profile_status_shim_extra" ] || return 1
      shimmy_target_profile_status_shim_default=-
      shimmy_target_profile_status_shim_versions=
      while IFS='|' read -r shimmy_target_profile_status_version_tool shimmy_target_profile_status_version_name shimmy_target_profile_status_version_slot shimmy_target_profile_status_version_extra; do
        [ -n "$shimmy_target_profile_status_version_tool" ] || continue
        [ -z "$shimmy_target_profile_status_version_extra" ] || return 1
        [ "$shimmy_target_profile_status_version_tool" = "$shimmy_target_profile_status_shim_name" ] || continue
        if [ -z "$shimmy_target_profile_status_shim_versions" ]; then
          shimmy_target_profile_status_shim_versions=$shimmy_target_profile_status_version_name
        else
          shimmy_target_profile_status_shim_versions=$shimmy_target_profile_status_shim_versions,$shimmy_target_profile_status_version_name
        fi
        [ "$shimmy_target_profile_status_version_slot" != default ] ||
          shimmy_target_profile_status_shim_default=$shimmy_target_profile_status_version_name
      done <<EOF
$shimmy_target_profile_status_versions
EOF
      printf '%s %s %s %s\n' "$shimmy_target_profile_status_shim_name" "$shimmy_target_profile_status_shim_default" \
        "$shimmy_target_profile_status_shim_mode" "$shimmy_target_profile_status_shim_versions"
    done <<EOF
$shimmy_target_profile_status_shims
EOF
  fi
  shimmy_target_profile_status_control_links=$shimmy_target_profile_status_control_link_current/$shimmy_target_profile_status_control_link_expected
  shimmy_target_profile_status_shims_links=$shimmy_target_profile_status_shims_link_current/$shimmy_target_profile_status_shims_link_expected
  [ "$shimmy_target_profile_status_control_link_current" != not-applicable ] || shimmy_target_profile_status_control_links=not-applicable
  [ "$shimmy_target_profile_status_shims_link_current" != not-applicable ] || shimmy_target_profile_status_shims_links=not-applicable
  printf '\nAI SKILLS\nBUNDLE STATUS LINKS REASON\n'
  printf 'control %s %s %s\n' "$shimmy_target_profile_status_control_bundle" \
    "$shimmy_target_profile_status_control_links" \
    "$shimmy_target_profile_status_control_reason"
  printf 'shims %s %s %s\n\n' "$shimmy_target_profile_status_shims_bundle" \
    "$shimmy_target_profile_status_shims_links" \
    "$shimmy_target_profile_status_shims_reason"
  printf 'STARTUP\nShell: %s\nFiles: %s\n' "$shimmy_target_profile_status_startup_shell" "${shimmy_target_profile_status_startup_files:-none}"
}

shimmy_target_profile_redirect_context_resolve() {
  shimmy_target_profile_redirect_config=$1
  shimmy_target_profile_redirect_name=$2
  shimmy_target_profile_installation_context_resolve "$shimmy_target_profile_redirect_config" || return 1
  shimmy_target_profile_candidate_resolve "$shimmy_target_profile_redirect_config" "$shimmy_target_profile_redirect_name" || return 1
  shimmy_target_profile_engine_context_resolve "$shimmy_target_profile_redirect_config" "$shimmy_target_profile_redirect_name"
}

shimmy_target_profile_redirect_mutate() {
  shimmy_target_profile_redirect_mutate_config=$1
  shimmy_target_profile_redirect_mutate_name=$2
  shimmy_target_profile_redirect_mutate_action=$3
  shimmy_target_profile_redirect_mutate_prefix=${4:-}
  shimmy_target_profile_redirect_mutate_location=${5:-}
  shimmy_target_profile_redirect_mutate_detach=${6:-0}
  shimmy_target_profile_redirect_mutate_dry_run=${7:-0}
  shimmy_target_profile_redirect_context_resolve "$shimmy_target_profile_redirect_mutate_config" "$shimmy_target_profile_redirect_mutate_name" || return 1
  [ "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" = "$shimmy_target_profile_redirect_mutate_name" ] ||
    shimmy_target_profile_error_set "profile redirect mutation requires the active invoking profile: $shimmy_target_profile_redirect_mutate_name" || return 1
  if [ "$shimmy_target_profile_redirect_mutate_dry_run" -eq 1 ]; then
    case "$shimmy_target_profile_redirect_mutate_action:$shimmy_target_profile_redirect_mutate_detach" in
      remove_all:1) shimmy_registries_mutate_remove_all_detach 1 ;;
      *) shimmy_registries_mutate "$shimmy_target_profile_redirect_mutate_action" "$shimmy_target_profile_redirect_mutate_prefix" "$shimmy_target_profile_redirect_mutate_location" 1 ;;
    esac
    return $?
  fi
  shimmy_target_profile_locks_acquire "$shimmy_target_profile_redirect_mutate_config" "$shimmy_target_profile_redirect_mutate_name" "$shimmy_target_profile_redirect_mutate_name" || {
    shimmy_target_locks_release_all || true
    return 1
  }
  shimmy_target_profile_redirect_context_resolve "$shimmy_target_profile_redirect_mutate_config" "$shimmy_target_profile_redirect_mutate_name" || {
    shimmy_target_locks_release_all || true
    return 1
  }
  [ "$SHIMMY_TARGET_PROFILE_ACTIVE_NAME" = "$shimmy_target_profile_redirect_mutate_name" ] || {
    shimmy_target_locks_release_all || true
    return 1
  }
  SHIMMY_TARGET_REGISTRY_LOCK_EXTERNAL=1
  case "$shimmy_target_profile_redirect_mutate_action:$shimmy_target_profile_redirect_mutate_detach" in
    remove_all:1) shimmy_registries_mutate_remove_all_detach 0 ;;
    *) shimmy_registries_mutate "$shimmy_target_profile_redirect_mutate_action" "$shimmy_target_profile_redirect_mutate_prefix" "$shimmy_target_profile_redirect_mutate_location" 0 ;;
  esac
  shimmy_target_profile_redirect_mutate_status=$?
  shimmy_target_locks_release_all || return 1
  return "$shimmy_target_profile_redirect_mutate_status"
}
