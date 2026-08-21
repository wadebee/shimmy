#!/bin/sh
# Private AI-skill bundle materialization and profile reconciliation.

SHIMMY_AI_SKILL_ERROR=
SHIMMY_AI_SKILL_RECONCILE_MUTATIONS=0

shimmy_ai_skill_error_set() {
  SHIMMY_AI_SKILL_ERROR=$*
  return 1
}

shimmy_ai_skill_bundle_output_prepare() {
  shimmy_ai_skill_output_root=$1
  shimmy_path_absolute_normalized_validate "$shimmy_ai_skill_output_root" || return 1
  shimmy_ai_skill_output_parent=$(dirname -- "$shimmy_ai_skill_output_root")
  [ -d "$shimmy_ai_skill_output_parent" ] && [ ! -L "$shimmy_ai_skill_output_parent" ] &&
    shimmy_path_parent_chain_validate "$shimmy_ai_skill_output_parent" || return 1
  [ ! -e "$shimmy_ai_skill_output_root" ] && [ ! -L "$shimmy_ai_skill_output_root" ] || return 1
  mkdir -p "$shimmy_ai_skill_output_root/skills"
}

shimmy_ai_skill_file_materialize() {
  shimmy_ai_skill_materialize_source=$1
  shimmy_ai_skill_materialize_name=$2
  shimmy_ai_skill_materialize_destination=$3
  shimmy_text_file_validate "$shimmy_ai_skill_materialize_source" || return 1
  shimmy_name_component_validate "$shimmy_ai_skill_materialize_name" || return 1
  shimmy_ai_skill_frontmatter_validate "$shimmy_ai_skill_materialize_source" "$shimmy_ai_skill_materialize_name" || return 1
  shimmy_ai_skill_managed_header_validate "$shimmy_ai_skill_materialize_source" || return 1
  mkdir -p "$(dirname -- "$shimmy_ai_skill_materialize_destination")" || return 1
  awk -v expected_name="$shimmy_ai_skill_materialize_name" '
    NR == 1 { if ($0 != "---") exit 1; frontmatter = 1; print; next }
    frontmatter && $0 == "---" { frontmatter = 0; closed++; print; next }
    frontmatter && /^name: / { names++; print "name: " expected_name; next }
    frontmatter && /^description: / { descriptions++; print; next }
    { print }
    END { if (closed != 1 || names != 1 || descriptions != 1) exit 1 }
  ' "$shimmy_ai_skill_materialize_source" > "$shimmy_ai_skill_materialize_destination" || return 1
  chmod 0644 "$shimmy_ai_skill_materialize_destination"
}

shimmy_ai_skill_control_bundle_materialize() {
  shimmy_ai_skill_control_source_root=$1
  shimmy_ai_skill_control_source_ref=$2
  shimmy_ai_skill_control_profile=$3
  shimmy_ai_skill_control_output=$4
  shimmy_path_absolute_normalized_validate "$shimmy_ai_skill_control_source_root" || return 1
  [ -d "$shimmy_ai_skill_control_source_root" ] && [ ! -L "$shimmy_ai_skill_control_source_root" ] &&
    shimmy_path_parent_chain_validate "$shimmy_ai_skill_control_source_root" || return 1
  shimmy_git_commit_validate "$shimmy_ai_skill_control_source_ref" || return 1
  shimmy_name_component_validate "$shimmy_ai_skill_control_profile" || return 1
  shimmy_ai_skill_control_resolved=$(git -C "$shimmy_ai_skill_control_source_root" rev-parse "$shimmy_ai_skill_control_source_ref^{commit}" 2>/dev/null) || return 1
  [ "$shimmy_ai_skill_control_resolved" = "$shimmy_ai_skill_control_source_ref" ] || return 1
  shimmy_ai_skill_control_actual=$(git -C "$shimmy_ai_skill_control_source_root" \
    ls-tree --name-only "$shimmy_ai_skill_control_source_ref:plugins/shimmy/skills" 2>/dev/null | LC_ALL=C sort) || return 1
  shimmy_ai_skill_control_expected=$(shimmy_ai_skill_control_names_render) || return 1
  [ "$shimmy_ai_skill_control_actual" = "$shimmy_ai_skill_control_expected" ] || return 1
  shimmy_ai_skill_bundle_output_prepare "$shimmy_ai_skill_control_output" || return 1

  shimmy_ai_skill_control_records=
  while IFS= read -r shimmy_ai_skill_control_name; do
    [ -n "$shimmy_ai_skill_control_name" ] || continue
    shimmy_ai_skill_control_source=$shimmy_ai_skill_control_output/.source.$shimmy_ai_skill_control_name.$$
    shimmy_ai_skill_control_file=$shimmy_ai_skill_control_output/skills/$shimmy_ai_skill_control_name/SKILL.md
    if ! git -C "$shimmy_ai_skill_control_source_root" show \
      "$shimmy_ai_skill_control_source_ref:plugins/shimmy/skills/$shimmy_ai_skill_control_name/SKILL.md" \
      > "$shimmy_ai_skill_control_source" 2>/dev/null; then
      rm -f "$shimmy_ai_skill_control_source"
      return 1
    fi
    if ! shimmy_ai_skill_file_materialize "$shimmy_ai_skill_control_source" \
      "$shimmy_ai_skill_control_name" "$shimmy_ai_skill_control_file"; then
      rm -f "$shimmy_ai_skill_control_source"
      return 1
    fi
    rm -f "$shimmy_ai_skill_control_source" || return 1
    shimmy_ai_skill_control_fingerprint=$(shimmy_sha256_fingerprint_file_render "$shimmy_ai_skill_control_file") || return 1
    shimmy_ai_skill_control_record="$shimmy_ai_skill_control_name|$shimmy_ai_skill_control_fingerprint|control|$shimmy_ai_skill_control_name|$shimmy_ai_skill_control_source_ref"
    shimmy_ai_skill_control_records=$(shimmy_append_line_list "$shimmy_ai_skill_control_records" "$shimmy_ai_skill_control_record")
  done <<EOF
$shimmy_ai_skill_control_expected
EOF
  shimmy_ai_skill_bundle_render control "$shimmy_ai_skill_control_profile" \
    "$shimmy_ai_skill_control_source_ref" "$shimmy_ai_skill_control_records" \
    > "$shimmy_ai_skill_control_output/bundle.conf" || return 1
  chmod 0644 "$shimmy_ai_skill_control_output/bundle.conf"
  shimmy_ai_skill_bundle_read "$shimmy_ai_skill_control_output" control "$shimmy_ai_skill_control_profile"
}

