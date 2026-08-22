#!/bin/sh
# Installed profile lifecycle command.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
SHIMMY_CONTROL_ROOT=$ROOT_DIR

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for shimmy_helper in \
  lib/common/common.sh lib/common/lock.sh lib/catalog/catalog.sh \
  lib/catalog/state.sh lib/catalog/authority.sh lib/shim/state.sh \
  lib/ai-skill/bundle.sh lib/profile/state.sh lib/install/manifest.sh \
  lib/profile/transaction.sh lib/ai-skill/link.sh lib/shim/shim.sh \
  lib/ai-skill/ai-skill.sh lib/install/profile.sh \
  lib/profile/profile.sh lib/profile/activation.sh \
  lib/registries/registries.sh lib/profile/management.sh \
  lib/startup/startup.sh lib/install/lifecycle.sh lib/install/uninstall.sh \
  lib/update/profile.sh
do
  [ -f "$ROOT_DIR/$shimmy_helper" ] && [ ! -L "$ROOT_DIR/$shimmy_helper" ] ||
    fail "missing profile helper: $shimmy_helper"
  . "$ROOT_DIR/$shimmy_helper"
done

usage() {
  cat <<'EOF'
Manage Shimmy profiles.

Usage:
  shimmy profile list [--format human|manifest]
  shimmy profile status [--format human|manifest]
  shimmy profile create <name> [--restart] [--stop-running] [--dry-run]
  shimmy profile activate <name> [--restart] [--stop-running] [--dry-run]
  shimmy profile sync
  shimmy profile repair-startup
  shimmy profile delete <name> [--stop-running]
  shimmy profile redirect list [--format human|manifest]
  shimmy profile redirect set --prefix <logical> --location <physical> [--dry-run]
  shimmy profile redirect delete (--prefix <logical> | --all) [--detach] [--dry-run]

Status and redirect use the invoking profile identity set by the launcher.
Activation changes engine/registry authority first,
then the active record and exact AI-skill links with bounded rollback.
EOF
}

shimmy_profile_command_cleanup() {
  shimmy_profile_sync_cleanup
  shimmy_profile_bootstrap_cleanup
  shimmy_profile_cleanup
}
trap shimmy_profile_command_cleanup EXIT
trap 'shimmy_profile_command_cleanup; trap - HUP; exit 129' HUP
trap 'shimmy_profile_command_cleanup; trap - INT; exit 130' INT
trap 'shimmy_profile_command_cleanup; trap - TERM; exit 143' TERM

[ "$#" -gt 0 ] || { usage; exit 0; }
case "$1" in -h|--help|help) usage; exit 0 ;; esac
shimmy_profile_action=$1
shift
shimmy_profile_config=${SHIMMY_CONFIG_ROOT:-}
[ -n "$shimmy_profile_config" ] || fail 'profile commands must run through an installed profile launcher'
shimmy_path_absolute_normalized_validate "$shimmy_profile_config" || fail 'invalid SHIMMY_CONFIG_ROOT'
shimmy_profile_invoking=${SHIMMY_INVOKING_PROFILE:-}

