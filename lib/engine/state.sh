#!/bin/sh
# Strict schema-1 engine and profile-binding state.

shimmy_engine_id_validate() {
  shimmy_engine_id_value=${1:-}
  case "$shimmy_engine_id_value" in
    shared) return 0 ;;
    profile-*) shimmy_name_component_validate "${shimmy_engine_id_value#profile-}" ;;
    *) return 1 ;;
  esac
}

shimmy_engine_paths_resolve() {
  shimmy_engine_paths_config_root=$1
  shimmy_engine_paths_id=$2
  shimmy_path_absolute_normalized_validate "$shimmy_engine_paths_config_root" || return 1
  shimmy_engine_id_validate "$shimmy_engine_paths_id" || return 1
  SHIMMY_ENGINES_ROOT=$shimmy_engine_paths_config_root/engines
  SHIMMY_ENGINE_ID=$shimmy_engine_paths_id
  SHIMMY_ENGINE_ROOT=$SHIMMY_ENGINES_ROOT/$shimmy_engine_paths_id
  SHIMMY_ENGINE_RECORD_PATH=$SHIMMY_ENGINE_ROOT/engine.conf
  SHIMMY_ENGINE_REGISTRIES_PATH=$SHIMMY_ENGINE_ROOT/registries.conf
  SHIMMY_ENGINE_PROJECTION_PATH=$SHIMMY_ENGINE_ROOT/projection.conf
  SHIMMY_ENGINE_LIFECYCLE_PATH=$SHIMMY_ENGINE_ROOT/lifecycle.conf
  shimmy_path_parent_chain_validate "$SHIMMY_ENGINE_ROOT"
}

shimmy_engine_state_file_validate() {
  shimmy_engine_state_file=$1
  shimmy_text_file_validate "$shimmy_engine_state_file" || return 1
  if shimmy_engine_state_mode=$(stat -c '%a' "$shimmy_engine_state_file" 2>/dev/null); then
    :
  else
    shimmy_engine_state_mode=$(stat -f '%Lp' "$shimmy_engine_state_file" 2>/dev/null) || return 1
  fi
  [ "$shimmy_engine_state_mode" = 644 ]
}

shimmy_engine_profile_registry_path_validate() {
  shimmy_engine_profile_registry_path=$1
  shimmy_engine_profile_registry_profile=$2
  shimmy_path_absolute_normalized_validate "$shimmy_engine_profile_registry_path" || return 1
  [ "${shimmy_engine_profile_registry_path%/registries.conf}" != \
    "$shimmy_engine_profile_registry_path" ] || return 1
  shimmy_engine_profile_registry_root=${shimmy_engine_profile_registry_path%/registries.conf}
  [ "${shimmy_engine_profile_registry_root##*/}" = \
    "$shimmy_engine_profile_registry_profile" ] || return 1
  shimmy_engine_profile_registry_profiles=${shimmy_engine_profile_registry_root%/*}
  case "$shimmy_engine_profile_registry_profiles" in
    /shimmy/profiles|*/shimmy/profiles) ;;
    *) return 1 ;;
  esac
}

shimmy_engine_binding_render() {
  shimmy_engine_binding_profile=$1
  shimmy_engine_binding_mode=$2
  shimmy_engine_binding_id=$3
  shimmy_name_component_validate "$shimmy_engine_binding_profile" || return 1
  shimmy_engine_id_validate "$shimmy_engine_binding_id" || return 1
  case "$shimmy_engine_binding_mode|$shimmy_engine_binding_id" in
    shared\|shared) ;;
    isolated\|profile-"$shimmy_engine_binding_profile") ;;
    *) return 1 ;;
  esac
  printf '%s\n' 'shimmy_engine_binding_version=1'
  printf 'profile=%s\n' "$shimmy_engine_binding_profile"
  printf 'mode=%s\n' "$shimmy_engine_binding_mode"
  printf 'engine=%s\n' "$shimmy_engine_binding_id"
}