shimmy_ai_skill_shims_bundle_materialize() {
  shimmy_ai_skill_shims_input=$1
  shimmy_ai_skill_shims_catalog=$2
  shimmy_ai_skill_shims_output=$3
  shimmy_shim_bundle_input_validate "$shimmy_ai_skill_shims_input" || return 1
  shimmy_ai_skill_shims_profile=$shimmy_shim_bundle_profile
  shimmy_ai_skill_shims_generation=$shimmy_shim_bundle_generation
  shimmy_ai_skill_shims_fingerprint=$shimmy_shim_bundle_fingerprint
  shimmy_ai_skill_shims_tools=$shimmy_shim_bundle_tools
  [ "$shimmy_ai_skill_shims_catalog" = "$(dirname -- "$(dirname -- "$shimmy_ai_skill_shims_catalog")")/generations/$shimmy_ai_skill_shims_generation" ] || return 1
  shimmy_catalog_generation_record_validate "$shimmy_ai_skill_shims_catalog" "$shimmy_ai_skill_shims_generation" || return 1
  [ "$SHIMMY_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$shimmy_ai_skill_shims_fingerprint" ] || return 1
  shimmy_ai_skill_bundle_output_prepare "$shimmy_ai_skill_shims_output" || return 1

  shimmy_ai_skill_shims_records=
  while IFS= read -r shimmy_ai_skill_shims_tool; do
    [ -n "$shimmy_ai_skill_shims_tool" ] || continue
    shimmy_ai_skill_shims_name=shimmy-tool-$shimmy_ai_skill_shims_tool
    shimmy_ai_skill_shims_source=$shimmy_ai_skill_shims_catalog/tools/$shimmy_ai_skill_shims_tool/SKILL.md
    shimmy_ai_skill_shims_file=$shimmy_ai_skill_shims_output/skills/$shimmy_ai_skill_shims_name/SKILL.md
    shimmy_ai_skill_file_materialize "$shimmy_ai_skill_shims_source" \
      "$shimmy_ai_skill_shims_name" "$shimmy_ai_skill_shims_file" || return 1
    shimmy_ai_skill_shims_skill_fingerprint=$(shimmy_sha256_fingerprint_file_render "$shimmy_ai_skill_shims_file") || return 1
    shimmy_ai_skill_shims_record="$shimmy_ai_skill_shims_name|$shimmy_ai_skill_shims_skill_fingerprint|default|$shimmy_ai_skill_shims_tool|$shimmy_ai_skill_shims_generation"
    shimmy_ai_skill_shims_records=$(shimmy_append_line_list "$shimmy_ai_skill_shims_records" "$shimmy_ai_skill_shims_record")
  done <<EOF
$shimmy_ai_skill_shims_tools
EOF
  shimmy_ai_skill_shims_source_ref=$shimmy_ai_skill_shims_generation/$shimmy_ai_skill_shims_fingerprint
  shimmy_ai_skill_bundle_render shims "$shimmy_ai_skill_shims_profile" \
    "$shimmy_ai_skill_shims_source_ref" "$shimmy_ai_skill_shims_records" \
    > "$shimmy_ai_skill_shims_output/bundle.conf" || return 1
  chmod 0644 "$shimmy_ai_skill_shims_output/bundle.conf"
  shimmy_ai_skill_bundle_read "$shimmy_ai_skill_shims_output" shims "$shimmy_ai_skill_shims_profile"
}

