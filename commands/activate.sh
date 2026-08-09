#!/bin/sh
# Print activation code for the enclosing installed profile.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Print shell code that prepends this profile's bin directory to PATH.

Usage:
  shimmy activate
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[ -f "$ROOT_DIR/lib/common/common.sh" ] || fail "missing common helper"
[ -f "$ROOT_DIR/lib/profile/profile.sh" ] || fail "missing profile helper"
# shellcheck source=lib/common/common.sh
. "$ROOT_DIR/lib/common/common.sh"
# shellcheck source=lib/profile/profile.sh
. "$ROOT_DIR/lib/profile/profile.sh"

shimmy_profile_context_resolve "$ROOT_DIR" || fail "installed launcher is outside a canonical profile root"
shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME" || fail "incomplete or damaged Shimmy profile at $SHIMMY_PROFILE_ROOT"
cat "$SHIMMY_PROFILE_ROOT/activate.sh"
