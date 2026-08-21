#!/bin/sh
# Installed catalog verification helpers for commands/catalog.sh.

SHIMMY_TARGET_IMAGES_ERROR=

shimmy_target_images_active_context_resolve() {
  shimmy_target_images_config_root=$1
  shimmy_target_catalog_tree_validate "$shimmy_target_images_config_root" || {
    shimmy_target_images_error_set "$SHIMMY_TARGET_CATALOG_ERROR"
    return 1
  }
  shimmy_target_images_catalog_generation=$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT
  shimmy_target_images_catalog_root=$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$shimmy_target_images_catalog_generation

  shimmy_target_installation_paths_resolve "$shimmy_target_images_config_root" || {
    shimmy_target_images_error_set "invalid target installation root: $shimmy_target_images_config_root"
    return 1
  }
  shimmy_target_active_profile_read "$SHIMMY_TARGET_ACTIVE_PROFILE_PATH" || {
    shimmy_target_images_error_set 'target catalog verification requires a valid active profile record'
    return 1
  }
  shimmy_target_images_active_profile=$SHIMMY_TARGET_ACTIVE_PROFILE_NAME
  shimmy_target_profile_paths_resolve "$shimmy_target_images_config_root" "$shimmy_target_images_active_profile" || {
    shimmy_target_images_error_set "invalid active target profile: $shimmy_target_images_active_profile"
    return 1
  }
  [ -d "$SHIMMY_TARGET_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_TARGET_PROFILE_ROOT" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_TARGET_PROFILE_ROOT" || {
      shimmy_target_images_error_set "unsafe active target profile root: $SHIMMY_TARGET_PROFILE_ROOT"
      return 1
    }
  shimmy_target_profile_manifest_read "$SHIMMY_TARGET_PROFILE_MANIFEST_PATH" || {
    shimmy_target_images_error_set "invalid active target profile manifest: $SHIMMY_TARGET_PROFILE_MANIFEST_PATH"
    return 1
  }
  [ "$SHIMMY_TARGET_PROFILE_NAME" = "$shimmy_target_images_active_profile" ] || {
    shimmy_target_images_error_set 'active target profile identity does not match its manifest'
    return 1
  }

  shimmy_target_catalog_pin_validate "$SHIMMY_TARGET_PROFILE_CATALOG_RECORD" || {
    shimmy_target_images_error_set 'active target profile has an invalid default-catalog pin'
    return 1
  }
  shimmy_target_images_profile_generation=$shimmy_target_catalog_pin_generation
  shimmy_target_images_profile_commit=$shimmy_target_catalog_pin_commit
  shimmy_target_images_profile_fingerprint=$shimmy_target_catalog_pin_fingerprint
  shimmy_target_catalog_generation_record_validate \
    "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$shimmy_target_images_profile_generation" \
    "$shimmy_target_images_profile_generation" || {
      shimmy_target_images_error_set "$SHIMMY_TARGET_CATALOG_ERROR"
      return 1
    }
  [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_COMMIT" = "$shimmy_target_images_profile_commit" ] &&
    [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$shimmy_target_images_profile_fingerprint" ] || {
      shimmy_target_images_error_set 'active target profile catalog pin does not match its retained generation'
      return 1
    }

  SHIMMY_TARGET_IMAGES_ACTIVE_PROFILE=$shimmy_target_images_active_profile
  SHIMMY_TARGET_IMAGES_CATALOG_GENERATION=$shimmy_target_images_catalog_generation
  SHIMMY_TARGET_IMAGES_CATALOG_ROOT=$shimmy_target_images_catalog_root
  SHIMMY_TARGET_IMAGES_PROFILE_ROOT=$SHIMMY_TARGET_PROFILE_ROOT
  SHIMMY_CATALOG_AUTHORITY_ROOT=$shimmy_target_images_catalog_root
  SHIMMY_CATALOG_TOOLS_DIR=$shimmy_target_images_catalog_root/tools
  SHIMMY_IMAGES_USE_PROFILE_METADATA=0
}

shimmy_target_images_cache_cleanup() {
  [ -n "${SHIMMY_IMAGES_CACHE_DIR:-}" ] || return 0
  [ -d "$SHIMMY_IMAGES_CACHE_DIR" ] || return 0
  case "$SHIMMY_IMAGES_CACHE_DIR" in
    "$SHIMMY_IMAGES_CACHE_PARENT"/shimmy-target-images.*) ;;
    *) return 1 ;;
  esac
  rm -rf "$SHIMMY_IMAGES_CACHE_DIR"
}

