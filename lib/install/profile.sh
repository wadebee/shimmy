#!/bin/sh
# Profile materialization and the exact jq/rg/Skopeo baseline.

SHIMMY_PROFILE_CANDIDATE_STAGE=

shimmy_profile_candidate_stage_cleanup() {
  [ -n "$SHIMMY_PROFILE_CANDIDATE_STAGE" ] || return 0
  case "$SHIMMY_PROFILE_CANDIDATE_STAGE" in
    "$SHIMMY_PROFILES_ROOT"/.*.profile-candidate.*)
      [ ! -e "$SHIMMY_PROFILE_CANDIDATE_STAGE" ] &&
        [ ! -L "$SHIMMY_PROFILE_CANDIDATE_STAGE" ] ||
        rm -rf "$SHIMMY_PROFILE_CANDIDATE_STAGE"
      ;;
    *) return 1 ;;
  esac
  SHIMMY_PROFILE_CANDIDATE_STAGE=
}

shimmy_profile_control_assets_copy() {
  shimmy_profile_control_source=$1
  shimmy_profile_control_destination=$2
  shimmy_path_absolute_normalized_validate "$shimmy_profile_control_source" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_profile_control_destination" || return 1
  [ -d "$shimmy_profile_control_source" ] && [ ! -L "$shimmy_profile_control_source" ] &&
    shimmy_path_parent_chain_validate "$shimmy_profile_control_source" || return 1
  [ -d "$shimmy_profile_control_source/commands" ] &&
    [ ! -L "$shimmy_profile_control_source/commands" ] || return 1
  [ -d "$shimmy_profile_control_source/lib" ] &&
    [ ! -L "$shimmy_profile_control_source/lib" ] || return 1
  mkdir -p "$shimmy_profile_control_destination/commands" || return 1
  for shimmy_profile_control_command in admin ai-skill catalog help profile shim; do
    [ -f "$shimmy_profile_control_source/commands/$shimmy_profile_control_command.sh" ] &&
      [ ! -L "$shimmy_profile_control_source/commands/$shimmy_profile_control_command.sh" ] || return 1
    cp "$shimmy_profile_control_source/commands/$shimmy_profile_control_command.sh" \
      "$shimmy_profile_control_destination/commands/$shimmy_profile_control_command.sh" || return 1
  done
  cp -R "$shimmy_profile_control_source/lib" \
    "$shimmy_profile_control_destination/lib" || return 1
}

shimmy_profile_control_assets_extract() {
  shimmy_profile_control_checkout=$1
  shimmy_profile_control_ref=$2
  shimmy_profile_control_destination=$3
  shimmy_path_absolute_normalized_validate "$shimmy_profile_control_checkout" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_profile_control_destination" || return 1
  shimmy_git_commit_validate "$shimmy_profile_control_ref" || return 1
  shimmy_profile_control_archive=$shimmy_profile_control_destination/.control-assets.$$.tar
  [ ! -e "$shimmy_profile_control_archive" ] && [ ! -L "$shimmy_profile_control_archive" ] || return 1
  git -C "$shimmy_profile_control_checkout" archive --format=tar \
    --output="$shimmy_profile_control_archive" "$shimmy_profile_control_ref" \
    commands/admin.sh commands/ai-skill.sh commands/catalog.sh commands/help.sh \
    commands/profile.sh commands/shim.sh lib 2>/dev/null || return 1
  tar -xf "$shimmy_profile_control_archive" -C "$shimmy_profile_control_destination" || {
    rm -f "$shimmy_profile_control_archive"
    return 1
  }
  rm -f "$shimmy_profile_control_archive"
}

shimmy_profile_control_bundle_copy() {
  shimmy_profile_control_bundle_source=$1
  shimmy_profile_control_bundle_profile=$2
  shimmy_profile_control_bundle_ref=$3
  shimmy_profile_control_bundle_destination=$4
  shimmy_ai_skill_bundle_read "$shimmy_profile_control_bundle_source" control || return 1
  shimmy_profile_control_bundle_source_ref=$SHIMMY_AI_SKILL_SOURCE_REF
  shimmy_profile_control_bundle_records=$SHIMMY_AI_SKILL_RECORDS
  [ "$shimmy_profile_control_bundle_source_ref" = "$shimmy_profile_control_bundle_ref" ] || return 1
  mkdir -p "$shimmy_profile_control_bundle_destination" || return 1
  cp -R "$shimmy_profile_control_bundle_source/skills" \
    "$shimmy_profile_control_bundle_destination/skills" || return 1
  shimmy_ai_skill_bundle_render control "$shimmy_profile_control_bundle_profile" \
    "$shimmy_profile_control_bundle_ref" "$shimmy_profile_control_bundle_records" \
    > "$shimmy_profile_control_bundle_destination/bundle.conf" || return 1
  chmod 0644 "$shimmy_profile_control_bundle_destination/bundle.conf" || return 1
  shimmy_ai_skill_bundle_read "$shimmy_profile_control_bundle_destination" control \
    "$shimmy_profile_control_bundle_profile"
}

