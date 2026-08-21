#!/bin/sh
# Canonical profile-local shim lifecycle.

SHIMMY_SHIM_ERROR=
SHIMMY_SHIM_STAGE_ROOT=
SHIMMY_SHIM_BACKUP_ROOT=

shimmy_shim_error_set() {
  SHIMMY_SHIM_ERROR=$*
  return 1
}

shimmy_shim_sorted() {
  [ -z "${1:-}" ] || printf '%s\n' "$1" | LC_ALL=C sort -u
}

shimmy_shim_policy_read() {
  shimmy_shim_policy_tool=$1
  printf '%s\n' "$SHIMMY_SHIM_RECORDS" |
    sed -n "s/^$shimmy_shim_policy_tool|//p" | sed -n '1p'
}

shimmy_shim_default_read() {
  shimmy_shim_default_tool=$1
  while IFS= read -r shimmy_shim_default_record; do
    [ -n "$shimmy_shim_default_record" ] || continue
    shimmy_shim_version_record_validate "$shimmy_shim_default_record" || return 1
    [ "$shimmy_shim_version_tool" = "$shimmy_shim_default_tool" ] || continue
    [ "$shimmy_shim_version_kind" = default ] || continue
    printf '%s\n' "$shimmy_shim_version_name"
    return 0
  done <<EOF
$SHIMMY_SHIM_VERSION_RECORDS
EOF
  return 1
}

shimmy_shim_version_role_read() {
  shimmy_shim_role_tool=$1
  shimmy_shim_role_version=$2
  while IFS= read -r shimmy_shim_role_record; do
    [ -n "$shimmy_shim_role_record" ] || continue
    shimmy_shim_version_record_validate "$shimmy_shim_role_record" || return 1
    [ "$shimmy_shim_version_tool" = "$shimmy_shim_role_tool" ] || continue
    [ "$shimmy_shim_version_name" = "$shimmy_shim_role_version" ] || continue
    printf '%s\n' "$shimmy_shim_version_kind"
    return 0
  done <<EOF
$SHIMMY_SHIM_VERSION_RECORDS
EOF
  return 1
}

shimmy_shim_catalog_version_validate() {
  shimmy_shim_catalog_tool=$1
  shimmy_shim_catalog_version=$2
  shimmy_name_component_validate "$shimmy_shim_catalog_tool" || return 1
  shimmy_version_token_validate "$shimmy_shim_catalog_version" || return 1
  [ -d "$SHIMMY_SHIM_CATALOG_ROOT/tools/$shimmy_shim_catalog_tool/versions/$shimmy_shim_catalog_version" ] &&
    [ ! -L "$SHIMMY_SHIM_CATALOG_ROOT/tools/$shimmy_shim_catalog_tool/versions/$shimmy_shim_catalog_version" ]
}

shimmy_shim_catalog_default_read() {
  shimmy_shim_catalog_default_tool=$1
  shimmy_shim_catalog_default_file=$SHIMMY_SHIM_CATALOG_ROOT/tools/$shimmy_shim_catalog_default_tool/tool.conf
  [ -f "$shimmy_shim_catalog_default_file" ] && [ ! -L "$shimmy_shim_catalog_default_file" ] || return 1
  shimmy_shim_catalog_default=$(shimmy__catalog_config_value_read "$shimmy_shim_catalog_default_file" tool_default_version)
  shimmy_shim_catalog_version_validate "$shimmy_shim_catalog_default_tool" "$shimmy_shim_catalog_default" || return 1
  printf '%s\n' "$shimmy_shim_catalog_default"
}

