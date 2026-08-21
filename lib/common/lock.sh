#!/bin/sh
# Private lock ordering, ownership, stale-owner handling, and cleanup.

SHIMMY_LOCK_HELD_RECORDS=
SHIMMY_LOCK_SEQUENCE=0
SHIMMY_LOCK_ACQUIRING_ACTIVE=0
SHIMMY_LOCK_ACQUIRING_CANDIDATE=
SHIMMY_LOCK_ACQUIRING_PATH=
SHIMMY_LOCK_ACQUIRING_TOKEN=

shimmy_lock_error_set() {
  SHIMMY_LOCK_ERROR=$1
}

shimmy_lock_kind_resolve() {
  shimmy_lock_kind=$1
  shimmy_lock_config_root=$2
  shimmy_lock_profile_name=${3:-}

  shimmy_path_absolute_normalized_validate "$shimmy_lock_config_root" || {
    shimmy_lock_error_set "invalid lock configuration root: $shimmy_lock_config_root"
    return 1
  }
  [ -d "$shimmy_lock_config_root" ] && [ ! -L "$shimmy_lock_config_root" ] &&
    shimmy_path_parent_chain_validate "$shimmy_lock_config_root" || {
      shimmy_lock_error_set "unsafe lock configuration root: $shimmy_lock_config_root"
      return 1
    }

  case "$shimmy_lock_kind" in
    catalog)
      [ -z "$shimmy_lock_profile_name" ] || return 1
      SHIMMY_LOCK_RANK=10
      SHIMMY_LOCK_PROFILE=-
      SHIMMY_LOCK_PATH=$shimmy_lock_config_root/.catalog.lock
      ;;
    activation)
      [ -z "$shimmy_lock_profile_name" ] || return 1
      SHIMMY_LOCK_RANK=20
      SHIMMY_LOCK_PROFILE=-
      SHIMMY_LOCK_PATH=$shimmy_lock_config_root/.activation.lock
      ;;
    profile|registry)
      shimmy_name_component_validate "$shimmy_lock_profile_name" || {
        shimmy_lock_error_set "invalid lock profile name: $shimmy_lock_profile_name"
        return 1
      }
      shimmy_lock_profile_root=$shimmy_lock_config_root/profiles/$shimmy_lock_profile_name
      [ -d "$shimmy_lock_profile_root" ] && [ ! -L "$shimmy_lock_profile_root" ] &&
        shimmy_path_parent_chain_validate "$shimmy_lock_profile_root" || {
          shimmy_lock_error_set "unsafe profile lock root: $shimmy_lock_profile_root"
          return 1
        }
      SHIMMY_LOCK_PROFILE=$shimmy_lock_profile_name
      if [ "$shimmy_lock_kind" = profile ]; then
        SHIMMY_LOCK_RANK=30
        SHIMMY_LOCK_PATH=$shimmy_lock_profile_root/.profile.lock
      else
        SHIMMY_LOCK_RANK=40
        SHIMMY_LOCK_PATH=$shimmy_lock_profile_root/.registries.lock
      fi
      ;;
    *)
      shimmy_lock_error_set "unknown lock kind: $shimmy_lock_kind"
      return 1
      ;;
  esac
}

shimmy_lock_owner_render() {
  shimmy_lock_owner_kind=$1
  shimmy_lock_owner_profile=$2
  shimmy_lock_owner_pid=$3
  shimmy_lock_owner_token=$4
  printf 'shimmy_lock_schema=1\n'
  printf 'shimmy_lock_kind=%s\n' "$shimmy_lock_owner_kind"
  printf 'shimmy_lock_profile=%s\n' "$shimmy_lock_owner_profile"
  printf 'shimmy_lock_pid=%s\n' "$shimmy_lock_owner_pid"
  printf 'shimmy_lock_token=%s\n' "$shimmy_lock_owner_token"
}

