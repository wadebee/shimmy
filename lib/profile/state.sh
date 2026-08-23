#!/bin/sh
# Canonical installation and profile state for schema-2 profiles.

shimmy_installation_paths_resolve() {
  shimmy_config_root=$1
  shimmy_path_absolute_normalized_validate "$shimmy_config_root" || return 1
  SHIMMY_CONFIG_ROOT=$shimmy_config_root
  SHIMMY_ACTIVE_PROFILE_PATH=$shimmy_config_root/active-profile.conf
  SHIMMY_CATALOG_DEFAULT_ROOT=$shimmy_config_root/catalogs/default
  SHIMMY_PROFILES_ROOT=$shimmy_config_root/profiles
}

shimmy_profile_state_paths_resolve() {
  shimmy_profile_config_root=$1
  shimmy_profile_name=$2
  shimmy_installation_paths_resolve "$shimmy_profile_config_root" || return 1
  shimmy_name_component_validate "$shimmy_profile_name" || return 1
  SHIMMY_PROFILE_NAME=$shimmy_profile_name
  SHIMMY_PROFILE_ROOT=$SHIMMY_PROFILES_ROOT/$shimmy_profile_name
  SHIMMY_PROFILE_MANIFEST_PATH=$SHIMMY_PROFILE_ROOT/install-manifest.txt
  SHIMMY_PROFILE_ENGINE_BINDING_PATH=$SHIMMY_PROFILE_ROOT/engine-binding.conf
  SHIMMY_PROFILE_MACHINE_PROJECTION_PATH=$SHIMMY_PROFILE_ROOT/machine-projection.txt
  SHIMMY_PROFILE_REGISTRIES_PATH=$SHIMMY_PROFILE_ROOT/registries.conf
  SHIMMY_PROFILE_SHELL_INIT_PATH=$SHIMMY_PROFILE_ROOT/shell-init.sh
  SHIMMY_PROFILE_LAUNCHER_PATH=$SHIMMY_PROFILE_ROOT/bin/shimmy
}

shimmy_active_profile_render() {
  shimmy_active_name=$1
  shimmy_active_skill_root=$2
  shimmy_name_component_validate "$shimmy_active_name" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_active_skill_root" || return 1
  printf 'shimmy_active_profile_schema=1\n'
  printf 'shimmy_active_profile_name=%s\n' "$shimmy_active_name"
  printf 'shimmy_active_ai_skill_root=%s\n' "$shimmy_active_skill_root"
}

shimmy_active_profile_read() {
  shimmy_active_file=$1
  shimmy_text_file_validate "$shimmy_active_file" || return 1
  if shimmy_active_mode=$(stat -c '%a' "$shimmy_active_file" 2>/dev/null); then
    :
  else
    shimmy_active_mode=$(stat -f '%Lp' "$shimmy_active_file" 2>/dev/null) || return 1
  fi
  [ "$shimmy_active_mode" = 644 ] || return 1
  [ "$(wc -l < "$shimmy_active_file" | tr -d ' ')" -eq 3 ] || return 1
  SHIMMY_ACTIVE_PROFILE_NAME=$(sed -n '2s/^shimmy_active_profile_name=//p' "$shimmy_active_file")
  SHIMMY_ACTIVE_AI_SKILL_ROOT=$(sed -n '3s/^shimmy_active_ai_skill_root=//p' "$shimmy_active_file")
  [ "$(shimmy_active_profile_render "$SHIMMY_ACTIVE_PROFILE_NAME" "$SHIMMY_ACTIVE_AI_SKILL_ROOT")" = "$(cat "$shimmy_active_file")" ]
}