shimmy_shim_context_resolve() {
  shimmy_shim_context_root=$1
  shimmy_shim_context_profile=$2
  shimmy_name_component_validate "$shimmy_shim_context_profile" || {
    shimmy_shim_error_set "invalid invoking profile: $shimmy_shim_context_profile"
    return 1
  }
  shimmy_catalog_tree_validate "$shimmy_shim_context_root" || {
    shimmy_shim_error_set "$SHIMMY_CATALOG_AUTHORITY_ERROR"
    return 1
  }
  shimmy_installation_paths_resolve "$shimmy_shim_context_root" || return 1
  shimmy_active_profile_read "$SHIMMY_ACTIVE_PROFILE_PATH" || {
    shimmy_shim_error_set 'shim lifecycle requires a valid active profile record'
    return 1
  }
  shimmy_shim_active_name=$SHIMMY_ACTIVE_PROFILE_NAME
  shimmy_profile_state_paths_resolve "$shimmy_shim_context_root" "$shimmy_shim_context_profile" || return 1
  [ -d "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_PROFILE_ROOT" || {
      shimmy_shim_error_set "unsafe invoking profile root: $SHIMMY_PROFILE_ROOT"
      return 1
    }
  shimmy_profile_manifest_read "$SHIMMY_PROFILE_MANIFEST_PATH" || {
    shimmy_shim_error_set "invalid profile manifest: $SHIMMY_PROFILE_MANIFEST_PATH"
    return 1
  }
  [ "$SHIMMY_PROFILE_NAME" = "$shimmy_shim_context_profile" ] || return 1

  SHIMMY_SHIM_ACTIVE_NAME=$shimmy_shim_active_name
  SHIMMY_SHIM_IS_ACTIVE=0
  [ "$shimmy_shim_context_profile" != "$shimmy_shim_active_name" ] ||
    SHIMMY_SHIM_IS_ACTIVE=1
  SHIMMY_SHIM_PROFILE_NAME=$SHIMMY_PROFILE_NAME
  SHIMMY_SHIM_PROFILE_ROOT=$SHIMMY_PROFILE_ROOT
  SHIMMY_SHIM_MANIFEST_PATH=$SHIMMY_PROFILE_MANIFEST_PATH
  SHIMMY_SHIM_SOURCE_URL=$SHIMMY_PROFILE_SOURCE_URL
  SHIMMY_SHIM_SOURCE_REF=$SHIMMY_PROFILE_SOURCE_REF
  SHIMMY_SHIM_CATALOG_RECORD=$SHIMMY_PROFILE_CATALOG_RECORD
  SHIMMY_SHIM_RECORDS=$SHIMMY_PROFILE_SHIM_RECORDS
  SHIMMY_SHIM_VERSION_RECORDS=$SHIMMY_PROFILE_SHIM_VERSION_RECORDS
  SHIMMY_SHIM_STARTUP_SHELL=$SHIMMY_PROFILE_STARTUP_SHELL
  SHIMMY_SHIM_STARTUP_FILES=$SHIMMY_PROFILE_STARTUP_FILES
  SHIMMY_SHIM_MANIFEST_FINGERPRINT=$(shimmy_sha256_fingerprint_file_render "$SHIMMY_SHIM_MANIFEST_PATH") || return 1

  shimmy_catalog_pin_validate "$SHIMMY_SHIM_CATALOG_RECORD" || return 1
  SHIMMY_SHIM_CATALOG_GENERATION=$shimmy_catalog_pin_generation
  SHIMMY_SHIM_CATALOG_COMMIT=$shimmy_catalog_pin_commit
  SHIMMY_SHIM_CATALOG_FINGERPRINT=$shimmy_catalog_pin_fingerprint
  SHIMMY_SHIM_CATALOG_ROOT=$SHIMMY_CATALOG_GENERATIONS_ROOT/$SHIMMY_SHIM_CATALOG_GENERATION
  shimmy_catalog_generation_record_validate "$SHIMMY_SHIM_CATALOG_ROOT" "$SHIMMY_SHIM_CATALOG_GENERATION" || return 1
  [ "$SHIMMY_CATALOG_VALIDATED_GENERATION_COMMIT" = "$SHIMMY_SHIM_CATALOG_COMMIT" ] &&
    [ "$SHIMMY_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$SHIMMY_SHIM_CATALOG_FINGERPRINT" ] || {
      shimmy_shim_error_set 'profile pin does not match its retained catalog generation'
      return 1
    }
}

shimmy_shim_bundle_input_render() {
  shimmy_shim_bundle_profile=$1
  shimmy_shim_bundle_generation=$2
  shimmy_shim_bundle_fingerprint=$3
  shimmy_shim_bundle_records=${4:-}
  shimmy_name_component_validate "$shimmy_shim_bundle_profile" || return 1
  shimmy_catalog_generation_validate "$shimmy_shim_bundle_generation" || return 1
  shimmy_sha256_fingerprint_validate "$shimmy_shim_bundle_fingerprint" || return 1
  [ "$(shimmy_catalog_generation_render "$shimmy_shim_bundle_fingerprint")" = "$shimmy_shim_bundle_generation" ] || return 1
  shimmy_line_list_lexical_unique_validate "$shimmy_shim_bundle_records" || return 1
  printf 'shimmy_shim_bundle_input_schema=1\n'
  printf 'shimmy_profile_name=%s\n' "$shimmy_shim_bundle_profile"
  printf 'shimmy_catalog_generation=%s\n' "$shimmy_shim_bundle_generation"
  printf 'shimmy_catalog_content_fingerprint=%s\n' "$shimmy_shim_bundle_fingerprint"
  while IFS= read -r shimmy_shim_bundle_record; do
    [ -n "$shimmy_shim_bundle_record" ] || continue
    shimmy_shim_record_validate "$shimmy_shim_bundle_record" || return 1
    printf 'shim=%s\n' "${shimmy_shim_bundle_record%%|*}"
  done <<EOF
$shimmy_shim_bundle_records
EOF
}

shimmy_shim_bundle_input_validate() {
  shimmy_shim_bundle_file=$1
  shimmy_text_file_validate "$shimmy_shim_bundle_file" || return 1
  shimmy_shim_bundle_profile=$(sed -n '2s/^shimmy_profile_name=//p' "$shimmy_shim_bundle_file")
  shimmy_shim_bundle_generation=$(sed -n '3s/^shimmy_catalog_generation=//p' "$shimmy_shim_bundle_file")
  shimmy_shim_bundle_fingerprint=$(sed -n '4s/^shimmy_catalog_content_fingerprint=//p' "$shimmy_shim_bundle_file")
  shimmy_shim_bundle_tools=$(sed -n '5,$s/^shim=//p' "$shimmy_shim_bundle_file")
  shimmy_shim_bundle_records=
  while IFS= read -r shimmy_shim_bundle_tool; do
    [ -n "$shimmy_shim_bundle_tool" ] || continue
    shimmy_name_component_validate "$shimmy_shim_bundle_tool" || return 1
    shimmy_shim_bundle_records=$(shimmy_append_line_list "$shimmy_shim_bundle_records" "$shimmy_shim_bundle_tool|tracking")
  done <<EOF
$shimmy_shim_bundle_tools
EOF
  shimmy_shim_bundle_records=$(shimmy_shim_sorted "$shimmy_shim_bundle_records")
  shimmy_shim_bundle_expected=$(shimmy_shim_bundle_input_render \
    "$shimmy_shim_bundle_profile" "$shimmy_shim_bundle_generation" \
    "$shimmy_shim_bundle_fingerprint" "$shimmy_shim_bundle_records") || return 1
  [ "$shimmy_shim_bundle_expected" = "$(cat "$shimmy_shim_bundle_file")" ]
}

shimmy_shim_wrapper_render() {
  shimmy_shim_wrapper_tool=$1
  shimmy_shim_wrapper_version=$2
  shimmy_name_component_validate "$shimmy_shim_wrapper_tool" || return 1
  shimmy_version_token_validate "$shimmy_shim_wrapper_version" || return 1
  cat <<EOF
#!/bin/sh
set -eu
shimmy_wrapper_dir=\$(cd -- "\$(dirname -- "\$0")" && pwd -P)
shimmy_wrapper_profile_root=\$(cd -- "\$shimmy_wrapper_dir/.." && pwd -P)
exec "\$shimmy_wrapper_profile_root/tools/$shimmy_shim_wrapper_tool/versions/$shimmy_shim_wrapper_version/run.sh" "\$@"
EOF
}

shimmy_shim_config_render() {
  shimmy_shim_config_tool=$1
  shimmy_shim_config_default=$2
  shimmy_shim_config_mode=$3
  shimmy_name_component_validate "$shimmy_shim_config_tool" || return 1
  shimmy_version_token_validate "$shimmy_shim_config_default" || return 1
  case "$shimmy_shim_config_mode" in tracking|pinned) ;; *) return 1 ;; esac
  printf 'shimmy_shim_config_schema=1\n'
  printf 'shim=%s\n' "$shimmy_shim_config_tool"
  printf 'default_version=%s\n' "$shimmy_shim_config_default"
  printf 'update_policy=%s\n' "$shimmy_shim_config_mode"
}

shimmy_shim_tool_config_render() {
  shimmy_shim_tool_source=$1
  shimmy_shim_tool_default=$2
  shimmy_version_token_validate "$shimmy_shim_tool_default" || return 1
  awk -v configured_default="$shimmy_shim_tool_default" '
    /^tool_default_version=/ { print "tool_default_version=" configured_default; found++; next }
    { print }
    END { if (found != 1) exit 1 }
  ' "$shimmy_shim_tool_source"
}

shimmy_shim_expected_tool_names() {
  printf '%s\n' "$1" | sed -n 's/|.*//p'
}

