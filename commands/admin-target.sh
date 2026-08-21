#!/bin/sh
# Uninstalled private target installation administration candidate.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
SHIMMY_CONTROL_ROOT=$ROOT_DIR

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for shimmy_target_helper in \
  lib/common/common.sh lib/common/lock.sh lib/catalog/catalog.sh \
  lib/catalog/state.sh lib/catalog/target.sh lib/shim/state.sh \
  lib/ai-skill/bundle.sh lib/profile/state.sh lib/install/manifest.sh \
  lib/profile/transaction.sh lib/ai-skill/link.sh lib/shim/target.sh \
  lib/ai-skill/target.sh lib/install/profile-target.sh \
  lib/profile/profile.sh lib/profile/activation.sh \
  lib/registries/registries.sh lib/profile/target.sh \
  lib/startup/startup.sh lib/install/lifecycle-target.sh \
  lib/install/uninstall-target.sh lib/update/profile-target.sh
do
  [ -f "$ROOT_DIR/$shimmy_target_helper" ] && [ ! -L "$ROOT_DIR/$shimmy_target_helper" ] ||
    fail "missing target administration helper: $shimmy_target_helper"
  . "$ROOT_DIR/$shimmy_target_helper"
done

usage() {
  cat <<'EOF'
Private target installation administration candidate.

Usage:
  admin-target.sh status [--format human|manifest]
  admin-target.sh network [--target <host-or-ip> ...]
    [--host-name <name>] [--host-ip <ipv4>] [--host-prefix <bits>]
    [--host-lan <cidr>] [--format human|manifest]
  admin-target.sh uninstall [--stop-running]
EOF
}

shimmy_target_admin_cleanup() {
  shimmy_target_profile_sync_cleanup
  shimmy_target_profile_bootstrap_cleanup
  shimmy_target_profile_cleanup
}

shimmy_target_admin_profile_manifest_render() {
  shimmy_target_admin_profile_name=$1
  shimmy_target_admin_profile_output=$2
  printf 'shimmy_admin_profile=%s|ok|-\n' "$shimmy_target_admin_profile_name"
  while IFS= read -r shimmy_target_admin_profile_line; do
    [ -n "$shimmy_target_admin_profile_line" ] || continue
    case "$shimmy_target_admin_profile_line" in
      *=*)
        shimmy_target_admin_profile_key=${shimmy_target_admin_profile_line%%=*}
        shimmy_target_admin_profile_value=${shimmy_target_admin_profile_line#*=}
        ;;
      *) return 1 ;;
    esac
    shimmy_shell_function_name_validate "$shimmy_target_admin_profile_key" || return 1
    printf 'shimmy_admin_profile_record=%s|%s|%s\n' "$shimmy_target_admin_profile_name" \
      "$shimmy_target_admin_profile_key" \
      "$(shimmy_manifest_value_encode "$shimmy_target_admin_profile_value")"
  done <<EOF
$shimmy_target_admin_profile_output
EOF
}

