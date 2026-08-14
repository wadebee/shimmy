#!/bin/sh
# Publish the immutable default catalog or explicitly rebind live upstream.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_CONTROL_ROOT=$ROOT_DIR

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

for helper_file in \
  "$ROOT_DIR/lib/common/common.sh" \
  "$ROOT_DIR/lib/catalog/catalog.sh" \
  "$ROOT_DIR/lib/profile/profile.sh" \
  "$ROOT_DIR/lib/install/catalog-lifecycle.sh"
do
  [ -f "$helper_file" ] || fail "missing catalog helper: $helper_file"
done

# shellcheck source=lib/common/common.sh
. "$ROOT_DIR/lib/common/common.sh"
# shellcheck source=lib/catalog/catalog.sh
. "$ROOT_DIR/lib/catalog/catalog.sh"
# shellcheck source=lib/profile/profile.sh
. "$ROOT_DIR/lib/profile/profile.sh"
# shellcheck source=lib/install/catalog-lifecycle.sh
. "$ROOT_DIR/lib/install/catalog-lifecycle.sh"

cleanup() {
  shimmy_catalog_lifecycle_cleanup
  shimmy_catalog_lock_release
}

usage() {
  cat <<'EOF'
Manage the fixed shared Shimmy catalogs.

Usage:
  shimmy catalog publish
  shimmy catalog rollback
  shimmy catalog rebind --checkout <absolute-path>

publish validates and publishes clean committed upstream content as a new
immutable default generation. rollback atomically restores the retained prior
default generation. rebind explicitly replaces only the live upstream registry
path after validating the replacement checkout.
EOF
}

main() {
  catalog_action=${1:-help}
  case "$catalog_action" in
    help|-h|--help) usage; return 0 ;;
    publish|rebind|rollback) shift ;;
    *) fail "unknown catalog command: $catalog_action" ;;
  esac

  shimmy_profile_context_resolve "$ROOT_DIR" || fail 'catalog management must run from a canonical installed profile'
  shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_PROFILE_NAME" || exit 1
  profile_catalog_name=$(shimmy_read_manifest_value "$SHIMMY_PROFILE_MANIFEST_PATH" catalog || true)
  [ "$SHIMMY_PROFILE_NAME" = upstream ] && [ "$profile_catalog_name" = upstream ] || fail 'catalog publish, rollback, and rebind require the upstream profile bound to the upstream catalog'

  case "$catalog_action" in
    publish)
      [ "$#" -eq 0 ] || fail "unknown argument: $1"
      shimmy_catalog_default_publish "$SHIMMY_CONFIG_ROOT" || fail "$SHIMMY_CATALOG_ERROR"
      printf 'Published default catalog generation: %s\n' "$SHIMMY_CATALOG_GENERATION"
      printf 'source_commit=%s\n' "$SHIMMY_CATALOG_SOURCE_COMMIT"
      printf 'content_fingerprint=%s\n' "$SHIMMY_CATALOG_CONTENT_FINGERPRINT"
      ;;
    rollback)
      [ "$#" -eq 0 ] || fail "unknown argument: $1"
      shimmy_catalog_default_rollback "$SHIMMY_CONFIG_ROOT" || fail "$SHIMMY_CATALOG_ERROR"
      printf 'Rolled back default catalog generation: %s\n' "$SHIMMY_CATALOG_GENERATION"
      printf 'source_commit=%s\n' "$SHIMMY_CATALOG_SOURCE_COMMIT"
      printf 'content_fingerprint=%s\n' "$SHIMMY_CATALOG_CONTENT_FINGERPRINT"
      ;;
    rebind)
      catalog_checkout=
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --checkout)
            [ "$#" -ge 2 ] || fail 'missing value for --checkout'
            [ -z "$catalog_checkout" ] || fail '--checkout may be specified only once'
            catalog_checkout=$2
            shift 2
            ;;
          -h|--help) usage; return 0 ;;
          *) fail "unknown argument: $1" ;;
        esac
      done
      [ -n "$catalog_checkout" ] || fail 'rebind requires --checkout <absolute-path>'
      case "$catalog_checkout" in /*) ;; *) fail 'rebind checkout must be an absolute path' ;; esac
      shimmy_catalog_upstream_rebind "$SHIMMY_CONFIG_ROOT" "$catalog_checkout" || fail "$SHIMMY_CATALOG_ERROR"
      printf 'Rebound upstream catalog.\n'
      printf 'prior_source_path=%s\n' "$SHIMMY_CATALOG_REBIND_PRIOR"
      printf 'new_source_path=%s\n' "$SHIMMY_CATALOG_REBIND_NEW"
      ;;
  esac
}

trap cleanup EXIT HUP INT TERM
main "$@"
