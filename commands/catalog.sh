#!/bin/sh
# Installed default-catalog command.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_CONTROL_ROOT=$ROOT_DIR

. "$ROOT_DIR/lib/common/common.sh"
. "$ROOT_DIR/lib/common/lock.sh"
. "$ROOT_DIR/lib/catalog/catalog.sh"
. "$ROOT_DIR/lib/catalog/state.sh"
. "$ROOT_DIR/lib/catalog/authority.sh"
. "$ROOT_DIR/lib/shim/state.sh"
. "$ROOT_DIR/lib/profile/state.sh"
. "$ROOT_DIR/lib/images/images.sh"
. "$ROOT_DIR/lib/images/catalog.sh"
. "$ROOT_DIR/lib/install/transaction.sh"
. "$ROOT_DIR/lib/install/catalog.sh"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  shimmy_images_cache_cleanup 2>/dev/null || true
  shimmy_filesystem_transaction_cleanup 2>/dev/null || true
  shimmy_catalog_lifecycle_cleanup 2>/dev/null || true
  shimmy_locks_release_all 2>/dev/null || true
}
trap cleanup 0 HUP INT TERM

usage() {
  cat <<'EOF'
Manage the immutable default catalog.

Usage:
  shimmy catalog status [--format human|manifest]
  shimmy catalog tools [--generation <sha256-generation>] [--format human|manifest]
  shimmy catalog verify [--tool <tool[@version]> ...] [--public-only]
                           [--require-current-upstream] [--format human|manifest]
  shimmy catalog publish
  shimmy catalog rollback

Publish runs only from a clean attached local main repository root.
EOF
}

config_root=${SHIMMY_CONFIG_ROOT:-}
[ -n "$config_root" ] || fail 'catalog commands must run through an installed profile launcher'

action=${1:-help}
case "$action" in
  help|-h|--help) usage; exit 0 ;;
  status|tools|verify|publish|rollback) shift ;;
  *) fail "unknown catalog command: $action" ;;
esac

case "$action" in
  status)
    output_format=human
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; output_format=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown argument: $1" ;;
      esac
    done
    shimmy_catalog_status_render "$config_root" "$output_format" || fail "$SHIMMY_CATALOG_AUTHORITY_ERROR"
    ;;
  tools)
    output_format=human
    generation=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; output_format=$2; shift 2 ;;
        --generation) [ "$#" -ge 2 ] || fail 'missing value for --generation'; generation=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown argument: $1" ;;
      esac
    done
    shimmy_catalog_tools_render "$config_root" "$generation" "$output_format" || fail "$SHIMMY_CATALOG_AUTHORITY_ERROR"
    ;;
  verify)
    output_format=human
    public_only=0
    require_current_upstream=0
    requested_tools=
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --tool)
          [ "$#" -ge 2 ] || fail 'missing value for --tool'
          requested_tools=$(shimmy_append_line_list "$requested_tools" "$2")
          shift 2
          ;;
        --public-only) public_only=1; shift ;;
        --require-current-upstream) require_current_upstream=1; shift ;;
        --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; output_format=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "unknown argument: $1" ;;
      esac
    done
    case "$output_format" in human|manifest) ;; *) fail "unsupported catalog verify format: $output_format" ;; esac
    if ! shimmy_images_verify_run "$config_root" "$requested_tools" \
      "$public_only" "$require_current_upstream" "$output_format"; then
      [ -z "$SHIMMY_IMAGES_ERROR" ] || fail "$SHIMMY_IMAGES_ERROR"
      exit 1
    fi
    ;;
  publish)
    [ "$#" -eq 0 ] || fail "unknown argument: $1"
    checkout_root=$(pwd -P)
    shimmy_catalog_default_publish "$config_root" "$checkout_root" || fail "$SHIMMY_CATALOG_AUTHORITY_ERROR"
    shimmy_catalog_status_render "$config_root" manifest
    ;;
  rollback)
    [ "$#" -eq 0 ] || fail "unknown argument: $1"
    shimmy_catalog_default_rollback "$config_root" || fail "$SHIMMY_CATALOG_AUTHORITY_ERROR"
    shimmy_catalog_status_render "$config_root" manifest
    ;;
esac