shimmy_target_images_error_set() {
  SHIMMY_TARGET_IMAGES_ERROR=$*
  return 1
}

shimmy_target_images_output_result() {
  shimmy_target_images_result_tool=$1
  shimmy_target_images_result_version=$2
  shimmy_target_images_result_role=$3
  shimmy_target_images_result_digest=$4
  shimmy_target_images_result_media_type=$5
  shimmy_target_images_result_platforms=$6
  shimmy_target_images_result_access=$7
  shimmy_target_images_result_drift=$8
  shimmy_target_images_result_state=$9
  shift 9
  shimmy_target_images_result_error=$1

  if [ "$SHIMMY_TARGET_IMAGES_OUTPUT_FORMAT" = manifest ]; then
    printf 'image_verify=%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_tool")" \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_version")" \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_role")" \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_digest")" \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_media_type")" \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_platforms")" \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_access")" \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_drift")" \
      "$(shimmy_manifest_value_encode "$shimmy_target_images_result_state")" \
      "$(shimmy_manifest_diagnostic_encode "$shimmy_target_images_result_error" "${SHIMMY_SKOPEO_AUTH_SECRET:-}")"
    return
  fi

  printf '%s %s@%s %s digest=%s media=%s platforms=%s access=%s upstream=%s' \
    "$(printf '%s' "$shimmy_target_images_result_state" | tr '[:lower:]' '[:upper:]')" \
    "$shimmy_target_images_result_tool" "$shimmy_target_images_result_version" \
    "$shimmy_target_images_result_role" "$shimmy_target_images_result_digest" \
    "$shimmy_target_images_result_media_type" "$shimmy_target_images_result_platforms" \
    "$shimmy_target_images_result_access" "$shimmy_target_images_result_drift"
  [ "$shimmy_target_images_result_error" = none ] || printf ' error=%s' "$shimmy_target_images_result_error"
  printf '\n'
}

shimmy_target_images_runtime_resolve() {
  shimmy_target_images_runtime_tool=$1
  shimmy_target_images_runtime_label=
  while IFS= read -r shimmy_target_images_runtime_record; do
    [ -n "$shimmy_target_images_runtime_record" ] || continue
    shimmy_target_shim_version_record_validate "$shimmy_target_images_runtime_record" || return 1
    [ "$shimmy_target_shim_version_tool" = "$shimmy_target_images_runtime_tool" ] || continue
    [ "$shimmy_target_shim_version_kind" = default ] || continue
    shimmy_target_images_runtime_label=$shimmy_target_shim_version_name
    break
  done <<EOF
$SHIMMY_TARGET_PROFILE_SHIM_VERSION_RECORDS
EOF

  if [ -z "$shimmy_target_images_runtime_label" ]; then
    shimmy_target_images_runtime_label=$(shimmy__catalog_config_value_read \
      "$SHIMMY_TARGET_IMAGES_CATALOG_ROOT/tools/$shimmy_target_images_runtime_tool/tool.conf" \
      tool_default_version)
    shimmy_version_token_validate "$shimmy_target_images_runtime_label" || {
      shimmy_target_images_error_set "target catalog is missing required $shimmy_target_images_runtime_tool metadata"
      return 1
    }
    shimmy_target_images_error_set "active profile is missing required $shimmy_target_images_runtime_tool@$shimmy_target_images_runtime_label; add it with: shimmy shim add $shimmy_target_images_runtime_tool@$shimmy_target_images_runtime_label"
    return 1
  fi

  shimmy_target_images_runtime_file=$SHIMMY_TARGET_IMAGES_PROFILE_ROOT/tools/$shimmy_target_images_runtime_tool/versions/$shimmy_target_images_runtime_label/run.sh
  [ -f "$shimmy_target_images_runtime_file" ] && [ ! -L "$shimmy_target_images_runtime_file" ] &&
    [ -x "$shimmy_target_images_runtime_file" ] &&
    shimmy_path_parent_chain_validate "$shimmy_target_images_runtime_file" || {
      shimmy_target_images_error_set "active profile is missing required $shimmy_target_images_runtime_tool@$shimmy_target_images_runtime_label; add it with: shimmy shim add $shimmy_target_images_runtime_tool@$shimmy_target_images_runtime_label"
      return 1
    }

  case "$shimmy_target_images_runtime_tool" in
    jq) SHIMMY_TARGET_IMAGES_JQ_VERSION=$shimmy_target_images_runtime_label ;;
    skopeo) SHIMMY_TARGET_IMAGES_SKOPEO_VERSION=$shimmy_target_images_runtime_label ;;
  esac
  SHIMMY_TARGET_IMAGES_RUNTIME_FILE=$shimmy_target_images_runtime_file
}