shimmy_target_admin_status_render() {
  shimmy_target_admin_status_config=$1
  shimmy_target_admin_status_format=$2
  shimmy_target_profile_installation_context_resolve "$shimmy_target_admin_status_config" || return 1
  shimmy_target_admin_status_active=$SHIMMY_TARGET_PROFILE_ACTIVE_NAME
  if [ "$shimmy_target_admin_status_format" = manifest ]; then
    printf 'shimmy_admin_active_profile=%s\n' "$shimmy_target_admin_status_active"
  else
    printf 'INSTALLATION\nActive profile: %s\n\nCATALOG\n' "$shimmy_target_admin_status_active"
    shimmy_target_catalog_status_render "$shimmy_target_admin_status_config" human || return 1
    printf '\nPROFILES\n'
  fi
  shimmy_target_admin_status_names=
  for shimmy_target_admin_status_path in "$SHIMMY_TARGET_PROFILES_ROOT"/*; do
    [ -e "$shimmy_target_admin_status_path" ] || [ -L "$shimmy_target_admin_status_path" ] || continue
    shimmy_target_admin_status_name=$(basename -- "$shimmy_target_admin_status_path")
    shimmy_name_component_validate "$shimmy_target_admin_status_name" &&
      [ -d "$shimmy_target_admin_status_path" ] && [ ! -L "$shimmy_target_admin_status_path" ] || return 1
    shimmy_target_admin_status_names=$(shimmy_append_line_list "$shimmy_target_admin_status_names" \
      "$shimmy_target_admin_status_name")
  done
  shimmy_target_admin_status_names=$(printf '%s\n' "$shimmy_target_admin_status_names" | sed '/^$/d' | LC_ALL=C sort)
  while IFS= read -r shimmy_target_admin_status_name; do
    [ -n "$shimmy_target_admin_status_name" ] || continue
    if shimmy_target_admin_status_profile=$(shimmy_target_profile_status_render \
      "$shimmy_target_admin_status_config" "$shimmy_target_admin_status_name" \
      "$shimmy_target_admin_status_format" 2>&1); then
      if [ "$shimmy_target_admin_status_format" = manifest ]; then
        shimmy_target_admin_profile_manifest_render "$shimmy_target_admin_status_name" \
          "$shimmy_target_admin_status_profile" || return 1
      else
        printf '\n%s\n' "$shimmy_target_admin_status_profile"
      fi
    else
      shimmy_target_admin_status_reason=$(shimmy_manifest_diagnostic_encode \
        "$shimmy_target_admin_status_profile")
      if [ "$shimmy_target_admin_status_format" = manifest ]; then
        printf 'shimmy_admin_profile=%s|error|%s\n' "$shimmy_target_admin_status_name" \
          "$shimmy_target_admin_status_reason"
      else
        printf '\nPROFILE %s\nState: invalid\nReason: %s\n' "$shimmy_target_admin_status_name" \
          "$shimmy_target_admin_status_profile"
      fi
    fi
  done <<EOF
$shimmy_target_admin_status_names
EOF
}

trap shimmy_target_admin_cleanup EXIT
trap 'shimmy_target_admin_cleanup; trap - HUP; exit 129' HUP
trap 'shimmy_target_admin_cleanup; trap - INT; exit 130' INT
trap 'shimmy_target_admin_cleanup; trap - TERM; exit 143' TERM

[ "$#" -gt 0 ] || { usage; exit 0; }
case "$1" in -h|--help|help) usage; exit 0 ;; esac
shimmy_target_admin_action=$1
shift
shimmy_target_admin_config=${SHIMMY_TARGET_CONFIG_ROOT:-}
[ -n "$shimmy_target_admin_config" ] || fail 'SHIMMY_TARGET_CONFIG_ROOT is required for private target administration'
shimmy_path_absolute_normalized_validate "$shimmy_target_admin_config" || fail 'invalid SHIMMY_TARGET_CONFIG_ROOT'

case "$shimmy_target_admin_action" in
  status)
    shimmy_target_admin_format=human
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; shimmy_target_admin_format=$2; shift 2 ;;
        *) fail "unknown admin status argument: $1" ;;
      esac
    done
    case "$shimmy_target_admin_format" in human|manifest) ;; *) fail "unsupported admin status format: $shimmy_target_admin_format" ;; esac
    shimmy_target_admin_status_render "$shimmy_target_admin_config" "$shimmy_target_admin_format" ||
      fail 'unable to inspect target installation state'
    ;;
  network)
    shimmy_target_profile_installation_context_resolve "$shimmy_target_admin_config" ||
      fail "${SHIMMY_TARGET_PROFILE_ERROR:-unable to resolve active profile for network inspection}"
    . "$ROOT_DIR/lib/netinfo/netinfo.sh"
    shimmy_netinfo_run "$@"
    ;;
  uninstall)
    shimmy_target_admin_stop_running=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --stop-running) [ "$shimmy_target_admin_stop_running" -eq 0 ] || fail 'duplicate option: --stop-running'; shimmy_target_admin_stop_running=1 ;;
        *) fail "unknown admin uninstall argument: $1" ;;
      esac
      shift
    done
    shimmy_target_uninstall_run "$shimmy_target_admin_config" "$shimmy_target_admin_stop_running" ||
      fail "${SHIMMY_TARGET_UNINSTALL_ERROR:-target administration uninstall failed}"
    ;;
  *) fail "unknown target administration action: $shimmy_target_admin_action" ;;
esac