shimmy_engine_binding_read() {
  shimmy_engine_binding_file=$1
  shimmy_engine_state_file_validate "$shimmy_engine_binding_file" || return 1
  SHIMMY_ENGINE_BINDING_PROFILE=$(sed -n '2s/^profile=//p' "$shimmy_engine_binding_file")
  SHIMMY_ENGINE_BINDING_MODE=$(sed -n '3s/^mode=//p' "$shimmy_engine_binding_file")
  SHIMMY_ENGINE_BINDING_ID=$(sed -n '4s/^engine=//p' "$shimmy_engine_binding_file")
  [ "$(shimmy_engine_binding_render "$SHIMMY_ENGINE_BINDING_PROFILE" \
    "$SHIMMY_ENGINE_BINDING_MODE" "$SHIMMY_ENGINE_BINDING_ID")" = \
    "$(cat "$shimmy_engine_binding_file")" ]
}

shimmy_engine_token_validate() {
  shimmy_engine_token_value=${1:-}
  [ "${#shimmy_engine_token_value}" -eq 64 ] || return 1
  case "$shimmy_engine_token_value" in *[!0123456789abcdef]*) return 1 ;; esac
}

shimmy_engine_record_render() {
  shimmy_engine_record_id=$1
  shimmy_engine_record_kind=$2
  shimmy_engine_record_scope=$3
  shimmy_engine_record_name=$4
  shimmy_engine_record_connection=$5
  shimmy_engine_record_provider=$6
  shimmy_engine_record_origin=$7
  shimmy_engine_record_token=${8:-}
  shimmy_engine_record_identity=${9:-}

  shimmy_engine_id_validate "$shimmy_engine_record_id" || return 1
  for shimmy_engine_record_scalar in "$shimmy_engine_record_name" \
    "$shimmy_engine_record_connection" "$shimmy_engine_record_provider"; do
    shimmy_scalar_value_validate "$shimmy_engine_record_scalar" || return 1
  done
  case "$shimmy_engine_record_kind|$shimmy_engine_record_scope|$shimmy_engine_record_origin" in
    darwin-machine\|installation\|shimmy-created)
      [ "$shimmy_engine_record_id" = shared ] || return 1
      ;;
    darwin-machine\|profile\|shimmy-created|darwin-machine\|profile\|external)
      case "$shimmy_engine_record_id" in profile-*) ;; *) return 1 ;; esac
      ;;
    linux-rootless\|installation\|host-local)
      [ "$shimmy_engine_record_id" = shared ] &&
        [ "$shimmy_engine_record_name" = local ] &&
        [ "$shimmy_engine_record_connection" = local ] &&
        [ "$shimmy_engine_record_provider" = none ] &&
        [ -z "$shimmy_engine_record_token" ] &&
        [ -z "$shimmy_engine_record_identity" ] || return 1
      ;;
    *) return 1 ;;
  esac
  case "$shimmy_engine_record_kind" in
    darwin-machine)
      shimmy_name_component_validate "$shimmy_engine_record_name" || return 1
      shimmy_name_component_validate "$shimmy_engine_record_connection" || return 1
      shimmy_version_token_validate "$shimmy_engine_record_provider" || return 1
      case "$shimmy_engine_record_origin" in
        shimmy-created)
          shimmy_engine_token_validate "$shimmy_engine_record_token" || return 1
          shimmy_sha256_fingerprint_validate "$shimmy_engine_record_identity" || return 1
          ;;
        external)
          [ -z "$shimmy_engine_record_token" ] || return 1
          [ -z "$shimmy_engine_record_identity" ] ||
            shimmy_sha256_fingerprint_validate "$shimmy_engine_record_identity" || return 1
          ;;
      esac
      ;;
  esac

  printf '%s\n' 'shimmy_engine_version=1'
  printf 'engine=%s\n' "$shimmy_engine_record_id"
  printf 'kind=%s\n' "$shimmy_engine_record_kind"
  printf 'scope=%s\n' "$shimmy_engine_record_scope"
  printf 'name=%s\n' "$shimmy_engine_record_name"
  printf 'connection=%s\n' "$shimmy_engine_record_connection"
  printf 'provider=%s\n' "$shimmy_engine_record_provider"
  printf 'origin=%s\n' "$shimmy_engine_record_origin"
  printf 'ownership_token=%s\n' "$shimmy_engine_record_token"
  printf 'created_identity=%s\n' "$shimmy_engine_record_identity"
}