shimmy_profile_image_plan_render() {
  shimmy_profile_image_plan_catalog=$1
  shimmy_profile_image_plan_pairs=${2:-}
  while IFS='|' read -r shimmy_profile_image_plan_tool shimmy_profile_image_plan_version shimmy_profile_image_plan_extra; do
    [ -n "$shimmy_profile_image_plan_tool" ] || continue
    [ -z "$shimmy_profile_image_plan_extra" ] || return 1
    shimmy_name_component_validate "$shimmy_profile_image_plan_tool" || return 1
    shimmy_version_token_validate "$shimmy_profile_image_plan_version" || return 1
    shimmy_profile_image_plan_config=$shimmy_profile_image_plan_catalog/tools/$shimmy_profile_image_plan_tool/versions/$shimmy_profile_image_plan_version/image.conf
    shimmy_profile_image_plan_source=$(shimmy__catalog_config_value_read \
      "$shimmy_profile_image_plan_config" image_source) || return 1
    case "$shimmy_profile_image_plan_source" in
      external) shimmy_profile_image_plan_action=pull ;;
      local-build) shimmy_profile_image_plan_action=build ;;
      *) return 1 ;;
    esac
    printf 'would_prepare_image=%s|%s|%s\n' "$shimmy_profile_image_plan_tool" \
      "$shimmy_profile_image_plan_version" "$shimmy_profile_image_plan_action"
  done <<EOF
$shimmy_profile_image_plan_pairs
EOF
}

shimmy_profile_images_prepare() {
  shimmy_profile_images_stage=$1
  shimmy_profile_images_pairs=${2:-}
  while IFS='|' read -r shimmy_profile_images_tool shimmy_profile_images_version shimmy_profile_images_extra; do
    [ -n "$shimmy_profile_images_tool" ] || continue
    [ -z "$shimmy_profile_images_extra" ] || return 1
    shimmy_profile_images_root=$shimmy_profile_images_stage/tools/$shimmy_profile_images_tool/versions/$shimmy_profile_images_version
    shimmy_profile_images_source=$(shimmy__catalog_config_value_read \
      "$shimmy_profile_images_root/image.conf" image_source) || return 1
    case "$shimmy_profile_images_source" in
      external) shimmy_profile_images_action=pull ;;
      local-build) shimmy_profile_images_action=build ;;
      *) return 1 ;;
    esac
    [ -x "$shimmy_profile_images_root/refresh.sh" ] &&
      [ ! -L "$shimmy_profile_images_root/refresh.sh" ] || return 1
    "$shimmy_profile_images_root/refresh.sh" "$shimmy_profile_images_action" || return 1
  done <<EOF
$shimmy_profile_images_pairs
EOF
}