shimmy_target_images_selection_resolve() {
  shimmy_target_images_requested_tools=${1:-}
  if [ -z "$shimmy_target_images_requested_tools" ]; then
    shimmy_images_catalog_selection_all
  else
    shimmy_images_request_selection "$shimmy_target_images_requested_tools"
  fi
}

shimmy_target_images_verify_record() {
  shimmy_target_images_record_tool=$1
  shimmy_target_images_record_version=$2
  shimmy_target_images_record_role=$3
  shimmy_target_images_upstream_ref=$4
  shimmy_target_images_default_ref=$5
  shimmy_target_images_registry_access=$6
  shimmy_target_images_configured_digest=$(shimmy_images_digest_read "$shimmy_target_images_default_ref")
  shimmy_target_images_media_type=not-inspected
  shimmy_target_images_platform_result=not-inspected
  shimmy_target_images_access_result=$shimmy_target_images_registry_access
  shimmy_target_images_drift_result=not-checked
  shimmy_target_images_result_state=pass
  shimmy_target_images_error_category=none

  if [ "$shimmy_target_images_registry_access" = authenticated ]; then
    if [ "$SHIMMY_TARGET_IMAGES_PUBLIC_ONLY" -eq 1 ]; then
      shimmy_target_images_output_result "$shimmy_target_images_record_tool" "$shimmy_target_images_record_version" \
        "$shimmy_target_images_record_role" "$shimmy_target_images_configured_digest" "$shimmy_target_images_media_type" \
        "$shimmy_target_images_platform_result" skipped "$shimmy_target_images_drift_result" skip none
      return 0
    fi
    if [ -z "${SHIMMY_SKOPEO_AUTH_SECRET:-}" ]; then
      shimmy_target_images_output_result "$shimmy_target_images_record_tool" "$shimmy_target_images_record_version" \
        "$shimmy_target_images_record_role" "$shimmy_target_images_configured_digest" "$shimmy_target_images_media_type" \
        "$shimmy_target_images_platform_result" missing "$shimmy_target_images_drift_result" fail authentication-required
      return 1
    fi
  fi

  shimmy_images_cache_inspect raw "$shimmy_target_images_default_ref"
  if [ "$SHIMMY_IMAGES_CACHE_STATUS" != ok ]; then
    shimmy_target_images_output_result "$shimmy_target_images_record_tool" "$shimmy_target_images_record_version" \
      "$shimmy_target_images_record_role" "$shimmy_target_images_configured_digest" "$shimmy_target_images_media_type" \
      "$shimmy_target_images_platform_result" "$shimmy_target_images_access_result" \
      "$shimmy_target_images_drift_result" fail pinned-reference-unreachable
    return 1
  fi

  if shimmy_target_images_parsed_index=$(shimmy_images_index_parse < "$SHIMMY_IMAGES_CACHE_FILE" 2>/dev/null); then
    shimmy_target_images_parse_category=$(printf '%s\n' "$shimmy_target_images_parsed_index" | awk -F '\t' '{print $1}')
    shimmy_target_images_media_type=$(printf '%s\n' "$shimmy_target_images_parsed_index" | awk -F '\t' '{print $2}')
    shimmy_target_images_platform_result=$(printf '%s\n' "$shimmy_target_images_parsed_index" | awk -F '\t' '{print $3}')
  else
    shimmy_target_images_parse_category=malformed-json
    shimmy_target_images_media_type=unknown
    shimmy_target_images_platform_result=failed
  fi
  if [ "$shimmy_target_images_parse_category" != verified ]; then
    shimmy_target_images_output_result "$shimmy_target_images_record_tool" "$shimmy_target_images_record_version" \
      "$shimmy_target_images_record_role" "$shimmy_target_images_configured_digest" "$shimmy_target_images_media_type" \
      "$shimmy_target_images_platform_result" "$shimmy_target_images_access_result" \
      "$shimmy_target_images_drift_result" fail "$shimmy_target_images_parse_category"
    return 1
  fi

  case "$shimmy_target_images_upstream_ref" in
    *@sha256:*) shimmy_target_images_drift_result=not-applicable ;;
    *)
      shimmy_images_cache_inspect digest "$shimmy_target_images_upstream_ref"
      if [ "$SHIMMY_IMAGES_CACHE_STATUS" != ok ]; then
        shimmy_target_images_output_result "$shimmy_target_images_record_tool" "$shimmy_target_images_record_version" \
          "$shimmy_target_images_record_role" "$shimmy_target_images_configured_digest" "$shimmy_target_images_media_type" \
          "$shimmy_target_images_platform_result" "$shimmy_target_images_access_result" unreachable fail upstream-reference-unreachable
        return 1
      fi
      shimmy_target_images_upstream_digest=$(sed -n '1p' "$SHIMMY_IMAGES_CACHE_FILE")
      if ! shimmy_images_digest_validate "$shimmy_target_images_upstream_digest"; then
        shimmy_target_images_output_result "$shimmy_target_images_record_tool" "$shimmy_target_images_record_version" \
          "$shimmy_target_images_record_role" "$shimmy_target_images_configured_digest" "$shimmy_target_images_media_type" \
          "$shimmy_target_images_platform_result" "$shimmy_target_images_access_result" invalid fail upstream-digest-invalid
        return 1
      elif [ "$shimmy_target_images_upstream_digest" = "$shimmy_target_images_configured_digest" ]; then
        shimmy_target_images_drift_result=current
      else
        shimmy_target_images_drift_result=moved
        if [ "$SHIMMY_TARGET_IMAGES_REQUIRE_CURRENT_UPSTREAM" -eq 1 ]; then
          shimmy_target_images_result_state=fail
          shimmy_target_images_error_category=upstream-drift
        else
          shimmy_target_images_result_state=warning
        fi
      fi
      ;;
  esac

  shimmy_target_images_output_result "$shimmy_target_images_record_tool" "$shimmy_target_images_record_version" \
    "$shimmy_target_images_record_role" "$shimmy_target_images_configured_digest" "$shimmy_target_images_media_type" \
    "$shimmy_target_images_platform_result" "$shimmy_target_images_access_result" "$shimmy_target_images_drift_result" \
    "$shimmy_target_images_result_state" "$shimmy_target_images_error_category"
  [ "$shimmy_target_images_result_state" != fail ]
}