shimmy_ai_skill_bundle_probe() {
  shimmy_ai_skill_probe_root=$1
  shimmy_ai_skill_probe_kind=$2
  shimmy_ai_skill_probe_profile=$3
  SHIMMY_AI_SKILL_PROBE_STATUS=invalid
  SHIMMY_AI_SKILL_PROBE_REASON=missing-bundle
  SHIMMY_AI_SKILL_PROBE_RECORDS=
  SHIMMY_AI_SKILL_PROBE_UNSUPPORTED=0
  case "$shimmy_ai_skill_probe_kind" in control|shims) ;; *) return 1 ;; esac
  if [ ! -e "$shimmy_ai_skill_probe_root" ] && [ ! -L "$shimmy_ai_skill_probe_root" ]; then
    return 0
  fi
  [ -d "$shimmy_ai_skill_probe_root" ] && [ ! -L "$shimmy_ai_skill_probe_root" ] || {
    SHIMMY_AI_SKILL_PROBE_REASON=unsafe-bundle-root
    return 0
  }
  shimmy_ai_skill_probe_file=$shimmy_ai_skill_probe_root/bundle.conf
  if [ ! -f "$shimmy_ai_skill_probe_file" ] || [ -L "$shimmy_ai_skill_probe_file" ]; then
    SHIMMY_AI_SKILL_PROBE_REASON=missing-bundle-manifest
    return 0
  fi
  shimmy_ai_skill_probe_schema=$(sed -n '1s/^shimmy_ai_skill_bundle_schema=//p' "$shimmy_ai_skill_probe_file")
  if [ -n "$shimmy_ai_skill_probe_schema" ] && [ "$shimmy_ai_skill_probe_schema" != 1 ]; then
    SHIMMY_AI_SKILL_PROBE_REASON=unsupported-schema-$shimmy_ai_skill_probe_schema
    SHIMMY_AI_SKILL_PROBE_UNSUPPORTED=1
    return 0
  fi
  if ! shimmy_ai_skill_bundle_read "$shimmy_ai_skill_probe_root" \
    "$shimmy_ai_skill_probe_kind" "$shimmy_ai_skill_probe_profile"; then
    SHIMMY_AI_SKILL_PROBE_REASON=malformed-supported-bundle
    return 0
  fi
  SHIMMY_AI_SKILL_PROBE_RECORDS=$SHIMMY_AI_SKILL_RECORDS
  SHIMMY_AI_SKILL_PROBE_REASON=-
  if [ -n "$SHIMMY_AI_SKILL_PROBE_RECORDS" ]; then
    SHIMMY_AI_SKILL_PROBE_STATUS=valid
  else
    SHIMMY_AI_SKILL_PROBE_STATUS=empty
  fi
}

shimmy_ai_skill_profile_core_validate() {
  shimmy_ai_skill_profile_manifest=$1
  shimmy_ai_skill_profile_registry=$2
  shimmy_ai_skill_profile_generation_root=$3
  shimmy_profile_manifest_read "$shimmy_ai_skill_profile_manifest" || return 1
  SHIMMY_AI_SKILL_PROFILE_NAME=$SHIMMY_PROFILE_NAME
  SHIMMY_AI_SKILL_PROFILE_SOURCE_REF=$SHIMMY_PROFILE_SOURCE_REF
  SHIMMY_AI_SKILL_PROFILE_CATALOG_RECORD=$SHIMMY_PROFILE_CATALOG_RECORD
  SHIMMY_AI_SKILL_PROFILE_SHIMS=$SHIMMY_PROFILE_SHIM_RECORDS
  shimmy_catalog_pin_validate "$SHIMMY_AI_SKILL_PROFILE_CATALOG_RECORD" || return 1
  SHIMMY_AI_SKILL_PROFILE_GENERATION=$shimmy_catalog_pin_generation
  SHIMMY_AI_SKILL_PROFILE_CATALOG_COMMIT=$shimmy_catalog_pin_commit
  SHIMMY_AI_SKILL_PROFILE_CATALOG_FINGERPRINT=$shimmy_catalog_pin_fingerprint
  shimmy_catalog_registry_read "$shimmy_ai_skill_profile_registry" || return 1
  [ "$shimmy_ai_skill_profile_generation_root" = "$(dirname -- "$shimmy_ai_skill_profile_registry")/generations/$SHIMMY_AI_SKILL_PROFILE_GENERATION" ] || return 1
  shimmy_catalog_generation_record_validate "$shimmy_ai_skill_profile_generation_root" "$SHIMMY_AI_SKILL_PROFILE_GENERATION" || return 1
  [ "$SHIMMY_CATALOG_VALIDATED_GENERATION_COMMIT" = "$SHIMMY_AI_SKILL_PROFILE_CATALOG_COMMIT" ] &&
    [ "$SHIMMY_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$SHIMMY_AI_SKILL_PROFILE_CATALOG_FINGERPRINT" ]
}

