#!/bin/sh
# Strict profile-owned containers/image registry redirect data.

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
  mutation_status=0
  shimmy_registries_file_replace "$candidate_entries" || mutation_status=$?
  shimmy_registries_lock_release
  return "$mutation_status"
}

shimmy_registries_policy_state_read() {
  registry_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || return 1
  if [ -n "$registry_entries" ]; then
    printf '%s\n' prepared
  else
    printf '%s\n' inactive
  fi
}

shimmy_registries_post_commit_validate() {
  shimmy_registries_config_validate "$1" "$SHIMMY_PROFILE_NAME"
}
