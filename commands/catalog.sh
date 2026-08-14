#!/bin/sh
# List shared catalogs, publish or roll back default, or rebind live upstream.
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

shimmy__catalog_list_usage_print() {
  cat <<'EOF'
List every tool in a resolved named catalog.

Usage:
  shimmy catalog list [--name <catalog>] [--format human|manifest]

Options:
  --name <catalog>         Select a named catalog. By default, use the invoking
                           profile's recorded catalog binding.
  --format human|manifest  Select output format. Default: human.
  -h, --help               Show this help.

Output:
  Human output identifies the catalog and prints one bullet per catalog tool.
  Manifest output emits shimmy_catalog_name followed by one
  shimmy_catalog_tool record per catalog tool.

Examples:
  shimmy catalog list
  shimmy catalog list --name upstream
  shimmy catalog list --format manifest --name default
EOF
}

shimmy__catalog_publish_usage_print() {
  cat <<'EOF'
Publish the live upstream catalog as a new immutable default generation.

Usage:
  shimmy catalog publish

Options:
  -h, --help  Show this help.

Requirements:
  Run this command from the upstream profile. The bound checkout must have a
  clean worktree and index, and HEAD must contain all content to publish.

Examples:
  . "${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh"
  shimmy catalog publish
EOF
}

shimmy__catalog_rebind_usage_print() {
  cat <<'EOF'
Replace the live upstream catalog binding with another checkout.

Usage:
  shimmy catalog rebind --checkout <absolute-path>

Options:
  --checkout <path>  Bind the upstream catalog to this validated absolute path.
  -h, --help         Show this help.

Requirements:
  Run this command from the upstream profile. Rebinding changes only the live
  upstream registry path; it does not modify either checkout.

Examples:
  shimmy catalog rebind --checkout /absolute/path/to/shimmy
EOF
}

shimmy__catalog_rollback_usage_print() {
  cat <<'EOF'
Restore the retained prior immutable default catalog generation.

Usage:
  shimmy catalog rollback

Options:
  -h, --help  Show this help.

Requirements:
  Run this command from the upstream profile. A valid retained prior default
  generation must exist.

Examples:
  shimmy catalog rollback
EOF
}

shimmy__catalog_usage_print() {
  cat <<'EOF'
List or manage the fixed shared Shimmy catalogs.

Usage:
  shimmy catalog <command>
  shimmy catalog <command> --help

Commands:
  list      List every tool in a resolved named catalog.
  publish   Publish clean committed upstream content as a new default generation.
  rollback  Restore the retained prior default generation.
  rebind    Replace the live upstream registry path with a validated checkout.

Examples:
  shimmy catalog list
  shimmy catalog list --name upstream --format manifest
  shimmy catalog publish
  shimmy catalog rebind --checkout /absolute/path/to/shimmy

Run 'shimmy catalog <command> --help' for command-specific options and
requirements.
EOF
}

shimmy__catalog_action_usage_print() {
  case "$1" in
    list) shimmy__catalog_list_usage_print ;;
    publish) shimmy__catalog_publish_usage_print ;;
    rebind) shimmy__catalog_rebind_usage_print ;;
    rollback) shimmy__catalog_rollback_usage_print ;;
  esac
}

shimmy__catalog_list() {
  catalog_list_format=human
  catalog_list_format_seen=0
  catalog_list_name=
  catalog_list_name_seen=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --format)
        [ "$#" -ge 2 ] || fail 'missing value for --format'
        [ "$catalog_list_format_seen" -eq 0 ] || fail '--format may be specified only once'
        catalog_list_format=$2
        catalog_list_format_seen=1
        shift 2
        ;;
      --name)
        [ "$#" -ge 2 ] || fail 'missing value for --name'
        [ "$catalog_list_name_seen" -eq 0 ] || fail '--name may be specified only once'
        catalog_list_name=$2
        catalog_list_name_seen=1
        shift 2
        ;;
      -h|--help)
        shimmy__catalog_list_usage_print
        return 0
        ;;
      *) fail "unknown argument: $1" ;;
    esac
  done

  case "$catalog_list_format" in
    human|manifest) ;;
    *) fail "unsupported catalog list format: $catalog_list_format" ;;
  esac
  if [ "$catalog_list_name_seen" -eq 1 ]; then
    shimmy_catalog_name_validate "$catalog_list_name" || fail "unsafe catalog name: $catalog_list_name"
  fi

  shimmy_profile_context_resolve "$ROOT_DIR" || fail 'catalog list must run from a canonical installed profile'
  shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_PROFILE_NAME" || exit 1
  if [ "$catalog_list_name_seen" -eq 1 ]; then
    shimmy_catalog_registry_resolve "$SHIMMY_CONFIG_ROOT" "$catalog_list_name" || fail "$SHIMMY_CATALOG_ERROR"
  else
    shimmy_catalog_profile_resolve "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_CONFIG_ROOT" || fail "$SHIMMY_CATALOG_ERROR"
  fi

  if [ "$catalog_list_format" = manifest ]; then
    printf 'shimmy_catalog_name=%s\n' "$SHIMMY_CATALOG_NAME"
    for catalog_tool_name in $(shimmy_tool_list); do
      printf 'shimmy_catalog_tool=%s\n' "$catalog_tool_name"
    done
  else
    printf 'Shimmy Catalog\n'
    printf 'catalog: %s\n' "$SHIMMY_CATALOG_NAME"
    for catalog_tool_name in $(shimmy_tool_list); do
      printf -- '- %s\n' "$catalog_tool_name"
    done
  fi
}

main() {
  catalog_action=${1:-help}
  case "$catalog_action" in
    help|-h|--help) shimmy__catalog_usage_print; return 0 ;;
    list|publish|rebind|rollback) shift ;;
    *) fail "unknown catalog command: $catalog_action. Run 'shimmy catalog --help' for available commands" ;;
  esac

  case "${1:-}" in
    help|-h|--help)
      [ "$#" -eq 1 ] || fail "unknown argument after ${1}: $2"
      shimmy__catalog_action_usage_print "$catalog_action"
      return 0
      ;;
  esac

  if [ "$catalog_action" = list ]; then
    shimmy__catalog_list "$@"
    return 0
  fi

  shimmy_profile_context_resolve "$ROOT_DIR" || fail 'catalog management must run from a canonical installed profile'
  shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_PROFILE_NAME" || exit 1
  profile_catalog_name=$(shimmy_read_manifest_value "$SHIMMY_PROFILE_MANIFEST_PATH" catalog || true)
  [ "$SHIMMY_PROFILE_NAME" = upstream ] && [ "$profile_catalog_name" = upstream ] ||
    fail "catalog $catalog_action requires the upstream profile bound to the upstream catalog." \
      "Run 'shimmy catalog $catalog_action --help' for requirements"
  trap cleanup EXIT HUP INT TERM

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
          -h|--help) shimmy__catalog_rebind_usage_print; return 0 ;;
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

main "$@"