shimmy_ai_skill_supported_bundles_validate() {
  shimmy_ai_skill_supported_profile_root=$1
  shimmy_ai_skill_supported_registry=$2
  shimmy_ai_skill_supported_generation_root=$3
  shimmy_ai_skill_profile_core_validate \
    "$shimmy_ai_skill_supported_profile_root/install-manifest.txt" \
    "$shimmy_ai_skill_supported_registry" "$shimmy_ai_skill_supported_generation_root" || return 1
  shimmy_ai_skill_supported_profile=$SHIMMY_AI_SKILL_PROFILE_NAME
  shimmy_ai_skill_supported_source=$SHIMMY_AI_SKILL_PROFILE_SOURCE_REF
  shimmy_ai_skill_supported_generation=$SHIMMY_AI_SKILL_PROFILE_GENERATION
  shimmy_ai_skill_supported_fingerprint=$SHIMMY_AI_SKILL_PROFILE_CATALOG_FINGERPRINT
  shimmy_ai_skill_supported_shims=$SHIMMY_AI_SKILL_PROFILE_SHIMS
  SHIMMY_AI_SKILL_SUPPORTED_NAMES=
  SHIMMY_AI_SKILL_UNSUPPORTED_KINDS=

  for shimmy_ai_skill_supported_kind in control shims; do
    shimmy_ai_skill_supported_bundle=$shimmy_ai_skill_supported_profile_root/ai-skills/$shimmy_ai_skill_supported_kind
    shimmy_ai_skill_bundle_probe "$shimmy_ai_skill_supported_bundle" \
      "$shimmy_ai_skill_supported_kind" "$shimmy_ai_skill_supported_profile" || return 1
    case "$shimmy_ai_skill_supported_kind" in
      control)
        SHIMMY_AI_SKILL_CONTROL_STATUS=$SHIMMY_AI_SKILL_PROBE_STATUS
        SHIMMY_AI_SKILL_CONTROL_REASON=$SHIMMY_AI_SKILL_PROBE_REASON
        ;;
      shims)
        SHIMMY_AI_SKILL_SHIMS_STATUS=$SHIMMY_AI_SKILL_PROBE_STATUS
        SHIMMY_AI_SKILL_SHIMS_REASON=$SHIMMY_AI_SKILL_PROBE_REASON
        ;;
    esac
    if [ "$SHIMMY_AI_SKILL_PROBE_UNSUPPORTED" -eq 1 ]; then
      SHIMMY_AI_SKILL_UNSUPPORTED_KINDS=$(shimmy_append_line_list \
        "$SHIMMY_AI_SKILL_UNSUPPORTED_KINDS" "$shimmy_ai_skill_supported_kind")
      continue
    fi
    case "$SHIMMY_AI_SKILL_PROBE_STATUS" in valid|empty) ;; *) return 1 ;; esac
    shimmy_ai_skill_supported_records=$SHIMMY_AI_SKILL_PROBE_RECORDS
    shimmy_ai_skill_bundle_read "$shimmy_ai_skill_supported_bundle" \
      "$shimmy_ai_skill_supported_kind" "$shimmy_ai_skill_supported_profile" || return 1
    case "$shimmy_ai_skill_supported_kind" in
      control)
        [ "$SHIMMY_AI_SKILL_SOURCE_REF" = "$shimmy_ai_skill_supported_source" ] || return 1
        shimmy_ai_skill_supported_expected_control=$(shimmy_ai_skill_control_names_render)
        shimmy_ai_skill_supported_actual_control=$(printf '%s\n' "$shimmy_ai_skill_supported_records" | sed -n 's/|.*//p')
        [ "$shimmy_ai_skill_supported_actual_control" = "$shimmy_ai_skill_supported_expected_control" ] || return 1
        ;;
      shims)
        [ "$SHIMMY_AI_SKILL_SOURCE_REF" = "$shimmy_ai_skill_supported_generation/$shimmy_ai_skill_supported_fingerprint" ] || return 1
        shimmy_ai_skill_supported_expected_shims=$(printf '%s\n' "$shimmy_ai_skill_supported_shims" | sed -n 's/^\([^|]*\)|.*$/shimmy-tool-\1/p')
        shimmy_ai_skill_supported_actual_shims=$(printf '%s\n' "$shimmy_ai_skill_supported_records" | sed -n 's/|.*//p')
        [ "$shimmy_ai_skill_supported_actual_shims" = "$shimmy_ai_skill_supported_expected_shims" ] || return 1
        ;;
    esac
    while IFS= read -r shimmy_ai_skill_supported_record; do
      [ -n "$shimmy_ai_skill_supported_record" ] || continue
      shimmy_ai_skill_supported_name=${shimmy_ai_skill_supported_record%%|*}
      shimmy_contains_line_list "$SHIMMY_AI_SKILL_SUPPORTED_NAMES" "$shimmy_ai_skill_supported_name" && return 1
      SHIMMY_AI_SKILL_SUPPORTED_NAMES=$(shimmy_append_line_list \
        "$SHIMMY_AI_SKILL_SUPPORTED_NAMES" "$shimmy_ai_skill_supported_name")
    done <<EOF
$shimmy_ai_skill_supported_records
EOF
  done
}