shimmy_profile_manifest_read() {
  shimmy_profile_manifest_file=$1
  shimmy_text_file_validate "$shimmy_profile_manifest_file" || return 1
  SHIMMY_PROFILE_NAME=
  SHIMMY_PROFILE_SOURCE_URL=
  SHIMMY_PROFILE_SOURCE_TRACKING_REF=
  SHIMMY_PROFILE_SOURCE_REF=
  SHIMMY_PROFILE_CATALOG_RECORD=
  SHIMMY_PROFILE_SHIM_RECORDS=
  SHIMMY_PROFILE_SHIM_VERSION_RECORDS=
  SHIMMY_PROFILE_STARTUP_SHELL=
  SHIMMY_PROFILE_STARTUP_FILES=
  shimmy_profile_manifest_line_number=0
  shimmy_profile_manifest_phase=identity

  while IFS= read -r shimmy_profile_manifest_line || [ -n "$shimmy_profile_manifest_line" ]; do
    shimmy_profile_manifest_line_number=$((shimmy_profile_manifest_line_number + 1))
    case "$shimmy_profile_manifest_line_number" in
      1) [ "$shimmy_profile_manifest_line" = shimmy_install_manifest_version=2 ] || return 1 ;;
      2) [ "$shimmy_profile_manifest_line" = shimmy_install_layout=profile-materialized-root ] || return 1 ;;
      3) [ "$shimmy_profile_manifest_line" = shimmy_profile_manifest_version=2 ] || return 1 ;;
      4) SHIMMY_PROFILE_NAME=${shimmy_profile_manifest_line#shimmy_profile_name=}; [ "$shimmy_profile_manifest_line" = "shimmy_profile_name=$SHIMMY_PROFILE_NAME" ] || return 1 ;;
      5) SHIMMY_PROFILE_SOURCE_URL=${shimmy_profile_manifest_line#shimmy_source_url=}; [ "$shimmy_profile_manifest_line" = "shimmy_source_url=$SHIMMY_PROFILE_SOURCE_URL" ] || return 1 ;;
      6) SHIMMY_PROFILE_SOURCE_TRACKING_REF=${shimmy_profile_manifest_line#shimmy_source_tracking_ref=}; [ "$shimmy_profile_manifest_line" = "shimmy_source_tracking_ref=$SHIMMY_PROFILE_SOURCE_TRACKING_REF" ] || return 1 ;;
      7) SHIMMY_PROFILE_SOURCE_REF=${shimmy_profile_manifest_line#shimmy_source_ref=}; [ "$shimmy_profile_manifest_line" = "shimmy_source_ref=$SHIMMY_PROFILE_SOURCE_REF" ] || return 1 ;;
      *)
        case "$shimmy_profile_manifest_line" in
          catalog=*)
            [ "$shimmy_profile_manifest_phase" = identity ] || return 1
            [ -z "$SHIMMY_PROFILE_CATALOG_RECORD" ] || return 1
            SHIMMY_PROFILE_CATALOG_RECORD=${shimmy_profile_manifest_line#catalog=}
            shimmy_profile_manifest_phase=shim
            ;;
          shim=*)
            case "$shimmy_profile_manifest_phase" in shim) ;; *) return 1 ;; esac
            SHIMMY_PROFILE_SHIM_RECORDS=$(shimmy_append_line_list "$SHIMMY_PROFILE_SHIM_RECORDS" "${shimmy_profile_manifest_line#shim=}")
            ;;
          shim_version=*)
            case "$shimmy_profile_manifest_phase" in shim|shim-version) ;; *) return 1 ;; esac
            shimmy_profile_manifest_phase=shim-version
            SHIMMY_PROFILE_SHIM_VERSION_RECORDS=$(shimmy_append_line_list "$SHIMMY_PROFILE_SHIM_VERSION_RECORDS" "${shimmy_profile_manifest_line#shim_version=}")
            ;;
          startup_shell=*)
            case "$shimmy_profile_manifest_phase" in shim|shim-version) ;; *) return 1 ;; esac
            [ -z "$SHIMMY_PROFILE_STARTUP_SHELL" ] || return 1
            SHIMMY_PROFILE_STARTUP_SHELL=${shimmy_profile_manifest_line#startup_shell=}
            shimmy_profile_manifest_phase=startup
            ;;
          startup_file=*)
            case "$shimmy_profile_manifest_phase" in shim|shim-version|startup|startup-file) ;; *) return 1 ;; esac
            shimmy_profile_manifest_phase=startup-file
            SHIMMY_PROFILE_STARTUP_FILES=$(shimmy_append_line_list "$SHIMMY_PROFILE_STARTUP_FILES" "${shimmy_profile_manifest_line#startup_file=}")
            ;;
          *) return 1 ;;
        esac
        ;;
    esac
  done < "$shimmy_profile_manifest_file"

  [ "$shimmy_profile_manifest_line_number" -ge 8 ] || return 1
  shimmy_name_component_validate "$SHIMMY_PROFILE_NAME" || return 1
  [ -n "$SHIMMY_PROFILE_SOURCE_URL" ] || return 1
  shimmy_scalar_value_validate "$SHIMMY_PROFILE_SOURCE_URL" || return 1
  [ "$SHIMMY_PROFILE_SOURCE_TRACKING_REF" = refs/heads/main ] || return 1
  shimmy_git_commit_validate "$SHIMMY_PROFILE_SOURCE_REF" || return 1
  shimmy_catalog_pin_validate "$SHIMMY_PROFILE_CATALOG_RECORD" || return 1
  shimmy_shim_records_validate "$SHIMMY_PROFILE_SHIM_RECORDS" "$SHIMMY_PROFILE_SHIM_VERSION_RECORDS" || return 1
  if [ -n "$SHIMMY_PROFILE_STARTUP_SHELL" ]; then
    case "$SHIMMY_PROFILE_STARTUP_SHELL" in bash|zsh|sh|ksh|mksh) ;; *) return 1 ;; esac
  fi
  shimmy_line_list_lexical_unique_validate "$SHIMMY_PROFILE_STARTUP_FILES" || return 1
  while IFS= read -r shimmy_profile_startup_file; do
    [ -n "$shimmy_profile_startup_file" ] || continue
    shimmy_path_absolute_normalized_validate "$shimmy_profile_startup_file" || return 1
  done <<EOF
