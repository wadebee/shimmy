#!/bin/sh
# Strict profile-owned containers/image registry redirect data.

shimmy_registries_active_link_parent_validate() {
  [ -n "${SHIMMY_REGISTRIES_CONFIG_DIR:-}" ] &&
    [ -n "${SHIMMY_REGISTRIES_DROPIN_DIR:-}" ] &&
    [ -n "${SHIMMY_REGISTRIES_ACTIVE_LINK:-}" ] || return 1
  [ "$SHIMMY_REGISTRIES_DROPIN_DIR" = "$SHIMMY_REGISTRIES_CONFIG_DIR/registries.conf.d" ] &&
    [ "$SHIMMY_REGISTRIES_ACTIVE_LINK" = "$SHIMMY_REGISTRIES_DROPIN_DIR/shimmy-active-profile.conf" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_REGISTRIES_CONFIG_DIR" || return 1
  for parent_path in "$SHIMMY_REGISTRIES_CONFIG_DIR" "$SHIMMY_REGISTRIES_DROPIN_DIR"; do
    if [ -e "$parent_path" ] || [ -L "$parent_path" ]; then
      [ -d "$parent_path" ] && [ ! -L "$parent_path" ] || return 1
    fi
  done
}

shimmy_registries_active_link_state_read() {
  SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=not_applicable
  SHIMMY_REGISTRIES_ACTIVE_PROFILE=none
  shimmy_registries_host_os_resolve
  [ "$SHIMMY_REGISTRIES_HOST_OS" = linux ] || return 0

  if ! shimmy_registries_active_link_parent_validate; then
    SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=invalid
    SHIMMY_REGISTRIES_ACTIVE_PROFILE=unknown
    return 0
  fi
  if [ -L "$SHIMMY_REGISTRIES_ACTIVE_LINK" ]; then
    active_target=$(readlink "$SHIMMY_REGISTRIES_ACTIVE_LINK" 2>/dev/null) || {
      SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=invalid
      SHIMMY_REGISTRIES_ACTIVE_PROFILE=unknown
      return 0
    }
    for active_profile in default upstream; do
      expected_target=$SHIMMY_CONFIG_ROOT/profiles/$active_profile/registries.conf
      [ "$active_target" = "$expected_target" ] || continue
      if ! shimmy_registries_config_validate "$expected_target" "$active_profile"; then
        SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=invalid
        SHIMMY_REGISTRIES_ACTIVE_PROFILE=unknown
        return 0
      fi
      SHIMMY_REGISTRIES_ACTIVE_PROFILE=$active_profile
      if [ "$active_profile" = "$SHIMMY_PROFILE_NAME" ] &&
        [ "$active_target" = "$SHIMMY_PROFILE_REGISTRIES_PATH" ]; then
        SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=current
      else
        SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=sibling
      fi
      return 0
    done
    SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=invalid
    SHIMMY_REGISTRIES_ACTIVE_PROFILE=unknown
    return 0
  fi
  if [ -e "$SHIMMY_REGISTRIES_ACTIVE_LINK" ]; then
    SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=invalid
    SHIMMY_REGISTRIES_ACTIVE_PROFILE=unknown
    return 0
  fi
  SHIMMY_REGISTRIES_ACTIVE_LINK_STATE=absent
}

shimmy_registries_active_link_prepare() {
  SHIMMY_REGISTRIES_CREATED_CONFIG_DIR=0
  SHIMMY_REGISTRIES_CREATED_DROPIN_DIR=0
  shimmy_registries_active_link_parent_validate || {
    printf 'ERROR: unsafe containers registry configuration path: %s\n' "$SHIMMY_REGISTRIES_DROPIN_DIR" >&2
    return 1
  }
  if [ ! -d "$SHIMMY_REGISTRIES_CONFIG_DIR" ]; then
    mkdir "$SHIMMY_REGISTRIES_CONFIG_DIR" || return 1
    SHIMMY_REGISTRIES_CREATED_CONFIG_DIR=1
  fi
  if [ ! -d "$SHIMMY_REGISTRIES_DROPIN_DIR" ]; then
    if ! mkdir "$SHIMMY_REGISTRIES_DROPIN_DIR"; then
      [ "$SHIMMY_REGISTRIES_CREATED_CONFIG_DIR" -eq 0 ] || rmdir "$SHIMMY_REGISTRIES_CONFIG_DIR" 2>/dev/null || true
      return 1
    fi
    SHIMMY_REGISTRIES_CREATED_DROPIN_DIR=1
  fi
  shimmy_registries_active_link_parent_validate
}

shimmy_registries_active_link_apply() {
  shimmy_registries_active_link_state_read
  case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
    current)
      SHIMMY_REGISTRIES_ACTIVE_LINK_CHANGED=0
      SHIMMY_REGISTRIES_ACTIVE_LINK_PRIOR_TARGET=$SHIMMY_PROFILE_REGISTRIES_PATH
      return 0
      ;;
    absent) SHIMMY_REGISTRIES_ACTIVE_LINK_PRIOR_TARGET= ;;
    sibling) SHIMMY_REGISTRIES_ACTIVE_LINK_PRIOR_TARGET=$(readlink "$SHIMMY_REGISTRIES_ACTIVE_LINK") ;;
    *)
      printf 'ERROR: refusing to replace invalid or foreign registry activation path: %s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
      return 1
      ;;
  esac

  shimmy_registries_active_link_prepare || return 1
  link_stage=$SHIMMY_REGISTRIES_DROPIN_DIR/.shimmy-active-profile.tmp.$$
  [ ! -e "$link_stage" ] && [ ! -L "$link_stage" ] || {
    printf 'ERROR: registry activation staging path collision: %s\n' "$link_stage" >&2
    shimmy_registries_active_link_created_dirs_remove
    return 1
  }
  ln -s "$SHIMMY_PROFILE_REGISTRIES_PATH" "$link_stage" || {
    shimmy_registries_active_link_created_dirs_remove
    return 1
  }
  if [ -n "$SHIMMY_REGISTRIES_ACTIVE_LINK_PRIOR_TARGET" ]; then
    [ -L "$SHIMMY_REGISTRIES_ACTIVE_LINK" ] &&
      [ "$(readlink "$SHIMMY_REGISTRIES_ACTIVE_LINK" 2>/dev/null || true)" = "$SHIMMY_REGISTRIES_ACTIVE_LINK_PRIOR_TARGET" ] || {
        rm -f "$link_stage"
        printf 'ERROR: registry activation path changed during transition: %s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
        return 1
      }
  elif [ -e "$SHIMMY_REGISTRIES_ACTIVE_LINK" ] || [ -L "$SHIMMY_REGISTRIES_ACTIVE_LINK" ]; then
    rm -f "$link_stage"
    printf 'ERROR: registry activation path appeared during transition: %s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
    return 1
  fi
  if ! mv "$link_stage" "$SHIMMY_REGISTRIES_ACTIVE_LINK"; then
    rm -f "$link_stage"
    shimmy_registries_active_link_created_dirs_remove
    return 1
  fi
  SHIMMY_REGISTRIES_ACTIVE_LINK_CHANGED=1
}