shimmy_engine_record_read() {
  shimmy_engine_record_file=$1
  shimmy_engine_state_file_validate "$shimmy_engine_record_file" || return 1
  SHIMMY_ENGINE_RECORD_ID=$(sed -n '2s/^engine=//p' "$shimmy_engine_record_file")
  SHIMMY_ENGINE_RECORD_KIND=$(sed -n '3s/^kind=//p' "$shimmy_engine_record_file")
  SHIMMY_ENGINE_RECORD_SCOPE=$(sed -n '4s/^scope=//p' "$shimmy_engine_record_file")
  SHIMMY_ENGINE_RECORD_NAME=$(sed -n '5s/^name=//p' "$shimmy_engine_record_file")
  SHIMMY_ENGINE_RECORD_CONNECTION=$(sed -n '6s/^connection=//p' "$shimmy_engine_record_file")
  SHIMMY_ENGINE_RECORD_PROVIDER=$(sed -n '7s/^provider=//p' "$shimmy_engine_record_file")
  SHIMMY_ENGINE_RECORD_ORIGIN=$(sed -n '8s/^origin=//p' "$shimmy_engine_record_file")
  SHIMMY_ENGINE_RECORD_OWNERSHIP_TOKEN=$(sed -n '9s/^ownership_token=//p' "$shimmy_engine_record_file")
  SHIMMY_ENGINE_RECORD_CREATED_IDENTITY=$(sed -n '10s/^created_identity=//p' "$shimmy_engine_record_file")
  [ "$(shimmy_engine_record_render "$SHIMMY_ENGINE_RECORD_ID" \
    "$SHIMMY_ENGINE_RECORD_KIND" "$SHIMMY_ENGINE_RECORD_SCOPE" \
    "$SHIMMY_ENGINE_RECORD_NAME" "$SHIMMY_ENGINE_RECORD_CONNECTION" \
    "$SHIMMY_ENGINE_RECORD_PROVIDER" "$SHIMMY_ENGINE_RECORD_ORIGIN" \
    "$SHIMMY_ENGINE_RECORD_OWNERSHIP_TOKEN" \
    "$SHIMMY_ENGINE_RECORD_CREATED_IDENTITY")" = "$(cat "$shimmy_engine_record_file")" ]
}

shimmy_engine_projection_render() {
  shimmy_engine_projection_id=$1
  shimmy_engine_projection_profile=$2
  shimmy_engine_projection_source_path=$3
  shimmy_engine_projection_source_fingerprint=$4
  shimmy_engine_projection_effective_fingerprint=$5
  shimmy_engine_projection_loaded_fingerprint=$6
  shimmy_engine_id_validate "$shimmy_engine_projection_id" || return 1
  shimmy_name_component_validate "$shimmy_engine_projection_profile" || return 1
  shimmy_engine_profile_registry_path_validate "$shimmy_engine_projection_source_path" \
    "$shimmy_engine_projection_profile" || return 1
  shimmy_sha256_fingerprint_validate "$shimmy_engine_projection_source_fingerprint" || return 1
  shimmy_sha256_fingerprint_validate "$shimmy_engine_projection_effective_fingerprint" || return 1
  case "$shimmy_engine_projection_loaded_fingerprint" in
    none) ;;
    *) shimmy_sha256_fingerprint_validate "$shimmy_engine_projection_loaded_fingerprint" || return 1 ;;
  esac
  printf '%s\n' 'shimmy_engine_projection_version=1'
  printf 'engine=%s\n' "$shimmy_engine_projection_id"
  printf 'source_profile=%s\n' "$shimmy_engine_projection_profile"
  printf 'source_path=%s\n' "$shimmy_engine_projection_source_path"
  printf 'source_fingerprint=%s\n' "$shimmy_engine_projection_source_fingerprint"
  printf 'effective_fingerprint=%s\n' "$shimmy_engine_projection_effective_fingerprint"
  printf 'loaded_fingerprint=%s\n' "$shimmy_engine_projection_loaded_fingerprint"
}