shimmy_target_images_verify_run() {
  shimmy_target_images_verify_config_root=$1
  shimmy_target_images_verify_requested_tools=${2:-}
  SHIMMY_TARGET_IMAGES_PUBLIC_ONLY=${3:-0}
  SHIMMY_TARGET_IMAGES_REQUIRE_CURRENT_UPSTREAM=${4:-0}
  SHIMMY_TARGET_IMAGES_OUTPUT_FORMAT=${5:-human}
  case "$SHIMMY_TARGET_IMAGES_OUTPUT_FORMAT" in human|manifest) ;; *) return 1 ;; esac

  shimmy_target_images_active_context_resolve "$shimmy_target_images_verify_config_root" || return 1
  shimmy_target_images_selected_versions=$(shimmy_target_images_selection_resolve "$shimmy_target_images_verify_requested_tools") || return 1
  [ -n "$shimmy_target_images_selected_versions" ] || {
    shimmy_target_images_error_set 'target catalog image verification selection is empty'
    return 1
  }

  shimmy_target_images_runtime_resolve skopeo || return 1
  SHIMMY_IMAGES_SKOPEO_RUNTIME=$SHIMMY_TARGET_IMAGES_RUNTIME_FILE
  shimmy_target_images_runtime_resolve jq || return 1
  SHIMMY_IMAGES_JQ_RUNTIME=$SHIMMY_TARGET_IMAGES_RUNTIME_FILE

  shimmy_target_images_tmp_parent=${TMPDIR:-/tmp}
  case "$shimmy_target_images_tmp_parent" in ''|/) shimmy_target_images_tmp_parent=/tmp ;; */) shimmy_target_images_tmp_parent=${shimmy_target_images_tmp_parent%/} ;; esac
  SHIMMY_IMAGES_CACHE_PARENT=$(cd -- "$shimmy_target_images_tmp_parent" && pwd -P) || {
    shimmy_target_images_error_set 'invalid target image verification temporary directory'
    return 1
  }
  SHIMMY_IMAGES_CACHE_DIR=$(mktemp -d "$SHIMMY_IMAGES_CACHE_PARENT/shimmy-target-images.XXXXXX") || {
    shimmy_target_images_error_set 'unable to create target image verification workspace'
    return 1
  }
  SHIMMY_IMAGES_CACHE_DIR=$(cd -- "$SHIMMY_IMAGES_CACHE_DIR" && pwd -P)
  SHIMMY_IMAGES_CACHE_INDEX=$SHIMMY_IMAGES_CACHE_DIR/cache
  SHIMMY_IMAGES_CACHE_COUNT=0
  shimmy_target_images_records_file=$SHIMMY_IMAGES_CACHE_DIR/records
  : > "$SHIMMY_IMAGES_CACHE_INDEX"
  : > "$shimmy_target_images_records_file"

  while IFS='|' read -r shimmy_target_images_tool_name shimmy_target_images_version_name shimmy_target_images_extra; do
    [ -n "$shimmy_target_images_tool_name" ] || continue
    [ -n "$shimmy_target_images_version_name" ] && [ -z "$shimmy_target_images_extra" ] || {
      shimmy_target_images_error_set 'invalid selected catalog tool/version pair'
      return 1
    }
    shimmy_images_config_records_print "$shimmy_target_images_tool_name" "$shimmy_target_images_version_name" \
      >> "$shimmy_target_images_records_file" || return 1
  done <<EOF
$shimmy_target_images_selected_versions
EOF

  shimmy_target_images_verification_failed=0
  while IFS='|' read -r shimmy_target_images_record_tool shimmy_target_images_record_version \
    shimmy_target_images_record_name shimmy_target_images_record_role shimmy_target_images_record_upstream \
    shimmy_target_images_record_default shimmy_target_images_record_access; do
    [ -n "$shimmy_target_images_record_tool" ] || continue
    shimmy_target_images_verify_record "$shimmy_target_images_record_tool" "$shimmy_target_images_record_version" \
      "$shimmy_target_images_record_role" "$shimmy_target_images_record_upstream" \
      "$shimmy_target_images_record_default" "$shimmy_target_images_record_access" || \
      shimmy_target_images_verification_failed=1
  done < "$shimmy_target_images_records_file"
  [ "$shimmy_target_images_verification_failed" -eq 0 ]
}