shimmy_registries_active_link_created_dirs_remove() {
  [ "${SHIMMY_REGISTRIES_CREATED_DROPIN_DIR:-0}" -eq 0 ] || rmdir "$SHIMMY_REGISTRIES_DROPIN_DIR" 2>/dev/null || true
  [ "${SHIMMY_REGISTRIES_CREATED_CONFIG_DIR:-0}" -eq 0 ] || rmdir "$SHIMMY_REGISTRIES_CONFIG_DIR" 2>/dev/null || true
  SHIMMY_REGISTRIES_CREATED_DROPIN_DIR=0
  SHIMMY_REGISTRIES_CREATED_CONFIG_DIR=0
}

shimmy_registries_active_link_rollback() {
  [ "${SHIMMY_REGISTRIES_ACTIVE_LINK_CHANGED:-0}" -eq 1 ] || return 0
  rollback_stage=$SHIMMY_REGISTRIES_DROPIN_DIR/.shimmy-active-profile.rollback.$$
  [ ! -e "$rollback_stage" ] && [ ! -L "$rollback_stage" ] || {
    printf 'ERROR: registry activation rollback path collision: %s\n' "$rollback_stage" >&2
    return 1
  }
  [ -L "$SHIMMY_REGISTRIES_ACTIVE_LINK" ] &&
    [ "$(readlink "$SHIMMY_REGISTRIES_ACTIVE_LINK" 2>/dev/null || true)" = "$SHIMMY_PROFILE_REGISTRIES_PATH" ] || {
      printf 'ERROR: registry activation rollback refused changed path: %s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
      return 1
    }
  if [ -n "${SHIMMY_REGISTRIES_ACTIVE_LINK_PRIOR_TARGET:-}" ]; then
    if ! ln -s "$SHIMMY_REGISTRIES_ACTIVE_LINK_PRIOR_TARGET" "$rollback_stage" ||
      ! mv "$rollback_stage" "$SHIMMY_REGISTRIES_ACTIVE_LINK"; then
      rm -f "$rollback_stage"
      printf 'ERROR: registry activation rollback failed for %s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
      return 1
    fi
  else
    rm -f "$SHIMMY_REGISTRIES_ACTIVE_LINK" || return 1
  fi
  shimmy_registries_active_link_created_dirs_remove
  SHIMMY_REGISTRIES_ACTIVE_LINK_CHANGED=0
}

shimmy_registries_active_link_commit() {
  SHIMMY_REGISTRIES_ACTIVE_LINK_CHANGED=0
  SHIMMY_REGISTRIES_CREATED_DROPIN_DIR=0
  SHIMMY_REGISTRIES_CREATED_CONFIG_DIR=0
}

shimmy_registries_active_link_detach() {
  shimmy_registries_active_link_state_read
  [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" = current ] || {
    printf 'ERROR: registry policy is not actively linked to profile %s; refusing --detach\n' "$SHIMMY_PROFILE_NAME" >&2
    return 1
  }
  [ -L "$SHIMMY_REGISTRIES_ACTIVE_LINK" ] &&
    [ "$(readlink "$SHIMMY_REGISTRIES_ACTIVE_LINK" 2>/dev/null || true)" = "$SHIMMY_PROFILE_REGISTRIES_PATH" ] || return 1
  rm -f "$SHIMMY_REGISTRIES_ACTIVE_LINK"
}

shimmy_registries_host_os_resolve() {
  if [ "${SHIMMY_TEST_PROFILE_OS+x}" = x ]; then
    registries_host_os=$SHIMMY_TEST_PROFILE_OS
  else
    registries_host_os=$(uname -s 2>/dev/null) || registries_host_os=
  fi
  case "$registries_host_os" in
    Linux) SHIMMY_REGISTRIES_HOST_OS=linux ;;
    Darwin) SHIMMY_REGISTRIES_HOST_OS=darwin ;;
    *) SHIMMY_REGISTRIES_HOST_OS=unsupported ;;
  esac
}

shimmy_registries_config_fingerprint_render() {
  config_path=$1
  fingerprint_output=$(cksum < "$config_path") || return 1
  set -- $fingerprint_output
  [ "$#" -eq 2 ] || return 1
  case "$1:$2" in *[!0123456789:]*|:*) return 1 ;; esac
  printf '%s-%s\n' "$1" "$2"
}

shimmy_registries_config_fingerprint_validate() {
  fingerprint_value=${1:-}
  case "$fingerprint_value" in
    *-*) ;;
    *) return 1 ;;
  esac
  fingerprint_checksum=${fingerprint_value%%-*}
  fingerprint_size=${fingerprint_value#*-}
  case "$fingerprint_checksum:$fingerprint_size" in
    *-*|*[!0123456789:]*|:*) return 1 ;;
  esac
}

shimmy_registries_machine_projection_commit() {
  shimmy_registries_machine_projection_record_commit
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_CHANGED=0
}

shimmy_registries_machine_projection_detach_finalize() {
  detach_backup_path=$1
  case "$detach_backup_path" in
    "$SHIMMY_PROFILE_ROOT"/.machine-projection.detach.*) rm -f "$detach_backup_path" ;;
    *) return 1 ;;
  esac
}

shimmy_registries_machine_projection_detach_prepare() {
  detach_record_path=$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH
  detach_backup_path=$SHIMMY_PROFILE_ROOT/.machine-projection.detach.$$
  shimmy_registries_machine_projection_record_validate "$detach_record_path" "$SHIMMY_PROFILE_NAME" || return 1
  [ ! -e "$detach_backup_path" ] && [ ! -L "$detach_backup_path" ] || {
    printf 'ERROR: Darwin projection detach backup collision: %s\n' "$detach_backup_path" >&2
    return 1
  }
  cp "$detach_record_path" "$detach_backup_path" || return 1
  chmod 0644 "$detach_backup_path" || {
    rm -f "$detach_backup_path"
    return 1
  }
  shimmy_registries_machine_projection_record_validate "$detach_backup_path" "$SHIMMY_PROFILE_NAME" || {
    rm -f "$detach_backup_path"
    return 1
  }
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_DETACH_BACKUP_PATH=$detach_backup_path
}

shimmy_registries_machine_projection_detach_record_remove() {
  detach_backup_path=$1
  case "$detach_backup_path" in "$SHIMMY_PROFILE_ROOT"/.machine-projection.detach.*) ;; *) return 1 ;; esac
  shimmy_registries_machine_projection_record_validate "$detach_backup_path" "$SHIMMY_PROFILE_NAME" || return 1
  shimmy_registries_machine_projection_record_validate \
    "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" "$SHIMMY_PROFILE_NAME" || return 1
  cmp -s "$detach_backup_path" "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" || return 1
  rm -f "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
}