shimmy_engine_projection_read() {
  shimmy_engine_projection_file=$1
  shimmy_engine_state_file_validate "$shimmy_engine_projection_file" || return 1
  SHIMMY_ENGINE_PROJECTION_ID=$(sed -n '2s/^engine=//p' "$shimmy_engine_projection_file")
  SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE=$(sed -n '3s/^source_profile=//p' "$shimmy_engine_projection_file")
  SHIMMY_ENGINE_PROJECTION_SOURCE_PATH=$(sed -n '4s/^source_path=//p' "$shimmy_engine_projection_file")
  SHIMMY_ENGINE_PROJECTION_SOURCE_FINGERPRINT=$(sed -n '5s/^source_fingerprint=//p' "$shimmy_engine_projection_file")
  SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT=$(sed -n '6s/^effective_fingerprint=//p' "$shimmy_engine_projection_file")
  SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT=$(sed -n '7s/^loaded_fingerprint=//p' "$shimmy_engine_projection_file")
  [ "$(shimmy_engine_projection_render "$SHIMMY_ENGINE_PROJECTION_ID" \
    "$SHIMMY_ENGINE_PROJECTION_SOURCE_PROFILE" "$SHIMMY_ENGINE_PROJECTION_SOURCE_PATH" \
    "$SHIMMY_ENGINE_PROJECTION_SOURCE_FINGERPRINT" \
    "$SHIMMY_ENGINE_PROJECTION_EFFECTIVE_FINGERPRINT" \
    "$SHIMMY_ENGINE_PROJECTION_LOADED_FINGERPRINT")" = \
    "$(cat "$shimmy_engine_projection_file")" ]
}

shimmy_engine_lifecycle_phase_validate() {
  shimmy_engine_lifecycle_operation=$1
  shimmy_engine_lifecycle_phase=$2
  case "$shimmy_engine_lifecycle_operation|$shimmy_engine_lifecycle_phase" in
    create\|planned|create\|initializing|create\|initialized|create\|recorded|create\|starting|create\|started|create\|guest-marking|create\|guest-marked|create\|committed|remove\|planned|remove\|verification-starting|remove\|verification-started|remove\|verified|remove\|stopping|remove\|stopped|remove\|removing|remove\|removed|remove\|committed) ;;
    *) return 1 ;;
  esac
}

