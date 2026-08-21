#!/bin/sh
# Uninstalled checkout bootstrap.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
SHIMMY_CONTROL_ROOT=$ROOT_DIR

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for shimmy_target_helper in \
  lib/common/common.sh lib/common/lock.sh lib/catalog/catalog.sh \
  lib/catalog/state.sh lib/catalog/authority.sh lib/shim/state.sh \
  lib/ai-skill/bundle.sh lib/profile/state.sh lib/install/manifest.sh \
  lib/install/transaction.sh lib/install/catalog.sh \
  lib/profile/transaction.sh lib/ai-skill/link.sh lib/shim/shim.sh \
  lib/ai-skill/ai-skill.sh lib/install/profile.sh \
  lib/profile/profile.sh lib/profile/activation.sh \
  lib/registries/registries.sh lib/profile/management.sh \
  lib/startup/startup.sh lib/install/lifecycle.sh
do
  [ -f "$ROOT_DIR/$shimmy_target_helper" ] && [ ! -L "$ROOT_DIR/$shimmy_target_helper" ] ||
    fail "missing bootstrap helper: $shimmy_target_helper"
  . "$ROOT_DIR/$shimmy_target_helper"
done

usage() {
  cat <<'EOF'
Bootstrap the default Shimmy profile.

Usage:
  ./bootstrap.sh [--shell <name>] [--no-startup]

Creates and activates the default profile with jq, rg, and Skopeo from a clean,
committed local main checkout. Use an absolute XDG_CONFIG_HOME for isolation.
EOF
}

shimmy_target_bootstrap_shell=
shimmy_target_bootstrap_startup=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --shell)
      [ "$#" -ge 2 ] || fail 'missing value for --shell'
      [ -z "$shimmy_target_bootstrap_shell" ] || fail 'duplicate option: --shell'
      shimmy_target_bootstrap_shell=$2
      shift 2
      ;;
    --no-startup)
      [ "$shimmy_target_bootstrap_startup" -eq 1 ] || fail 'duplicate option: --no-startup'
      shimmy_target_bootstrap_startup=0
      shift
      ;;
    *) fail "unknown bootstrap argument: $1" ;;
  esac
done

shimmy_target_bootstrap_home=${HOME:-}
shimmy_path_absolute_normalized_validate "$shimmy_target_bootstrap_home" || fail 'bootstrap requires a normalized absolute HOME'
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  shimmy_target_bootstrap_config=$XDG_CONFIG_HOME/shimmy
else
  shimmy_target_bootstrap_config=$shimmy_target_bootstrap_home/.config/shimmy
fi
shimmy_path_absolute_normalized_validate "$shimmy_target_bootstrap_config" || fail 'invalid bootstrap configuration root'

trap shimmy_target_profile_bootstrap_cleanup EXIT
trap 'shimmy_target_profile_bootstrap_cleanup; trap - HUP; exit 129' HUP
trap 'shimmy_target_profile_bootstrap_cleanup; trap - INT; exit 130' INT
trap 'shimmy_target_profile_bootstrap_cleanup; trap - TERM; exit 143' TERM

shimmy_target_profile_bootstrap_run "$ROOT_DIR" "$shimmy_target_bootstrap_config" \
  "$shimmy_target_bootstrap_shell" "$shimmy_target_bootstrap_startup" ||
  fail "${SHIMMY_TARGET_PROFILE_LIFECYCLE_ERROR:-bootstrap failed}"