shimmy_registries_machine_projection_detach_record_rollback() {
  detach_backup_path=$1
  case "$detach_backup_path" in "$SHIMMY_PROFILE_ROOT"/.machine-projection.detach.*) ;; *) return 1 ;; esac
  shimmy_registries_machine_projection_record_validate "$detach_backup_path" "$SHIMMY_PROFILE_NAME" || return 1
  if [ -f "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ] &&
    [ ! -L "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ] &&
    cmp -s "$detach_backup_path" "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"; then
    return 0
  fi
  [ ! -e "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ] &&
    [ ! -L "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ] || return 1
  cp "$detach_backup_path" "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" &&
    chmod 0644 "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
}

shimmy_registries_machine_projection_detach_remote() {
  shimmy_registries_machine_projection_link_state_read
  [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE" = current ] || {
    printf 'ERROR: refusing Darwin detach with foreign, absent, or invalid machine projection: %s\n' \
      "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK" >&2
    return 1
  }
  detach_output=$(shimmy_registries_machine_projection_root_run detach) || detach_output=
  [ "$detach_output" = detached ] || {
    printf 'ERROR: unable to detach Darwin registry projection from %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
    return 1
  }
}

shimmy_registries_machine_projection_detach_remote_rollback() {
  rollback_output=$(shimmy_registries_machine_projection_root_run apply 2>/dev/null) || rollback_output=
  [ "$rollback_output" = changed ]
}

shimmy_registries_machine_projection_link_apply() {
  projection_output=$(shimmy_registries_machine_projection_root_run apply) || {
    printf 'ERROR: unable to install Darwin registry projection in %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
    return 1
  }
  case "$projection_output" in
    changed) SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_CHANGED=1 ;;
    unchanged) SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_CHANGED=0 ;;
    *)
      printf 'ERROR: invalid Darwin registry projection response from %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
      return 1
      ;;
  esac
}

shimmy_registries_machine_projection_link_state_read() {
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE=unreachable
  projection_output=$(shimmy_registries_machine_projection_root_run inspect 2>/dev/null) || return 0
  case "$projection_output" in
    absent|current|foreign) SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE=$projection_output ;;
    *) SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE=invalid ;;
  esac
}

shimmy_registries_machine_projection_record_apply() {
  projection_fingerprint_requested=$1
  shimmy_registries_config_fingerprint_validate "$projection_fingerprint_requested" || return 1
  record_path=$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH
  stage_path=$SHIMMY_PROFILE_ROOT/.machine-projection.tmp.$$
  rollback_path=$SHIMMY_PROFILE_ROOT/.machine-projection.rollback.$$
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_CHANGED=0
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_PRIOR_EXISTS=0
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_ROLLBACK_PATH=

  if [ -e "$record_path" ] || [ -L "$record_path" ]; then
    shimmy_registries_machine_projection_record_validate "$record_path" "$SHIMMY_PROFILE_NAME" || return 1
    existing_record=$(cat "$record_path")
    candidate_record=$(shimmy_registries_machine_projection_record_render "$SHIMMY_PROFILE_NAME" "$projection_fingerprint_requested") || return 1
    [ "$existing_record" != "$candidate_record" ] || return 0
    [ ! -e "$rollback_path" ] && [ ! -L "$rollback_path" ] || {
      printf 'ERROR: machine projection rollback path collision: %s\n' "$rollback_path" >&2
      return 1
    }
    cp "$record_path" "$rollback_path" || return 1
    chmod 0644 "$rollback_path" || { rm -f "$rollback_path"; return 1; }
    SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_PRIOR_EXISTS=1
    SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_ROLLBACK_PATH=$rollback_path
  fi

  [ ! -e "$stage_path" ] && [ ! -L "$stage_path" ] || {
    rm -f "$rollback_path"
    printf 'ERROR: machine projection staging path collision: %s\n' "$stage_path" >&2
    return 1
  }
  shimmy_registries_machine_projection_record_render "$SHIMMY_PROFILE_NAME" "$projection_fingerprint_requested" > "$stage_path" || {
    rm -f "$stage_path" "$rollback_path"
    return 1
  }
  chmod 0644 "$stage_path" || { rm -f "$stage_path" "$rollback_path"; return 1; }
  shimmy_registries_machine_projection_record_validate "$stage_path" "$SHIMMY_PROFILE_NAME" || {
    rm -f "$stage_path" "$rollback_path"
    return 1
  }
  record_path=$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH
  mv "$stage_path" "$record_path" || { rm -f "$stage_path" "$rollback_path"; return 1; }
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_APPLIED_FINGERPRINT=$projection_fingerprint_requested
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_CHANGED=1
}

shimmy_registries_machine_projection_record_commit() {
  rollback_path=${SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_ROLLBACK_PATH:-}
  case "$rollback_path" in
    "$SHIMMY_PROFILE_ROOT"/.machine-projection.rollback.*) rm -f "$rollback_path" ;;
  esac
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_CHANGED=0
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_PRIOR_EXISTS=0
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_ROLLBACK_PATH=
}

shimmy_registries_machine_projection_record_read() {
  record_path=$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE=absent
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORDED_FINGERPRINT=none
  if [ -e "$record_path" ] || [ -L "$record_path" ]; then
    if shimmy_registries_machine_projection_record_validate "$record_path" "$SHIMMY_PROFILE_NAME"; then
      SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE=valid
      SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORDED_FINGERPRINT=$(sed -n 's/^config_fingerprint=//p' "$record_path")
    else
      SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE=invalid
      SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORDED_FINGERPRINT=unknown
    fi
  fi
}

shimmy_registries_machine_projection_record_render() {
  profile_name=$1
  projection_fingerprint=$2
  shimmy_profile_name_validate "$profile_name" || return 1
  shimmy_registries_config_fingerprint_validate "$projection_fingerprint" || return 1
  printf '%s\n' 'shimmy_machine_projection_version=1'
  printf 'profile=%s\n' "$profile_name"
  printf 'machine=shimmy-%s\n' "$profile_name"
  printf 'target=%s\n' "$SHIMMY_CONFIG_ROOT/profiles/$profile_name/registries.conf"
  printf 'config_fingerprint=%s\n' "$projection_fingerprint"
}

shimmy_registries_machine_projection_record_rollback() {
  [ "${SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_CHANGED:-0}" -eq 1 ] || return 0
  record_path=$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH
  applied_fingerprint=${SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_APPLIED_FINGERPRINT:-}
  shimmy_registries_machine_projection_record_validate "$record_path" "$SHIMMY_PROFILE_NAME" || return 1
  current_fingerprint=$(sed -n 's/^config_fingerprint=//p' "$record_path")
  [ "$current_fingerprint" = "$applied_fingerprint" ] || return 1
  if [ "${SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_PRIOR_EXISTS:-0}" -eq 1 ]; then
    rollback_path=$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_ROLLBACK_PATH
    shimmy_registries_machine_projection_record_validate "$rollback_path" "$SHIMMY_PROFILE_NAME" || return 1
    mv "$rollback_path" "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" || return 1
  else
    rm -f "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" || return 1
  fi
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_CHANGED=0
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_ROLLBACK_PATH=
}

shimmy_registries_machine_projection_record_validate() {
  record_path=$1
  profile_name=$2
  expected_target=${3:-$(dirname -- "$record_path")/registries.conf}
  shimmy_profile_name_validate "$profile_name" || return 1
  [ -f "$record_path" ] && [ ! -L "$record_path" ] || return 1
  if record_mode=$(stat -c '%a' "$record_path" 2>/dev/null); then
    :
  else
    record_mode=$(stat -f '%Lp' "$record_path" 2>/dev/null) || return 1
  fi
  [ "$record_mode" = 644 ] || return 1
  expected_machine=shimmy-$profile_name
  awk -v profile="$profile_name" -v machine="$expected_machine" -v target="$expected_target" '
    NR == 1 { if ($0 != "shimmy_machine_projection_version=1") exit 1; next }
    NR == 2 { if ($0 != "profile=" profile) exit 1; next }
    NR == 3 { if ($0 != "machine=" machine) exit 1; next }
    NR == 4 { if ($0 != "target=" target) exit 1; next }
    NR == 5 { if ($0 !~ /^config_fingerprint=[0-9]+-[0-9]+$/) exit 1; next }
    { exit 1 }
    END { if (NR != 5) exit 1 }
  ' "$record_path" || return 1
  projection_fingerprint=$(sed -n 's/^config_fingerprint=//p' "$record_path")
  shimmy_registries_config_fingerprint_validate "$projection_fingerprint"
}

