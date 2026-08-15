#!/bin/sh
# Inspect or activate the invoking installed profile's Podman engine.
set -eu

profile_usage() {
  cat <<'EOF'
Manage this installed Shimmy profile's Podman engine and strict registry
redirect preparation.

Usage:
  shimmy profile --help
  shimmy profile status [--format human|manifest]
  shimmy profile activate [--restart] [--stop-running] [--dry-run]
  shimmy profile redirect --help

Commands:
  status    Inspect profile-bound engine and connection state without mutation.
  activate  Select and validate this profile's deterministic engine.
  redirect  Prepare strict registry prefix replacement for this profile.

PATH selection is separate: source the profile's shell-init.sh after activation.

Examples:
  shimmy profile status --format manifest
  shimmy profile activate --dry-run
  shimmy profile redirect list
EOF
}

profile_redirect_list_usage() {
  cat <<'EOF'
List this profile's prepared strict registry redirects.

Usage:
  shimmy profile redirect list [--format human|manifest]

Options:
  --format human|manifest  Select human-readable or stable key/value output.

Prepared redirects are not active engine policy until profile projection is
implemented and explicitly activated.

Examples:
  shimmy profile redirect list
  shimmy profile redirect list --format manifest
EOF
}

profile_redirect_remove_usage() {
  cat <<'EOF'
Remove strict registry redirects from this profile.

Usage:
  shimmy profile redirect remove (--prefix <logical-prefix> | --all)
                                 [--detach] [--dry-run]

Options:
  --prefix <logical-prefix>  Remove one exact logical prefix.
  --all                      Leave the required managed file empty.
  --detach                   Also detach owned projection state when supported.
  --dry-run                  Render the full candidate without filesystem changes.

Chunk 3 creates no platform projection, so --detach has no external state to
remove. It is valid only with --all.

Examples:
  shimmy profile redirect remove --prefix docker.io
  shimmy profile redirect remove --all --dry-run
EOF
}

profile_redirect_usage() {
  cat <<'EOF'
Prepare strict registry prefix replacement for this profile.

Usage:
  shimmy profile redirect --prefix <logical-prefix> --location <physical-location>
                          [--dry-run]
  shimmy profile redirect list [--format human|manifest]
  shimmy profile redirect remove (--prefix <logical-prefix> | --all)
                                 [--detach] [--dry-run]

Commands:
  list    List deterministic redirects and their prepared/inactive state.
  remove  Remove one exact prefix or all redirects.

The direct option form atomically upserts one [[registry]] prefix/location
replacement. It does not create a mirror or fallback. Prepared redirects are
not active engine policy until a later platform-projection implementation is
accepted and explicitly activated.

Examples:
  shimmy profile redirect --prefix docker.io --location registry.corp.example/docker
  shimmy profile redirect list --format manifest
  shimmy profile redirect remove --all --dry-run
EOF
}

profile_status_usage() {
  cat <<'EOF'
Inspect this profile's engine and prepared registry state without mutation.

Usage:
  shimmy profile status [--format human|manifest]

Options:
  --format human|manifest  Select human-readable or stable key/value output.

Examples:
  shimmy profile status
  shimmy profile status --format manifest
EOF
}

profile_activate_usage() {
  cat <<'EOF'
Activate this profile's deterministic Podman engine.

Usage:
  shimmy profile activate [--restart] [--stop-running] [--dry-run]

Options:
  --restart       Restart an already running expected macOS machine.
  --stop-running  Acknowledge interruption of listed running containers.
  --dry-run       Inspect and print the transition without changing state.

Shimmy never creates, adopts, renames, or removes Podman machines.

Examples:
  shimmy profile activate --dry-run
  shimmy profile activate
  shimmy profile activate --restart --stop-running
EOF
}

operation=${1:-}
case "$operation" in
  -h|--help) profile_usage; exit 0 ;;
  status)
    case "${2:-}" in -h|--help) profile_status_usage; exit 0 ;; esac
    ;;
  activate)
    case "${2:-}" in -h|--help) profile_activate_usage; exit 0 ;; esac
    ;;
  redirect)
    case "${2:-}" in
      -h|--help) profile_redirect_usage; exit 0 ;;
      list) case "${3:-}" in -h|--help) profile_redirect_list_usage; exit 0 ;; esac ;;
      remove) case "${3:-}" in -h|--help) profile_redirect_remove_usage; exit 0 ;; esac ;;
      mirror|set|registries) printf 'ERROR: unsupported profile redirect alias: %s\n' "$2" >&2; exit 1 ;;
    esac
    ;;
  --profile|--machine) printf 'ERROR: unknown argument: %s\n' "$operation" >&2; exit 1 ;;
  '') profile_usage >&2; printf '%s\n' 'ERROR: missing profile operation' >&2; exit 1 ;;
  *) profile_usage >&2; printf 'ERROR: unknown profile operation: %s\n' "$operation" >&2; exit 1 ;;
