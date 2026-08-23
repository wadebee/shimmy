#!/bin/sh
# Atomic engine registry projection and compensated service-recycle transaction.

shimmy_engine_projection_effective_fingerprint_render() {
  shimmy_engine_projection_effective_entries=${1:-}
  shimmy_engine_projection_effective_tmp=$(mktemp \
    "${TMPDIR:-/tmp}/shimmy-engine-policy.XXXXXX") || return 1
  printf '%s\n' "$shimmy_engine_projection_effective_entries" > \
    "$shimmy_engine_projection_effective_tmp" || return 1
  shimmy_engine_projection_effective_result=$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_engine_projection_effective_tmp") || {
    rm -f "$shimmy_engine_projection_effective_tmp"
    return 1
  }
  rm -f "$shimmy_engine_projection_effective_tmp"
  printf '%s\n' "$shimmy_engine_projection_effective_result"
}

shimmy_engine_projection_prefixes_render() {
  shimmy_engine_projection_prefix_entries=${1:-}
  while IFS='|' read -r shimmy_engine_projection_prefix \
    shimmy_engine_projection_location shimmy_engine_projection_extra; do
    [ -n "$shimmy_engine_projection_prefix" ] || continue
    [ -z "$shimmy_engine_projection_extra" ] || return 1
    printf '%s\n' "$shimmy_engine_projection_prefix"
  done <<EOF
$shimmy_engine_projection_prefix_entries
EOF
}

shimmy_engine_projection_prepare_artifacts_cleanup() {
  for shimmy_engine_projection_prepare_cleanup_path in \
    "${SHIMMY_ENGINE_PROJECTION_CONFIG_BACKUP:-}" \
    "${SHIMMY_ENGINE_PROJECTION_RECORD_BACKUP:-}" \
    "${SHIMMY_ENGINE_PROJECTION_CONFIG_STAGE:-}" \
    "${SHIMMY_ENGINE_PROJECTION_RECORD_STAGE:-}"; do
    case "$shimmy_engine_projection_prepare_cleanup_path" in
      "$SHIMMY_ENGINE_ROOT"/.registries.rollback.*|"$SHIMMY_ENGINE_ROOT"/.projection.rollback.*|"$SHIMMY_ENGINE_ROOT"/.registries.tmp.*|"$SHIMMY_ENGINE_ROOT"/.projection.tmp.*)
        rm -f "$shimmy_engine_projection_prepare_cleanup_path" || return 1
        ;;
    esac
  done
}