shimmy_registries_machine_projection_reconcile() {
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_CHANGED=0
  host_fingerprint=$(shimmy_registries_config_fingerprint_render "$SHIMMY_PROFILE_REGISTRIES_PATH") || return 1
  source_fingerprint=$(shimmy_registries_machine_projection_user_run source) || {
    printf 'ERROR: profile registry configuration is not readable at the same path inside %s: %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
    return 1
  }
  [ "$source_fingerprint" = "$host_fingerprint" ] || {
    printf 'ERROR: profile registry configuration differs at the same path inside %s: %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
    return 1
  }
  shimmy_registries_machine_projection_link_state_read
  case "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE" in
    absent|current) ;;
    *)
      printf 'ERROR: refusing foreign or invalid Darwin registry projection in %s: %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK" >&2
      return 1
      ;;
  esac
  shimmy_registries_machine_projection_link_apply || return 1
  projected_fingerprint=$(shimmy_registries_machine_projection_user_run projection) || {
    printf 'ERROR: rootless validation of Darwin registry projection failed in %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
    return 1
  }
  [ "$projected_fingerprint" = "$host_fingerprint" ] || {
    printf 'ERROR: Darwin registry projection fingerprint mismatch in %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
    return 1
  }
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_CURRENT_FINGERPRINT=$host_fingerprint
}

shimmy_registries_machine_projection_rollback() {
  rollback_complete=1
  record_changed=${SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_CHANGED:-0}
  if [ "$record_changed" -eq 1 ]; then
    if shimmy_registries_machine_projection_record_rollback; then
      printf 'Rollback: machine projection record restored for %s\n' "$SHIMMY_PROFILE_NAME" >&2
    else
      printf 'Rollback: machine projection record restoration failed for %s\n' "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" >&2
      rollback_complete=0
    fi
  fi
  if [ "${SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_CHANGED:-0}" -eq 1 ]; then
    projection_output=$(shimmy_registries_machine_projection_root_run rollback 2>/dev/null) || projection_output=
    if [ "$projection_output" = detached ]; then
      printf 'Rollback: machine registry projection removed from %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
      SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_CHANGED=0
    else
      printf 'Rollback: machine registry projection removal failed for %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
      rollback_complete=0
    fi
  fi
  [ "$rollback_complete" -eq 1 ]
}

shimmy_registries_machine_projection_root_run() {
  projection_action=$1
  [ "$SHIMMY_PROFILE_EXPECTED_MACHINE" = "shimmy-$SHIMMY_PROFILE_NAME" ] || return 1
  [ "$SHIMMY_PROFILE_REGISTRIES_PATH" = "$SHIMMY_PROFILE_ROOT/registries.conf" ] || return 1
  [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK" = /etc/containers/registries.conf.d/shimmy-profile.conf ] || return 1
  "$SHIMMY_PROFILE_PODMAN_BIN" machine ssh --username root "$SHIMMY_PROFILE_EXPECTED_MACHINE" /bin/sh -s -- \
    "$projection_action" "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK" <<'EOF'
set -eu
action=$1
target=$2
link=$3
[ "$(id -u)" -eq 0 ]
[ "$link" = /etc/containers/registries.conf.d/shimmy-profile.conf ]
case "$target" in /shimmy/profiles/default/registries.conf|/shimmy/profiles/upstream/registries.conf|/*/shimmy/profiles/default/registries.conf|/*/shimmy/profiles/upstream/registries.conf) ;; *) exit 20 ;; esac
[ -d /etc/containers ] && [ ! -L /etc/containers ]
[ -d /etc/containers/registries.conf.d ] && [ ! -L /etc/containers/registries.conf.d ]
state=absent
if [ -L "$link" ]; then
  actual_target=$(readlink "$link")
  if [ "$actual_target" = "$target" ]; then state=current; else state=foreign; fi
elif [ -e "$link" ]; then
  state=foreign
fi
case "$action" in
  inspect) printf '%s\n' "$state" ;;
  apply)
    case "$state" in
      current) printf '%s\n' unchanged ;;
      absent) ln -s "$target" "$link"; printf '%s\n' changed ;;
      *) exit 21 ;;
    esac
    ;;
  detach|rollback)
    [ "$state" = current ]
    rm -f "$link"
    printf '%s\n' detached
    ;;
  *) exit 22 ;;
esac
EOF
}

shimmy_registries_machine_projection_state_read() {
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=unverified
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE=unverified
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_CURRENT_FINGERPRINT=unknown
  shimmy_registries_machine_projection_record_read
  current_fingerprint=$(shimmy_registries_config_fingerprint_render "$SHIMMY_PROFILE_REGISTRIES_PATH" 2>/dev/null) || {
    SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=invalid
    return 0
  }
  SHIMMY_REGISTRIES_MACHINE_PROJECTION_CURRENT_FINGERPRINT=$current_fingerprint
  [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE" != invalid ] || {
    SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=invalid
    return 0
  }
  case "${SHIMMY_PROFILE_EXPECTED_MACHINE_STATE:-unknown}" in
    missing) SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE=machine_missing; return 0 ;;
    stopped) SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE=unverified; return 0 ;;
    running) ;;
    *) return 0 ;;
  esac
  [ "${SHIMMY_PROFILE_ENGINE_REACHABLE:-unknown}" = true ] || return 0
  shimmy_registries_machine_projection_link_state_read
  case "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE" in
    absent)
      SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=restart-required
      return 0
      ;;
    current) ;;
    *)
      SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=invalid
      return 0
      ;;
  esac
  projected_fingerprint=$(shimmy_registries_machine_projection_user_run projection 2>/dev/null) || {
    SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=invalid
    return 0
  }
  [ "$projected_fingerprint" = "$current_fingerprint" ] || {
    SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=restart-required
    return 0
  }
  if [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE" = valid ] &&
    [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORDED_FINGERPRINT" = "$current_fingerprint" ]; then
    SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=current
  else
    SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE=restart-required
  fi
}

shimmy_registries_machine_projection_user_run() {
  projection_action=$1
  [ "$SHIMMY_PROFILE_EXPECTED_MACHINE" = "shimmy-$SHIMMY_PROFILE_NAME" ] || return 1
  "$SHIMMY_PROFILE_PODMAN_BIN" machine ssh "$SHIMMY_PROFILE_EXPECTED_MACHINE" /bin/sh -s -- \
    "$projection_action" "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK" <<'EOF'
set -eu
action=$1
target=$2
link=$3
[ "$(id -u)" -ne 0 ]
[ "$link" = /etc/containers/registries.conf.d/shimmy-profile.conf ]
case "$target" in /shimmy/profiles/default/registries.conf|/shimmy/profiles/upstream/registries.conf|/*/shimmy/profiles/default/registries.conf|/*/shimmy/profiles/upstream/registries.conf) ;; *) exit 30 ;; esac
[ -f "$target" ] && [ ! -L "$target" ] && [ -r "$target" ]
case "$action" in
  source) fingerprint_path=$target ;;
  projection)
    [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ] && [ -r "$link" ]
    fingerprint_path=$link
    ;;
  *) exit 31 ;;
