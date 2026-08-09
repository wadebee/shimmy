#!/bin/sh
# Bootstrap one canonical Shimmy profile from this source checkout.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
profile_name=default

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Bootstrap a canonical Shimmy profile from this source checkout.

Usage:
  ./install.sh [--profile default|upstream] [install options]

Profile selection is bootstrap-only. Installed launchers manage only their
enclosing profile.
EOF
}

case "${1:-}" in
  --profile)
    [ "$#" -ge 2 ] || fail "missing value for --profile"
    profile_name=$2
    shift 2
    ;;
esac

case "$profile_name" in
  default|upstream) ;;
  *) fail "unsupported Shimmy profile: $profile_name" ;;
esac

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

for required_path in commands lib tools lib/install/launcher-template.sh; do
  [ -e "$SCRIPT_DIR/$required_path" ] || fail "invalid Shimmy source checkout: missing $required_path"
done
[ -x "$SCRIPT_DIR/commands/install.sh" ] || fail "invalid Shimmy source checkout: commands/install.sh is not executable"

SHIMMY_BOOTSTRAP_PROFILE=$profile_name
export SHIMMY_BOOTSTRAP_PROFILE
exec "$SCRIPT_DIR/commands/install.sh" "$@"