case "$shimmy_profile_action" in
  create)
    shimmy_name_component_validate "$shimmy_profile_invoking" || fail 'create requires a valid invoking profile identity'
    [ "$#" -ge 1 ] || fail 'profile create requires a new profile name'
    shimmy_profile_name=$1
    shimmy_name_component_validate "$shimmy_profile_name" || fail "invalid profile name: $shimmy_profile_name"
    shift
    shimmy_profile_restart=0
    shimmy_profile_stop_running=0
    shimmy_profile_dry_run=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --restart) [ "$shimmy_profile_restart" -eq 0 ] || fail 'duplicate option: --restart'; shimmy_profile_restart=1 ;;
        --stop-running) [ "$shimmy_profile_stop_running" -eq 0 ] || fail 'duplicate option: --stop-running'; shimmy_profile_stop_running=1 ;;
        --dry-run) [ "$shimmy_profile_dry_run" -eq 0 ] || fail 'duplicate option: --dry-run'; shimmy_profile_dry_run=1 ;;
        *) fail "unknown profile create argument: $1" ;;
      esac
      shift
    done
    shimmy_profile_create_run "$shimmy_profile_config" "$shimmy_profile_invoking" \
      "$shimmy_profile_name" "$shimmy_profile_restart" \
      "$shimmy_profile_stop_running" "$shimmy_profile_dry_run" ||
      fail "${SHIMMY_PROFILE_LIFECYCLE_ERROR:-profile creation failed}"
    ;;
  list)
    shimmy_profile_format=human
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; shimmy_profile_format=$2; shift 2 ;;
        *) fail "unknown profile list argument: $1" ;;
      esac
    done
    case "$shimmy_profile_format" in human|manifest) ;; *) fail "unsupported profile list format: $shimmy_profile_format" ;; esac
    shimmy_profile_list_render "$shimmy_profile_config" "$shimmy_profile_format" ||
      fail "${SHIMMY_PROFILE_ERROR:-unable to list profiles}"
    ;;
  status)
    shimmy_profile_format=human
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; shimmy_profile_format=$2; shift 2 ;;
        *) fail "unknown profile status argument: $1" ;;
      esac
    done
    shimmy_name_component_validate "$shimmy_profile_invoking" || fail 'status requires a valid invoking profile identity'
    case "$shimmy_profile_format" in human|manifest) ;; *) fail "unsupported profile status format: $shimmy_profile_format" ;; esac
    shimmy_profile_status_render "$shimmy_profile_config" "$shimmy_profile_invoking" "$shimmy_profile_format" ||
      fail "${SHIMMY_PROFILE_ERROR:-unable to inspect profile}"
    ;;
  sync)
    [ "$#" -eq 0 ] || fail 'profile sync accepts no arguments'
    shimmy_name_component_validate "$shimmy_profile_invoking" || fail 'sync requires a valid invoking profile identity'
    shimmy_profile_sync_run "$shimmy_profile_config" "$shimmy_profile_invoking" ||
      fail "${SHIMMY_PROFILE_SYNC_ERROR:-profile sync failed}"
    ;;
  repair-startup)
    [ "$#" -eq 0 ] || fail 'profile repair-startup accepts no arguments'
    shimmy_name_component_validate "$shimmy_profile_invoking" || fail 'startup repair requires a valid invoking profile identity'
    shimmy_profile_startup_repair_run "$shimmy_profile_config" "$shimmy_profile_invoking" ||
      fail 'profile startup repair failed'
    ;;
  delete)
    [ "$#" -ge 1 ] || fail 'profile delete requires an installed profile name'
    shimmy_profile_name=$1
    shimmy_name_component_validate "$shimmy_profile_name" || fail "invalid profile name: $shimmy_profile_name"
    shift
    shimmy_profile_stop_running=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --stop-running) [ "$shimmy_profile_stop_running" -eq 0 ] || fail 'duplicate option: --stop-running'; shimmy_profile_stop_running=1 ;;
        *) fail "unknown profile delete argument: $1" ;;
      esac
      shift
    done
    shimmy_profile_delete_run "$shimmy_profile_config" "$shimmy_profile_name" \
      "$shimmy_profile_stop_running" ||
      fail "${SHIMMY_UNINSTALL_ERROR:-profile deletion failed}"
    ;;
  activate)
    [ "$#" -ge 1 ] || fail 'profile activate requires an installed profile name'
    shimmy_profile_name=$1
    shimmy_name_component_validate "$shimmy_profile_name" || fail "invalid profile name: $shimmy_profile_name"
    shift
    shimmy_profile_restart=0
    shimmy_profile_stop_running=0
    shimmy_profile_dry_run=0
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --restart) [ "$shimmy_profile_restart" -eq 0 ] || fail 'duplicate option: --restart'; shimmy_profile_restart=1 ;;
        --stop-running) [ "$shimmy_profile_stop_running" -eq 0 ] || fail 'duplicate option: --stop-running'; shimmy_profile_stop_running=1 ;;
        --dry-run) [ "$shimmy_profile_dry_run" -eq 0 ] || fail 'duplicate option: --dry-run'; shimmy_profile_dry_run=1 ;;
        *) fail "unknown profile activate argument: $1" ;;
      esac
      shift
    done
    shimmy_profile_activate_run "$shimmy_profile_config" "$shimmy_profile_name" \
      "$shimmy_profile_restart" "$shimmy_profile_stop_running" "$shimmy_profile_dry_run" ||
      fail "${SHIMMY_PROFILE_ERROR:-profile activation failed}"
    ;;
  redirect)
    shimmy_name_component_validate "$shimmy_profile_invoking" || fail 'redirect requires a valid invoking profile identity'
    shimmy_profile_redirect_action=${1:-}
    [ -n "$shimmy_profile_redirect_action" ] || fail 'profile redirect requires list, set, or delete'
    shift
    case "$shimmy_profile_redirect_action" in
      list)
        shimmy_profile_format=human
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; shimmy_profile_format=$2; shift 2 ;;
            *) fail "unknown profile redirect list argument: $1" ;;
          esac
        done
        case "$shimmy_profile_format" in human|manifest) ;; *) fail "unsupported profile redirect format: $shimmy_profile_format" ;; esac
        shimmy_profile_redirect_context_resolve "$shimmy_profile_config" "$shimmy_profile_invoking" ||
          fail "${SHIMMY_PROFILE_ERROR:-unable to inspect profile redirects}"
        shimmy_profile_redirect_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") ||
          fail 'invalid registry configuration'
        shimmy_profile_state_read
        shimmy_registries_active_link_state_read
        shimmy_profile_redirect_policy=$(shimmy_registries_policy_state_read)
        if [ "$shimmy_profile_format" = manifest ]; then
          printf 'shimmy_profile_redirect_profile=%s\n' "$SHIMMY_PROFILE_NAME"
          printf 'shimmy_profile_redirect_policy=%s\n' "$shimmy_profile_redirect_policy"
          printf 'shimmy_profile_redirect_active=%s\n' "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE"
          while IFS= read -r shimmy_profile_redirect_entry; do
            [ -z "$shimmy_profile_redirect_entry" ] || printf 'shimmy_profile_redirect=%s\n' "$shimmy_profile_redirect_entry"
          done <<EOF
