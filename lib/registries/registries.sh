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
  SHIMMY_REGISTRIES_ACTIVE_EDIT=0
  shimmy_registries_host_os_resolve
  [ "$SHIMMY_REGISTRIES_HOST_OS" = linux ] || return 0
  shimmy_registries_active_link_state_read
  case "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" in
    current)
      shimmy_registries_override_reject || return 1
      command -v shimmy_profile_linux_engine_validate >/dev/null 2>&1 || {
        printf '%s\n' 'ERROR: Linux registry activation validation is unavailable' >&2
        return 1
      }
      shimmy_profile_linux_engine_validate || return 1
      SHIMMY_REGISTRIES_ACTIVE_EDIT=1
      ;;
    absent|sibling) ;;
    *)
      printf 'ERROR: refusing registry mutation with invalid or foreign activation path: %s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK" >&2
      return 1
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
  if ! shimmy_registries_linux_active_edit_prepare; then
    shimmy_registries_lock_release
    return 1
  fi
  mutation_status=0
  shimmy_registries_file_replace "$candidate_entries" || mutation_status=$?
  shimmy_registries_lock_release
  return "$mutation_status"
}

shimmy_registries_mutate_remove_all_detach() {
  dry_run_requested=${1:-0}
  existing_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || {
    printf 'ERROR: invalid managed registry redirect configuration: %s\n' "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
    return 1
  }
  shimmy_registries_host_os_resolve
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
  elif [ -n "$registry_entries" ]; then
    printf '%s\n' prepared
  else
    printf '%s\n' inactive
  fi
}

shimmy_registries_post_commit_validate() {
  shimmy_registries_config_validate "$1" "$SHIMMY_PROFILE_NAME" || return 1
  [ "${SHIMMY_REGISTRIES_ACTIVE_EDIT:-0}" -eq 1 ] || return 0
  shimmy_profile_linux_engine_validate
}
