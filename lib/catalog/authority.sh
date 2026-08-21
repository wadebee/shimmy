#!/bin/sh
# Immutable default-catalog validation and local inspection.

SHIMMY_TARGET_CATALOG_SKILL_HEADER='> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.'
SHIMMY_TARGET_CATALOG_ERROR=

shimmy_target_catalog_error_set() {
  SHIMMY_TARGET_CATALOG_ERROR=$*
  return 1
}

shimmy_target_catalog_skill_header_validate() {
  shimmy_target_catalog_skill_file=$1
  [ -f "$shimmy_target_catalog_skill_file" ] && [ ! -L "$shimmy_target_catalog_skill_file" ] || return 1
  [ "$(sed -n '6p' "$shimmy_target_catalog_skill_file")" = "$SHIMMY_TARGET_CATALOG_SKILL_HEADER" ] || return 1
}

shimmy_target_catalog_payload_validate() {
  shimmy_target_catalog_payload_root=$1
  shimmy_catalog_payload_validate "$shimmy_target_catalog_payload_root" default || {
    shimmy_target_catalog_error_set "$SHIMMY_CATALOG_ERROR"
    return 1
  }

  shimmy_target_catalog_control_skills='shimmy-catalog
shimmy-create-tool
shimmy-escalation
shimmy-init
shimmy-install
shimmy-tool-local-build'
  shimmy_target_catalog_actual_control_skills=
  for shimmy_target_catalog_skill_dir in "$shimmy_target_catalog_payload_root"/plugins/shimmy/skills/*; do
    [ -e "$shimmy_target_catalog_skill_dir" ] || continue
    shimmy_target_catalog_skill_name=$(basename -- "$shimmy_target_catalog_skill_dir")
    shimmy_target_catalog_actual_control_skills=$(shimmy_append_line_list "$shimmy_target_catalog_actual_control_skills" "$shimmy_target_catalog_skill_name")
    shimmy_target_catalog_skill_header_validate "$shimmy_target_catalog_skill_dir/SKILL.md" || {
      shimmy_target_catalog_error_set "catalog control skill has an invalid canonical header: $shimmy_target_catalog_skill_name"
      return 1
    }
  done
  shimmy_target_catalog_actual_control_skills=$(printf '%s\n' "$shimmy_target_catalog_actual_control_skills" | LC_ALL=C sort)
  [ "$shimmy_target_catalog_actual_control_skills" = "$shimmy_target_catalog_control_skills" ] || {
    shimmy_target_catalog_error_set 'catalog control skills do not match the canonical target set'
    return 1
  }

  for shimmy_target_catalog_tool_dir in "$shimmy_target_catalog_payload_root"/tools/*; do
    [ -d "$shimmy_target_catalog_tool_dir" ] && [ ! -L "$shimmy_target_catalog_tool_dir" ] || continue
    shimmy_target_catalog_tool_name=$(basename -- "$shimmy_target_catalog_tool_dir")
    shimmy_target_catalog_skill_header_validate "$shimmy_target_catalog_tool_dir/SKILL.md" || {
      shimmy_target_catalog_error_set "catalog tool skill has an invalid canonical header: shimmy-tool-$shimmy_target_catalog_tool_name"
      return 1
    }
  done
}

shimmy_target_catalog_generation_record_validate() {
  shimmy_target_catalog_generation_root=$1
  shimmy_target_catalog_generation_name=$2
  shimmy_target_catalog_generation_validate "$shimmy_target_catalog_generation_name" || {
    shimmy_target_catalog_error_set "unsafe target catalog generation: $shimmy_target_catalog_generation_name"
    return 1
  }
  [ -d "$shimmy_target_catalog_generation_root" ] && [ ! -L "$shimmy_target_catalog_generation_root" ] || {
    shimmy_target_catalog_error_set "missing target catalog generation: $shimmy_target_catalog_generation_name"
    return 1
  }
  shimmy_path_parent_chain_validate "$shimmy_target_catalog_generation_root" || {
    shimmy_target_catalog_error_set "target catalog generation has a symbolic-link path component: $shimmy_target_catalog_generation_name"
    return 1
  }
  shimmy_target_catalog_payload_validate "$shimmy_target_catalog_generation_root" || return 1
  shimmy_target_catalog_generation_metadata_read "$shimmy_target_catalog_generation_root/generation.conf" || {
    shimmy_target_catalog_error_set "invalid target catalog generation metadata: $shimmy_target_catalog_generation_name"
    return 1
  }
  shimmy_target_catalog_generation_commit=$SHIMMY_TARGET_CATALOG_GENERATION_SOURCE_COMMIT
  shimmy_target_catalog_generation_fingerprint=$SHIMMY_TARGET_CATALOG_GENERATION_CONTENT_FINGERPRINT
  [ "$(shimmy_target_catalog_generation_render "$shimmy_target_catalog_generation_fingerprint")" = "$shimmy_target_catalog_generation_name" ] || {
    shimmy_target_catalog_error_set "target catalog generation metadata does not match its directory: $shimmy_target_catalog_generation_name"
    return 1
  }
  shimmy_target_catalog_resolved_fingerprint=$(shimmy_target_catalog_content_fingerprint_render "$shimmy_target_catalog_generation_root") || {
    shimmy_target_catalog_error_set "unable to fingerprint target catalog generation: $shimmy_target_catalog_generation_name"
    return 1
  }
  [ "$shimmy_target_catalog_resolved_fingerprint" = "$shimmy_target_catalog_generation_fingerprint" ] || {
    shimmy_target_catalog_error_set "target catalog generation content fingerprint mismatch: $shimmy_target_catalog_generation_name"
    return 1
  }
  SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_COMMIT=$shimmy_target_catalog_generation_commit
  SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_FINGERPRINT=$shimmy_target_catalog_generation_fingerprint
}

shimmy_target_catalog_root_paths_resolve() {
  shimmy_target_catalog_config_root=$1
  shimmy_path_absolute_normalized_validate "$shimmy_target_catalog_config_root" || {
    shimmy_target_catalog_error_set "invalid target catalog configuration root: $shimmy_target_catalog_config_root"
    return 1
  }
  [ -d "$shimmy_target_catalog_config_root" ] && [ ! -L "$shimmy_target_catalog_config_root" ] &&
    shimmy_path_parent_chain_validate "$shimmy_target_catalog_config_root" || {
      shimmy_target_catalog_error_set "unsafe target catalog configuration root: $shimmy_target_catalog_config_root"
      return 1
    }
  SHIMMY_TARGET_CATALOG_CONFIG_ROOT=$shimmy_target_catalog_config_root
  SHIMMY_TARGET_CATALOGS_ROOT=$shimmy_target_catalog_config_root/catalogs
  SHIMMY_TARGET_CATALOG_DEFAULT_ROOT=$SHIMMY_TARGET_CATALOGS_ROOT/default
  SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT=$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT/generations
  SHIMMY_TARGET_CATALOG_REGISTRY_PATH=$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT/registry.conf
}

shimmy_target_catalog_tree_validate() {
  shimmy_target_catalog_root_paths_resolve "$1" || return 1
  [ -d "$SHIMMY_TARGET_CATALOGS_ROOT" ] && [ ! -L "$SHIMMY_TARGET_CATALOGS_ROOT" ] || {
    shimmy_target_catalog_error_set "missing target catalog root: $SHIMMY_TARGET_CATALOGS_ROOT"
    return 1
  }
  for shimmy_target_catalog_entry in "$SHIMMY_TARGET_CATALOGS_ROOT"/* "$SHIMMY_TARGET_CATALOGS_ROOT"/.[!.]* "$SHIMMY_TARGET_CATALOGS_ROOT"/..?*; do
    [ -e "$shimmy_target_catalog_entry" ] || [ -L "$shimmy_target_catalog_entry" ] || continue
    [ "$shimmy_target_catalog_entry" = "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] || {
      shimmy_target_catalog_error_set "unsupported target catalog state: $shimmy_target_catalog_entry"
      return 1
    }
  done
  [ -d "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] && [ ! -L "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] || {
    shimmy_target_catalog_error_set "default target catalog must be a regular directory: $SHIMMY_TARGET_CATALOG_DEFAULT_ROOT"
    return 1
  }
  for shimmy_target_catalog_entry in "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT"/* "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT"/.[!.]* "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT"/..?*; do
    [ -e "$shimmy_target_catalog_entry" ] || [ -L "$shimmy_target_catalog_entry" ] || continue
    case "$shimmy_target_catalog_entry" in
      "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH"|"$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT") ;;
      *) shimmy_target_catalog_error_set "unrecognized target default-catalog state: $shimmy_target_catalog_entry"; return 1 ;;
    esac
  done
  [ -d "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT" ] && [ ! -L "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT" ] || {
    shimmy_target_catalog_error_set "target catalog generations must be a regular directory: $SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT"
    return 1
  }
  shimmy_target_catalog_registry_read "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH" || {
    shimmy_target_catalog_error_set "invalid target default-catalog registry: $SHIMMY_TARGET_CATALOG_REGISTRY_PATH"
    return 1
  }
  shimmy_target_catalog_registry_current=$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT
  shimmy_target_catalog_registry_previous=$SHIMMY_TARGET_CATALOG_GENERATION_PREVIOUS
  shimmy_target_catalog_registry_commit=$SHIMMY_TARGET_CATALOG_SOURCE_COMMIT
  shimmy_target_catalog_registry_fingerprint=$SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT

  shimmy_target_catalog_generation_count=0
  for shimmy_target_catalog_generation_dir in "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT"/* "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT"/.[!.]* "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT"/..?*; do
    [ -e "$shimmy_target_catalog_generation_dir" ] || [ -L "$shimmy_target_catalog_generation_dir" ] || continue
    [ -d "$shimmy_target_catalog_generation_dir" ] && [ ! -L "$shimmy_target_catalog_generation_dir" ] || {
      shimmy_target_catalog_error_set "target catalog generation must be a regular directory: $shimmy_target_catalog_generation_dir"
      return 1
    }
    shimmy_target_catalog_generation_name=$(basename -- "$shimmy_target_catalog_generation_dir")
    shimmy_target_catalog_generation_validate "$shimmy_target_catalog_generation_name" || {
      shimmy_target_catalog_error_set "unsafe target catalog generation directory: $shimmy_target_catalog_generation_name"
      return 1
    }
    shimmy_target_catalog_generation_count=$((shimmy_target_catalog_generation_count + 1))
  done
  [ "$shimmy_target_catalog_generation_count" -gt 0 ] || {
    shimmy_target_catalog_error_set 'target default catalog contains no generations'
    return 1
  }

  shimmy_target_catalog_generation_record_validate "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$shimmy_target_catalog_registry_current" "$shimmy_target_catalog_registry_current" || return 1
  [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_COMMIT" = "$shimmy_target_catalog_registry_commit" ] &&
    [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$shimmy_target_catalog_registry_fingerprint" ] || {
      shimmy_target_catalog_error_set 'target catalog current registry provenance does not match its generation'
      return 1
    }
  if [ -n "$shimmy_target_catalog_registry_previous" ]; then
    shimmy_target_catalog_generation_record_validate "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$shimmy_target_catalog_registry_previous" "$shimmy_target_catalog_registry_previous" || return 1
  fi

  SHIMMY_TARGET_CATALOG_GENERATION_CURRENT=$shimmy_target_catalog_registry_current
  SHIMMY_TARGET_CATALOG_GENERATION_PREVIOUS=$shimmy_target_catalog_registry_previous
  SHIMMY_TARGET_CATALOG_SOURCE_COMMIT=$shimmy_target_catalog_registry_commit
  SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT=$shimmy_target_catalog_registry_fingerprint
}

shimmy_target_catalog_status_render() {
  shimmy_target_catalog_status_root=$1
  shimmy_target_catalog_status_format=${2:-human}
  case "$shimmy_target_catalog_status_format" in human|manifest) ;; *) return 1 ;; esac
  shimmy_target_catalog_tree_validate "$shimmy_target_catalog_status_root" || return 1
  if [ "$shimmy_target_catalog_status_format" = manifest ]; then
    printf 'shimmy_catalog=default|%s|%s|%s|%s|ok\n' \
      "$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT" "$SHIMMY_TARGET_CATALOG_GENERATION_PREVIOUS" \
      "$SHIMMY_TARGET_CATALOG_SOURCE_COMMIT" "$SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT"
    return
  fi
  printf 'CATALOG CURRENT PREVIOUS SOURCE HEALTH\n'
  printf 'default %s %s %s ok\n' "$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT" \
    "${SHIMMY_TARGET_CATALOG_GENERATION_PREVIOUS:--}" "$SHIMMY_TARGET_CATALOG_SOURCE_COMMIT"
}

shimmy_target_catalog_tool_versions_render() {
  shimmy_target_catalog_tool_root=$1
  shimmy_target_catalog_tool_version_list=$(
    for shimmy_target_catalog_version_dir in "$shimmy_target_catalog_tool_root"/versions/*; do
      [ -d "$shimmy_target_catalog_version_dir" ] && [ ! -L "$shimmy_target_catalog_version_dir" ] || continue
      basename -- "$shimmy_target_catalog_version_dir"
    done | LC_ALL=C sort
  )
  shimmy_target_catalog_tool_versions=
  while IFS= read -r shimmy_target_catalog_version; do
    [ -n "$shimmy_target_catalog_version" ] || continue
    if [ -n "$shimmy_target_catalog_tool_versions" ]; then
      shimmy_target_catalog_tool_versions=$shimmy_target_catalog_tool_versions,$shimmy_target_catalog_version
    else
      shimmy_target_catalog_tool_versions=$shimmy_target_catalog_version
    fi
  done <<EOF
$shimmy_target_catalog_tool_version_list
EOF
  printf '%s\n' "$shimmy_target_catalog_tool_versions"
}

shimmy_target_catalog_tools_render() {
  shimmy_target_catalog_tools_root=$1
  shimmy_target_catalog_tools_generation=${2:-}
  shimmy_target_catalog_tools_format=${3:-human}
  case "$shimmy_target_catalog_tools_format" in human|manifest) ;; *) return 1 ;; esac
  shimmy_target_catalog_tree_validate "$shimmy_target_catalog_tools_root" || return 1
  [ -n "$shimmy_target_catalog_tools_generation" ] || shimmy_target_catalog_tools_generation=$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT
  shimmy_target_catalog_generation_record_validate "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$shimmy_target_catalog_tools_generation" "$shimmy_target_catalog_tools_generation" || return 1
  shimmy_target_catalog_tools_payload=$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$shimmy_target_catalog_tools_generation
  if [ "$shimmy_target_catalog_tools_format" = human ]; then
    printf 'TOOL DEFAULT VERSIONS\n'
  fi
  shimmy_target_catalog_tool_names=$(
    for shimmy_target_catalog_tool_dir in "$shimmy_target_catalog_tools_payload"/tools/*; do
      [ -d "$shimmy_target_catalog_tool_dir" ] && [ ! -L "$shimmy_target_catalog_tool_dir" ] || continue
      basename -- "$shimmy_target_catalog_tool_dir"
    done | LC_ALL=C sort
  )
  while IFS= read -r shimmy_target_catalog_tool_name; do
    [ -n "$shimmy_target_catalog_tool_name" ] || continue
    shimmy_target_catalog_tool_dir=$shimmy_target_catalog_tools_payload/tools/$shimmy_target_catalog_tool_name
    shimmy_target_catalog_tool_default=$(shimmy__catalog_config_value_read "$shimmy_target_catalog_tool_dir/tool.conf" tool_default_version)
    shimmy_target_catalog_tool_versions=$(shimmy_target_catalog_tool_versions_render "$shimmy_target_catalog_tool_dir") || return 1
    if [ "$shimmy_target_catalog_tools_format" = manifest ]; then
      printf 'shimmy_catalog_tool=default|%s|%s|%s|%s\n' "$shimmy_target_catalog_tools_generation" \
        "$shimmy_target_catalog_tool_name" "$shimmy_target_catalog_tool_default" "$shimmy_target_catalog_tool_versions"
    else
      printf '%s %s %s\n' "$shimmy_target_catalog_tool_name" "$shimmy_target_catalog_tool_default" "$shimmy_target_catalog_tool_versions"
    fi
  done <<EOF
$shimmy_target_catalog_tool_names
EOF
}