shimmy_profile_materialization_prepare() {
  shimmy_profile_materialize_config=$1
  shimmy_profile_materialize_name=$2
  shimmy_profile_materialize_source_kind=$3
  shimmy_profile_materialize_control_root=$4
  shimmy_profile_materialize_source_url=$5
  shimmy_profile_materialize_source_ref=$6
  shimmy_profile_materialize_catalog_record=$7
  shimmy_profile_materialize_shims=${8:-}
  shimmy_profile_materialize_versions=${9:-}
  shift 9
  shimmy_profile_materialize_startup_shell=${1:-}
  shimmy_profile_materialize_startup_files=${2:-}
  shimmy_profile_materialize_registries_source=${3:-}
  shimmy_profile_materialize_control_bundle_source=${4:-}

  shimmy_installation_paths_resolve "$shimmy_profile_materialize_config" || return 1
  shimmy_name_component_validate "$shimmy_profile_materialize_name" || return 1
  shimmy_profile_manifest_render "$shimmy_profile_materialize_name" \
    "$shimmy_profile_materialize_source_url" "$shimmy_profile_materialize_source_ref" \
    "$shimmy_profile_materialize_catalog_record" "$shimmy_profile_materialize_shims" \
    "$shimmy_profile_materialize_versions" "$shimmy_profile_materialize_startup_shell" \
    "$shimmy_profile_materialize_startup_files" >/dev/null || return 1
  shimmy_catalog_pin_validate "$shimmy_profile_materialize_catalog_record" || return 1
  shimmy_profile_materialize_generation=$shimmy_catalog_pin_generation
  shimmy_profile_materialize_fingerprint=$shimmy_catalog_pin_fingerprint
  shimmy_profile_materialize_catalog=$SHIMMY_CATALOG_DEFAULT_ROOT/generations/$shimmy_profile_materialize_generation
  shimmy_catalog_generation_record_validate "$shimmy_profile_materialize_catalog" \
    "$shimmy_profile_materialize_generation" || return 1

  SHIMMY_PROFILE_CANDIDATE_STAGE=$SHIMMY_PROFILES_ROOT/.$shimmy_profile_materialize_name.profile-candidate.$$
  [ ! -e "$SHIMMY_PROFILE_CANDIDATE_STAGE" ] && [ ! -L "$SHIMMY_PROFILE_CANDIDATE_STAGE" ] || return 1
  mkdir -p "$SHIMMY_PROFILE_CANDIDATE_STAGE/bin" \
    "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shims" \
    "$SHIMMY_PROFILE_CANDIDATE_STAGE/tools" \
    "$SHIMMY_PROFILE_CANDIDATE_STAGE/ai-skills" || return 1

  case "$shimmy_profile_materialize_source_kind" in
    git)
      shimmy_profile_control_assets_extract "$shimmy_profile_materialize_control_root" \
        "$shimmy_profile_materialize_source_ref" "$SHIMMY_PROFILE_CANDIDATE_STAGE" || return 1
      shimmy_ai_skill_control_bundle_materialize "$shimmy_profile_materialize_control_root" \
        "$shimmy_profile_materialize_source_ref" "$shimmy_profile_materialize_name" \
        "$SHIMMY_PROFILE_CANDIDATE_STAGE/ai-skills/control" || return 1
      ;;
    installed)
      shimmy_profile_control_assets_copy "$shimmy_profile_materialize_control_root" \
        "$SHIMMY_PROFILE_CANDIDATE_STAGE" || return 1
      shimmy_profile_control_bundle_copy "$shimmy_profile_materialize_control_bundle_source" \
        "$shimmy_profile_materialize_name" "$shimmy_profile_materialize_source_ref" \
        "$SHIMMY_PROFILE_CANDIDATE_STAGE/ai-skills/control" || return 1
      ;;
    *) return 1 ;;
  esac

  shimmy_profile_launcher_render "$shimmy_profile_materialize_config" \
    "$shimmy_profile_materialize_name" > "$SHIMMY_PROFILE_CANDIDATE_STAGE/bin/shimmy" || return 1
  chmod 0755 "$SHIMMY_PROFILE_CANDIDATE_STAGE/bin/shimmy" || return 1
  shimmy_profile_shell_init_render "$shimmy_profile_materialize_config" \
    "$shimmy_profile_materialize_name" > "$SHIMMY_PROFILE_CANDIDATE_STAGE/shell-init.sh" || return 1
  chmod 0644 "$SHIMMY_PROFILE_CANDIDATE_STAGE/shell-init.sh" || return 1
  if [ -n "$shimmy_profile_materialize_registries_source" ]; then
    shimmy_registries_config_validate "$shimmy_profile_materialize_registries_source" \
      "$shimmy_profile_materialize_name" || return 1
    cp "$shimmy_profile_materialize_registries_source" \
      "$SHIMMY_PROFILE_CANDIDATE_STAGE/registries.conf" || return 1
  else
    shimmy_registries_config_render "$shimmy_profile_materialize_name" '' \
      > "$SHIMMY_PROFILE_CANDIDATE_STAGE/registries.conf" || return 1
  fi
  chmod 0644 "$SHIMMY_PROFILE_CANDIDATE_STAGE/registries.conf" || return 1

  SHIMMY_SHIM_VERSION_RECORDS=$shimmy_profile_materialize_versions
  while IFS= read -r shimmy_profile_materialize_shim_record; do
    [ -n "$shimmy_profile_materialize_shim_record" ] || continue
    shimmy_shim_record_validate "$shimmy_profile_materialize_shim_record" || return 1
    shimmy_profile_materialize_tool=$shimmy_shim_record_tool
    shimmy_profile_materialize_mode=$shimmy_shim_record_mode
    shimmy_profile_materialize_default=$(shimmy_shim_default_read \
      "$shimmy_profile_materialize_tool") || return 1
    shimmy_profile_materialize_tool_source=$shimmy_profile_materialize_catalog/tools/$shimmy_profile_materialize_tool
    shimmy_profile_materialize_tool_target=$SHIMMY_PROFILE_CANDIDATE_STAGE/tools/$shimmy_profile_materialize_tool
    mkdir -p "$shimmy_profile_materialize_tool_target/versions" \
      "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shims/$shimmy_profile_materialize_tool" || return 1
    shimmy_shim_tool_config_render "$shimmy_profile_materialize_tool_source/tool.conf" \
      "$shimmy_profile_materialize_default" > "$shimmy_profile_materialize_tool_target/tool.conf" || return 1
    chmod 0644 "$shimmy_profile_materialize_tool_target/tool.conf" || return 1
    shimmy_shim_config_render "$shimmy_profile_materialize_tool" \
      "$shimmy_profile_materialize_default" "$shimmy_profile_materialize_mode" \
      > "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shims/$shimmy_profile_materialize_tool/shim.conf" || return 1
    chmod 0644 "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shims/$shimmy_profile_materialize_tool/shim.conf" || return 1
    while IFS= read -r shimmy_profile_materialize_version_record; do
      [ -n "$shimmy_profile_materialize_version_record" ] || continue
      shimmy_shim_version_record_validate "$shimmy_profile_materialize_version_record" || return 1
      [ "$shimmy_shim_version_tool" = "$shimmy_profile_materialize_tool" ] || continue
      shimmy_profile_materialize_version=$shimmy_shim_version_name
      cp -R "$shimmy_profile_materialize_tool_source/versions/$shimmy_profile_materialize_version" \
        "$shimmy_profile_materialize_tool_target/versions/$shimmy_profile_materialize_version" || return 1
      cp "$shimmy_profile_materialize_tool_source/versions/$shimmy_profile_materialize_version/smoke.conf" \
        "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shims/$shimmy_profile_materialize_tool/$shimmy_profile_materialize_version.conf" || return 1
      chmod 0644 "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shims/$shimmy_profile_materialize_tool/$shimmy_profile_materialize_version.conf" || return 1
    done <<EOF