shimmy_shim_directory_names() {
  shimmy_shim_names_root=$1
  [ -d "$shimmy_shim_names_root" ] && [ ! -L "$shimmy_shim_names_root" ] || return 1
  shimmy_shim_names=
  for shimmy_shim_names_entry in "$shimmy_shim_names_root"/*; do
    [ -e "$shimmy_shim_names_entry" ] || [ -L "$shimmy_shim_names_entry" ] || continue
    [ -d "$shimmy_shim_names_entry" ] && [ ! -L "$shimmy_shim_names_entry" ] || return 1
    shimmy_shim_names=$(shimmy_append_line_list "$shimmy_shim_names" "$(basename -- "$shimmy_shim_names_entry")")
  done
  shimmy_shim_sorted "$shimmy_shim_names"
}

shimmy_shim_file_names() {
  shimmy_shim_file_names_root=$1
  [ -d "$shimmy_shim_file_names_root" ] && [ ! -L "$shimmy_shim_file_names_root" ] || return 1
  shimmy_shim_file_names_value=
  for shimmy_shim_file_names_entry in "$shimmy_shim_file_names_root"/*; do
    [ -e "$shimmy_shim_file_names_entry" ] || [ -L "$shimmy_shim_file_names_entry" ] || continue
    [ -f "$shimmy_shim_file_names_entry" ] && [ ! -L "$shimmy_shim_file_names_entry" ] || return 1
    shimmy_shim_file_names_value=$(shimmy_append_line_list "$shimmy_shim_file_names_value" "$(basename -- "$shimmy_shim_file_names_entry")")
  done
  shimmy_shim_sorted "$shimmy_shim_file_names_value"
}

shimmy_shim_materialization_validate() {
  shimmy_shim_validate_root=$1
  shimmy_shim_validate_catalog=$2
  shimmy_profile_manifest_read "$shimmy_shim_validate_root/install-manifest.txt" || return 1
  shimmy_shim_validate_profile=$SHIMMY_PROFILE_NAME
  shimmy_shim_validate_catalog_record=$SHIMMY_PROFILE_CATALOG_RECORD
  shimmy_shim_validate_records=$SHIMMY_PROFILE_SHIM_RECORDS
  shimmy_shim_validate_versions=$SHIMMY_PROFILE_SHIM_VERSION_RECORDS
  shimmy_catalog_pin_validate "$shimmy_shim_validate_catalog_record" || return 1
  shimmy_shim_validate_generation=$shimmy_catalog_pin_generation
  shimmy_shim_validate_fingerprint=$shimmy_catalog_pin_fingerprint
  [ "$shimmy_shim_validate_catalog" = "$(dirname -- "$(dirname -- "$shimmy_shim_validate_catalog")")/generations/$shimmy_shim_validate_generation" ] || return 1
  [ -d "$shimmy_shim_validate_root/bin" ] && [ ! -L "$shimmy_shim_validate_root/bin" ] || return 1
  [ -d "$shimmy_shim_validate_root/tools" ] && [ ! -L "$shimmy_shim_validate_root/tools" ] || return 1
  [ -d "$shimmy_shim_validate_root/config/shims" ] && [ ! -L "$shimmy_shim_validate_root/config/shims" ] || return 1
  shimmy_shim_validate_expected_tools=$(shimmy_shim_expected_tool_names "$shimmy_shim_validate_records")
  [ "$(shimmy_shim_directory_names "$shimmy_shim_validate_root/tools")" = "$shimmy_shim_validate_expected_tools" ] || return 1
  [ "$(shimmy_shim_directory_names "$shimmy_shim_validate_root/config/shims")" = "$shimmy_shim_validate_expected_tools" ] || return 1

  while IFS= read -r shimmy_shim_validate_record; do
    [ -n "$shimmy_shim_validate_record" ] || continue
    shimmy_shim_record_validate "$shimmy_shim_validate_record" || return 1
    shimmy_shim_validate_tool=$shimmy_shim_record_tool
    shimmy_shim_validate_mode=$shimmy_shim_record_mode
    SHIMMY_SHIM_VERSION_RECORDS=$shimmy_shim_validate_versions
    shimmy_shim_validate_default=$(shimmy_shim_default_read "$shimmy_shim_validate_tool") || return 1
    shimmy_shim_validate_wrapper=$shimmy_shim_validate_root/bin/$shimmy_shim_validate_tool
    [ -f "$shimmy_shim_validate_wrapper" ] && [ ! -L "$shimmy_shim_validate_wrapper" ] && [ -x "$shimmy_shim_validate_wrapper" ] || return 1
    [ "$(shimmy_shim_wrapper_render "$shimmy_shim_validate_tool" "$shimmy_shim_validate_default")" = "$(cat "$shimmy_shim_validate_wrapper")" ] || return 1
    shimmy_shim_validate_config=$shimmy_shim_validate_root/config/shims/$shimmy_shim_validate_tool/shim.conf
    [ "$(shimmy_shim_config_render "$shimmy_shim_validate_tool" "$shimmy_shim_validate_default" "$shimmy_shim_validate_mode")" = "$(cat "$shimmy_shim_validate_config")" ] || return 1
    shimmy_shim_validate_tool_source=$shimmy_shim_validate_catalog/tools/$shimmy_shim_validate_tool/tool.conf
    shimmy_shim_validate_tool_target=$shimmy_shim_validate_root/tools/$shimmy_shim_validate_tool/tool.conf
    [ "$(shimmy_shim_tool_config_render "$shimmy_shim_validate_tool_source" "$shimmy_shim_validate_default")" = "$(cat "$shimmy_shim_validate_tool_target")" ] || return 1
    for shimmy_shim_validate_tool_entry in "$shimmy_shim_validate_root/tools/$shimmy_shim_validate_tool"/*; do
      [ -e "$shimmy_shim_validate_tool_entry" ] || [ -L "$shimmy_shim_validate_tool_entry" ] || continue
      case "$shimmy_shim_validate_tool_entry" in
        "$shimmy_shim_validate_tool_target") [ -f "$shimmy_shim_validate_tool_entry" ] && [ ! -L "$shimmy_shim_validate_tool_entry" ] || return 1 ;;
        "$shimmy_shim_validate_root/tools/$shimmy_shim_validate_tool/versions") [ -d "$shimmy_shim_validate_tool_entry" ] && [ ! -L "$shimmy_shim_validate_tool_entry" ] || return 1 ;;
        *) return 1 ;;
      esac
    done
    shimmy_shim_validate_expected_versions=
    shimmy_shim_validate_expected_configs=shim.conf
    while IFS= read -r shimmy_shim_validate_version_record; do
      [ -n "$shimmy_shim_validate_version_record" ] || continue
      shimmy_shim_version_record_validate "$shimmy_shim_validate_version_record" || return 1
      [ "$shimmy_shim_version_tool" = "$shimmy_shim_validate_tool" ] || continue
      shimmy_shim_validate_version=$shimmy_shim_version_name
      shimmy_shim_validate_expected_versions=$(shimmy_append_line_list "$shimmy_shim_validate_expected_versions" "$shimmy_shim_validate_version")
      shimmy_shim_validate_expected_configs=$(shimmy_append_line_list "$shimmy_shim_validate_expected_configs" "$shimmy_shim_validate_version.conf")
      diff -r "$shimmy_shim_validate_catalog/tools/$shimmy_shim_validate_tool/versions/$shimmy_shim_validate_version" \
        "$shimmy_shim_validate_root/tools/$shimmy_shim_validate_tool/versions/$shimmy_shim_validate_version" >/dev/null || return 1
      cmp -s "$shimmy_shim_validate_catalog/tools/$shimmy_shim_validate_tool/versions/$shimmy_shim_validate_version/smoke.conf" \
        "$shimmy_shim_validate_root/config/shims/$shimmy_shim_validate_tool/$shimmy_shim_validate_version.conf" || return 1
    done <<EOF
$shimmy_shim_validate_versions
EOF
    shimmy_shim_validate_expected_versions=$(shimmy_shim_sorted "$shimmy_shim_validate_expected_versions")
    shimmy_shim_validate_expected_configs=$(shimmy_shim_sorted "$shimmy_shim_validate_expected_configs")
    [ "$(shimmy_shim_directory_names "$shimmy_shim_validate_root/tools/$shimmy_shim_validate_tool/versions")" = "$shimmy_shim_validate_expected_versions" ] || return 1
    [ "$(shimmy_shim_file_names "$shimmy_shim_validate_root/config/shims/$shimmy_shim_validate_tool")" = "$shimmy_shim_validate_expected_configs" ] || return 1
  done <<EOF
$shimmy_shim_validate_records
EOF

  shimmy_shim_validate_input=$shimmy_shim_validate_root/config/shim-bundle-input.conf
  shimmy_shim_bundle_input_validate "$shimmy_shim_validate_input" || return 1
  [ "$shimmy_shim_bundle_profile" = "$shimmy_shim_validate_profile" ] &&
    [ "$shimmy_shim_bundle_generation" = "$shimmy_shim_validate_generation" ] &&
    [ "$shimmy_shim_bundle_fingerprint" = "$shimmy_shim_validate_fingerprint" ] &&
    [ "$shimmy_shim_bundle_tools" = "$shimmy_shim_validate_expected_tools" ]
}

shimmy_shim_stage_cleanup() {
  if [ -n "$SHIMMY_SHIM_STAGE_ROOT" ]; then
    case "$SHIMMY_SHIM_STAGE_ROOT" in
      "$SHIMMY_PROFILES_ROOT"/.*.shim-candidate.*)
        [ ! -e "$SHIMMY_SHIM_STAGE_ROOT" ] && [ ! -L "$SHIMMY_SHIM_STAGE_ROOT" ] || rm -rf "$SHIMMY_SHIM_STAGE_ROOT"
        ;;
      *) return 1 ;;
    esac
  fi
  SHIMMY_SHIM_STAGE_ROOT=
}

shimmy_shim_candidate_prepare() {
  SHIMMY_SHIM_CANDIDATE_RECORDS=$(shimmy_shim_sorted "$1") || return 1
  SHIMMY_SHIM_CANDIDATE_VERSIONS=$(shimmy_shim_sorted "$2") || return 1
  shimmy_shim_records_validate "$SHIMMY_SHIM_CANDIDATE_RECORDS" "$SHIMMY_SHIM_CANDIDATE_VERSIONS" || return 1
  SHIMMY_SHIM_STAGE_ROOT=$SHIMMY_PROFILES_ROOT/.$SHIMMY_SHIM_PROFILE_NAME.shim-candidate.$$
  [ ! -e "$SHIMMY_SHIM_STAGE_ROOT" ] && [ ! -L "$SHIMMY_SHIM_STAGE_ROOT" ] || return 1
  cp -R "$SHIMMY_SHIM_PROFILE_ROOT" "$SHIMMY_SHIM_STAGE_ROOT" || return 1
  rm -rf "$SHIMMY_SHIM_STAGE_ROOT/tools" "$SHIMMY_SHIM_STAGE_ROOT/config/shims"
  mkdir -p "$SHIMMY_SHIM_STAGE_ROOT/tools" "$SHIMMY_SHIM_STAGE_ROOT/config/shims" "$SHIMMY_SHIM_STAGE_ROOT/bin"
  while IFS= read -r shimmy_shim_old_record; do
    [ -n "$shimmy_shim_old_record" ] || continue
    rm -f "$SHIMMY_SHIM_STAGE_ROOT/bin/${shimmy_shim_old_record%%|*}"
  done <<EOF
$SHIMMY_SHIM_RECORDS
EOF

  while IFS= read -r shimmy_shim_candidate_record; do
    [ -n "$shimmy_shim_candidate_record" ] || continue
    shimmy_shim_record_validate "$shimmy_shim_candidate_record" || return 1
    shimmy_shim_candidate_tool=$shimmy_shim_record_tool
    shimmy_shim_candidate_mode=$shimmy_shim_record_mode
    SHIMMY_SHIM_VERSION_RECORDS=$SHIMMY_SHIM_CANDIDATE_VERSIONS
    shimmy_shim_candidate_default=$(shimmy_shim_default_read "$shimmy_shim_candidate_tool") || return 1
    shimmy_shim_candidate_source=$SHIMMY_SHIM_CATALOG_ROOT/tools/$shimmy_shim_candidate_tool
    shimmy_shim_candidate_target=$SHIMMY_SHIM_STAGE_ROOT/tools/$shimmy_shim_candidate_tool
    mkdir -p "$shimmy_shim_candidate_target/versions" "$SHIMMY_SHIM_STAGE_ROOT/config/shims/$shimmy_shim_candidate_tool"
    shimmy_shim_tool_config_render "$shimmy_shim_candidate_source/tool.conf" "$shimmy_shim_candidate_default" > "$shimmy_shim_candidate_target/tool.conf" || return 1
    chmod 0644 "$shimmy_shim_candidate_target/tool.conf"
    shimmy_shim_config_render "$shimmy_shim_candidate_tool" "$shimmy_shim_candidate_default" "$shimmy_shim_candidate_mode" > "$SHIMMY_SHIM_STAGE_ROOT/config/shims/$shimmy_shim_candidate_tool/shim.conf" || return 1
    chmod 0644 "$SHIMMY_SHIM_STAGE_ROOT/config/shims/$shimmy_shim_candidate_tool/shim.conf"
    while IFS= read -r shimmy_shim_candidate_version_record; do
      [ -n "$shimmy_shim_candidate_version_record" ] || continue
      shimmy_shim_version_record_validate "$shimmy_shim_candidate_version_record" || return 1
      [ "$shimmy_shim_version_tool" = "$shimmy_shim_candidate_tool" ] || continue
      shimmy_shim_candidate_version=$shimmy_shim_version_name
      cp -R "$shimmy_shim_candidate_source/versions/$shimmy_shim_candidate_version" \
        "$shimmy_shim_candidate_target/versions/$shimmy_shim_candidate_version" || return 1
      cp "$shimmy_shim_candidate_source/versions/$shimmy_shim_candidate_version/smoke.conf" \
        "$SHIMMY_SHIM_STAGE_ROOT/config/shims/$shimmy_shim_candidate_tool/$shimmy_shim_candidate_version.conf" || return 1
      chmod 0644 "$SHIMMY_SHIM_STAGE_ROOT/config/shims/$shimmy_shim_candidate_tool/$shimmy_shim_candidate_version.conf"
    done <<EOF
$SHIMMY_SHIM_CANDIDATE_VERSIONS
EOF
    shimmy_shim_wrapper_render "$shimmy_shim_candidate_tool" "$shimmy_shim_candidate_default" > "$SHIMMY_SHIM_STAGE_ROOT/bin/$shimmy_shim_candidate_tool" || return 1
    chmod 0755 "$SHIMMY_SHIM_STAGE_ROOT/bin/$shimmy_shim_candidate_tool"
  done <<EOF
$SHIMMY_SHIM_CANDIDATE_RECORDS
EOF

  shimmy_shim_bundle_input_render "$SHIMMY_SHIM_PROFILE_NAME" "$SHIMMY_SHIM_CATALOG_GENERATION" \
    "$SHIMMY_SHIM_CATALOG_FINGERPRINT" "$SHIMMY_SHIM_CANDIDATE_RECORDS" > "$SHIMMY_SHIM_STAGE_ROOT/config/shim-bundle-input.conf" || return 1
  chmod 0644 "$SHIMMY_SHIM_STAGE_ROOT/config/shim-bundle-input.conf"
  [ -d "$SHIMMY_SHIM_STAGE_ROOT/ai-skills" ] && [ ! -L "$SHIMMY_SHIM_STAGE_ROOT/ai-skills" ] || return 1
  if [ -e "$SHIMMY_SHIM_STAGE_ROOT/ai-skills/shims" ] || [ -L "$SHIMMY_SHIM_STAGE_ROOT/ai-skills/shims" ]; then
    [ -d "$SHIMMY_SHIM_STAGE_ROOT/ai-skills/shims" ] && [ ! -L "$SHIMMY_SHIM_STAGE_ROOT/ai-skills/shims" ] || return 1
    rm -rf "$SHIMMY_SHIM_STAGE_ROOT/ai-skills/shims" || return 1
  fi
  shimmy_ai_skill_shims_bundle_materialize \
    "$SHIMMY_SHIM_STAGE_ROOT/config/shim-bundle-input.conf" \
    "$SHIMMY_SHIM_CATALOG_ROOT" "$SHIMMY_SHIM_STAGE_ROOT/ai-skills/shims" || return 1
  shimmy_profile_manifest_render "$SHIMMY_SHIM_PROFILE_NAME" "$SHIMMY_SHIM_SOURCE_URL" \
    "$SHIMMY_SHIM_SOURCE_REF" "$SHIMMY_SHIM_CATALOG_RECORD" \
    "$SHIMMY_SHIM_CANDIDATE_RECORDS" "$SHIMMY_SHIM_CANDIDATE_VERSIONS" \
    "$SHIMMY_SHIM_STARTUP_SHELL" "$SHIMMY_SHIM_STARTUP_FILES" > "$SHIMMY_SHIM_STAGE_ROOT/install-manifest.txt" || return 1
  chmod 0644 "$SHIMMY_SHIM_STAGE_ROOT/install-manifest.txt"
  shimmy_shim_materialization_validate "$SHIMMY_SHIM_STAGE_ROOT" "$SHIMMY_SHIM_CATALOG_ROOT" || return 1
  shimmy_profile_state_validate "$SHIMMY_SHIM_STAGE_ROOT/install-manifest.txt" \
    "$SHIMMY_CATALOG_REGISTRY_PATH" "$SHIMMY_SHIM_CATALOG_ROOT" \
    "$SHIMMY_SHIM_STAGE_ROOT/ai-skills/control" "$SHIMMY_SHIM_STAGE_ROOT/ai-skills/shims"
}

shimmy_shim_images_prepare() {
  shimmy_shim_prepare_pairs=${1:-}
  while IFS= read -r shimmy_shim_prepare_pair; do
    [ -n "$shimmy_shim_prepare_pair" ] || continue
    shimmy_shim_prepare_tool=${shimmy_shim_prepare_pair%%|*}
    shimmy_shim_prepare_version=${shimmy_shim_prepare_pair#*|}
    shimmy_shim_catalog_version_validate "$shimmy_shim_prepare_tool" "$shimmy_shim_prepare_version" || return 1
    shimmy_shim_prepare_version_root=$SHIMMY_SHIM_STAGE_ROOT/tools/$shimmy_shim_prepare_tool/versions/$shimmy_shim_prepare_version
    shimmy_shim_prepare_source=$(shimmy__catalog_config_value_read "$shimmy_shim_prepare_version_root/image.conf" image_source)
    case "$shimmy_shim_prepare_source" in external) shimmy_shim_prepare_action=pull ;; local-build) shimmy_shim_prepare_action=build ;; *) return 1 ;; esac
    [ -x "$shimmy_shim_prepare_version_root/refresh.sh" ] || return 1
    "$shimmy_shim_prepare_version_root/refresh.sh" "$shimmy_shim_prepare_action" || {
      shimmy_shim_error_set "image preparation failed for $shimmy_shim_prepare_tool@$shimmy_shim_prepare_version"
      return 1
    }
  done <<EOF
$shimmy_shim_prepare_pairs
EOF
  shimmy_shim_materialization_validate "$SHIMMY_SHIM_STAGE_ROOT" "$SHIMMY_SHIM_CATALOG_ROOT"
}

shimmy_shim_commit_restore() {
  [ -n "$SHIMMY_SHIM_BACKUP_ROOT" ] || return 0
  for shimmy_shim_restore_path in bin tools config/shims config/shim-bundle-input.conf ai-skills/shims install-manifest.txt; do
    shimmy_shim_restore_target=$SHIMMY_SHIM_PROFILE_ROOT/$shimmy_shim_restore_path
    shimmy_shim_restore_backup=$SHIMMY_SHIM_BACKUP_ROOT/$shimmy_shim_restore_path
    if [ -e "$shimmy_shim_restore_target" ] || [ -L "$shimmy_shim_restore_target" ]; then
      if [ -d "$shimmy_shim_restore_target" ] && [ ! -L "$shimmy_shim_restore_target" ]; then rm -rf "$shimmy_shim_restore_target"; else rm -f "$shimmy_shim_restore_target"; fi
    fi
    if [ -e "$shimmy_shim_restore_backup" ] || [ -L "$shimmy_shim_restore_backup" ]; then
      mkdir -p "$(dirname -- "$shimmy_shim_restore_target")"
      mv "$shimmy_shim_restore_backup" "$shimmy_shim_restore_target" || return 1
    fi
  done
  rm -rf "$SHIMMY_SHIM_BACKUP_ROOT"
  SHIMMY_SHIM_BACKUP_ROOT=
}

shimmy_shim_authority_revalidate() {
  shimmy_active_profile_read "$SHIMMY_ACTIVE_PROFILE_PATH" &&
    [ "$SHIMMY_ACTIVE_PROFILE_NAME" = "$SHIMMY_SHIM_PROFILE_NAME" ] || return 1
  [ -f "$SHIMMY_SHIM_MANIFEST_PATH" ] && [ ! -L "$SHIMMY_SHIM_MANIFEST_PATH" ] &&
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_SHIM_MANIFEST_PATH")" = "$SHIMMY_SHIM_MANIFEST_FINGERPRINT" ] || return 1
  shimmy_catalog_generation_record_validate "$SHIMMY_SHIM_CATALOG_ROOT" "$SHIMMY_SHIM_CATALOG_GENERATION" || return 1
  [ "$SHIMMY_CATALOG_VALIDATED_GENERATION_COMMIT" = "$SHIMMY_SHIM_CATALOG_COMMIT" ] &&
    [ "$SHIMMY_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$SHIMMY_SHIM_CATALOG_FINGERPRINT" ]
}

shimmy_shim_candidate_commit() {
  shimmy_lock_acquire activation "$SHIMMY_CONFIG_ROOT" || {
    shimmy_shim_error_set "$SHIMMY_LOCK_ERROR"
    return 1
  }
  shimmy_lock_acquire profile "$SHIMMY_CONFIG_ROOT" "$SHIMMY_SHIM_PROFILE_NAME" || {
    shimmy_shim_error_set "$SHIMMY_LOCK_ERROR"
    return 1
  }
  shimmy_shim_authority_revalidate || {
    shimmy_shim_error_set 'shim authority changed during staging'
    return 1
  }
  if [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] && [ "${SHIMMY_TEST_SHIM_FAILURE:-}" = before-commit ]; then
    shimmy_shim_error_set 'injected shim failure before commit'
    return 1
  fi
  SHIMMY_SHIM_BACKUP_ROOT=$SHIMMY_SHIM_PROFILE_ROOT/.shim-backup.$$
  [ ! -e "$SHIMMY_SHIM_BACKUP_ROOT" ] && [ ! -L "$SHIMMY_SHIM_BACKUP_ROOT" ] || return 1
  mkdir -p "$SHIMMY_SHIM_BACKUP_ROOT/config"
  for shimmy_shim_commit_path in bin tools config/shims config/shim-bundle-input.conf ai-skills/shims install-manifest.txt; do
    shimmy_shim_commit_source=$SHIMMY_SHIM_PROFILE_ROOT/$shimmy_shim_commit_path
    shimmy_shim_commit_backup=$SHIMMY_SHIM_BACKUP_ROOT/$shimmy_shim_commit_path
    if [ -e "$shimmy_shim_commit_source" ] || [ -L "$shimmy_shim_commit_source" ]; then
      mkdir -p "$(dirname -- "$shimmy_shim_commit_backup")"
      mv "$shimmy_shim_commit_source" "$shimmy_shim_commit_backup" || { shimmy_shim_commit_restore; return 1; }
    fi
  done
  for shimmy_shim_commit_path in bin tools config/shims config/shim-bundle-input.conf ai-skills/shims; do
    shimmy_shim_commit_source=$SHIMMY_SHIM_STAGE_ROOT/$shimmy_shim_commit_path
    shimmy_shim_commit_target=$SHIMMY_SHIM_PROFILE_ROOT/$shimmy_shim_commit_path
    mkdir -p "$(dirname -- "$shimmy_shim_commit_target")"
    mv "$shimmy_shim_commit_source" "$shimmy_shim_commit_target" || { shimmy_shim_commit_restore; return 1; }
  done
  if [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] && [ "${SHIMMY_TEST_SHIM_FAILURE:-}" = after-assets ]; then
    shimmy_shim_commit_restore || true
    shimmy_shim_error_set 'injected shim failure after asset replacement'
    return 1
  fi
  mv "$SHIMMY_SHIM_STAGE_ROOT/install-manifest.txt" "$SHIMMY_SHIM_MANIFEST_PATH" || { shimmy_shim_commit_restore; return 1; }
  if ! shimmy_shim_materialization_validate "$SHIMMY_SHIM_PROFILE_ROOT" "$SHIMMY_SHIM_CATALOG_ROOT" ||
    ! shimmy_profile_state_validate "$SHIMMY_SHIM_MANIFEST_PATH" \
      "$SHIMMY_CATALOG_REGISTRY_PATH" "$SHIMMY_SHIM_CATALOG_ROOT" \
      "$SHIMMY_SHIM_PROFILE_ROOT/ai-skills/control" "$SHIMMY_SHIM_PROFILE_ROOT/ai-skills/shims"; then
    shimmy_shim_commit_restore || true
    shimmy_shim_error_set 'committed shim materialization failed validation'
    return 1
  fi
}

shimmy_shim_commit_finalize() {
  [ -n "$SHIMMY_SHIM_BACKUP_ROOT" ] || return 1
  rm -rf "$SHIMMY_SHIM_BACKUP_ROOT"
  SHIMMY_SHIM_BACKUP_ROOT=
  shimmy_locks_release_all || return 1
  shimmy_shim_stage_cleanup
}

shimmy_shim_mutation_apply() {
  shimmy_shim_new_records=$1
  shimmy_shim_new_versions=$2
  shimmy_shim_prepare_pairs=${3:-}
  shimmy_shim_candidate_prepare "$shimmy_shim_new_records" "$shimmy_shim_new_versions" || return 1
  shimmy_shim_images_prepare "$shimmy_shim_prepare_pairs" || return 1
  shimmy_shim_candidate_commit || return 1
  if ! shimmy_ai_skill_context_resolve "$SHIMMY_CONFIG_ROOT" ||
    ! shimmy_ai_skill_reconcile_preflight "$SHIMMY_AI_SKILL_PROFILE_ROOT" \
      "$SHIMMY_CATALOG_REGISTRY_PATH" "$SHIMMY_AI_SKILL_GENERATION_ROOT" ||
    ! shimmy_ai_skill_reconcile_plan_render human; then
    shimmy_shim_commit_restore || true
    shimmy_locks_release_all || true
    shimmy_shim_error_set "${SHIMMY_AI_SKILL_ERROR:-unable to plan AI-skill reconciliation}"
    return 1
  fi
  shimmy_external_transaction_begin || {
    shimmy_shim_commit_restore || true
    shimmy_locks_release_all || true
    return 1
  }
  if ! shimmy_ai_skill_reconcile_apply; then
    shimmy_shim_reconcile_reason=${SHIMMY_AI_SKILL_ERROR:-AI-skill reconciliation failed}
    shimmy_external_transaction_rollback "$shimmy_shim_reconcile_reason" || true
    shimmy_shim_commit_restore || true
    shimmy_locks_release_all || true
    shimmy_shim_error_set "$shimmy_shim_reconcile_reason"
    return 1
  fi
  shimmy_external_transaction_commit || {
    shimmy_shim_commit_restore || true
    shimmy_locks_release_all || true
    return 1
  }
  if [ -n "$SHIMMY_AI_SKILL_UNSUPPORTED_KINDS" ]; then
    printf 'WARNING: shim mutation skipped unsupported AI-skill bundles: %s\n' \
      "$(printf '%s' "$SHIMMY_AI_SKILL_UNSUPPORTED_KINDS" | tr '\n' ',')" >&2
  fi
  shimmy_shim_commit_finalize
}

shimmy_shim_record_without_tool() {
  shimmy_shim_filter_records=$1
  shimmy_shim_filter_tool=$2
  printf '%s\n' "$shimmy_shim_filter_records" | awk -F'|' -v tool="$shimmy_shim_filter_tool" '$1 != tool'
}

shimmy_shim_record_without_version() {
  shimmy_shim_filter_versions=$1
  shimmy_shim_filter_tool=$2
  shimmy_shim_filter_version=$3
  printf '%s\n' "$shimmy_shim_filter_versions" | awk -F'|' -v tool="$shimmy_shim_filter_tool" -v version="$shimmy_shim_filter_version" '!($1 == tool && $2 == version)'
}

shimmy_shim_add() {
  shimmy_shim_add_tool=$1
  shimmy_shim_add_version=$2
  shimmy_shim_add_mode=$3
  shimmy_shim_catalog_version_validate "$shimmy_shim_add_tool" "$shimmy_shim_add_version" || {
    shimmy_shim_error_set "unsupported shim selector: $shimmy_shim_add_tool@$shimmy_shim_add_version"
    return 1
  }
  SHIMMY_SHIM_VERSION_RECORDS=$SHIMMY_SHIM_VERSION_RECORDS
  if shimmy_shim_version_role_read "$shimmy_shim_add_tool" "$shimmy_shim_add_version" >/dev/null 2>&1; then
    shimmy_shim_error_set "shim version is already installed: $shimmy_shim_add_tool@$shimmy_shim_add_version"
    return 1
  fi
  if [ -n "$(shimmy_shim_policy_read "$shimmy_shim_add_tool")" ]; then
    shimmy_shim_add_records=$SHIMMY_SHIM_RECORDS
    shimmy_shim_add_versions=$(shimmy_append_line_list "$SHIMMY_SHIM_VERSION_RECORDS" "$shimmy_shim_add_tool|$shimmy_shim_add_version|exact")
  else
    case "$shimmy_shim_add_mode" in tracking|pinned) ;; *) return 1 ;; esac
    shimmy_shim_add_records=$(shimmy_append_line_list "$SHIMMY_SHIM_RECORDS" "$shimmy_shim_add_tool|$shimmy_shim_add_mode")
    shimmy_shim_add_versions=$(shimmy_append_line_list "$SHIMMY_SHIM_VERSION_RECORDS" "$shimmy_shim_add_tool|$shimmy_shim_add_version|default")
  fi
  shimmy_shim_mutation_apply "$shimmy_shim_add_records" "$shimmy_shim_add_versions" "$shimmy_shim_add_tool|$shimmy_shim_add_version"
}

shimmy_shim_remove() {
  shimmy_shim_remove_tool=$1
  shimmy_shim_remove_version=${2:-}
  [ -n "$(shimmy_shim_policy_read "$shimmy_shim_remove_tool")" ] || {
    shimmy_shim_error_set "shim is not installed: $shimmy_shim_remove_tool"
    return 1
  }
  if [ -z "$shimmy_shim_remove_version" ]; then
    shimmy_shim_remove_records=$(shimmy_shim_record_without_tool "$SHIMMY_SHIM_RECORDS" "$shimmy_shim_remove_tool")
    shimmy_shim_remove_versions=$(shimmy_shim_record_without_tool "$SHIMMY_SHIM_VERSION_RECORDS" "$shimmy_shim_remove_tool")
  else
    shimmy_shim_remove_role=$(shimmy_shim_version_role_read "$shimmy_shim_remove_tool" "$shimmy_shim_remove_version" || true)
    [ -n "$shimmy_shim_remove_role" ] || { shimmy_shim_error_set "shim version is not installed: $shimmy_shim_remove_tool@$shimmy_shim_remove_version"; return 1; }
    [ "$shimmy_shim_remove_role" != default ] || { shimmy_shim_error_set "cannot remove selected default version: $shimmy_shim_remove_tool@$shimmy_shim_remove_version"; return 1; }
    shimmy_shim_remove_records=$SHIMMY_SHIM_RECORDS
    shimmy_shim_remove_versions=$(shimmy_shim_record_without_version "$SHIMMY_SHIM_VERSION_RECORDS" "$shimmy_shim_remove_tool" "$shimmy_shim_remove_version")
  fi
  shimmy_shim_mutation_apply "$shimmy_shim_remove_records" "$shimmy_shim_remove_versions" ''
}

shimmy_shim_set_version() {
  shimmy_shim_set_tool=$1
  shimmy_shim_set_version=$2
  shimmy_shim_set_role=$(shimmy_shim_version_role_read "$shimmy_shim_set_tool" "$shimmy_shim_set_version" || true)
  [ "$shimmy_shim_set_role" = exact ] || { shimmy_shim_error_set "set-version requires an installed exact version: $shimmy_shim_set_tool@$shimmy_shim_set_version"; return 1; }
  shimmy_shim_set_default=$(shimmy_shim_default_read "$shimmy_shim_set_tool") || return 1
  shimmy_shim_set_records=$(shimmy_shim_record_without_tool "$SHIMMY_SHIM_RECORDS" "$shimmy_shim_set_tool")
  shimmy_shim_set_records=$(shimmy_append_line_list "$shimmy_shim_set_records" "$shimmy_shim_set_tool|pinned")
  shimmy_shim_set_versions=$(shimmy_shim_record_without_version "$SHIMMY_SHIM_VERSION_RECORDS" "$shimmy_shim_set_tool" "$shimmy_shim_set_version")
  shimmy_shim_set_versions=$(shimmy_shim_record_without_version "$shimmy_shim_set_versions" "$shimmy_shim_set_tool" "$shimmy_shim_set_default")
  shimmy_shim_set_versions=$(shimmy_append_line_list "$shimmy_shim_set_versions" "$shimmy_shim_set_tool|$shimmy_shim_set_version|default")
  shimmy_shim_set_versions=$(shimmy_append_line_list "$shimmy_shim_set_versions" "$shimmy_shim_set_tool|$shimmy_shim_set_default|exact")
  shimmy_shim_mutation_apply "$shimmy_shim_set_records" "$shimmy_shim_set_versions" ''
}

shimmy_shim_sync() {
  shimmy_shim_sync_selectors=${1:-}
  [ -n "$shimmy_shim_sync_selectors" ] || shimmy_shim_sync_selectors=$(shimmy_shim_expected_tool_names "$SHIMMY_SHIM_RECORDS")
  shimmy_shim_sync_records=$SHIMMY_SHIM_RECORDS
  shimmy_shim_sync_versions=$SHIMMY_SHIM_VERSION_RECORDS
  shimmy_shim_sync_prepare=
  while IFS= read -r shimmy_shim_sync_selector; do
    [ -n "$shimmy_shim_sync_selector" ] || continue
    case "$shimmy_shim_sync_selector" in
      *@*)
        shimmy_shim_sync_tool=${shimmy_shim_sync_selector%%@*}
        shimmy_shim_sync_exact=${shimmy_shim_sync_selector#*@}
        shimmy_shim_version_role_read "$shimmy_shim_sync_tool" "$shimmy_shim_sync_exact" >/dev/null 2>&1 || {
          shimmy_shim_error_set "shim version is not installed: $shimmy_shim_sync_selector"
          return 1
        }
        shimmy_shim_sync_prepare=$(shimmy_append_line_list "$shimmy_shim_sync_prepare" "$shimmy_shim_sync_tool|$shimmy_shim_sync_exact")
        continue
        ;;
      *) shimmy_shim_sync_tool=$shimmy_shim_sync_selector ;;
    esac
    shimmy_shim_sync_mode=$(shimmy_shim_policy_read "$shimmy_shim_sync_tool")
    [ -n "$shimmy_shim_sync_mode" ] || { shimmy_shim_error_set "shim is not installed: $shimmy_shim_sync_tool"; return 1; }
    if [ "$shimmy_shim_sync_mode" = tracking ]; then
      shimmy_shim_sync_old_default=$(SHIMMY_SHIM_VERSION_RECORDS=$shimmy_shim_sync_versions shimmy_shim_default_read "$shimmy_shim_sync_tool") || return 1
      shimmy_shim_sync_new_default=$(shimmy_shim_catalog_default_read "$shimmy_shim_sync_tool") || return 1
      shimmy_shim_sync_versions=$(shimmy_shim_record_without_version "$shimmy_shim_sync_versions" "$shimmy_shim_sync_tool" "$shimmy_shim_sync_old_default")
      shimmy_shim_sync_versions=$(shimmy_shim_record_without_version "$shimmy_shim_sync_versions" "$shimmy_shim_sync_tool" "$shimmy_shim_sync_new_default")
      shimmy_shim_sync_versions=$(shimmy_append_line_list "$shimmy_shim_sync_versions" "$shimmy_shim_sync_tool|$shimmy_shim_sync_new_default|default")
    fi
    while IFS= read -r shimmy_shim_sync_version_record; do
      [ -n "$shimmy_shim_sync_version_record" ] || continue
      shimmy_shim_version_record_validate "$shimmy_shim_sync_version_record" || return 1
      [ "$shimmy_shim_version_tool" = "$shimmy_shim_sync_tool" ] || continue
      shimmy_shim_sync_prepare=$(shimmy_append_line_list "$shimmy_shim_sync_prepare" "$shimmy_shim_sync_tool|$shimmy_shim_version_name")
    done <<EOF
$shimmy_shim_sync_versions
EOF
  done <<EOF
$shimmy_shim_sync_selectors
EOF
  shimmy_shim_mutation_apply "$shimmy_shim_sync_records" "$shimmy_shim_sync_versions" "$(shimmy_shim_sorted "$shimmy_shim_sync_prepare")"
}

shimmy_shim_list_render() {
  shimmy_shim_list_format=${1:-human}
  case "$shimmy_shim_list_format" in human|manifest) ;; *) return 1 ;; esac
  [ "$shimmy_shim_list_format" != human ] || printf 'SHIM DEFAULT MODE VERSIONS\n'
  while IFS= read -r shimmy_shim_list_record; do
    [ -n "$shimmy_shim_list_record" ] || continue
    shimmy_shim_record_validate "$shimmy_shim_list_record" || return 1
    shimmy_shim_list_tool=$shimmy_shim_record_tool
    shimmy_shim_list_mode=$shimmy_shim_record_mode
    shimmy_shim_list_default=$(shimmy_shim_default_read "$shimmy_shim_list_tool") || return 1
    shimmy_shim_list_versions=
    while IFS= read -r shimmy_shim_list_version_record; do
      [ -n "$shimmy_shim_list_version_record" ] || continue
      shimmy_shim_version_record_validate "$shimmy_shim_list_version_record" || return 1
      [ "$shimmy_shim_version_tool" = "$shimmy_shim_list_tool" ] || continue
      if [ -n "$shimmy_shim_list_versions" ]; then shimmy_shim_list_versions=$shimmy_shim_list_versions,$shimmy_shim_version_name; else shimmy_shim_list_versions=$shimmy_shim_version_name; fi
    done <<EOF
$SHIMMY_SHIM_VERSION_RECORDS
EOF
    if [ "$shimmy_shim_list_format" = manifest ]; then
      printf 'shimmy_shim=%s|%s|%s|%s\n' "$shimmy_shim_list_tool" "$shimmy_shim_list_default" "$shimmy_shim_list_mode" "$shimmy_shim_list_versions"
    else
      printf '%s %s %s %s\n' "$shimmy_shim_list_tool" "$shimmy_shim_list_default" "$shimmy_shim_list_mode" "$shimmy_shim_list_versions"
    fi
  done <<EOF
$SHIMMY_SHIM_RECORDS
EOF
}

shimmy_shim_smoke_run() {
  shimmy_shim_smoke_pairs=$1
  while IFS= read -r shimmy_shim_smoke_pair; do
    [ -n "$shimmy_shim_smoke_pair" ] || continue
    shimmy_shim_smoke_tool=${shimmy_shim_smoke_pair%%|*}
    shimmy_shim_smoke_version=${shimmy_shim_smoke_pair#*|}
    shimmy_shim_smoke_root=$SHIMMY_SHIM_PROFILE_ROOT/tools/$shimmy_shim_smoke_tool/versions/$shimmy_shim_smoke_version
    [ -x "$shimmy_shim_smoke_root/run.sh" ] && [ -f "$shimmy_shim_smoke_root/smoke.conf" ] || return 1
    set --
    while IFS= read -r shimmy_shim_smoke_line || [ -n "$shimmy_shim_smoke_line" ]; do
      case "$shimmy_shim_smoke_line" in smoke_arg=*) set -- "$@" "${shimmy_shim_smoke_line#smoke_arg=}" ;; esac
    done < "$shimmy_shim_smoke_root/smoke.conf"
    [ "$#" -gt 0 ] || return 1
    "$shimmy_shim_smoke_root/run.sh" "$@" || return $?
    printf 'shimmy_shim_test=%s|%s|pass\n' "$shimmy_shim_smoke_tool" "$shimmy_shim_smoke_version"
  done <<EOF
$shimmy_shim_smoke_pairs
EOF
}