shimmy_lock_owner_read() {
  shimmy_lock_owner_file=$1
  shimmy_text_file_validate "$shimmy_lock_owner_file" || return 1
  [ "$(wc -l < "$shimmy_lock_owner_file" | tr -d ' ')" -eq 5 ] || return 1
  SHIMMY_LOCK_OWNER_KIND=$(sed -n '2s/^shimmy_lock_kind=//p' "$shimmy_lock_owner_file")
  SHIMMY_LOCK_OWNER_PROFILE=$(sed -n '3s/^shimmy_lock_profile=//p' "$shimmy_lock_owner_file")
  SHIMMY_LOCK_OWNER_PID=$(sed -n '4s/^shimmy_lock_pid=//p' "$shimmy_lock_owner_file")
  SHIMMY_LOCK_OWNER_TOKEN=$(sed -n '5s/^shimmy_lock_token=//p' "$shimmy_lock_owner_file")
  case "$SHIMMY_LOCK_OWNER_KIND" in catalog|activation|profile|registry) ;; *) return 1 ;; esac
  case "$SHIMMY_LOCK_OWNER_PROFILE" in -) ;; *) shimmy_name_component_validate "$SHIMMY_LOCK_OWNER_PROFILE" || return 1 ;; esac
  case "$SHIMMY_LOCK_OWNER_KIND|$SHIMMY_LOCK_OWNER_PROFILE" in
    catalog\|-|activation\|-) ;;
    profile\|-|registry\|-) return 1 ;;
    profile\|*|registry\|*) ;;
    *) return 1 ;;
  esac
  case "$SHIMMY_LOCK_OWNER_PID" in ''|*[!0123456789]*) return 1 ;; esac
  case "${#SHIMMY_LOCK_OWNER_PID}" in 1|2|3|4|5|6|7|8|9|10) ;; *) return 1 ;; esac
  [ "$SHIMMY_LOCK_OWNER_PID" -gt 0 ] || return 1
  case "$SHIMMY_LOCK_OWNER_TOKEN" in
    "$SHIMMY_LOCK_OWNER_PID"-*) ;;
    *) return 1 ;;
  esac
  shimmy_lock_owner_sequence=${SHIMMY_LOCK_OWNER_TOKEN#"$SHIMMY_LOCK_OWNER_PID"-}
  case "$shimmy_lock_owner_sequence" in ''|*[!0123456789]*) return 1 ;; esac
  [ "$(shimmy_lock_owner_render "$SHIMMY_LOCK_OWNER_KIND" "$SHIMMY_LOCK_OWNER_PROFILE" "$SHIMMY_LOCK_OWNER_PID" "$SHIMMY_LOCK_OWNER_TOKEN")" = "$(cat "$shimmy_lock_owner_file")" ]
}