shimmy_engine_projection_prepare() {
  shimmy_engine_projection_prepare_id=$1
  shimmy_engine_projection_prepare_root=$2
  shimmy_engine_projection_prepare_source_profile=$3
  shimmy_engine_projection_prepare_source_path=$4
  shimmy_engine_projection_prepare_connection=$5
  shimmy_engine_id_validate "$shimmy_engine_projection_prepare_id" || return 1
  shimmy_name_component_validate "$shimmy_engine_projection_prepare_source_profile" || return 1
  shimmy_name_component_validate "$shimmy_engine_projection_prepare_connection" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_engine_projection_prepare_root" || return 1
  [ -d "$shimmy_engine_projection_prepare_root" ] &&
    [ ! -L "$shimmy_engine_projection_prepare_root" ] || return 1
  SHIMMY_ENGINE_ID=$shimmy_engine_projection_prepare_id
  SHIMMY_ENGINE_ROOT=$shimmy_engine_projection_prepare_root
  SHIMMY_ENGINE_REGISTRIES_PATH=$SHIMMY_ENGINE_ROOT/registries.conf
  SHIMMY_ENGINE_PROJECTION_PATH=$SHIMMY_ENGINE_ROOT/projection.conf
  SHIMMY_ENGINE_PROJECTION_CONNECTION=$shimmy_engine_projection_prepare_connection
  shimmy_registries_config_validate "$shimmy_engine_projection_prepare_source_path" \
    "$shimmy_engine_projection_prepare_source_profile" || return 1
  SHIMMY_ENGINE_PROJECTION_NEW_ENTRIES=$(shimmy_registries_config_entries_read \
    "$shimmy_engine_projection_prepare_source_path" \
    "$shimmy_engine_projection_prepare_source_profile") || return 1
  SHIMMY_ENGINE_PROJECTION_NEW_SOURCE_FINGERPRINT=$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_engine_projection_prepare_source_path") || return 1
  SHIMMY_ENGINE_PROJECTION_NEW_EFFECTIVE_FINGERPRINT=$(shimmy_engine_projection_effective_fingerprint_render \
    "$SHIMMY_ENGINE_PROJECTION_NEW_ENTRIES") || return 1

  SHIMMY_ENGINE_PROJECTION_PRIOR_EXISTS=0
  SHIMMY_ENGINE_PROJECTION_PRIOR_ENTRIES=
  SHIMMY_ENGINE_PROJECTION_PRIOR_LOADED=none
  SHIMMY_ENGINE_PROJECTION_CONFIG_BACKUP=$SHIMMY_ENGINE_ROOT/.registries.rollback.$$
  SHIMMY_ENGINE_PROJECTION_RECORD_BACKUP=$SHIMMY_ENGINE_ROOT/.projection.rollback.$$
  SHIMMY_ENGINE_PROJECTION_CONFIG_STAGE=$SHIMMY_ENGINE_ROOT/.registries.tmp.$$
  SHIMMY_ENGINE_PROJECTION_RECORD_STAGE=$SHIMMY_ENGINE_ROOT/.projection.tmp.$$
  for shimmy_engine_projection_prepare_temp in \
    "$SHIMMY_ENGINE_PROJECTION_CONFIG_BACKUP" \
    "$SHIMMY_ENGINE_PROJECTION_RECORD_BACKUP" \
    "$SHIMMY_ENGINE_PROJECTION_CONFIG_STAGE" \
    "$SHIMMY_ENGINE_PROJECTION_RECORD_STAGE"; do
    [ ! -e "$shimmy_engine_projection_prepare_temp" ] &&
      [ ! -L "$shimmy_engine_projection_prepare_temp" ] || return 1
  done

  if [ -e "$SHIMMY_ENGINE_REGISTRIES_PATH" ] || [ -L "$SHIMMY_ENGINE_REGISTRIES_PATH" ] ||
    [ -e "$SHIMMY_ENGINE_PROJECTION_PATH" ] || [ -L "$SHIMMY_ENGINE_PROJECTION_PATH" ]; then
    [ -f "$SHIMMY_ENGINE_REGISTRIES_PATH" ] && [ ! -L "$SHIMMY_ENGINE_REGISTRIES_PATH" ] || return 1
    shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_PATH" || return 1
    [ "$SHIMMY_ENGINE_PROJECTION_ID" = "$shimmy_engine_projection_prepare_id" ] || return 1
    shimmy_registries_config_validate "$SHIMMY_ENGINE_REGISTRIES_PATH" \
      "$SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE" || return 1
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_ENGINE_REGISTRIES_PATH")" = \
      "$SHIMMY_ENGINE_PROJECTION_SOURCE_FINGERPRINT" ] || return 1
    SHIMMY_ENGINE_PROJECTION_PRIOR_ENTRIES=$(shimmy_registries_config_entries_read \
      "$SHIMMY_ENGINE_REGISTRIES_PATH" "$SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE") || return 1
    [ "$(shimmy_engine_projection_effective_fingerprint_render \
      "$SHIMMY_ENGINE_PROJECTION_PRIOR_ENTRIES")" = \
      "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" ] || return 1
    SHIMMY_ENGINE_PROJECTION_PRIOR_LOADED=$SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT
    SHIMMY_ENGINE_PROJECTION_PRIOR_EXISTS=1
  fi

  cp "$shimmy_engine_projection_prepare_source_path" \
    "$SHIMMY_ENGINE_PROJECTION_CONFIG_STAGE" || {
    shimmy_engine_projection_prepare_artifacts_cleanup
    return 1
  }
  chmod 0644 "$SHIMMY_ENGINE_PROJECTION_CONFIG_STAGE" || {
    shimmy_engine_projection_prepare_artifacts_cleanup
    return 1
  }
  shimmy_registries_config_validate "$SHIMMY_ENGINE_PROJECTION_CONFIG_STAGE" \
    "$shimmy_engine_projection_prepare_source_profile" || {
    shimmy_engine_projection_prepare_artifacts_cleanup
    return 1
  }
  shimmy_engine_projection_render "$shimmy_engine_projection_prepare_id" \
    "$shimmy_engine_projection_prepare_source_profile" \
    "$shimmy_engine_projection_prepare_source_path" \
    "$SHIMMY_ENGINE_PROJECTION_NEW_SOURCE_FINGERPRINT" \
    "$SHIMMY_ENGINE_PROJECTION_NEW_EFFECTIVE_FINGERPRINT" \
    "$SHIMMY_ENGINE_PROJECTION_PRIOR_LOADED" > \
    "$SHIMMY_ENGINE_PROJECTION_RECORD_STAGE" || {
    shimmy_engine_projection_prepare_artifacts_cleanup
    return 1
  }
  chmod 0644 "$SHIMMY_ENGINE_PROJECTION_RECORD_STAGE" || {
    shimmy_engine_projection_prepare_artifacts_cleanup
    return 1
  }
  shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_RECORD_STAGE" || {
    shimmy_engine_projection_prepare_artifacts_cleanup
    return 1
  }
  if [ "$SHIMMY_ENGINE_PROJECTION_PRIOR_EXISTS" -eq 1 ]; then
    cp "$SHIMMY_ENGINE_REGISTRIES_PATH" "$SHIMMY_ENGINE_PROJECTION_CONFIG_BACKUP" || {
      shimmy_engine_projection_prepare_artifacts_cleanup
      return 1
    }
    cp "$SHIMMY_ENGINE_PROJECTION_PATH" "$SHIMMY_ENGINE_PROJECTION_RECORD_BACKUP" || {
      shimmy_engine_projection_prepare_artifacts_cleanup
      return 1
    }
    chmod 0644 "$SHIMMY_ENGINE_PROJECTION_CONFIG_BACKUP" \
      "$SHIMMY_ENGINE_PROJECTION_RECORD_BACKUP" || {
      shimmy_engine_projection_prepare_artifacts_cleanup
      return 1
    }
  fi
  mv "$SHIMMY_ENGINE_PROJECTION_CONFIG_STAGE" "$SHIMMY_ENGINE_REGISTRIES_PATH" || {
    shimmy_engine_projection_prepare_artifacts_cleanup
    return 1
  }
  if ! mv "$SHIMMY_ENGINE_PROJECTION_RECORD_STAGE" "$SHIMMY_ENGINE_PROJECTION_PATH"; then
    if [ "$SHIMMY_ENGINE_PROJECTION_PRIOR_EXISTS" -eq 1 ]; then
      mv "$SHIMMY_ENGINE_PROJECTION_CONFIG_BACKUP" "$SHIMMY_ENGINE_REGISTRIES_PATH" || return 1
    else
      rm -f "$SHIMMY_ENGINE_REGISTRIES_PATH" || return 1
    fi
    shimmy_engine_projection_prepare_artifacts_cleanup
    return 1
  fi
  SHIMMY_ENGINE_PROJECTION_APPLIED=1
  SHIMMY_ENGINE_PROJECTION_SERVICE_RECYCLED=0
  if [ "$SHIMMY_ENGINE_PROJECTION_PRIOR_LOADED" = \
    "$SHIMMY_ENGINE_PROJECTION_NEW_EFFECTIVE_FINGERPRINT" ]; then
    SHIMMY_ENGINE_PROJECTION_ACTION=none
  else
    SHIMMY_ENGINE_PROJECTION_ACTION=recycle-podman-service
  fi
}

