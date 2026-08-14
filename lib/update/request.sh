#!/bin/sh
# Installed-profile update request parsing.

shimmy_update_requested_shim_append() {
  requested_shim=$1
  if [ -n "$REQUESTED_SHIMS" ]; then
    REQUESTED_SHIMS="$REQUESTED_SHIMS $requested_shim"
  else
    REQUESTED_SHIMS=$requested_shim
  fi
}

shimmy_update_request_reset() {
  BUILD_IMAGES=0
  PULL_IMAGES=0
  REPAIR_STARTUP=0
  REQUESTED_SHELL=
  REQUESTED_SHIMS=
  REQUESTED_STARTUP_FILES=
  UPDATE_ALL=0
}

shimmy_update_usage_print() {
  cat <<'EOF'
Refresh the invoking installed Shimmy profile.

Usage:
  shimmy update [--shim <name>] [--all] [--pull] [--build] [--repair-startup]

The launcher manages only its enclosing profile. --all selects all installed
tools in that profile; it does not enumerate sibling profiles. Selected tools
adopt their current catalog defaults before optional image refresh hooks run.
EOF
}

shimmy_update_request_parse() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --shim) [ "$#" -ge 2 ] || fail "missing value for --shim"; shimmy_update_requested_shim_append "$2"; shift 2 ;;
      --all) UPDATE_ALL=1; shift ;;
      --pull) PULL_IMAGES=1; shift ;;
      --build) BUILD_IMAGES=1; shift ;;
      --repair-startup) REPAIR_STARTUP=1; shift ;;
      --shell) [ "$#" -ge 2 ] || fail "missing value for --shell"; REQUESTED_SHELL=$2; shift 2 ;;
      --startup-file) [ "$#" -ge 2 ] || fail "missing value for --startup-file"; REQUESTED_STARTUP_FILES=$(shimmy_append_line_list "$REQUESTED_STARTUP_FILES" "$2"); shift 2 ;;
      -h|--help) shimmy_update_usage_print; exit 0 ;;
      *) fail "unknown argument: $1" ;;
    esac
  done
  [ "$UPDATE_ALL" -eq 0 ] || [ -z "$REQUESTED_SHIMS" ] || fail "--all cannot be combined with --shim"
}
