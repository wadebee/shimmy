#!/bin/sh
# Uninstalled private target bootstrap candidate.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
SHIMMY_CONTROL_ROOT=$ROOT_DIR

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for shimmy_target_helper in \
  lib/common/common.sh lib/common/lock.sh lib/catalog/catalog.sh \
  lib/catalog/state.sh lib/catalog/target.sh lib/shim/state.sh \
  lib/ai-skill/bundle.sh lib/profile/state.sh lib/install/manifest.sh \
  lib/install/transaction.sh lib/install/catalog-target.sh \
  lib/profile/transaction.sh lib/ai-skill/link.sh lib/shim/target.sh \
  lib/ai-skill/target.sh lib/install/profile-target.sh \
  lib/profile/profile.sh lib/profile/activation.sh \
  lib/registries/registries.sh lib/profile/target.sh \
  lib/startup/startup.sh lib/install/lifecycle-target.sh
do
  [ -f "$ROOT_DIR/$shimmy_target_helper" ] && [ ! -L "$ROOT_DIR/$shimmy_target_helper" ] ||
    fail "missing target bootstrap helper: $shimmy_target_helper"
  . "$ROOT_DIR/$shimmy_target_helper"
done

usage() {
  cat <<'EOF'
Private target pristine bootstrap candidate.

Usage:
  bootstrap-target.sh [--shell <name>] [--no-startup]

Creates an active default profile with jq, rg, and Skopeo. The private
SHIMMY_TARGET_CONFIG_ROOT override may name an absolute disposable root.
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
    *) fail "unknown target bootstrap argument: $1" ;;
  esac
done

shimmy_target_bootstrap_home=${HOME:-}
shimmy_path_absolute_normalized_validate "$shimmy_target_bootstrap_home" || fail 'target bootstrap requires a normalized absolute HOME'
if [ -n "${SHIMMY_TARGET_CONFIG_ROOT:-}" ]; then
  shimmy_target_bootstrap_config=$SHIMMY_TARGET_CONFIG_ROOT
elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
  shimmy_target_bootstrap_config=$XDG_CONFIG_HOME/shimmy
else
  shimmy_target_bootstrap_config=$shimmy_target_bootstrap_home/.config/shimmy
fi
shimmy_path_absolute_normalized_validate "$shimmy_target_bootstrap_config" || fail 'invalid target bootstrap configuration root'

trap shimmy_target_profile_bootstrap_cleanup EXIT
trap 'shimmy_target_profile_bootstrap_cleanup; trap - HUP; exit 129' HUP
trap 'shimmy_target_profile_bootstrap_cleanup; trap - INT; exit 130' INT
trap 'shimmy_target_profile_bootstrap_cleanup; trap - TERM; exit 143' TERM

shimmy_target_profile_bootstrap_run "$ROOT_DIR" "$shimmy_target_bootstrap_config" \
  "$shimmy_target_bootstrap_shell" "$shimmy_target_bootstrap_startup" ||
  fail "${SHIMMY_TARGET_PROFILE_LIFECYCLE_ERROR:-target bootstrap failed}"