shimmy_engine_lifecycle_render() {
  shimmy_engine_lifecycle_id=$1
  shimmy_engine_lifecycle_operation=$2
  shimmy_engine_lifecycle_phase=$3
  shimmy_engine_lifecycle_name=$4
  shimmy_engine_lifecycle_connection=$5
  shimmy_engine_lifecycle_initial_state=$6
  shimmy_engine_lifecycle_token=${7:-}
  shimmy_engine_lifecycle_identity=${8:-}
  shimmy_engine_id_validate "$shimmy_engine_lifecycle_id" || return 1
  shimmy_engine_lifecycle_phase_validate "$shimmy_engine_lifecycle_operation" \
    "$shimmy_engine_lifecycle_phase" || return 1
  shimmy_name_component_validate "$shimmy_engine_lifecycle_name" || return 1
  shimmy_name_component_validate "$shimmy_engine_lifecycle_connection" || return 1
  case "$shimmy_engine_lifecycle_operation|$shimmy_engine_lifecycle_initial_state" in
    create\|absent|remove\|running|remove\|stopped) ;;
    *) return 1 ;;
  esac
  case "$shimmy_engine_lifecycle_operation|$shimmy_engine_lifecycle_phase" in
    create\|planned|create\|initializing)
      [ -z "$shimmy_engine_lifecycle_token" ] &&
        [ -z "$shimmy_engine_lifecycle_identity" ] || return 1
      ;;
    *)
      shimmy_engine_token_validate "$shimmy_engine_lifecycle_token" || return 1
      shimmy_sha256_fingerprint_validate "$shimmy_engine_lifecycle_identity" || return 1
      ;;
  esac
  printf '%s\n' 'shimmy_engine_lifecycle_version=1'
  printf 'engine=%s\n' "$shimmy_engine_lifecycle_id"
  printf 'operation=%s\n' "$shimmy_engine_lifecycle_operation"
  printf 'phase=%s\n' "$shimmy_engine_lifecycle_phase"
  printf 'name=%s\n' "$shimmy_engine_lifecycle_name"
  printf 'connection=%s\n' "$shimmy_engine_lifecycle_connection"
  printf 'initial_machine_state=%s\n' "$shimmy_engine_lifecycle_initial_state"
  printf 'ownership_token=%s\n' "$shimmy_engine_lifecycle_token"
  printf 'created_identity=%s\n' "$shimmy_engine_lifecycle_identity"
}

shimmy_engine_lifecycle_read() {
  shimmy_engine_lifecycle_file=$1
  shimmy_engine_state_file_validate "$shimmy_engine_lifecycle_file" || return 1
  SHIMMY_ENGINE_LIFECYCLE_ID=$(sed -n '2s/^engine=//p' "$shimmy_engine_lifecycle_file")
  SHIMMY_ENGINE_LIFECYCLE_OPERATION=$(sed -n '3s/^operation=//p' "$shimmy_engine_lifecycle_file")
  SHIMMY_ENGINE_LIFECYCLE_PHASE=$(sed -n '4s/^phase=//p' "$shimmy_engine_lifecycle_file")
  SHIMMY_ENGINE_LIFECYCLE_NAME=$(sed -n '5s/^name=//p' "$shimmy_engine_lifecycle_file")
  SHIMMY_ENGINE_LIFECYCLE_CONNECTION=$(sed -n '6s/^connection=//p' "$shimmy_engine_lifecycle_file")
  SHIMMY_ENGINE_LIFECYCLE_INITIAL_MACHINE_STATE=$(sed -n '7s/^initial_machine_state=//p' "$shimmy_engine_lifecycle_file")
  SHIMMY_ENGINE_LIFECYCLE_OWNERSHIP_TOKEN=$(sed -n '8s/^ownership_token=//p' "$shimmy_engine_lifecycle_file")
  SHIMMY_ENGINE_LIFECYCLE_CREATED_IDENTITY=$(sed -n '9s/^created_identity=//p' "$shimmy_engine_lifecycle_file")
  [ "$(shimmy_engine_lifecycle_render "$SHIMMY_ENGINE_LIFECYCLE_ID" \
    "$SHIMMY_ENGINE_LIFECYCLE_OPERATION" "$SHIMMY_ENGINE_LIFECYCLE_PHASE" \
    "$SHIMMY_ENGINE_LIFECYCLE_NAME" "$SHIMMY_ENGINE_LIFECYCLE_CONNECTION" \
    "$SHIMMY_ENGINE_LIFECYCLE_INITIAL_MACHINE_STATE" \
    "$SHIMMY_ENGINE_LIFECYCLE_OWNERSHIP_TOKEN" \
    "$SHIMMY_ENGINE_LIFECYCLE_CREATED_IDENTITY")" = \
    "$(cat "$shimmy_engine_lifecycle_file")" ]
}