esac
set -- $(cksum < "$fingerprint_path")
[ "$#" -eq 2 ]
printf '%s-%s\n' "$1" "$2"
EOF
}

shimmy_registries_override_read() {
  SHIMMY_REGISTRIES_OVERRIDE=none
  if [ -n "${CONTAINERS_REGISTRIES_CONF:-}" ] && [ -n "${CONTAINERS_REGISTRIES_CONF_OVERRIDE:-}" ]; then
    SHIMMY_REGISTRIES_OVERRIDE=CONTAINERS_REGISTRIES_CONF,CONTAINERS_REGISTRIES_CONF_OVERRIDE
  elif [ -n "${CONTAINERS_REGISTRIES_CONF:-}" ]; then
    SHIMMY_REGISTRIES_OVERRIDE=CONTAINERS_REGISTRIES_CONF
  elif [ -n "${CONTAINERS_REGISTRIES_CONF_OVERRIDE:-}" ]; then
    SHIMMY_REGISTRIES_OVERRIDE=CONTAINERS_REGISTRIES_CONF_OVERRIDE
  fi
}

shimmy_registries_override_reject() {
  shimmy_registries_override_read
  [ "$SHIMMY_REGISTRIES_OVERRIDE" = none ] && return 0
  printf 'ERROR: %s masks Shimmy registry activation; unset it and retry (its value was not displayed)\n' "$SHIMMY_REGISTRIES_OVERRIDE" >&2
  return 1
}

shimmy_registries_candidate_entries_render() {
  current_entries=$1
  mutation_action=$2
  mutation_prefix=${3:-}
  mutation_location=${4:-}
  candidate_entries=
  mutation_found=0

  while IFS='|' read -r current_prefix current_location current_extra; do
    [ -n "$current_prefix" ] || continue
    [ -z "$current_extra" ] || return 1
    if [ "$current_prefix" = "$mutation_prefix" ]; then
      mutation_found=1
      [ "$mutation_action" != upsert ] ||
        candidate_entries=$(shimmy_append_line_list "$candidate_entries" "$mutation_prefix|$mutation_location")
      continue
    fi
    [ "$mutation_action" != remove_all ] || continue
    candidate_entries=$(shimmy_append_line_list "$candidate_entries" "$current_prefix|$current_location")
  done <<EOF
$current_entries
EOF

  if [ "$mutation_action" = upsert ] && [ "$mutation_found" -eq 0 ]; then
    candidate_entries=$(shimmy_append_line_list "$candidate_entries" "$mutation_prefix|$mutation_location")
  fi
  [ -z "$candidate_entries" ] || candidate_entries=$(printf '%s\n' "$candidate_entries" | LC_ALL=C sort)
  printf '%s\n' "$candidate_entries"
}

shimmy_registries_client_mount_fail() {
  client_mount_reason=$1
  printf 'ERROR: registry client policy is unavailable for installed Shimmy profile %s: %s\n' \
    "${SHIMMY_PROFILE_NAME:-unknown}" "$client_mount_reason" >&2
  return 1
}

shimmy_registries_client_mount_resolve() {
  [ -n "${SHIMMY_RUNTIME_DIR:-}" ] || return 0
  client_profile_root=$(cd -- "$SHIMMY_RUNTIME_DIR/../.." 2>/dev/null && pwd -P) || return 0
  client_profile_name=$(basename -- "$client_profile_root")
  case "$client_profile_name" in default|upstream) ;; *) return 0 ;; esac

  shimmy_profile_paths_resolve "$client_profile_name" || {
    shimmy_registries_client_mount_fail 'profile paths are invalid'
    return 1
  }
  [ "$client_profile_root" = "$SHIMMY_PROFILE_ROOT" ] || return 0
  shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$client_profile_name" || {
    shimmy_registries_client_mount_fail 'profile manifest is invalid'
    return 1
  }
  shimmy_path_parent_chain_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" || {
    shimmy_registries_client_mount_fail 'registry configuration path is unsafe'
    return 1
  }
  case "$SHIMMY_PROFILE_REGISTRIES_PATH" in
    *:*)
      shimmy_registries_client_mount_fail 'registry configuration path cannot be represented as a Podman volume'
      return 1
      ;;
  esac
  shimmy_registries_config_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" "$client_profile_name" || {
    shimmy_registries_client_mount_fail 'registry configuration is invalid'
    return 1
  }
  shimmy_registries_override_read
  [ "$SHIMMY_REGISTRIES_OVERRIDE" = none ] || {
    shimmy_registries_client_mount_fail "$SHIMMY_REGISTRIES_OVERRIDE masks registry client policy (value hidden)"
    return 1
  }
  if [ -n "${CONTAINER_CONNECTION:-}" ]; then
    shimmy_registries_client_mount_fail 'CONTAINER_CONNECTION masks the active profile engine (value hidden)'
    return 1
  fi
  if [ -n "${CONTAINER_HOST:-}" ]; then
    shimmy_registries_client_mount_fail 'CONTAINER_HOST masks the active profile engine (value hidden)'
    return 1
  fi

  shimmy_registries_host_os_resolve
  case "$SHIMMY_REGISTRIES_HOST_OS" in
    linux)
      shimmy_registries_active_link_state_read
      case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
        absent) return 0 ;;
        current) ;;
        sibling)
          shimmy_registries_client_mount_fail "active registry policy belongs to profile $SHIMMY_REGISTRIES_ACTIVE_PROFILE"
          return 1
          ;;
        *)
          shimmy_registries_client_mount_fail 'active registry policy path is invalid or unsafe'
          return 1
          ;;
      esac
      ;;
    darwin)
      shimmy_registries_machine_projection_record_read
      case "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE" in
        absent) return 0 ;;
        valid) ;;
        *)
          shimmy_registries_client_mount_fail 'machine projection record is invalid'
          return 1
          ;;
      esac
      if [ "${SHIMMY_PODMAN_PROFILE_REGISTRY_AFFINITY:-}" != "$client_profile_name:current" ]; then
        command -v shimmy_podman_profile_affinity_require >/dev/null 2>&1 || {
          shimmy_registries_client_mount_fail 'active machine projection cannot be verified'
          return 1
        }
        shimmy_podman_profile_affinity_require || return 1
      fi
      [ "${SHIMMY_PODMAN_PROFILE_REGISTRY_AFFINITY:-}" = "$client_profile_name:current" ] || {
        shimmy_registries_client_mount_fail 'machine projection is not current'
        return 1
      }
      ;;
    *)
      shimmy_registries_client_mount_fail 'host operating system is unsupported'
      return 1
      ;;
  esac

  printf '%s:%s:ro\n' "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK"
}

