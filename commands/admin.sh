#!/bin/sh
# Installed installation-administration command.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
SHIMMY_ROOT_DIR=$ROOT_DIR

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for shimmy_helper in \
  lib/common/common.sh lib/common/lock.sh lib/catalog/catalog.sh \
  lib/catalog/state.sh lib/catalog/authority.sh lib/shim/state.sh \
  lib/ai-skill/bundle.sh lib/profile/state.sh lib/install/manifest.sh \
  lib/profile/transaction.sh lib/ai-skill/link.sh lib/shim/shim.sh \
  lib/ai-skill/ai-skill.sh lib/install/profile.sh \
  lib/engine/state.sh lib/engine/podman.sh lib/engine/ownership.sh \
  lib/engine/lifecycle.sh lib/engine/projection.sh lib/engine/registry.sh \
  lib/profile/profile.sh lib/profile/activation.sh \
  lib/registries/registries.sh lib/profile/management.sh \
  lib/startup/startup.sh lib/install/lifecycle.sh \
  lib/install/uninstall.sh lib/update/profile.sh
do
  [ -f "$ROOT_DIR/$shimmy_helper" ] && [ ! -L "$ROOT_DIR/$shimmy_helper" ] ||
    fail "missing administration helper: $shimmy_helper"
  . "$ROOT_DIR/$shimmy_helper"
done

usage() {
  cat <<'EOF'
Manage the active Shimmy installation.

Usage:
  shimmy admin status [--format human|manifest]
  shimmy admin engine status [--format human|manifest]
  shimmy admin network [--target <host-or-ip> ...]
    [--host-name <name>] [--host-ip <ipv4>] [--host-prefix <bits>]
    [--host-lan <cidr>] [--format human|manifest]
  shimmy admin uninstall [--stop-running] [--dry-run]
EOF
}

shimmy_admin_cleanup() {
  shimmy_profile_sync_cleanup
  shimmy_profile_bootstrap_cleanup
  shimmy_profile_cleanup
}

shimmy_admin_profile_manifest_render() {
  shimmy_admin_profile_name=$1
  shimmy_admin_profile_output=$2
  printf 'shimmy_admin_profile=%s|ok|-\n' "$shimmy_admin_profile_name"
  while IFS= read -r shimmy_admin_profile_line; do
    [ -n "$shimmy_admin_profile_line" ] || continue
    case "$shimmy_admin_profile_line" in
      *=*)
        shimmy_admin_profile_key=${shimmy_admin_profile_line%%=*}
        shimmy_admin_profile_value=${shimmy_admin_profile_line#*=}
        ;;
      *) return 1 ;;
    esac
    shimmy_shell_function_name_validate "$shimmy_admin_profile_key" || return 1
    printf 'shimmy_admin_profile_record=%s|%s|%s\n' "$shimmy_admin_profile_name" \
      "$shimmy_admin_profile_key" \
      "$(shimmy_manifest_value_encode "$shimmy_admin_profile_value")"
  done <<EOF
$shimmy_admin_profile_output
EOF
}