shimmy_engine_state_candidate_replace() {
  shimmy_engine_state_candidate=$1
  shimmy_engine_state_target=$2
  shimmy_engine_state_parent=$3
  [ "$(dirname -- "$shimmy_engine_state_candidate")" = "$shimmy_engine_state_parent" ] || return 1
  [ "$(dirname -- "$shimmy_engine_state_target")" = "$shimmy_engine_state_parent" ] || return 1
  [ -d "$shimmy_engine_state_parent" ] && [ ! -L "$shimmy_engine_state_parent" ] || return 1
  shimmy_path_parent_chain_validate "$shimmy_engine_state_parent" || return 1
  [ -f "$shimmy_engine_state_candidate" ] && [ ! -L "$shimmy_engine_state_candidate" ] || return 1
  if [ -e "$shimmy_engine_state_target" ] || [ -L "$shimmy_engine_state_target" ]; then
    [ -f "$shimmy_engine_state_target" ] && [ ! -L "$shimmy_engine_state_target" ] || return 1
  fi
  chmod 0644 "$shimmy_engine_state_candidate" || return 1
  mv "$shimmy_engine_state_candidate" "$shimmy_engine_state_target"
}

shimmy_engine_binding_write() {
  shimmy_engine_binding_write_path=$1
  shimmy_engine_binding_write_profile=$2
  shimmy_engine_binding_write_mode=$3
  shimmy_engine_binding_write_id=$4
  shimmy_engine_binding_write_root=$(dirname -- "$shimmy_engine_binding_write_path")
  [ -d "$shimmy_engine_binding_write_root" ] &&
    [ ! -L "$shimmy_engine_binding_write_root" ] || return 1
  shimmy_engine_binding_write_stage=$shimmy_engine_binding_write_root/.engine-binding.tmp.$$
  [ ! -e "$shimmy_engine_binding_write_stage" ] &&
    [ ! -L "$shimmy_engine_binding_write_stage" ] || return 1
  shimmy_engine_binding_render "$shimmy_engine_binding_write_profile" \
    "$shimmy_engine_binding_write_mode" "$shimmy_engine_binding_write_id" \
    > "$shimmy_engine_binding_write_stage" || {
      rm -f "$shimmy_engine_binding_write_stage"
      return 1
    }
  chmod 0644 "$shimmy_engine_binding_write_stage" || {
    rm -f "$shimmy_engine_binding_write_stage"
    return 1
  }
  shimmy_engine_binding_read "$shimmy_engine_binding_write_stage" || {
    rm -f "$shimmy_engine_binding_write_stage"
    return 1
  }
  shimmy_engine_state_candidate_replace "$shimmy_engine_binding_write_stage" \
    "$shimmy_engine_binding_write_path" "$shimmy_engine_binding_write_root"
}

shimmy_engine_record_write() {
  shimmy_engine_record_write_path=$1
  shift
  shimmy_engine_record_write_root=$(dirname -- "$shimmy_engine_record_write_path")
  [ -d "$shimmy_engine_record_write_root" ] &&
    [ ! -L "$shimmy_engine_record_write_root" ] || return 1
  shimmy_engine_record_write_stage=$shimmy_engine_record_write_root/.engine.tmp.$$
  [ ! -e "$shimmy_engine_record_write_stage" ] &&
    [ ! -L "$shimmy_engine_record_write_stage" ] || return 1
  shimmy_engine_record_render "$@" > "$shimmy_engine_record_write_stage" || {
    rm -f "$shimmy_engine_record_write_stage"
    return 1
  }
  chmod 0644 "$shimmy_engine_record_write_stage" || {
    rm -f "$shimmy_engine_record_write_stage"
    return 1
  }
  shimmy_engine_record_read "$shimmy_engine_record_write_stage" || {
    rm -f "$shimmy_engine_record_write_stage"
    return 1
  }
  shimmy_engine_state_candidate_replace "$shimmy_engine_record_write_stage" \
    "$shimmy_engine_record_write_path" "$shimmy_engine_record_write_root"
}