$shimmy_profile_redirect_entries
EOF
        else
          shimmy_style_init
          printf '%s%-12s %-12s %-10s%s\n' "$SHIMMY_STYLE_DIM" "PROFILE" "POLICY" "ACTIVE" "$SHIMMY_STYLE_RESET"
          shimmy_active_fmt=$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE
          if [ "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" = yes ] && [ -n "$SHIMMY_STYLE_GREEN" ]; then
            shimmy_active_fmt="${SHIMMY_STYLE_GREEN}yes${SHIMMY_STYLE_RESET}      "
            printf '%-12s %-12s %s\n' "$SHIMMY_PROFILE_NAME" "$shimmy_profile_redirect_policy" "$shimmy_active_fmt"
          else
            printf '%-12s %-12s %-10s\n' "$SHIMMY_PROFILE_NAME" "$shimmy_profile_redirect_policy" "$shimmy_active_fmt"
          fi
          if [ -z "$shimmy_profile_redirect_entries" ]; then printf '%s\n' 'Redirects: none'; else printf 'Redirects:\n%s\n' "$shimmy_profile_redirect_entries"; fi
        fi
        ;;
      set)
        shimmy_profile_redirect_prefix=
        shimmy_profile_redirect_location=
        shimmy_profile_redirect_dry_run=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --prefix) [ "$#" -ge 2 ] || fail 'missing value for --prefix'; [ -z "$shimmy_profile_redirect_prefix" ] || fail 'duplicate option: --prefix'; shimmy_profile_redirect_prefix=$2; shift 2 ;;
            --location) [ "$#" -ge 2 ] || fail 'missing value for --location'; [ -z "$shimmy_profile_redirect_location" ] || fail 'duplicate option: --location'; shimmy_profile_redirect_location=$2; shift 2 ;;
            --dry-run) [ "$shimmy_profile_redirect_dry_run" -eq 0 ] || fail 'duplicate option: --dry-run'; shimmy_profile_redirect_dry_run=1; shift ;;
            *) fail "unknown profile redirect set argument: $1" ;;
          esac
        done
        shimmy_registries_endpoint_validate "$shimmy_profile_redirect_prefix" || fail 'invalid logical registry prefix'
        shimmy_registries_endpoint_validate "$shimmy_profile_redirect_location" || fail 'invalid physical registry location'
        shimmy_profile_redirect_mutate "$shimmy_profile_config" "$shimmy_profile_invoking" upsert \
          "$shimmy_profile_redirect_prefix" "$shimmy_profile_redirect_location" 0 "$shimmy_profile_redirect_dry_run" ||
          fail "${SHIMMY_PROFILE_ERROR:-redirect mutation failed}"
        ;;
      delete)
        shimmy_profile_redirect_prefix=
        shimmy_profile_redirect_all=0
        shimmy_profile_redirect_detach=0
        shimmy_profile_redirect_dry_run=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --prefix) [ "$#" -ge 2 ] || fail 'missing value for --prefix'; [ -z "$shimmy_profile_redirect_prefix" ] || fail 'duplicate option: --prefix'; shimmy_profile_redirect_prefix=$2; shift 2 ;;
            --all) [ "$shimmy_profile_redirect_all" -eq 0 ] || fail 'duplicate option: --all'; shimmy_profile_redirect_all=1; shift ;;
            --detach) [ "$shimmy_profile_redirect_detach" -eq 0 ] || fail 'duplicate option: --detach'; shimmy_profile_redirect_detach=1; shift ;;
            --dry-run) [ "$shimmy_profile_redirect_dry_run" -eq 0 ] || fail 'duplicate option: --dry-run'; shimmy_profile_redirect_dry_run=1; shift ;;
            *) fail "unknown profile redirect delete argument: $1" ;;
          esac
        done
        [ "$shimmy_profile_redirect_all" -eq 0 ] || [ -z "$shimmy_profile_redirect_prefix" ] || fail '--all cannot be combined with --prefix'
        if [ "$shimmy_profile_redirect_all" -eq 0 ]; then
          shimmy_registries_endpoint_validate "$shimmy_profile_redirect_prefix" || fail 'redirect delete requires a valid --prefix or --all'
          [ "$shimmy_profile_redirect_detach" -eq 0 ] || fail '--detach requires --all'
          shimmy_profile_redirect_mutation=remove
        else
          shimmy_profile_redirect_mutation=remove_all
        fi
        shimmy_profile_redirect_mutate "$shimmy_profile_config" "$shimmy_profile_invoking" \
          "$shimmy_profile_redirect_mutation" "$shimmy_profile_redirect_prefix" '' \
          "$shimmy_profile_redirect_detach" "$shimmy_profile_redirect_dry_run" ||
          fail "${SHIMMY_PROFILE_ERROR:-redirect mutation failed}"
        ;;
      *) fail "unknown profile redirect action: $shimmy_profile_redirect_action" ;;
    esac
    ;;
  *) fail "unknown profile action: $shimmy_profile_action" ;;
esac
