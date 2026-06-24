#!/bin/sh
# Update request parsing and usage rendering.

shimmy_update_request_parse() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
        shift 2
        ;;
      --profile)
        [ "$#" -ge 2 ] || fail "missing value for --profile"
        SHIMMY_PROFILE_REQUESTED=$2
        SHIMMY_PROFILE_ACTIVATED=1
        shift 2
        ;;
      --shim)
        [ "$#" -ge 2 ] || fail "missing value for --shim"
        shimmy_update_requested_shim_append "$2"
        shift 2
        ;;
      --all)
        UPDATE_ALL=1
        shift
        ;;
      --pull)
        PULL_IMAGES=1
        shift
        ;;
      --build)
        BUILD_IMAGES=1
        shift
        ;;
      --repair-startup)
        REPAIR_STARTUP=1
        shift
        ;;
      --shell)
        [ "$#" -ge 2 ] || fail "missing value for --shell"
        REQUESTED_SHELL=$2
        shift 2
        ;;
      --startup-file)
        [ "$#" -ge 2 ] || fail "missing value for --startup-file"
        REQUESTED_STARTUP_FILES=$(shimmy_append_line_list "$REQUESTED_STARTUP_FILES" "$2")
        shift 2
        ;;
      -h|--help)
        shimmy_update_usage_print
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done
}

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
  REQUESTED_INSTALL_DIR=
  REQUESTED_SHELL=
  REQUESTED_SHIMS=
  REQUESTED_STARTUP_FILES=
  SHIMMY_PROFILE_ACTIVATED=0
  SHIMMY_PROFILE_REQUESTED=
  UPDATE_ALL=0
}

shimmy_update_usage_print() {
  cat <<'EOF'
Refresh an existing shimmy installation.

Usage:
  commands/update.sh [--install-dir <dir>] [--profile default|upstream] [--shim <name>] [--all] [--pull] [--build] [--repair-startup]

When run from a source checkout, update refreshes the install from that checkout.
When run through an installed shimmy command, update fetches the recorded
shimmy_source_url and refreshes the management plane from that source.

Options:
  --install-dir <dir>   Base install directory. Default: ~/.config/shimmy
  --profile <name>         Update profile: default or upstream
  --shim <name>         Refresh one installed shim in the selected profile. Repeatable.
  --all                 Refresh root assets and every installed profile shim.
  --pull                Pull newer remote images for installed remote-image shims.
  --build               Rebuild local images for installed local-build shims.
  --repair-startup      Rewrite the managed Shimmy startup block after reinstalling
  --shell <name>        Override shell detection for startup-file repair
  --startup-file <path> Override startup files used during repair. Repeatable.
  -h, --help
EOF
}