esac

for selector_name in SHIMMY_PROFILE SHIMMY_PROFILE_NAME SHIMMY_MACHINE SHIMMY_PODMAN_MACHINE; do
  eval "selector_value=\${$selector_name:-}"
  [ -z "$selector_value" ] || {
    printf 'ERROR: profile and machine environment selectors are unsupported: %s\n' "$selector_name" >&2
    exit 1
  }
done

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
for helper_file in "$ROOT_DIR/lib/common/common.sh" "$ROOT_DIR/lib/profile/profile.sh" "$ROOT_DIR/lib/profile/activation.sh" "$ROOT_DIR/lib/registries/registries.sh"; do
  [ -f "$helper_file" ] || { printf 'ERROR: missing Shimmy profile helper: %s\n' "$helper_file" >&2; exit 1; }
done
. "$ROOT_DIR/lib/common/common.sh"
. "$ROOT_DIR/lib/profile/profile.sh"
. "$ROOT_DIR/lib/profile/activation.sh"
. "$ROOT_DIR/lib/registries/registries.sh"

shimmy_profile_context_resolve "$ROOT_DIR" || {
  printf '%s\n' 'ERROR: profile operations require an installed canonical default or upstream profile launcher' >&2
  exit 1
}
shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME" || {
  printf 'ERROR: incomplete or damaged Shimmy profile at %s\n' "$SHIMMY_PROFILE_ROOT" >&2
  exit 1
}

SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=0
SHIMMY_REGISTRIES_LOCK_HELD=0
trap 'shimmy_registries_lock_release; shimmy_profile_activation_lock_release' EXIT
trap 'shimmy_registries_lock_release; shimmy_profile_activation_lock_release; exit 1' HUP INT TERM

case "$operation" in
  status)
    output_format=human
    shift
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --format)
          [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: missing value for --format' >&2; exit 1; }
          output_format=$2
          shift 2
          ;;
        *) printf 'ERROR: unknown profile status option: %s\n' "$1" >&2; exit 1 ;;
      esac
    done
    case "$output_format" in human|manifest) ;; *) printf 'ERROR: unsupported profile status format: %s\n' "$output_format" >&2; exit 1 ;; esac
    registry_policy=$(shimmy_registries_policy_state_read) || {
      printf 'ERROR: invalid managed registry redirect configuration: %s\n' "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
      exit 1
    }
    shimmy_profile_status_print "$output_format"
    case "$output_format" in
      manifest)
        printf '%s\n' 'registry_config=valid'
        printf 'registry_policy=%s\n' "$registry_policy"
        ;;
      human)
        printf '%s\n' 'Registry configuration: valid'
        printf 'Registry policy: %s (not active engine policy)\n' "$registry_policy"
        ;;
    esac
    ;;
  activate)
    restart_requested=0
    stop_running_requested=0
    dry_run_requested=0
    shift
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --restart) [ "$restart_requested" -eq 0 ] || { printf '%s\n' 'ERROR: duplicate option: --restart' >&2; exit 1; }; restart_requested=1 ;;
        --stop-running) [ "$stop_running_requested" -eq 0 ] || { printf '%s\n' 'ERROR: duplicate option: --stop-running' >&2; exit 1; }; stop_running_requested=1 ;;
        --dry-run) [ "$dry_run_requested" -eq 0 ] || { printf '%s\n' 'ERROR: duplicate option: --dry-run' >&2; exit 1; }; dry_run_requested=1 ;;
        *) printf 'ERROR: unknown profile activate option: %s\n' "$1" >&2; exit 1 ;;
      esac
      shift
    done
    shimmy_profile_activate "$restart_requested" "$stop_running_requested" "$dry_run_requested"
    ;;
  redirect)
    shift
    redirect_action=${1:-upsert}
    case "$redirect_action" in
      list)
        shift
        output_format=human
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --format)
              [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: missing value for --format' >&2; exit 1; }
              output_format=$2
              shift 2
              ;;
            *) printf 'ERROR: unknown profile redirect list option: %s\n' "$1" >&2; exit 1 ;;
          esac
        done
        case "$output_format" in human|manifest) ;; *) printf 'ERROR: unsupported profile redirect list format: %s\n' "$output_format" >&2; exit 1 ;; esac
        registry_entries=$(shimmy_registries_config_entries_read "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_PROFILE_NAME") || {
          printf 'ERROR: invalid managed registry redirect configuration: %s\n' "$SHIMMY_PROFILE_REGISTRIES_PATH" >&2
          exit 1
        }
        registry_policy=$(shimmy_registries_policy_state_read)
        case "$output_format" in
          manifest)
            printf 'profile=%s\nregistry_policy=%s\n' "$SHIMMY_PROFILE_NAME" "$registry_policy"
            while IFS= read -r registry_entry; do [ -z "$registry_entry" ] || printf 'redirect=%s\n' "$registry_entry"; done <<EOF