shimmy_engine_projection_prefix_union_render() {
  {
    shimmy_engine_projection_prefixes_render "${SHIMMY_ENGINE_PROJECTION_PRIOR_ENTRIES:-}"
    shimmy_engine_projection_prefixes_render "${SHIMMY_ENGINE_PROJECTION_NEW_ENTRIES:-}"
  } | sed '/^$/d' | LC_ALL=C sort -u
}

shimmy_engine_projection_loaded_record_update() {
  shimmy_engine_projection_read "$SHIMMY_ENGINE_PROJECTION_PATH" || return 1
  shimmy_engine_projection_loaded_stage=$SHIMMY_ENGINE_ROOT/.projection.loaded.$$
  [ ! -e "$shimmy_engine_projection_loaded_stage" ] &&
    [ ! -L "$shimmy_engine_projection_loaded_stage" ] || return 1
  shimmy_engine_projection_render "$SHIMMY_ENGINE_PROJECTION_ID" \
    "$SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE" "$SHIMMY_ENGINE_PROJECTION_SOURCE_PATH" \
    "$SHIMMY_ENGINE_PROJECTION_SOURCE_FINGERPRINT" \
    "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" \
    "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" > \
    "$shimmy_engine_projection_loaded_stage" || return 1
  shimmy_engine_projection_read "$shimmy_engine_projection_loaded_stage" || {
    rm -f "$shimmy_engine_projection_loaded_stage"
    return 1
  }
  shimmy_engine_state_candidate_replace "$shimmy_engine_projection_loaded_stage" \
    "$SHIMMY_ENGINE_PROJECTION_PATH" "$SHIMMY_ENGINE_ROOT"
}