$shimmy_profile_materialize_versions
EOF
    shimmy_shim_wrapper_render "$shimmy_profile_materialize_tool" \
      "$shimmy_profile_materialize_default" > "$SHIMMY_PROFILE_CANDIDATE_STAGE/bin/$shimmy_profile_materialize_tool" || return 1
    chmod 0755 "$SHIMMY_PROFILE_CANDIDATE_STAGE/bin/$shimmy_profile_materialize_tool" || return 1
  done <<EOF
$shimmy_profile_materialize_shims
EOF

  shimmy_shim_bundle_input_render "$shimmy_profile_materialize_name" \
    "$shimmy_profile_materialize_generation" "$shimmy_profile_materialize_fingerprint" \
    "$shimmy_profile_materialize_shims" > "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shim-bundle-input.conf" || return 1
  chmod 0644 "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shim-bundle-input.conf" || return 1
  shimmy_ai_skill_shims_bundle_materialize \
    "$SHIMMY_PROFILE_CANDIDATE_STAGE/config/shim-bundle-input.conf" \
    "$shimmy_profile_materialize_catalog" \
    "$SHIMMY_PROFILE_CANDIDATE_STAGE/ai-skills/shims" || return 1
  shimmy_profile_manifest_render "$shimmy_profile_materialize_name" \
    "$shimmy_profile_materialize_source_url" "$shimmy_profile_materialize_source_ref" \
    "$shimmy_profile_materialize_catalog_record" "$shimmy_profile_materialize_shims" \
    "$shimmy_profile_materialize_versions" "$shimmy_profile_materialize_startup_shell" \
    "$shimmy_profile_materialize_startup_files" > "$SHIMMY_PROFILE_CANDIDATE_STAGE/install-manifest.txt" || return 1
  chmod 0644 "$SHIMMY_PROFILE_CANDIDATE_STAGE/install-manifest.txt" || return 1

  shimmy_profile_launcher_validate "$SHIMMY_PROFILE_CANDIDATE_STAGE/bin/shimmy" \
    "$shimmy_profile_materialize_config" "$shimmy_profile_materialize_name" || return 1
  shimmy_profile_shell_init_validate "$SHIMMY_PROFILE_CANDIDATE_STAGE/shell-init.sh" \
    "$shimmy_profile_materialize_config" "$shimmy_profile_materialize_name" || return 1
  shimmy_shim_materialization_validate "$SHIMMY_PROFILE_CANDIDATE_STAGE" \
    "$shimmy_profile_materialize_catalog" || return 1
  shimmy_profile_state_validate "$SHIMMY_PROFILE_CANDIDATE_STAGE/install-manifest.txt" \
    "$SHIMMY_CATALOG_DEFAULT_ROOT/registry.conf" "$shimmy_profile_materialize_catalog" \
    "$SHIMMY_PROFILE_CANDIDATE_STAGE/ai-skills/control" \
    "$SHIMMY_PROFILE_CANDIDATE_STAGE/ai-skills/shims"
}