$registry_entries
EOF
            ;;
          human)
            printf 'Profile: %s\nPolicy: %s (not active engine policy)\n' "$SHIMMY_PROFILE_NAME" "$registry_policy"
            if [ -z "$registry_entries" ]; then
              printf '%s\n' 'Redirects: none'
            else
              printf '%s\n' 'Redirects:'
              while IFS='|' read -r logical_prefix physical_location; do
                [ -z "$logical_prefix" ] || printf '  %s -> %s\n' "$logical_prefix" "$physical_location"
              done <<EOF
$registry_entries
EOF
            fi
            ;;
        esac
        ;;
      remove)
        shift
        remove_prefix=
        remove_all=0
        detach_requested=0
        dry_run_requested=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --prefix)
              [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: missing value for --prefix' >&2; exit 1; }
              [ -z "$remove_prefix" ] || { printf '%s\n' 'ERROR: duplicate option: --prefix' >&2; exit 1; }
              remove_prefix=$2
              shift 2
              ;;
            --all) [ "$remove_all" -eq 0 ] || { printf '%s\n' 'ERROR: duplicate option: --all' >&2; exit 1; }; remove_all=1; shift ;;
            --detach) [ "$detach_requested" -eq 0 ] || { printf '%s\n' 'ERROR: duplicate option: --detach' >&2; exit 1; }; detach_requested=1; shift ;;
            --dry-run) [ "$dry_run_requested" -eq 0 ] || { printf '%s\n' 'ERROR: duplicate option: --dry-run' >&2; exit 1; }; dry_run_requested=1; shift ;;
            *) printf 'ERROR: unknown profile redirect remove option: %s\n' "$1" >&2; exit 1 ;;
          esac
        done
        [ -z "$remove_prefix" ] || shimmy_registries_endpoint_validate "$remove_prefix" || { printf 'ERROR: invalid logical registry prefix: %s\n' "$remove_prefix" >&2; exit 1; }
        if [ "$remove_all" -eq 1 ] && [ -n "$remove_prefix" ]; then printf '%s\n' 'ERROR: --all cannot be combined with --prefix' >&2; exit 1; fi
        if [ "$remove_all" -eq 0 ] && [ -z "$remove_prefix" ]; then printf '%s\n' 'ERROR: redirect remove requires --prefix or --all' >&2; exit 1; fi
        [ "$detach_requested" -eq 0 ] || [ "$remove_all" -eq 1 ] || { printf '%s\n' 'ERROR: --detach requires --all' >&2; exit 1; }
        if [ "$remove_all" -eq 1 ]; then
          shimmy_registries_mutate remove_all '' '' "$dry_run_requested"
        else
          shimmy_registries_mutate remove "$remove_prefix" '' "$dry_run_requested"
        fi
        ;;
      --*)
        logical_prefix=
        physical_location=
        dry_run_requested=0
        while [ "$#" -gt 0 ]; do
          case "$1" in
            --prefix)
              [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: missing value for --prefix' >&2; exit 1; }
              [ -z "$logical_prefix" ] || { printf '%s\n' 'ERROR: duplicate option: --prefix' >&2; exit 1; }
              logical_prefix=$2
              shift 2
              ;;
            --location)
              [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: missing value for --location' >&2; exit 1; }
              [ -z "$physical_location" ] || { printf '%s\n' 'ERROR: duplicate option: --location' >&2; exit 1; }
              physical_location=$2
              shift 2
              ;;
            --dry-run) [ "$dry_run_requested" -eq 0 ] || { printf '%s\n' 'ERROR: duplicate option: --dry-run' >&2; exit 1; }; dry_run_requested=1; shift ;;
            *) printf 'ERROR: unknown profile redirect option: %s\n' "$1" >&2; exit 1 ;;
          esac
        done
        [ -n "$logical_prefix" ] || { printf '%s\n' 'ERROR: redirect upsert requires --prefix' >&2; exit 1; }
        [ -n "$physical_location" ] || { printf '%s\n' 'ERROR: redirect upsert requires --location' >&2; exit 1; }
        shimmy_registries_endpoint_validate "$logical_prefix" || { printf 'ERROR: invalid logical registry prefix: %s\n' "$logical_prefix" >&2; exit 1; }
        shimmy_registries_endpoint_validate "$physical_location" || { printf 'ERROR: invalid physical registry location: %s\n' "$physical_location" >&2; exit 1; }
        shimmy_registries_mutate upsert "$logical_prefix" "$physical_location" "$dry_run_requested"
        ;;
      '') profile_redirect_usage >&2; printf '%s\n' 'ERROR: missing profile redirect request' >&2; exit 1 ;;
      *) printf 'ERROR: unknown profile redirect operation: %s\n' "$redirect_action" >&2; exit 1 ;;
    esac
    ;;
esac