shimmy_admin_status_render() {
  shimmy_admin_status_config=$1
  shimmy_admin_status_format=$2
  shimmy_profile_installation_context_resolve "$shimmy_admin_status_config" || return 1
  shimmy_admin_status_active=$SHIMMY_PROFILE_ACTIVE_NAME
  if [ "$shimmy_admin_status_format" = manifest ]; then
    printf 'shimmy_admin_active_profile=%s\n' "$shimmy_admin_status_active"
  else
    shimmy_style_init
    shimmy_section_header "INSTALLATION STATUS"
    printf 'Active Profile:  %s%s%s\n' "$SHIMMY_STYLE_GREEN" "$shimmy_admin_status_active" "$SHIMMY_STYLE_RESET"
    printf 'Config Root:     %s\n\n' "$shimmy_admin_status_config"
    shimmy_section_header "CATALOG AUTHORITY"
    shimmy_catalog_status_render "$shimmy_admin_status_config" human || return 1
    printf '\n'
    shimmy_section_header "MATERIALIZED PROFILES"
  fi
  shimmy_admin_status_names=
  for shimmy_admin_status_path in "$SHIMMY_PROFILES_ROOT"/*; do
    [ -e "$shimmy_admin_status_path" ] || [ -L "$shimmy_admin_status_path" ] || continue
    shimmy_admin_status_name=$(basename -- "$shimmy_admin_status_path")
    shimmy_name_component_validate "$shimmy_admin_status_name" &&
      [ -d "$shimmy_admin_status_path" ] && [ ! -L "$shimmy_admin_status_path" ] || return 1
    shimmy_admin_status_names=$(shimmy_append_line_list "$shimmy_admin_status_names" \
      "$shimmy_admin_status_name")
  done
  shimmy_admin_status_names=$(printf '%s\n' "$shimmy_admin_status_names" | sed '/^$/d' | LC_ALL=C sort)
  while IFS= read -r shimmy_admin_status_name; do
    [ -n "$shimmy_admin_status_name" ] || continue
    if shimmy_admin_status_profile=$(shimmy_profile_status_render \
      "$shimmy_admin_status_config" "$shimmy_admin_status_name" \
      "$shimmy_admin_status_format" 2>&1); then
      if [ "$shimmy_admin_status_format" = manifest ]; then
        shimmy_admin_profile_manifest_render "$shimmy_admin_status_name" \
          "$shimmy_admin_status_profile" || return 1
      else
        printf '\n%s\n' "$shimmy_admin_status_profile"
      fi
    else
      shimmy_admin_status_reason=$(shimmy_manifest_diagnostic_encode \
        "$shimmy_admin_status_profile")
      if [ "$shimmy_admin_status_format" = manifest ]; then
        printf 'shimmy_admin_profile=%s|error|%s\n' "$shimmy_admin_status_name" \
          "$shimmy_admin_status_reason"
      else
        printf '\nPROFILE %s\nState: invalid\nReason: %s\n' "$shimmy_admin_status_name" \
          "$shimmy_admin_status_profile"
      fi
    fi
  done <<EOF
$shimmy_admin_status_names
EOF
}

trap shimmy_admin_cleanup EXIT
trap 'shimmy_admin_cleanup; trap - HUP; exit 129' HUP
trap 'shimmy_admin_cleanup; trap - INT; exit 130' INT
trap 'shimmy_admin_cleanup; trap - TERM; exit 143' TERM

[ "$#" -gt 0 ] || { usage; exit 0; }
case "$1" in -h|--help|help) usage; exit 0 ;; esac
shimmy_admin_action=$1
shift
shimmy_admin_config=${SHIMMY_CONFIG_ROOT:-}
[ -n "$shimmy_admin_config" ] || fail 'administration must run through an installed profile launcher'
shimmy_path_absolute_normalized_validate "$shimmy_admin_config" || fail 'invalid SHIMMY_CONFIG_ROOT'

case "$shimmy_admin_action" in
  status)
    shimmy_admin_format=human
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; shimmy_admin_format=$2; shift 2 ;;
        *) fail "unknown admin status argument: $1" ;;
      esac
    done
    case "$shimmy_admin_format" in human|manifest) ;; *) fail "unsupported admin status format: $shimmy_admin_format" ;; esac
    shimmy_admin_status_render "$shimmy_admin_config" "$shimmy_admin_format" ||
      fail 'unable to inspect installation state'
    ;;
  network)
    shimmy_profile_installation_context_resolve "$shimmy_admin_config" ||
      fail "${SHIMMY_PROFILE_ERROR:-unable to resolve active profile for network inspection}"
    . "$ROOT_DIR/lib/netinfo/netinfo.sh"
    shimmy_netinfo_run "$@"
    ;;
  engine)
    shimmy_admin_engine_action=${1:-}
    [ -n "$shimmy_admin_engine_action" ] || fail 'admin engine requires status'
    shift
    case "$shimmy_admin_engine_action" in
      status)
        shimmy_admin_engine_format=human
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; shimmy_admin_engine_format=$2; shift 2 ;;
            *) fail "unknown admin engine status argument: $1" ;;
          esac
        done
        shimmy_engine_registry_status_render "$shimmy_admin_config" "$shimmy_admin_engine_format" ||
          fail 'unable to inspect engine registry state'
        ;;
      *) fail "unknown admin engine action: $shimmy_admin_engine_action" ;;
    esac
    ;;
  uninstall)
    shimmy_admin_stop_running=0
    shimmy_admin_uninstall_dry_run=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --stop-running) [ "$shimmy_admin_stop_running" -eq 0 ] || fail 'duplicate option: --stop-running'; shimmy_admin_stop_running=1 ;;
        --dry-run) [ "$shimmy_admin_uninstall_dry_run" -eq 0 ] || fail 'duplicate option: --dry-run'; shimmy_admin_uninstall_dry_run=1 ;;
        *) fail "unknown admin uninstall argument: $1" ;;
      esac
      shift
    done
    shimmy_uninstall_run "$shimmy_admin_config" "$shimmy_admin_stop_running" \
      "$shimmy_admin_uninstall_dry_run" ||
      fail "${SHIMMY_UNINSTALL_ERROR:-administration uninstall failed}"
    ;;
  *) fail "unknown administration action: $shimmy_admin_action" ;;
esac