shimmy_registries_config_entries_read() {
  config_file=$1
  profile_name=$2
  shimmy_profile_name_validate "$profile_name" || return 1
  [ -f "$config_file" ] && [ ! -L "$config_file" ] || return 1
  [ "$(tail -c 1 "$config_file" | wc -l | tr -d ' ')" -eq 1 ] 2>/dev/null || return 1

  managed_header="# Managed by Shimmy for profile \"$profile_name\". Use \`shimmy profile redirect\`; do not edit."
  parsed_entries=$(awk -v managed_header="$managed_header" '
    NR == 1 {
      if ($0 != managed_header) exit 1
      state = 1
      next
    }
    NR == 2 {
      if ($0 != "# shimmy_registry_redirects_version=1") exit 1
      state = 2
      next
    }
    state == 2 || state == 6 {
      if ($0 != "") exit 1
      state = 3
      next
    }
    state == 3 {
      if ($0 != "[[registry]]") exit 1
      state = 4
      next
    }
    state == 4 {
      if ($0 !~ /^prefix = "[^"]+"$/) exit 1
      prefix = substr($0, 11, length($0) - 11)
      state = 5
      next
    }
    state == 5 {
      if ($0 !~ /^location = "[^"]+"$/) exit 1
      location = substr($0, 13, length($0) - 13)
      if (previous_prefix != "" && prefix <= previous_prefix) exit 1
      print prefix "|" location
      previous_prefix = prefix
      state = 6
      next
    }
    { exit 1 }
    END {
      if (NR < 2 || (state != 2 && state != 6)) exit 1
    }
  ' "$config_file") || return 1

  while IFS='|' read -r logical_prefix physical_location entry_extra; do
    [ -n "$logical_prefix" ] || continue
    [ -z "$entry_extra" ] || return 1
    shimmy_registries_endpoint_validate "$logical_prefix" || return 1
    shimmy_registries_endpoint_validate "$physical_location" || return 1
  done <<EOF
$parsed_entries
EOF

  printf '%s\n' "$parsed_entries"
}

shimmy_registries_config_render() {
  profile_name=$1
  registry_entries=${2:-}
  shimmy_profile_name_validate "$profile_name" || return 1

  printf '# Managed by Shimmy for profile "%s". Use `shimmy profile redirect`; do not edit.\n' "$profile_name"
  printf '%s\n' '# shimmy_registry_redirects_version=1'
  while IFS='|' read -r logical_prefix physical_location entry_extra; do
    [ -n "$logical_prefix" ] || continue
    [ -z "$entry_extra" ] || return 1
    shimmy_registries_endpoint_validate "$logical_prefix" || return 1
    shimmy_registries_endpoint_validate "$physical_location" || return 1
    printf '\n[[registry]]\nprefix = "%s"\nlocation = "%s"\n' "$logical_prefix" "$physical_location"
  done <<EOF
$registry_entries
EOF
}

shimmy_registries_config_validate() {
  config_file=$1
  profile_name=$2
  shimmy_registries_config_entries_read "$config_file" "$profile_name" >/dev/null || return 1
  if config_mode=$(stat -c '%a' "$config_file" 2>/dev/null); then
    :
  else
    config_mode=$(stat -f '%Lp' "$config_file" 2>/dev/null) || return 1
  fi
  [ "$config_mode" = 644 ]
}

shimmy_registries_endpoint_validate() {
  endpoint_value=${1:-}
  case "$endpoint_value" in
    ''|*://*|*/|*//*|*@*|*\**|*\?*|*\[*|*\]*|*\"*|*\'*|*[!abcdefghijklmnopqrstuvwxyz0123456789._:/-]*) return 1 ;;
  esac

  endpoint_host=${endpoint_value%%/*}
  endpoint_path=
  case "$endpoint_value" in */*) endpoint_path=${endpoint_value#*/} ;; esac

  endpoint_port=
  endpoint_host_name=$endpoint_host
  case "$endpoint_host" in
    *:*)
      endpoint_port=${endpoint_host##*:}
      endpoint_host_name=${endpoint_host%:*}
      case "$endpoint_host_name" in *:*) return 1 ;; esac
      case "$endpoint_port" in ''|*[!0123456789]*) return 1 ;; esac
      [ "$endpoint_port" -ge 1 ] 2>/dev/null && [ "$endpoint_port" -le 65535 ] 2>/dev/null || return 1
      ;;
  esac

  case "$endpoint_host_name" in
    ''|.*|*.|*..*|-*|*-|*[!abcdefghijklmnopqrstuvwxyz0123456789.-]*) return 1 ;;
  esac
  case "$endpoint_host_name" in
    localhost|*.*) ;;
    *) [ -n "$endpoint_port" ] || return 1 ;;
  esac
  old_ifs=$IFS
  IFS=.
  set -- $endpoint_host_name
  IFS=$old_ifs
  for host_label in "$@"; do
    case "$host_label" in ''|-*|*-|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return 1 ;; esac
  done

  [ -z "$endpoint_path" ] && return 0
  old_ifs=$IFS
  IFS=/
  set -- $endpoint_path
  IFS=$old_ifs
  for path_segment in "$@"; do
    case "$path_segment" in ''|.|..|.*|-*|_*|*[-._]) return 1 ;; esac
    printf '%s\n' "$path_segment" | LC_ALL=C awk '
      /^[a-z0-9]+(([._]|__|-+)[a-z0-9]+)*$/ { valid = 1 }
      END { exit(valid ? 0 : 1) }
    ' || return 1
  done
}

shimmy_registries_file_replace() {
  candidate_entries=$1
  config_path=$SHIMMY_PROFILE_REGISTRIES_PATH
  stage_path=$SHIMMY_PROFILE_ROOT/.registries.tmp.$$
  rollback_path=$SHIMMY_PROFILE_ROOT/.registries.rollback.$$

  for transient_path in "$stage_path" "$rollback_path"; do
    [ ! -e "$transient_path" ] && [ ! -L "$transient_path" ] || {
      printf 'ERROR: registry transaction path collision: %s\n' "$transient_path" >&2
      return 1
    }
  done
  shimmy_registries_config_render "$SHIMMY_PROFILE_NAME" "$candidate_entries" > "$stage_path" || {
    rm -f "$stage_path"
    return 1
  }
  chmod 0644 "$stage_path" || { rm -f "$stage_path"; return 1; }
  shimmy_registries_config_validate "$stage_path" "$SHIMMY_PROFILE_NAME" || {
    rm -f "$stage_path"
    printf '%s\n' 'ERROR: rendered registry redirect configuration failed validation' >&2
    return 1
  }
  cp "$config_path" "$rollback_path" || { rm -f "$stage_path" "$rollback_path"; return 1; }
  chmod 0644 "$rollback_path" || { rm -f "$stage_path" "$rollback_path"; return 1; }
  if ! mv "$stage_path" "$config_path"; then
    rm -f "$stage_path" "$rollback_path"
    return 1
  fi
  if ! shimmy_registries_post_commit_validate "$config_path"; then
    if ! mv "$rollback_path" "$config_path"; then
      printf 'ERROR: registry redirect validation failed and rollback could not restore %s\n' "$config_path" >&2
      return 1
    fi
    printf '%s\n' 'ERROR: registry redirect validation failed; prior configuration restored' >&2
    return 1
  fi
  rm -f "$rollback_path"
}

shimmy_registries_linux_active_edit_prepare() {
  shimmy_registries_active_link_state_read
  case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
    current)
      shimmy_registries_override_reject || return 1
      command -v shimmy_profile_linux_engine_validate >/dev/null 2>&1 || {
        printf '%s\n' 'ERROR: Linux registry activation validation is unavailable' >&2
        return 1
      }
      shimmy_profile_linux_engine_validate || return 1
      SHIMMY_REGISTRIES_ACTIVE_EDIT=linux
      ;;
    absent|sibling) ;;
    *)
      printf 'ERROR: refusing registry mutation with invalid or foreign activation path: %s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
      return 1
      ;;
  esac
}