$SHIMMY_PROFILE_STARTUP_FILES
EOF
}

shimmy_profile_state_validate() {
  shimmy_state_manifest=$1
  shimmy_state_registry=$2
  shimmy_state_generation_root=$3
  shimmy_state_control_bundle=$4
  shimmy_state_shims_bundle=$5

  shimmy_profile_manifest_read "$shimmy_state_manifest" || return 1
  shimmy_state_profile_name=$SHIMMY_PROFILE_NAME
  shimmy_state_source_ref=$SHIMMY_PROFILE_SOURCE_REF
  shimmy_state_catalog=$SHIMMY_PROFILE_CATALOG_RECORD
  shimmy_state_shims=$SHIMMY_PROFILE_SHIM_RECORDS
  shimmy_catalog_pin_validate "$shimmy_state_catalog" || return 1
  shimmy_state_generation=$shimmy_catalog_pin_generation
  shimmy_state_catalog_commit=$shimmy_catalog_pin_commit
  shimmy_state_catalog_fingerprint=$shimmy_catalog_pin_fingerprint

  shimmy_catalog_registry_read "$shimmy_state_registry" || return 1
  shimmy_state_registry_dir=$(dirname -- "$shimmy_state_registry")
  [ "$shimmy_state_generation_root" = "$shimmy_state_registry_dir/generations/$shimmy_state_generation" ] || return 1
  shimmy_catalog_generation_metadata_read "$shimmy_state_generation_root/generation.conf" || return 1
  [ "$SHIMMY_CATALOG_GENERATION_SOURCE_COMMIT" = "$shimmy_state_catalog_commit" ] || return 1
  [ "$SHIMMY_CATALOG_GENERATION_CONTENT_FINGERPRINT" = "$shimmy_state_catalog_fingerprint" ] || return 1

  shimmy_ai_skill_bundle_read "$shimmy_state_control_bundle" control "$shimmy_state_profile_name" || return 1
  shimmy_state_control_source_ref=$SHIMMY_AI_SKILL_SOURCE_REF
  shimmy_state_control_skills=$SHIMMY_AI_SKILL_RECORDS
  [ "$shimmy_state_control_source_ref" = "$shimmy_state_source_ref" ] || return 1
  shimmy_state_expected_control_skills=$(shimmy_ai_skill_control_names_render) || return 1
  shimmy_state_actual_control_skills=$(printf '%s\n' "$shimmy_state_control_skills" | sed -n 's/|.*//p')
  [ "$shimmy_state_actual_control_skills" = "$shimmy_state_expected_control_skills" ] || return 1
  shimmy_ai_skill_bundle_read "$shimmy_state_shims_bundle" shims "$shimmy_state_profile_name" || return 1
  shimmy_state_shim_source_ref=$SHIMMY_AI_SKILL_SOURCE_REF
  shimmy_state_shim_skills=$SHIMMY_AI_SKILL_RECORDS
  [ "$shimmy_state_shim_source_ref" = "$shimmy_state_generation/$shimmy_state_catalog_fingerprint" ] || return 1

  shimmy_state_skill_names=
  while IFS= read -r shimmy_state_skill_record; do
    [ -n "$shimmy_state_skill_record" ] || continue
    shimmy_state_skill_name=${shimmy_state_skill_record%%|*}
    shimmy_contains_line_list "$shimmy_state_skill_names" "$shimmy_state_skill_name" && return 1
    shimmy_state_skill_names=$(shimmy_append_line_list "$shimmy_state_skill_names" "$shimmy_state_skill_name")
  done <<EOF
$shimmy_state_control_skills
$shimmy_state_shim_skills
EOF

  shimmy_state_expected_shim_skills=
  while IFS= read -r shimmy_state_shim_record; do
    [ -n "$shimmy_state_shim_record" ] || continue
    shimmy_state_shim_tool=${shimmy_state_shim_record%%|*}
    shimmy_state_expected_shim_skills=$(shimmy_append_line_list "$shimmy_state_expected_shim_skills" "shimmy-tool-$shimmy_state_shim_tool")
  done <<EOF
$shimmy_state_shims
EOF
  shimmy_state_actual_shim_skills=
  while IFS= read -r shimmy_state_skill_record; do
    [ -n "$shimmy_state_skill_record" ] || continue
    shimmy_state_actual_shim_skills=$(shimmy_append_line_list "$shimmy_state_actual_shim_skills" "${shimmy_state_skill_record%%|*}")
  done <<EOF
$shimmy_state_shim_skills
EOF
  [ "$shimmy_state_expected_shim_skills" = "$shimmy_state_actual_shim_skills" ]
}