shimmy_engine_projection_apply() {
  shimmy_engine_projection_machine=$1
  [ "${SHIMMY_ENGINE_PROJECTION_APPLIED:-0}" -eq 1 ] || return 1
  if [ "$SHIMMY_ENGINE_PROJECTION_ACTION" = recycle-podman-service ]; then
    shimmy_engine_podman_service_recycle "$shimmy_engine_projection_machine" \
      "$SHIMMY_ENGINE_PROJECTION_CONNECTION" || return 1
    SHIMMY_ENGINE_PROJECTION_SERVICE_RECYCLED=1
  fi
  shimmy_engine_projection_prefixes=$(shimmy_engine_projection_prefix_union_render) || return 1
  shimmy_engine_podman_registry_entries_validate "$SHIMMY_ENGINE_PROJECTION_CONNECTION" \
    "$SHIMMY_ENGINE_PROJECTION_NEW_ENTRIES" "$shimmy_engine_projection_prefixes" || return 1
  shimmy_engine_projection_loaded_record_update
}

shimmy_engine_projection_rollback() {
  shimmy_engine_projection_machine=$1
  [ "${SHIMMY_ENGINE_PROJECTION_APPLIED:-0}" -eq 1 ] || return 0
  shimmy_engine_projection_rollback_complete=1
  if [ "$SHIMMY_ENGINE_PROJECTION_PRIOR_EXISTS" -eq 1 ]; then
    mv "$SHIMMY_ENGINE_PROJECTION_CONFIG_BACKUP" "$SHIMMY_ENGINE_REGISTRIES_PATH" ||
      shimmy_engine_projection_rollback_complete=0
    mv "$SHIMMY_ENGINE_PROJECTION_RECORD_BACKUP" "$SHIMMY_ENGINE_PROJECTION_PATH" ||
      shimmy_engine_projection_rollback_complete=0
  else
    rm -f "$SHIMMY_ENGINE_REGISTRIES_PATH" "$SHIMMY_ENGINE_PROJECTION_PATH" ||
      shimmy_engine_projection_rollback_complete=0
  fi
  if [ "${SHIMMY_ENGINE_PROJECTION_SERVICE_RECYCLED:-0}" -eq 1 ]; then
    shimmy_engine_podman_service_recycle "$shimmy_engine_projection_machine" \
      "$SHIMMY_ENGINE_PROJECTION_CONNECTION" || shimmy_engine_projection_rollback_complete=0
    shimmy_engine_projection_prefixes=$(shimmy_engine_projection_prefix_union_render) ||
      shimmy_engine_projection_rollback_complete=0
    shimmy_engine_podman_registry_entries_validate "$SHIMMY_ENGINE_PROJECTION_CONNECTION" \
      "$SHIMMY_ENGINE_PROJECTION_PRIOR_ENTRIES" "$shimmy_engine_projection_prefixes" ||
      shimmy_engine_projection_rollback_complete=0
  fi
  SHIMMY_ENGINE_PROJECTION_APPLIED=0
  [ "$shimmy_engine_projection_rollback_complete" -eq 1 ]
}

shimmy_engine_projection_commit() {
  [ "${SHIMMY_ENGINE_PROJECTION_APPLIED:-0}" -eq 1 ] || return 1
  for shimmy_engine_projection_commit_backup in \
    "${SHIMMY_ENGINE_PROJECTION_CONFIG_BACKUP:-}" \
    "${SHIMMY_ENGINE_PROJECTION_RECORD_BACKUP:-}"; do
    case "$shimmy_engine_projection_commit_backup" in
      "$SHIMMY_ENGINE_ROOT"/.registries.rollback.*|"$SHIMMY_ENGINE_ROOT"/.projection.rollback.*)
        rm -f "$shimmy_engine_projection_commit_backup" || return 1
        ;;
    esac
  done
  SHIMMY_ENGINE_PROJECTION_APPLIED=0
}
