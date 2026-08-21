#!/bin/sh
# Installed active-profile AI-skill lifecycle command.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_CONTROL_ROOT=$ROOT_DIR

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for shimmy_helper in \
  lib/common/common.sh lib/common/lock.sh lib/catalog/catalog.sh \
  lib/catalog/state.sh lib/catalog/authority.sh lib/shim/state.sh \
  lib/ai-skill/bundle.sh lib/profile/state.sh lib/install/manifest.sh \
  lib/profile/transaction.sh lib/ai-skill/link.sh lib/shim/shim.sh \
  lib/ai-skill/ai-skill.sh
do
  . "$ROOT_DIR/$shimmy_helper"
done

usage() {
  cat <<'EOF'
Manage active-profile AI-skill links.

Usage:
  shimmy ai-skill list [--format human|manifest]
  shimmy ai-skill repair

Repair unconditionally overwrites exact bundle-declared user skill names without
backup. It never recursively cleans the recorded user skill root.
EOF
}

cleanup() {
  if [ "${SHIMMY_EXTERNAL_TRANSACTION_ACTIVE:-0}" -eq 1 ]; then
    shimmy_external_transaction_rollback 'AI-skill command interruption' 2>/dev/null || true
  fi
  shimmy_locks_release_all 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

[ "$#" -gt 0 ] || { usage; exit 0; }
case "$1" in -h|--help|help) usage; exit 0 ;; esac
shimmy_action=$1
shift
shimmy_config_root=${SHIMMY_CONFIG_ROOT:-}
[ -n "$shimmy_config_root" ] || fail 'AI-skill commands must run through an installed profile launcher'

case "$shimmy_action" in
  list)
    shimmy_format=human
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; shimmy_format=$2; shift 2 ;;
        *) fail "unknown argument: $1" ;;
      esac
    done
    shimmy_ai_skill_context_resolve "$shimmy_config_root" || fail "$SHIMMY_AI_SKILL_ERROR"
    shimmy_ai_skill_list_render "$shimmy_format" || fail 'unable to inspect AI-skill bundles and links'
    ;;
  repair)
    [ "$#" -eq 0 ] || fail 'AI-skill repair accepts no arguments'
    set +e
    shimmy_ai_skill_repair "$shimmy_config_root"
    shimmy_repair_status=$?
    set -e
    case "$shimmy_repair_status" in
      0) ;;
      2) printf 'WARNING: %s\n' "$SHIMMY_AI_SKILL_ERROR" >&2; exit 2 ;;
      *) fail "${SHIMMY_AI_SKILL_ERROR:-AI-skill repair failed}" ;;
    esac
    ;;
  *) fail "unknown AI-skill action: $shimmy_action" ;;
esac
