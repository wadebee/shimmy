#!/bin/sh
# Inspect or activate the invoking installed profile's Podman engine.
set -eu

profile_usage() {
  cat <<'EOF'
Inspect or activate this installed Shimmy profile's Podman engine.

Usage:
  shimmy profile --help
  shimmy profile status [--format human|manifest]
  shimmy profile activate [--restart] [--stop-running] [--dry-run]

Commands:
  status    Inspect profile-bound engine and connection state without mutation.
  activate  Select and validate this profile's deterministic engine.

PATH selection is separate: source the profile's shell-init.sh after activation.

Examples:
  shimmy profile status --format manifest
  shimmy profile activate --dry-run
EOF
}

profile_status_usage() {
  cat <<'EOF'
Inspect this profile's engine state without mutation.

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
for helper_file in "$ROOT_DIR/lib/common/common.sh" "$ROOT_DIR/lib/profile/profile.sh" "$ROOT_DIR/lib/profile/activation.sh"; do
  [ -f "$helper_file" ] || { printf 'ERROR: missing Shimmy profile helper: %s\n' "$helper_file" >&2; exit 1; }
done
. "$ROOT_DIR/lib/common/common.sh"
. "$ROOT_DIR/lib/profile/profile.sh"
. "$ROOT_DIR/lib/profile/activation.sh"

shimmy_profile_context_resolve "$ROOT_DIR" || {
  printf '%s\n' 'ERROR: profile operations require an installed canonical default or upstream profile launcher' >&2
  exit 1
}
shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME" || {
  printf 'ERROR: incomplete or damaged Shimmy profile at %s\n' "$SHIMMY_PROFILE_ROOT" >&2
  exit 1
}

SHIMMY_PROFILE_ACTIVATION_LOCK_HELD=0
trap 'shimmy_profile_activation_lock_release' EXIT
trap 'shimmy_profile_activation_lock_release; exit 1' HUP INT TERM

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
    shimmy_profile_status_print "$output_format"
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
esac