shimmy_lock_order_validate() {
  shimmy_lock_requested_rank=$1
  shimmy_lock_requested_profile=$2
  shimmy_lock_last_record=$(printf '%s\n' "$SHIMMY_LOCK_HELD_RECORDS" | sed -n '$p')
  [ -n "$shimmy_lock_last_record" ] || return 0
  shimmy_lock_last_rank=${shimmy_lock_last_record%%|*}
  shimmy_lock_last_remainder=${shimmy_lock_last_record#*|}
  shimmy_lock_last_kind=${shimmy_lock_last_remainder%%|*}
  shimmy_lock_last_remainder=${shimmy_lock_last_remainder#*|}
  shimmy_lock_last_profile=${shimmy_lock_last_remainder%%|*}

  [ "$shimmy_lock_requested_rank" -ge "$shimmy_lock_last_rank" ] || {
    shimmy_lock_error_set 'lock order inversion rejected'
    return 1
  }
  if [ "$shimmy_lock_requested_rank" -eq "$shimmy_lock_last_rank" ]; then
    [ "$shimmy_lock_requested_rank" -eq 30 ] || {
      shimmy_lock_error_set "duplicate or same-rank lock rejected after $shimmy_lock_last_kind"
      return 1
    }
    [ "$shimmy_lock_requested_profile" != "$shimmy_lock_last_profile" ] || {
      shimmy_lock_error_set "duplicate profile lock rejected: $shimmy_lock_requested_profile"
      return 1
    }
    shimmy_lock_profiles_sorted=$(printf '%s\n%s\n' "$shimmy_lock_last_profile" "$shimmy_lock_requested_profile" | LC_ALL=C sort)
    [ "$shimmy_lock_profiles_sorted" = "$shimmy_lock_last_profile
$shimmy_lock_requested_profile" ] || {
      shimmy_lock_error_set "profile locks must be acquired in lexical order: $shimmy_lock_last_profile before $shimmy_lock_requested_profile"
      return 1
    }
  fi
}

shimmy_lock_stale_remove() {
  shimmy_lock_stale_path=$1
  shimmy_lock_stale_expected_kind=$2
  shimmy_lock_stale_expected_profile=$3
  shimmy_lock_owner_read "$shimmy_lock_stale_path" || {
    shimmy_lock_error_set "unclassifiable lock owner; refusing stale cleanup: $shimmy_lock_stale_path"
    return 1
  }
  shimmy_lock_stale_kind=$SHIMMY_LOCK_OWNER_KIND
  shimmy_lock_stale_profile=$SHIMMY_LOCK_OWNER_PROFILE
  shimmy_lock_stale_pid=$SHIMMY_LOCK_OWNER_PID
  shimmy_lock_stale_token=$SHIMMY_LOCK_OWNER_TOKEN
  [ "$shimmy_lock_stale_kind" = "$shimmy_lock_stale_expected_kind" ] &&
    [ "$shimmy_lock_stale_profile" = "$shimmy_lock_stale_expected_profile" ] || {
      shimmy_lock_error_set "lock identity does not match its path; refusing stale cleanup: $shimmy_lock_stale_path"
      return 1
    }
  shimmy_lock_stale_fingerprint=$(shimmy_sha256_fingerprint_file_render "$shimmy_lock_stale_path") || return 1
  shimmy_lock_stale_ps_pid=$(ps -p "$shimmy_lock_stale_pid" -o pid= 2>/dev/null | tr -d ' ' || true)
  if kill -0 "$shimmy_lock_stale_pid" 2>/dev/null ||
    [ "$shimmy_lock_stale_ps_pid" = "$shimmy_lock_stale_pid" ]; then
    shimmy_lock_error_set "lock is held by live process $SHIMMY_LOCK_OWNER_PID: $shimmy_lock_stale_path"
    return 1
  fi
  SHIMMY_LOCK_SEQUENCE=$((SHIMMY_LOCK_SEQUENCE + 1))
  shimmy_lock_stale_quarantine=$shimmy_lock_stale_path.stale.$$.$SHIMMY_LOCK_SEQUENCE
  [ ! -e "$shimmy_lock_stale_quarantine" ] && [ ! -L "$shimmy_lock_stale_quarantine" ] || {
    shimmy_lock_error_set "stale-lock quarantine collision: $shimmy_lock_stale_quarantine"
    return 1
  }
  mv "$shimmy_lock_stale_path" "$shimmy_lock_stale_quarantine" 2>/dev/null || return 2
  if ! shimmy_lock_owner_read "$shimmy_lock_stale_quarantine" ||
    [ "$SHIMMY_LOCK_OWNER_KIND" != "$shimmy_lock_stale_kind" ] ||
    [ "$SHIMMY_LOCK_OWNER_PROFILE" != "$shimmy_lock_stale_profile" ] ||
    [ "$SHIMMY_LOCK_OWNER_PID" != "$shimmy_lock_stale_pid" ] ||
    [ "$SHIMMY_LOCK_OWNER_TOKEN" != "$shimmy_lock_stale_token" ] ||
    [ "$(shimmy_sha256_fingerprint_file_render "$shimmy_lock_stale_quarantine")" != "$shimmy_lock_stale_fingerprint" ]; then
    if [ ! -e "$shimmy_lock_stale_path" ] && [ ! -L "$shimmy_lock_stale_path" ]; then
      mv "$shimmy_lock_stale_quarantine" "$shimmy_lock_stale_path" 2>/dev/null || true
    fi
    shimmy_lock_error_set "stale-lock ownership changed during cleanup: $shimmy_lock_stale_path"
    return 1
  fi
  rm -f "$shimmy_lock_stale_quarantine" || return 1
}

shimmy_lock_acquire() {
  shimmy_lock_acquire_kind=$1
  shimmy_lock_acquire_config_root=$2
  shimmy_lock_acquire_profile=${3:-}
  SHIMMY_LOCK_ERROR=
  shimmy_lock_kind_resolve "$shimmy_lock_acquire_kind" "$shimmy_lock_acquire_config_root" "$shimmy_lock_acquire_profile" || return 1
  shimmy_lock_acquire_rank=$SHIMMY_LOCK_RANK
  shimmy_lock_acquire_profile_resolved=$SHIMMY_LOCK_PROFILE
  shimmy_lock_acquire_path=$SHIMMY_LOCK_PATH
  shimmy_lock_order_validate "$shimmy_lock_acquire_rank" "$shimmy_lock_acquire_profile_resolved" || return 1
  shimmy_lock_acquire_path_encoded=$(shimmy_manifest_value_encode "$shimmy_lock_acquire_path") || return 1

  SHIMMY_LOCK_SEQUENCE=$((SHIMMY_LOCK_SEQUENCE + 1))
  shimmy_lock_acquire_token=$$-$SHIMMY_LOCK_SEQUENCE
  shimmy_lock_acquire_candidate=$shimmy_lock_acquire_path.candidate.$$.$SHIMMY_LOCK_SEQUENCE
  [ ! -e "$shimmy_lock_acquire_candidate" ] && [ ! -L "$shimmy_lock_acquire_candidate" ] || {
    shimmy_lock_error_set "lock candidate collision: $shimmy_lock_acquire_candidate"
    return 1
  }
  SHIMMY_LOCK_ACQUIRING_PATH=$shimmy_lock_acquire_path
  SHIMMY_LOCK_ACQUIRING_TOKEN=$shimmy_lock_acquire_token
  SHIMMY_LOCK_ACQUIRING_CANDIDATE=$shimmy_lock_acquire_candidate
  SHIMMY_LOCK_ACQUIRING_ACTIVE=1
  if ! shimmy_lock_owner_render "$shimmy_lock_acquire_kind" "$shimmy_lock_acquire_profile_resolved" "$$" "$shimmy_lock_acquire_token" > "$shimmy_lock_acquire_candidate" ||
    ! chmod 0600 "$shimmy_lock_acquire_candidate" ||
    ! shimmy_lock_owner_read "$shimmy_lock_acquire_candidate"; then
    shimmy_lock_acquiring_cleanup || true
    shimmy_lock_error_set "unable to prepare lock ownership: $shimmy_lock_acquire_path"
    return 1
  fi

  while ! ln "$shimmy_lock_acquire_candidate" "$shimmy_lock_acquire_path" 2>/dev/null; do
    [ -f "$shimmy_lock_acquire_path" ] && [ ! -L "$shimmy_lock_acquire_path" ] || {
      shimmy_lock_error_set "unsafe lock occupant: $shimmy_lock_acquire_path"
      shimmy_lock_acquiring_cleanup || true
      return 1
    }
    if shimmy_lock_stale_remove "$shimmy_lock_acquire_path" "$shimmy_lock_acquire_kind" "$shimmy_lock_acquire_profile_resolved"; then
      shimmy_lock_stale_status=0
    else
      shimmy_lock_stale_status=$?
    fi
    case "$shimmy_lock_stale_status" in
      0|2) ;;
      *) shimmy_lock_acquiring_cleanup || true; return 1 ;;
    esac
  done
  if ! shimmy_lock_owner_read "$shimmy_lock_acquire_path" ||
    [ "$SHIMMY_LOCK_OWNER_PID" != "$$" ] ||
    [ "$SHIMMY_LOCK_OWNER_TOKEN" != "$shimmy_lock_acquire_token" ]; then
    shimmy_lock_acquiring_cleanup || true
    shimmy_lock_error_set "unable to record lock ownership: $shimmy_lock_acquire_path"
    return 1
  fi
  rm -f "$shimmy_lock_acquire_candidate" || {
    shimmy_lock_acquiring_cleanup || true
    return 1
  }
  shimmy_lock_acquire_record=$shimmy_lock_acquire_rank\|$shimmy_lock_acquire_kind\|$shimmy_lock_acquire_profile_resolved\|$shimmy_lock_acquire_path_encoded\|$shimmy_lock_acquire_token
  SHIMMY_LOCK_HELD_RECORDS=$(shimmy_append_line_list "$SHIMMY_LOCK_HELD_RECORDS" "$shimmy_lock_acquire_record")
  SHIMMY_LOCK_ACQUIRING_ACTIVE=0
  SHIMMY_LOCK_ACQUIRING_CANDIDATE=
  SHIMMY_LOCK_ACQUIRING_PATH=
  SHIMMY_LOCK_ACQUIRING_TOKEN=
}