shimmy_engine_profile_binding_resolve() {
  shimmy_engine_binding_config=$1
  shimmy_engine_binding_profile=$2
  shimmy_path_absolute_normalized_validate "$shimmy_engine_binding_config" || return 1
  shimmy_name_component_validate "$shimmy_engine_binding_profile" || return 1
  shimmy_engine_binding_profile_root=$shimmy_engine_binding_config/profiles/$shimmy_engine_binding_profile
  SHIMMY_PROFILE_ENGINE_BINDING_PATH=$shimmy_engine_binding_profile_root/engine-binding.conf
  shimmy_engine_binding_read "$SHIMMY_PROFILE_ENGINE_BINDING_PATH" || return 1
  [ "$SHIMMY_ENGINE_BINDING_PROFILE" = "$shimmy_engine_binding_profile" ] || return 1
  shimmy_engine_paths_resolve "$shimmy_engine_binding_config" \
    "$SHIMMY_ENGINE_BINDING_ID" || return 1
  shimmy_engine_record_read "$SHIMMY_ENGINE_RECORD_PATH" || return 1
  [ "$SHIMMY_ENGINE_RECORD_ID" = "$SHIMMY_ENGINE_BINDING_ID" ] || return 1
  case "$SHIMMY_ENGINE_BINDING_MODE|$SHIMMY_ENGINE_RECORD_KIND|$SHIMMY_ENGINE_RECORD_SCOPE|$SHIMMY_ENGINE_RECORD_ORIGIN" in
    shared\|darwin-machine\|installation\|shimmy-created|shared\|linux-rootless\|installation\|host-local) ;;
    isolated\|darwin-machine\|profile\|shimmy-created) ;;
    *) return 1 ;;
  esac
  SHIMMY_PROFILE_ENGINE_BINDING_MODE=$SHIMMY_ENGINE_BINDING_MODE
  SHIMMY_PROFILE_ENGINE_ID=$SHIMMY_ENGINE_BINDING_ID
  SHIMMY_PROFILE_ENGINE_KIND=$SHIMMY_ENGINE_RECORD_KIND
  SHIMMY_PROFILE_ENGINE_ORIGIN=$SHIMMY_ENGINE_RECORD_ORIGIN
  SHIMMY_PROFILE_EXPECTED_MACHINE=$SHIMMY_ENGINE_RECORD_NAME
  SHIMMY_PROFILE_EXPECTED_CONNECTION=$SHIMMY_ENGINE_RECORD_CONNECTION
  SHIMMY_PROFILE_ENGINE_RECORD_PATH=$SHIMMY_ENGINE_RECORD_PATH
}

shimmy_engine_installation_validate() {
  shimmy_engine_schema_config=$1
  shimmy_path_absolute_normalized_validate "$shimmy_engine_schema_config" || return 1
  SHIMMY_ENGINE_INSTALLATION_PROFILE_COUNT=0
  [ -d "$shimmy_engine_schema_config/profiles" ] &&
    [ ! -L "$shimmy_engine_schema_config/profiles" ] || return 1
  for shimmy_engine_schema_profile_root in "$shimmy_engine_schema_config"/profiles/*; do
    [ -e "$shimmy_engine_schema_profile_root" ] ||
      [ -L "$shimmy_engine_schema_profile_root" ] || continue
    shimmy_engine_schema_profile=$(basename -- "$shimmy_engine_schema_profile_root")
    shimmy_name_component_validate "$shimmy_engine_schema_profile" &&
      [ -d "$shimmy_engine_schema_profile_root" ] &&
      [ ! -L "$shimmy_engine_schema_profile_root" ] || return 1
    SHIMMY_ENGINE_INSTALLATION_PROFILE_COUNT=$((SHIMMY_ENGINE_INSTALLATION_PROFILE_COUNT + 1))
    shimmy_engine_profile_binding_resolve "$shimmy_engine_schema_config" \
      "$shimmy_engine_schema_profile" || return 1
  done
  [ "$SHIMMY_ENGINE_INSTALLATION_PROFILE_COUNT" -gt 0 ] || return 1
  [ -d "$shimmy_engine_schema_config/engines" ] &&
    [ ! -L "$shimmy_engine_schema_config/engines" ]
}