shimmy_ai_skill_context_resolve() {
  shimmy_ai_skill_context_root=$1
  SHIMMY_AI_SKILL_ERROR=
  shimmy_catalog_tree_validate "$shimmy_ai_skill_context_root" || {
    shimmy_ai_skill_error_set "$SHIMMY_CATALOG_AUTHORITY_ERROR"
    return 1
  }
  shimmy_installation_paths_resolve "$shimmy_ai_skill_context_root" || return 1
  shimmy_active_profile_read "$SHIMMY_ACTIVE_PROFILE_PATH" || {
    shimmy_ai_skill_error_set 'AI-skill lifecycle requires a valid active profile record'
    return 1
  }
  SHIMMY_AI_SKILL_ACTIVE_NAME=$SHIMMY_ACTIVE_PROFILE_NAME
  SHIMMY_AI_SKILL_USER_ROOT=$SHIMMY_ACTIVE_AI_SKILL_ROOT
  shimmy_ai_skill_home=${HOME:-}
  shimmy_path_absolute_normalized_validate "$shimmy_ai_skill_home" || {
    shimmy_ai_skill_error_set 'AI-skill lifecycle requires a normalized absolute HOME'
    return 1
  }
  [ "$SHIMMY_AI_SKILL_USER_ROOT" = "$shimmy_ai_skill_home/.agents/skills" ] || {
    shimmy_ai_skill_error_set "recorded AI-skill root does not match the current installation context: $SHIMMY_AI_SKILL_USER_ROOT"
    return 1
  }
  [ -d "$SHIMMY_AI_SKILL_USER_ROOT" ] && [ ! -L "$SHIMMY_AI_SKILL_USER_ROOT" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_AI_SKILL_USER_ROOT" || {
      shimmy_ai_skill_error_set "unsafe recorded AI-skill root: $SHIMMY_AI_SKILL_USER_ROOT"
      return 1
    }
  shimmy_profile_state_paths_resolve "$shimmy_ai_skill_context_root" "$SHIMMY_AI_SKILL_ACTIVE_NAME" || return 1
  SHIMMY_AI_SKILL_PROFILE_ROOT=$SHIMMY_PROFILE_ROOT
  [ -d "$SHIMMY_AI_SKILL_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_AI_SKILL_PROFILE_ROOT" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_AI_SKILL_PROFILE_ROOT" || {
      shimmy_ai_skill_error_set "unsafe active AI-skill profile root: $SHIMMY_AI_SKILL_PROFILE_ROOT"
      return 1
    }
  shimmy_profile_manifest_read "$SHIMMY_AI_SKILL_PROFILE_ROOT/install-manifest.txt" || {
    shimmy_ai_skill_error_set 'invalid active profile manifest for AI-skill lifecycle'
    return 1
  }
  [ "$SHIMMY_PROFILE_NAME" = "$SHIMMY_AI_SKILL_ACTIVE_NAME" ] || return 1
  shimmy_catalog_pin_validate "$SHIMMY_PROFILE_CATALOG_RECORD" || return 1
  SHIMMY_AI_SKILL_GENERATION=$shimmy_catalog_pin_generation
  SHIMMY_AI_SKILL_GENERATION_ROOT=$SHIMMY_CATALOG_GENERATIONS_ROOT/$SHIMMY_AI_SKILL_GENERATION
  shimmy_ai_skill_profile_core_validate \
    "$SHIMMY_AI_SKILL_PROFILE_ROOT/install-manifest.txt" \
    "$SHIMMY_CATALOG_REGISTRY_PATH" "$SHIMMY_AI_SKILL_GENERATION_ROOT" || {
      shimmy_ai_skill_error_set 'active profile catalog authority is inconsistent for AI-skill lifecycle'
      return 1
    }
}

shimmy_ai_skill_desired_records_render() {
  shimmy_ai_skill_desired_profile_root=$1
  for shimmy_ai_skill_desired_kind in control shims; do
    if shimmy_contains_line_list "$SHIMMY_AI_SKILL_UNSUPPORTED_KINDS" "$shimmy_ai_skill_desired_kind"; then
      continue
    fi
    shimmy_ai_skill_desired_bundle=$shimmy_ai_skill_desired_profile_root/ai-skills/$shimmy_ai_skill_desired_kind
    shimmy_ai_skill_bundle_read "$shimmy_ai_skill_desired_bundle" \
      "$shimmy_ai_skill_desired_kind" "$SHIMMY_AI_SKILL_ACTIVE_NAME" || return 1
    while IFS= read -r shimmy_ai_skill_desired_record; do
      [ -n "$shimmy_ai_skill_desired_record" ] || continue
      printf '%s|%s|%s\n' "$shimmy_ai_skill_desired_kind" \
        "${shimmy_ai_skill_desired_record%%|*}" "$shimmy_ai_skill_desired_bundle"
    done <<EOF
$SHIMMY_AI_SKILL_RECORDS
EOF
  done
}

shimmy_ai_skill_desired_name_contains() {
  shimmy_ai_skill_desired_records=$1
  shimmy_ai_skill_desired_expected=$2
  while IFS='|' read -r shimmy_ai_skill_desired_kind shimmy_ai_skill_desired_name shimmy_ai_skill_desired_bundle; do
    [ -n "$shimmy_ai_skill_desired_kind" ] || continue
    [ "$shimmy_ai_skill_desired_name" = "$shimmy_ai_skill_desired_expected" ] && return 0
  done <<EOF
$shimmy_ai_skill_desired_records
EOF
  return 1
}