shimmy_lock_release() {
  shimmy_lock_release_record=$(printf '%s\n' "$SHIMMY_LOCK_HELD_RECORDS" | sed -n '$p')
  [ -n "$shimmy_lock_release_record" ] || return 0
  shimmy_lock_release_remainder=${shimmy_lock_release_record#*|}
  shimmy_lock_release_kind=${shimmy_lock_release_remainder%%|*}
  shimmy_lock_release_remainder=${shimmy_lock_release_remainder#*|}
  shimmy_lock_release_profile=${shimmy_lock_release_remainder%%|*}
  shimmy_lock_release_remainder=${shimmy_lock_release_remainder#*|}
  shimmy_lock_release_path_encoded=${shimmy_lock_release_remainder%%|*}
  shimmy_lock_release_path=$(shimmy_manifest_value_decode "$shimmy_lock_release_path_encoded") || return 1
  shimmy_lock_release_token=${shimmy_lock_release_remainder#*|}
  shimmy_path_parent_chain_validate "$(dirname -- "$shimmy_lock_release_path")" || {
    shimmy_lock_error_set "lock parent changed; refusing release: $shimmy_lock_release_path"
    return 1
  }
  shimmy_lock_owner_read "$shimmy_lock_release_path" &&
    [ "$SHIMMY_LOCK_OWNER_KIND" = "$shimmy_lock_release_kind" ] &&
    [ "$SHIMMY_LOCK_OWNER_PROFILE" = "$shimmy_lock_release_profile" ] &&
    [ "$SHIMMY_LOCK_OWNER_PID" = "$$" ] &&
    [ "$SHIMMY_LOCK_OWNER_TOKEN" = "$shimmy_lock_release_token" ] || {
      shimmy_lock_error_set "lock ownership changed; refusing release: $shimmy_lock_release_path"
      return 1
    }
  rm -f "$shimmy_lock_release_path" || return 1
  SHIMMY_LOCK_HELD_RECORDS=$(printf '%s\n' "$SHIMMY_LOCK_HELD_RECORDS" | sed '$d')
}

shimmy_lock_held() {
  shimmy_lock_held_kind=$1
  shimmy_lock_held_profile=${2:--}
  case "$shimmy_lock_held_kind|$shimmy_lock_held_profile" in
    catalog\|-|activation\|-) ;;
    profile\|-|registry\|-) return 1 ;;
    profile\|*|registry\|*) shimmy_name_component_validate "$shimmy_lock_held_profile" || return 1 ;;
    *) return 1 ;;
  esac
  while IFS='|' read -r shimmy_lock_held_rank shimmy_lock_held_record_kind shimmy_lock_held_record_profile shimmy_lock_held_remainder; do
    [ -n "$shimmy_lock_held_rank" ] || continue
    if [ "$shimmy_lock_held_record_kind" = "$shimmy_lock_held_kind" ] &&
      [ "$shimmy_lock_held_record_profile" = "$shimmy_lock_held_profile" ]; then
      return 0
    fi
  done <<EOF
$SHIMMY_LOCK_HELD_RECORDS
EOF
  return 1
}