shimmy_registries_active_edit_prepare() {
  SHIMMY_REGISTRIES_ACTIVE_EDIT=none
  shimmy_registries_host_os_resolve
  case "$SHIMMY_REGISTRIES_HOST_OS" in
    linux) shimmy_registries_linux_active_edit_prepare ;;
    darwin)
      shimmy_registries_machine_projection_record_read
      case "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE" in
        absent) return 0 ;;
        invalid)
          printf 'ERROR: refusing registry mutation with invalid Darwin machine projection record: %s\n' "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" >&2
          return 1
          ;;
      esac
      command -v shimmy_profile_state_read >/dev/null 2>&1 || return 0
      shimmy_profile_state_read
      case "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" in
        running)
          case "${SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE:-unverified}" in
            current|restart-required)
              shimmy_registries_override_reject || return 1
              SHIMMY_REGISTRIES_ACTIVE_EDIT=darwin
              ;;
            invalid)
              printf 'ERROR: refusing registry mutation with invalid Darwin machine projection for profile %s\n' "$SHIMMY_PROFILE_NAME" >&2
              return 1
              ;;
          esac
          ;;
      esac
      ;;
  esac
}

shimmy_registries_lock_acquire() {
  lock_path=$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH
  [ "$SHIMMY_PROFILE_REGISTRIES_PATH" = "$SHIMMY_PROFILE_ROOT/registries.conf" ] &&
    [ "$lock_path" = "$SHIMMY_PROFILE_ROOT/.registries.lock" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_PROFILE_ROOT" || {
      printf 'ERROR: unsafe profile registry transaction paths below %s\n' "$SHIMMY_PROFILE_ROOT" >&2
      return 1
    }
  [ -d "$SHIMMY_PROFILE_ROOT" ] && [ ! -L "$SHIMMY_PROFILE_ROOT" ] || {
    printf 'ERROR: invalid profile root for registry transaction: %s\n' "$SHIMMY_PROFILE_ROOT" >&2
    return 1
  }
  if ! mkdir "$lock_path" 2>/dev/null; then
    printf 'ERROR: another registry transaction holds %s; wait for it to finish and do not remove the lock automatically\n' "$lock_path" >&2
    return 1
  fi
  SHIMMY_REGISTRIES_LOCK_HELD=1
}

shimmy_registries_lock_check() {
  lock_path=$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH
  [ "$SHIMMY_PROFILE_REGISTRIES_PATH" = "$SHIMMY_PROFILE_ROOT/registries.conf" ] &&
    [ "$lock_path" = "$SHIMMY_PROFILE_ROOT/.registries.lock" ] &&
    shimmy_path_parent_chain_validate "$SHIMMY_PROFILE_ROOT" || return 1
  if [ -e "$lock_path" ] || [ -L "$lock_path" ]; then
    printf 'ERROR: another registry transaction holds %s; dry-run made no changes\n' "$lock_path" >&2
    return 1
  fi
}

shimmy_registries_lock_release() {
  [ "${SHIMMY_REGISTRIES_LOCK_HELD:-0}" -eq 1 ] || return 0
  case "${SHIMMY_PROFILE_REGISTRIES_LOCK_PATH:-}" in
    "$SHIMMY_PROFILE_ROOT"/.registries.lock) rmdir "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH" 2>/dev/null || true ;;
  esac
  SHIMMY_REGISTRIES_LOCK_HELD=0
}

shimmy_registries_mutate() {
  mutation_action=$1
  mutation_prefix=${2:-}
  mutation_location=${3:-}
  dry_run_requested=${4:-0}

  existing_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || {
    printf 'ERROR: invalid managed registry redirect configuration: %s\n' "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
    return 1
  }
  candidate_entries=$(shimmy_registries_candidate_entries_render "$existing_entries" "$mutation_action" "$mutation_prefix" "$mutation_location") || return 1
  if [ "$dry_run_requested" -eq 1 ]; then
    shimmy_registries_config_render "$SHIMMY_PROFILE_NAME" "$candidate_entries"
    return 0
  fi

  shimmy_registries_lock_acquire || return 1
  existing_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || {
    printf 'ERROR: invalid managed registry redirect configuration after locking: %s\n' "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
    shimmy_registries_lock_release
    return 1
  }
  candidate_entries=$(shimmy_registries_candidate_entries_render "$existing_entries" "$mutation_action" "$mutation_prefix" "$mutation_location") || {
    shimmy_registries_lock_release
    return 1
  }
  if [ "$candidate_entries" = "$existing_entries" ]; then
    shimmy_registries_lock_release
    return 0
  fi
  if ! shimmy_registries_active_edit_prepare; then
    shimmy_registries_lock_release
    return 1
  fi
  mutation_status=0
  shimmy_registries_file_replace "$candidate_entries" || mutation_status=$?
  shimmy_registries_lock_release
  if [ "$mutation_status" -eq 0 ] && [ "$SHIMMY_REGISTRIES_ACTIVE_EDIT" = darwin ]; then
    printf "Registry policy changed for running profile %s; restart it with: '%s/bin/shimmy' profile activate --restart\n" "$SHIMMY_PROFILE_NAME" "$SHIMMY_PROFILE_ROOT"
  fi
  return "$mutation_status"
}

shimmy_registries_mutate_remove_all_detach() {
  dry_run_requested=${1:-0}
  existing_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || {
    printf 'ERROR: invalid managed registry redirect configuration: %s\n' "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
    return 1
  }
  shimmy_registries_host_os_resolve
  if [ "$SHIMMY_REGISTRIES_HOST_OS" = darwin ]; then
    shimmy_registries_mutate_remove_all_detach_darwin "$dry_run_requested" "$existing_entries"
    return $?
  fi
  if [ "$SHIMMY_REGISTRIES_HOST_OS" != linux ]; then
    shimmy_registries_mutate remove_all '' '' "$dry_run_requested"
    return $?
  fi

  shimmy_registries_active_link_state_read
  [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" = current ] || {
    printf 'ERROR: registry policy is not actively linked to profile %s; refusing --detach\n' "$SHIMMY_PROFILE_NAME" >&2
    return 1
  }
  shimmy_registries_override_reject || return 1
  if [ "$dry_run_requested" -eq 1 ]; then
    shimmy_registries_config_render "$SHIMMY_PROFILE_NAME" ''
    printf 'would_detach=%s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK"
    return 0
  fi

  shimmy_registries_lock_acquire || return 1
  existing_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || {
    shimmy_registries_lock_release
    return 1
  }
  shimmy_registries_active_link_state_read
  [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" = current ] || {
    shimmy_registries_lock_release
    printf 'ERROR: registry policy changed before detach for profile %s\n' "$SHIMMY_PROFILE_NAME" >&2
    return 1
  }
  prior_target=$(readlink "$SHIMMY_REGISTRIES_ACTIVE_LINK") || {
    shimmy_registries_lock_release
    return 1
  }
  shimmy_registries_active_link_detach || {
    shimmy_registries_lock_release
    return 1
  }
  mutation_status=0
  if [ -n "$existing_entries" ] && ! shimmy_registries_file_replace ''; then
    mutation_status=1
    restore_stage=$SHIMMY_REGISTRIES_DROPIN_DIR/.shimmy-active-profile.detach-rollback.$$
    if [ ! -e "$restore_stage" ] && [ ! -L "$restore_stage" ] &&
      [ ! -e "$SHIMMY_REGISTRIES_ACTIVE_LINK" ] && [ ! -L "$SHIMMY_REGISTRIES_ACTIVE_LINK" ] &&
      ln -s "$prior_target" "$restore_stage" && mv "$restore_stage" "$SHIMMY_REGISTRIES_ACTIVE_LINK"; then
      printf '%s\n' 'ERROR: registry detach transaction failed; prior activation link restored' >&2
    else
      rm -f "$restore_stage"
      printf '%s\n' 'ERROR: registry detach transaction failed and activation link rollback was incomplete' >&2
    fi
  fi
  shimmy_registries_lock_release
  return "$mutation_status"
}