shimmy_ai_skill_reconcile_preflight() {
  shimmy_ai_skill_reconcile_profile_root=$1
  shimmy_ai_skill_reconcile_registry=$2
  shimmy_ai_skill_reconcile_generation_root=$3
  shimmy_ai_skill_supported_bundles_validate "$shimmy_ai_skill_reconcile_profile_root" \
    "$shimmy_ai_skill_reconcile_registry" "$shimmy_ai_skill_reconcile_generation_root" || {
      shimmy_ai_skill_error_set 'supported AI-skill bundle consistency validation failed'
      return 1
    }
  SHIMMY_AI_SKILL_DESIRED_RECORDS=$(shimmy_ai_skill_desired_records_render \
    "$shimmy_ai_skill_reconcile_profile_root") || return 1
}

shimmy_ai_skill_reconcile_plan_render() {
  shimmy_ai_skill_plan_format=${1:-human}
  case "$shimmy_ai_skill_plan_format" in human|manifest) ;; *) return 1 ;; esac
  while IFS= read -r shimmy_ai_skill_plan_unsupported; do
    [ -n "$shimmy_ai_skill_plan_unsupported" ] || continue
    if [ "$shimmy_ai_skill_plan_format" = manifest ]; then
      printf 'shimmy_ai_skill_plan=skip|%s|unsupported-bundle|-|-\n' "$shimmy_ai_skill_plan_unsupported"
    else
      printf 'WARNING: skipping unsupported %s AI-skill bundle; recognized stale links of that kind will be removed.\n' \
        "$shimmy_ai_skill_plan_unsupported"
    fi
  done <<EOF