shimmy_locks_release_all() {
  shimmy_lock_release_all_status=0
  while [ -n "$SHIMMY_LOCK_HELD_RECORDS" ]; do
    shimmy_lock_release || {
      shimmy_lock_release_all_status=1
      break
    }
  done
  return "$shimmy_lock_release_all_status"
}

shimmy_lock_acquiring_cleanup() {
  [ "$SHIMMY_LOCK_ACQUIRING_ACTIVE" -eq 1 ] || return 0
  shimmy_lock_acquiring_cleanup_path=$SHIMMY_LOCK_ACQUIRING_PATH
  if shimmy_path_parent_chain_validate "$(dirname -- "$shimmy_lock_acquiring_cleanup_path")" &&
    [ -f "$shimmy_lock_acquiring_cleanup_path" ] &&
    [ ! -L "$shimmy_lock_acquiring_cleanup_path" ]; then
    shimmy_lock_owner_read "$shimmy_lock_acquiring_cleanup_path" &&
      [ "$SHIMMY_LOCK_OWNER_PID" = "$$" ] &&
      [ "$SHIMMY_LOCK_OWNER_TOKEN" = "$SHIMMY_LOCK_ACQUIRING_TOKEN" ] &&
      rm -f "$shimmy_lock_acquiring_cleanup_path" || true
  fi
  case "$SHIMMY_LOCK_ACQUIRING_CANDIDATE" in
    "$shimmy_lock_acquiring_cleanup_path".candidate.$$.*)
      shimmy_path_parent_chain_validate "$(dirname -- "$SHIMMY_LOCK_ACQUIRING_CANDIDATE")" &&
        rm -f "$SHIMMY_LOCK_ACQUIRING_CANDIDATE"
      ;;
  esac
  SHIMMY_LOCK_ACQUIRING_ACTIVE=0
  SHIMMY_LOCK_ACQUIRING_CANDIDATE=
  SHIMMY_LOCK_ACQUIRING_PATH=
  SHIMMY_LOCK_ACQUIRING_TOKEN=
}

shimmy_locks_signal_handle() {
  shimmy_lock_signal=$1
  shimmy_lock_acquiring_cleanup || true
  shimmy_locks_release_all || true
  trap - 0 "$shimmy_lock_signal"
  case "$shimmy_lock_signal" in
    HUP) exit 129 ;;
    INT) exit 130 ;;
    TERM) exit 143 ;;
  esac
}

shimmy_locks_cleanup_install() {
  trap 'shimmy_lock_acquiring_cleanup || true; shimmy_locks_release_all' 0
  trap 'shimmy_locks_signal_handle HUP' HUP
  trap 'shimmy_locks_signal_handle INT' INT
  trap 'shimmy_locks_signal_handle TERM' TERM
}