shimmy_profile_baseline_render() {
  shimmy_profile_baseline_catalog_root=$1
  shimmy_catalog_authority_payload_validate "$shimmy_profile_baseline_catalog_root" || return 1

  for shimmy_profile_baseline_tool in jq rg skopeo; do
    shimmy_profile_baseline_tool_file=$shimmy_profile_baseline_catalog_root/tools/$shimmy_profile_baseline_tool/tool.conf
    [ -f "$shimmy_profile_baseline_tool_file" ] && [ ! -L "$shimmy_profile_baseline_tool_file" ] || return 1
    shimmy_profile_baseline_version=$(shimmy__catalog_config_value_read \
      "$shimmy_profile_baseline_tool_file" tool_default_version)
    shimmy_version_token_validate "$shimmy_profile_baseline_version" || return 1
    [ -d "$shimmy_profile_baseline_catalog_root/tools/$shimmy_profile_baseline_tool/versions/$shimmy_profile_baseline_version" ] || return 1
    printf '%s|%s\n' "$shimmy_profile_baseline_tool" "$shimmy_profile_baseline_version"
  done
}

shimmy_profile_launcher_render() {
  shimmy_profile_launcher_config_root=$1
  shimmy_profile_launcher_name=$2
  shimmy_path_absolute_normalized_validate "$shimmy_profile_launcher_config_root" || return 1
  shimmy_name_component_validate "$shimmy_profile_launcher_name" || return 1
  [ -f "$SHIMMY_CONTROL_ROOT/lib/install/launcher-template.sh" ] &&
    [ ! -L "$SHIMMY_CONTROL_ROOT/lib/install/launcher-template.sh" ] || return 1
  cat "$SHIMMY_CONTROL_ROOT/lib/install/launcher-template.sh"
}

shimmy_profile_launcher_validate() {
  shimmy_profile_launcher_file=$1
  shimmy_profile_launcher_config_root=$2
  shimmy_profile_launcher_name=$3
  [ -f "$shimmy_profile_launcher_file" ] && [ ! -L "$shimmy_profile_launcher_file" ] &&
    [ -x "$shimmy_profile_launcher_file" ] || return 1
  [ "$(shimmy_profile_launcher_render "$shimmy_profile_launcher_config_root" "$shimmy_profile_launcher_name")" = "$(cat "$shimmy_profile_launcher_file")" ]
}