$SHIMMY_AI_SKILL_UNSUPPORTED_KINDS
EOF

  for shimmy_ai_skill_plan_destination in "$SHIMMY_AI_SKILL_USER_ROOT"/*; do
    [ -e "$shimmy_ai_skill_plan_destination" ] || [ -L "$shimmy_ai_skill_plan_destination" ] || continue
    shimmy_ai_skill_link_recognized_read "$shimmy_ai_skill_plan_destination" \
      "$SHIMMY_AI_SKILL_USER_ROOT" "$SHIMMY_PROFILES_ROOT" || continue
    shimmy_ai_skill_plan_name=$SHIMMY_AI_SKILL_LINK_RECOGNIZED_NAME
    shimmy_ai_skill_desired_name_contains "$SHIMMY_AI_SKILL_DESIRED_RECORDS" "$shimmy_ai_skill_plan_name" && continue
    if [ "$shimmy_ai_skill_plan_format" = manifest ]; then
      printf 'shimmy_ai_skill_plan=remove|%s|recognized-stale|%s|%s\n' \
        "$SHIMMY_AI_SKILL_LINK_RECOGNIZED_KIND" \
        "$(shimmy_manifest_value_encode "$shimmy_ai_skill_plan_name")" \
        "$(shimmy_manifest_value_encode "$shimmy_ai_skill_plan_destination")"
    else
      printf 'Remove recognized stale Shimmy link: %s\n' "$shimmy_ai_skill_plan_destination"
    fi
  done

  while IFS='|' read -r shimmy_ai_skill_plan_kind shimmy_ai_skill_plan_name shimmy_ai_skill_plan_bundle; do
    [ -n "$shimmy_ai_skill_plan_kind" ] || continue
    shimmy_ai_skill_link_plan "$SHIMMY_AI_SKILL_USER_ROOT" "$SHIMMY_PROFILES_ROOT" \
      "$shimmy_ai_skill_plan_bundle" "$shimmy_ai_skill_plan_name" || return 1
    shimmy_ai_skill_plan_classification=$SHIMMY_AI_SKILL_LINK_CLASSIFICATION
    case "$shimmy_ai_skill_plan_classification" in shimmy-link-current) shimmy_ai_skill_plan_action=keep ;; *) shimmy_ai_skill_plan_action=replace ;; esac
    if [ "$shimmy_ai_skill_plan_format" = manifest ]; then
      printf 'shimmy_ai_skill_plan=%s|%s|%s|%s|%s\n' \
        "$shimmy_ai_skill_plan_action" "$shimmy_ai_skill_plan_kind" \
        "$(shimmy_manifest_value_encode "$shimmy_ai_skill_plan_name")" \
        "$(shimmy_manifest_value_encode "$shimmy_ai_skill_plan_classification")" \
        "$(shimmy_manifest_value_encode "$SHIMMY_AI_SKILL_LINK_DESTINATION")"
    else
      case "$shimmy_ai_skill_plan_classification" in
        empty|shimmy-link-current) ;;
        file|directory-empty|directory-nonempty|foreign-link|foreign-link-broken)
          printf 'Replace %s AI-skill destination: %s (%s)\n' \
            "$shimmy_ai_skill_plan_kind" "$SHIMMY_AI_SKILL_LINK_DESTINATION" \
            "$shimmy_ai_skill_plan_classification"
          printf 'WARNING: exact destination will be overwritten without backup and is not recoverable: %s\n' \
            "$SHIMMY_AI_SKILL_LINK_DESTINATION"
          ;;
        *)
          printf 'Replace %s AI-skill destination: %s (%s)\n' \
            "$shimmy_ai_skill_plan_kind" "$SHIMMY_AI_SKILL_LINK_DESTINATION" \
            "$shimmy_ai_skill_plan_classification"
          ;;
      esac
    fi
  done <<EOF
$SHIMMY_AI_SKILL_DESIRED_RECORDS
EOF
}

shimmy_ai_skill_reconcile_injection_check() {
  SHIMMY_AI_SKILL_RECONCILE_MUTATIONS=$((SHIMMY_AI_SKILL_RECONCILE_MUTATIONS + 1))
  [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] || return 0
  [ -n "${SHIMMY_TEST_AI_SKILL_FAILURE_AFTER:-}" ] || return 0
  if [ "$SHIMMY_AI_SKILL_RECONCILE_MUTATIONS" -eq "$SHIMMY_TEST_AI_SKILL_FAILURE_AFTER" ]; then
    shimmy_ai_skill_error_set "injected AI-skill reconciliation failure after link $SHIMMY_AI_SKILL_RECONCILE_MUTATIONS"
    return 1
  fi
}

shimmy_ai_skill_reconcile_apply() {
  [ "$SHIMMY_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  SHIMMY_AI_SKILL_RECONCILE_MUTATIONS=0
  for shimmy_ai_skill_apply_destination in "$SHIMMY_AI_SKILL_USER_ROOT"/*; do
    [ -e "$shimmy_ai_skill_apply_destination" ] || [ -L "$shimmy_ai_skill_apply_destination" ] || continue
    shimmy_ai_skill_link_recognized_read "$shimmy_ai_skill_apply_destination" \
      "$SHIMMY_AI_SKILL_USER_ROOT" "$SHIMMY_PROFILES_ROOT" || continue
    shimmy_ai_skill_apply_name=$SHIMMY_AI_SKILL_LINK_RECOGNIZED_NAME
    shimmy_ai_skill_desired_name_contains "$SHIMMY_AI_SKILL_DESIRED_RECORDS" "$shimmy_ai_skill_apply_name" && continue
    shimmy_ai_skill_link_remove_recognized "$SHIMMY_AI_SKILL_USER_ROOT" \
      "$SHIMMY_PROFILES_ROOT" "$shimmy_ai_skill_apply_name" || return 1
    shimmy_ai_skill_reconcile_injection_check || return 1
  done

  while IFS='|' read -r shimmy_ai_skill_apply_kind shimmy_ai_skill_apply_name shimmy_ai_skill_apply_bundle; do
    [ -n "$shimmy_ai_skill_apply_kind" ] || continue
    shimmy_ai_skill_link_plan "$SHIMMY_AI_SKILL_USER_ROOT" "$SHIMMY_PROFILES_ROOT" \
      "$shimmy_ai_skill_apply_bundle" "$shimmy_ai_skill_apply_name" || return 1
    shimmy_ai_skill_apply_classification=$SHIMMY_AI_SKILL_LINK_CLASSIFICATION
    shimmy_ai_skill_link_replace "$SHIMMY_AI_SKILL_USER_ROOT" "$SHIMMY_PROFILES_ROOT" \
      "$shimmy_ai_skill_apply_bundle" "$shimmy_ai_skill_apply_name" || return 1
    [ "$shimmy_ai_skill_apply_classification" = shimmy-link-current ] || \
      shimmy_ai_skill_reconcile_injection_check || return 1
  done <<EOF
$SHIMMY_AI_SKILL_DESIRED_RECORDS
EOF
}

shimmy_ai_skill_list_render() {
  shimmy_ai_skill_list_format=${1:-human}
  case "$shimmy_ai_skill_list_format" in human|manifest) ;; *) return 1 ;; esac
  if [ "$shimmy_ai_skill_list_format" = human ]; then
    printf 'BUNDLE STATUS SKILLS REASON\n'
  fi
  for shimmy_ai_skill_list_kind in control shims; do
    shimmy_ai_skill_list_bundle=$SHIMMY_AI_SKILL_PROFILE_ROOT/ai-skills/$shimmy_ai_skill_list_kind
    shimmy_ai_skill_bundle_probe "$shimmy_ai_skill_list_bundle" \
      "$shimmy_ai_skill_list_kind" "$SHIMMY_AI_SKILL_ACTIVE_NAME" || return 1
    shimmy_ai_skill_list_status=$SHIMMY_AI_SKILL_PROBE_STATUS
    shimmy_ai_skill_list_reason=$SHIMMY_AI_SKILL_PROBE_REASON
    shimmy_ai_skill_list_records=$SHIMMY_AI_SKILL_PROBE_RECORDS
    shimmy_ai_skill_list_count=0
    while IFS= read -r shimmy_ai_skill_list_count_record; do
      [ -n "$shimmy_ai_skill_list_count_record" ] || continue
      shimmy_ai_skill_list_count=$((shimmy_ai_skill_list_count + 1))
    done <<EOF
$shimmy_ai_skill_list_records
EOF
    if [ "$shimmy_ai_skill_list_format" = manifest ]; then
      printf 'shimmy_ai_skill_bundle=%s|%s|%s|%s\n' \
        "$shimmy_ai_skill_list_kind" "$shimmy_ai_skill_list_status" \
        "$shimmy_ai_skill_list_count" "$(shimmy_manifest_value_encode "$shimmy_ai_skill_list_reason")"
    else
      printf '%s %s %s %s\n' "$shimmy_ai_skill_list_kind" \
        "$shimmy_ai_skill_list_status" "$shimmy_ai_skill_list_count" "$shimmy_ai_skill_list_reason"
    fi
    case "$shimmy_ai_skill_list_status" in valid|empty) ;; *) continue ;; esac
    while IFS= read -r shimmy_ai_skill_list_record; do
      [ -n "$shimmy_ai_skill_list_record" ] || continue
      shimmy_ai_skill_record_validate "$shimmy_ai_skill_list_kind" \
        "$(sed -n '4s/^shimmy_ai_skill_source_ref=//p' "$shimmy_ai_skill_list_bundle/bundle.conf")" \
        "$shimmy_ai_skill_list_record" || return 1
      shimmy_ai_skill_list_name=$shimmy_ai_skill_name
      shimmy_ai_skill_list_fingerprint=$shimmy_ai_skill_fingerprint
      shimmy_ai_skill_list_identity=$shimmy_ai_skill_identity
      shimmy_ai_skill_link_plan "$SHIMMY_AI_SKILL_USER_ROOT" "$SHIMMY_PROFILES_ROOT" \
        "$shimmy_ai_skill_list_bundle" "$shimmy_ai_skill_list_name" || return 1
      if [ "$shimmy_ai_skill_list_format" = manifest ]; then
        printf 'shimmy_ai_skill=%s|%s|%s|%s|%s|%s\n' \
          "$shimmy_ai_skill_list_kind" "$shimmy_ai_skill_list_name" \
          "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" "$shimmy_ai_skill_list_fingerprint" \
          "$(shimmy_manifest_value_encode "$shimmy_ai_skill_list_identity")" \
          "$(shimmy_manifest_value_encode "$SHIMMY_AI_SKILL_LINK_DESTINATION")"
      else
        printf '  %s %s %s\n' "$shimmy_ai_skill_list_name" \
          "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" "$SHIMMY_AI_SKILL_LINK_DESTINATION"
      fi
    done <<EOF
$shimmy_ai_skill_list_records
EOF
  done
}

shimmy_ai_skill_repair() {
  shimmy_ai_skill_repair_config=$1
  shimmy_ai_skill_context_resolve "$shimmy_ai_skill_repair_config" || return 1
  shimmy_ai_skill_reconcile_preflight "$SHIMMY_AI_SKILL_PROFILE_ROOT" \
    "$SHIMMY_CATALOG_REGISTRY_PATH" "$SHIMMY_AI_SKILL_GENERATION_ROOT" || return 1
  shimmy_ai_skill_reconcile_plan_render human || return 1
  shimmy_lock_acquire activation "$shimmy_ai_skill_repair_config" || {
    shimmy_ai_skill_error_set "$SHIMMY_LOCK_ERROR"
    return 1
  }
  shimmy_lock_acquire profile "$shimmy_ai_skill_repair_config" "$SHIMMY_AI_SKILL_ACTIVE_NAME" || {
    shimmy_ai_skill_error_set "$SHIMMY_LOCK_ERROR"
    shimmy_locks_release_all || true
    return 1
  }
  if ! shimmy_ai_skill_context_resolve "$shimmy_ai_skill_repair_config" ||
    ! shimmy_ai_skill_reconcile_preflight "$SHIMMY_AI_SKILL_PROFILE_ROOT" \
      "$SHIMMY_CATALOG_REGISTRY_PATH" "$SHIMMY_AI_SKILL_GENERATION_ROOT"; then
    shimmy_locks_release_all || true
    return 1
  fi
  shimmy_external_transaction_begin || {
    shimmy_locks_release_all || true
    return 1
  }
  if ! shimmy_ai_skill_reconcile_apply; then
    shimmy_ai_skill_repair_reason=${SHIMMY_AI_SKILL_ERROR:-AI-skill reconciliation failed}
    shimmy_external_transaction_rollback "$shimmy_ai_skill_repair_reason" || true
    shimmy_locks_release_all || true
    return 1
  fi
  shimmy_external_transaction_commit || {
    shimmy_locks_release_all || true
    return 1
  }
  shimmy_locks_release_all || return 1
  if [ -n "$SHIMMY_AI_SKILL_UNSUPPORTED_KINDS" ]; then
    shimmy_ai_skill_error_set 'AI-skill repair skipped unsupported bundles'
    return 2
  fi
  printf 'AI-skill links repaired for active profile %s.\n' "$SHIMMY_AI_SKILL_ACTIVE_NAME"
}