shimmy_registries_mutate_remove_all_detach_darwin() {
  dry_run_requested=$1
  existing_entries=$2
  command -v shimmy_profile_state_read >/dev/null 2>&1 || {
    printf '%s\n' 'ERROR: Darwin profile state inspection is unavailable' >&2
    return 1
  }
  shimmy_profile_state_read
  [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE" = valid ] || {
    printf 'ERROR: no valid Darwin projection record is attached to profile %s\n' "$SHIMMY_PROFILE_NAME" >&2
    return 1
  }
  detach_mode=
  case "$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" in
    missing) detach_mode=missing_machine ;;
    stopped)
      printf "ERROR: expected machine %s is stopped; activate it before detach with: '%s/bin/shimmy' profile activate\n" "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_PROFILE_ROOT" >&2
      return 1
      ;;
    running)
      [ "$SHIMMY_PROFILE_ENGINE_REACHABLE" = true ] || {
        printf 'ERROR: expected machine %s is unreachable; refusing Darwin projection detach\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
        return 1
      }
      [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE" = current ] || {
        printf 'ERROR: refusing Darwin detach with foreign, absent, or invalid machine projection: %s\n' "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK" >&2
        return 1
      }
      shimmy_profile_activation_override_reject || return 1
      shimmy_registries_override_reject || return 1
      detach_mode=running_machine
      ;;
    *)
      printf 'ERROR: unable to prove Darwin machine state for projection detach: %s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" >&2
      return 1
      ;;
  esac

  if [ "$dry_run_requested" -eq 1 ]; then
    shimmy_registries_config_render "$SHIMMY_PROFILE_NAME" ''
    if [ "$detach_mode" = running_machine ]; then
      printf 'would_detach=%s:%s\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE" "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK"
    else
      printf 'would_detach=record-only:%s-missing\n' "$SHIMMY_PROFILE_EXPECTED_MACHINE"
    fi
    printf 'would_remove_record=%s\n' "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
    return 0
  fi

  shimmy_registries_lock_acquire || return 1
  existing_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || {
    shimmy_registries_lock_release
    return 1
  }
  shimmy_profile_state_read
  [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE" = valid ] || {
    shimmy_registries_lock_release
    printf 'ERROR: Darwin projection record changed before detach for profile %s\n' "$SHIMMY_PROFILE_NAME" >&2
    return 1
  }
  case "$detach_mode:$SHIMMY_PROFILE_EXPECTED_MACHINE_STATE" in
    missing_machine:missing) ;;
    running_machine:running)
      [ "$SHIMMY_PROFILE_ENGINE_REACHABLE" = true ] &&
        [ "$SHIMMY_REGISTRIES_MACHINE_PROJECTION_LINK_STATE" = current ] || {
          shimmy_registries_lock_release
          printf 'ERROR: Darwin machine projection changed before detach for profile %s\n' "$SHIMMY_PROFILE_NAME" >&2
          return 1
        }
      ;;
    *)
      shimmy_registries_lock_release
      printf 'ERROR: Darwin machine state changed before detach for profile %s\n' "$SHIMMY_PROFILE_NAME" >&2
      return 1
      ;;
  esac

  shimmy_registries_machine_projection_detach_prepare || {
    shimmy_registries_lock_release
    return 1
  }
  record_backup=$SHIMMY_REGISTRIES_MACHINE_PROJECTION_DETACH_BACKUP_PATH
  remote_detached=0
  if [ "$detach_mode" = running_machine ]; then
    if ! shimmy_registries_machine_projection_detach_remote; then
      shimmy_registries_machine_projection_detach_finalize "$record_backup"
      shimmy_registries_lock_release
      return 1
    fi
    remote_detached=1
  fi
  mutation_status=0
  if ! shimmy_registries_machine_projection_detach_record_remove "$record_backup"; then
    mutation_status=1
  elif [ -n "$existing_entries" ] && ! shimmy_registries_file_replace ''; then
    mutation_status=1
  fi
  if [ "$mutation_status" -ne 0 ]; then
    rollback_complete=1
    shimmy_registries_machine_projection_detach_record_rollback "$record_backup" || rollback_complete=0
    if [ "$remote_detached" -eq 1 ]; then
      shimmy_registries_machine_projection_detach_remote_rollback || rollback_complete=0
    fi
    if [ "$rollback_complete" -eq 1 ]; then
      printf '%s\n' 'ERROR: Darwin projection detach failed; prior projection and record restored' >&2
    else
      printf '%s\n' 'ERROR: Darwin projection detach failed and rollback was incomplete' >&2
    fi
    shimmy_registries_machine_projection_detach_finalize "$record_backup" || true
    shimmy_registries_lock_release
    return 1
  fi
  shimmy_registries_machine_projection_detach_finalize "$record_backup"
  shimmy_registries_lock_release
}

shimmy_registries_policy_state_read() {
  registry_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || {
    printf '%s\n' invalid
    return 0
  }
  shimmy_registries_override_read
  shimmy_registries_host_os_resolve
  if [ "$SHIMMY_REGISTRIES_HOST_OS" = linux ]; then
    shimmy_registries_active_link_state_read
    case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
      absent|sibling) printf '%s\n' inactive ;;
      current)
        if [ "$SHIMMY_REGISTRIES_OVERRIDE" = none ] &&
          [ "${SHIMMY_PROFILE_ENGINE_REACHABLE:-unknown}" = true ]; then
          printf '%s\n' current
        else
          printf '%s\n' invalid
        fi
        ;;
      *) printf '%s\n' invalid ;;
    esac
  elif [ "$SHIMMY_REGISTRIES_HOST_OS" = darwin ]; then
    case "${SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE:-unverified}" in
      current)
        if [ "$SHIMMY_REGISTRIES_OVERRIDE" = none ]; then printf '%s\n' current; else printf '%s\n' invalid; fi
        ;;
      restart-required) printf '%s\n' restart-required ;;
      invalid) printf '%s\n' invalid ;;
      *)
        if [ -z "$registry_entries" ] && [ "${SHIMMY_REGISTRIES_MACHINE_PROJECTION_RECORD_STATE:-absent}" = absent ]; then
          printf '%s\n' inactive
        else
          printf '%s\n' unverified
        fi
        ;;
    esac
  elif [ -n "$registry_entries" ]; then
    printf '%s\n' prepared
  else
    printf '%s\n' inactive
  fi
}

shimmy_registries_post_commit_validate() {
  shimmy_registries_config_validate "$1" "$SHIMMY_PROFILE_NAME" || return 1
  case "${SHIMMY_REGISTRIES_ACTIVE_EDIT:-none}" in
    linux) shimmy_profile_linux_engine_validate ;;
    *) return 0 ;;
  esac
}