shimmy_profile_shell_init_render() {
  shimmy_profile_shell_config_root=$1
  shimmy_profile_shell_name=$2
  shimmy_path_absolute_normalized_validate "$shimmy_profile_shell_config_root" || return 1
  shimmy_name_component_validate "$shimmy_profile_shell_name" || return 1
  shimmy_profile_shell_profiles_root=$shimmy_profile_shell_config_root/profiles
  shimmy_profile_shell_bin=$shimmy_profile_shell_profiles_root/$shimmy_profile_shell_name/bin
  shimmy_profile_shell_launcher=$shimmy_profile_shell_bin/shimmy
  shimmy_profile_shell_profiles_quoted=$(shimmy_quote_shell_word "$shimmy_profile_shell_profiles_root") || return 1
  shimmy_profile_shell_bin_quoted=$(shimmy_quote_shell_word "$shimmy_profile_shell_bin") || return 1
  shimmy_profile_shell_launcher_quoted=$(shimmy_quote_shell_word "$shimmy_profile_shell_launcher") || return 1

  printf '%s\n' '# shimmy_shell_init_schema=1'
  printf 'PATH=`\n'
  printf '  shimmy_shell_profiles_root=%s\n' "$shimmy_profile_shell_profiles_quoted"
  printf '  shimmy_shell_bin=%s\n' "$shimmy_profile_shell_bin_quoted"
  printf '  shimmy_shell_input=${PATH-}\n'
  printf '  shimmy_shell_output=\n'
  printf '  shimmy_shell_output_count=0\n'
  printf '  while :; do\n'
  printf '    case "$shimmy_shell_input" in\n'
  printf '      *:*) shimmy_shell_entry=${shimmy_shell_input%%%%:*}; shimmy_shell_input=${shimmy_shell_input#*:}; shimmy_shell_more=1 ;;\n'
  printf '      *) shimmy_shell_entry=$shimmy_shell_input; shimmy_shell_more=0 ;;\n'
  printf '    esac\n'
  printf '    shimmy_shell_remove=0\n'
  printf '    case "$shimmy_shell_entry" in\n'
  printf '      "$shimmy_shell_profiles_root"/*/bin)\n'
  printf '        shimmy_shell_remainder=${shimmy_shell_entry#"$shimmy_shell_profiles_root"/}\n'
  printf '        shimmy_shell_profile=${shimmy_shell_remainder%%/bin}\n'
  printf '        if [ "$shimmy_shell_remainder" = "$shimmy_shell_profile/bin" ]; then\n'
  printf '%s\n' '          case "$shimmy_shell_profile" in '\'''\''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) ;; *) shimmy_shell_remove=1 ;; esac'
  printf '        fi\n'
  printf '        ;;\n'
  printf '    esac\n'
  printf '    if [ "$shimmy_shell_remove" -eq 0 ]; then\n'
  printf '      if [ "$shimmy_shell_output_count" -eq 0 ]; then shimmy_shell_output=$shimmy_shell_entry; else shimmy_shell_output=$shimmy_shell_output:$shimmy_shell_entry; fi\n'
  printf '      shimmy_shell_output_count=$((shimmy_shell_output_count + 1))\n'
  printf '    fi\n'
  printf '    [ "$shimmy_shell_more" -eq 1 ] || break\n'
  printf '  done\n'
  printf '  if [ "$shimmy_shell_output_count" -eq 0 ]; then printf "%%s\\n" "$shimmy_shell_bin"; else printf "%%s:%%s\\n" "$shimmy_shell_bin" "$shimmy_shell_output"; fi\n'
  printf '`\n'
  printf '%s\n' 'if [ -x /opt/podman/bin/podman ] && ! command -v podman >/dev/null 2>&1; then PATH=${PATH:+$PATH:}/opt/podman/bin; fi'
  printf '%s\n' 'export PATH'
  printf '%s\n' 'hash -r 2>/dev/null || true'
  printf '%s\n' 'shimmy() {'
  printf '  case "${1-}|${2-}|${3-}" in\n'
  printf '    profile\\|activate\\|[abcdefghijklmnopqrstuvwxyz0123456789]*|profile\\|create\\|[abcdefghijklmnopqrstuvwxyz0123456789]*)\n'
  printf '      %s "$@" || return $?\n' "$shimmy_profile_shell_launcher_quoted"
  printf '%s\n' '      if ( shift 3; for shimmy_shell_arg do [ "$shimmy_shell_arg" != --dry-run ] || exit 0; done; exit 1 ); then return 0; fi'
  printf '      . %s/${3}/shell-init.sh\n' "$shimmy_profile_shell_profiles_quoted"
  printf '      ;;\n'
  printf '    *) %s "$@" ;;\n' "$shimmy_profile_shell_launcher_quoted"
  printf '  esac\n'
  printf '%s\n' '}'
}

shimmy_profile_shell_init_validate() {
  shimmy_profile_shell_file=$1
  shimmy_profile_shell_config_root=$2
  shimmy_profile_shell_name=$3
  shimmy_text_file_validate "$shimmy_profile_shell_file" || return 1
  if shimmy_profile_shell_mode=$(stat -c '%a' "$shimmy_profile_shell_file" 2>/dev/null); then
    :
  else
    shimmy_profile_shell_mode=$(stat -f '%Lp' "$shimmy_profile_shell_file" 2>/dev/null) || return 1
  fi
  [ "$shimmy_profile_shell_mode" = 644 ] || return 1
  [ "$(shimmy_profile_shell_init_render "$shimmy_profile_shell_config_root" "$shimmy_profile_shell_name")" = "$(cat "$shimmy_profile_shell_file")" ]
}
