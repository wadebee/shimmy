#!/bin/sh
# Installed profile-local shim lifecycle command.
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
Manage profile-local shims and concrete versions.

Usage:
  shimmy shim list [--format human|manifest]
  shimmy shim add <tool[@version]>
  shimmy shim remove <tool[@version]>
  shimmy shim set-version <tool@version>
  shimmy shim sync [<tool[@version]> ...]
  shimmy shim test [<tool[@version]> ...]

Unqualified add is interactive and records tracking policy. Explicit versions
are noninteractive and a first explicit version records pinned policy.
EOF
}

shimmy_selector_parse() {
  shimmy_selector=$1
  case "$shimmy_selector" in
    *@*)
      SHIMMY_SELECTOR_TOOL=${shimmy_selector%%@*}
      SHIMMY_SELECTOR_VERSION=${shimmy_selector#*@}
      case "$SHIMMY_SELECTOR_VERSION" in ''|*@*) return 1 ;; esac
      ;;
    *) SHIMMY_SELECTOR_TOOL=$shimmy_selector; SHIMMY_SELECTOR_VERSION= ;;
  esac
  shimmy_name_component_validate "$SHIMMY_SELECTOR_TOOL" || return 1
  [ -z "$SHIMMY_SELECTOR_VERSION" ] || shimmy_version_token_validate "$SHIMMY_SELECTOR_VERSION"
}

shimmy_interactive_version_select() {
  shimmy_interactive_tool=$1
  if [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] && [ -n "${SHIMMY_TEST_INTERACTIVE_SELECTION:-}" ]; then
    shimmy_interactive_selected=$SHIMMY_TEST_INTERACTIVE_SELECTION
  else
    [ -t 0 ] && [ -t 2 ] || fail "unqualified add requires an interactive terminal; use $shimmy_interactive_tool@<version> for automation"
    shimmy_interactive_default=$(shimmy_shim_catalog_default_read "$shimmy_interactive_tool") || fail "unsupported shim tool: $shimmy_interactive_tool"
    shimmy_interactive_versions=$(find "$SHIMMY_SHIM_CATALOG_ROOT/tools/$shimmy_interactive_tool/versions" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')
    printf 'Select %s version [%s] (%s): ' "$shimmy_interactive_tool" "$shimmy_interactive_default" "$shimmy_interactive_versions" >&2
    IFS= read -r shimmy_interactive_selected || return 1
    [ -n "$shimmy_interactive_selected" ] || shimmy_interactive_selected=$shimmy_interactive_default
  fi
  shimmy_shim_catalog_version_validate "$shimmy_interactive_tool" "$shimmy_interactive_selected" || fail "unsupported shim selector: $shimmy_interactive_tool@$shimmy_interactive_selected"
  printf '%s\n' "$shimmy_interactive_selected"
}

shimmy_selected_tools_resolve() {
  shimmy_selected_selectors=
  for shimmy_selected_selector in "$@"; do
    shimmy_selector_parse "$shimmy_selected_selector" || fail "invalid shim selector: $shimmy_selected_selector"
    [ -n "$(shimmy_shim_policy_read "$SHIMMY_SELECTOR_TOOL")" ] || fail "shim is not installed: $SHIMMY_SELECTOR_TOOL"
    if [ -n "$SHIMMY_SELECTOR_VERSION" ]; then
      shimmy_shim_version_role_read "$SHIMMY_SELECTOR_TOOL" "$SHIMMY_SELECTOR_VERSION" >/dev/null 2>&1 || fail "shim version is not installed: $shimmy_selected_selector"
    fi
    if [ -z "$SHIMMY_SELECTOR_VERSION" ]; then
      shimmy_selected_retained=
      while IFS= read -r shimmy_selected_existing; do
        [ -n "$shimmy_selected_existing" ] || continue
        case "$shimmy_selected_existing" in "$SHIMMY_SELECTOR_TOOL"|"$SHIMMY_SELECTOR_TOOL"@*) continue ;; esac
        shimmy_selected_retained=$(shimmy_append_line_list "$shimmy_selected_retained" "$shimmy_selected_existing")
      done <<EOF
$shimmy_selected_selectors
EOF
      shimmy_selected_selectors=$(shimmy_append_line_list "$shimmy_selected_retained" "$SHIMMY_SELECTOR_TOOL")
    elif shimmy_contains_line_list "$shimmy_selected_selectors" "$SHIMMY_SELECTOR_TOOL"; then
      continue
    elif ! shimmy_contains_line_list "$shimmy_selected_selectors" "$shimmy_selected_selector"; then
      shimmy_selected_selectors=$(shimmy_append_line_list "$shimmy_selected_selectors" "$shimmy_selected_selector")
    fi
  done
  shimmy_shim_sorted "$shimmy_selected_selectors"
}

shimmy_smoke_pairs_resolve() {
  shimmy_smoke_pairs=
  if [ "$#" -eq 0 ]; then
    while IFS= read -r shimmy_smoke_record; do
      [ -n "$shimmy_smoke_record" ] || continue
      shimmy_shim_version_record_validate "$shimmy_smoke_record" || return 1
      shimmy_smoke_pairs=$(shimmy_append_line_list "$shimmy_smoke_pairs" "$shimmy_shim_version_tool|$shimmy_shim_version_name")
    done <<EOF
$SHIMMY_SHIM_VERSION_RECORDS
EOF
  else
    for shimmy_smoke_selector in "$@"; do
      shimmy_selector_parse "$shimmy_smoke_selector" || fail "invalid shim selector: $shimmy_smoke_selector"
      if [ -n "$SHIMMY_SELECTOR_VERSION" ]; then
        shimmy_shim_version_role_read "$SHIMMY_SELECTOR_TOOL" "$SHIMMY_SELECTOR_VERSION" >/dev/null 2>&1 || fail "shim version is not installed: $shimmy_smoke_selector"
        shimmy_smoke_version=$SHIMMY_SELECTOR_VERSION
      else
        shimmy_smoke_version=$(shimmy_shim_default_read "$SHIMMY_SELECTOR_TOOL") || fail "shim is not installed: $SHIMMY_SELECTOR_TOOL"
      fi
      shimmy_smoke_pairs=$(shimmy_append_line_list "$shimmy_smoke_pairs" "$SHIMMY_SELECTOR_TOOL|$shimmy_smoke_version")
    done
  fi
  shimmy_shim_sorted "$shimmy_smoke_pairs"
}

cleanup() {
  if [ "${SHIMMY_EXTERNAL_TRANSACTION_ACTIVE:-0}" -eq 1 ]; then
    shimmy_external_transaction_rollback 'shim command interruption' 2>/dev/null || true
  fi
  shimmy_shim_commit_restore 2>/dev/null || true
  shimmy_shim_stage_cleanup 2>/dev/null || true
  shimmy_locks_release_all 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

shimmy_shim_mutation_preflight() {
  [ "$SHIMMY_SHIM_IS_ACTIVE" -eq 1 ] ||
    fail "shim mutation requires the invoking profile to be active; activate it with: shimmy profile activate $SHIMMY_SHIM_PROFILE_NAME"
  shimmy_ai_skill_context_resolve "$shimmy_config_root" || fail "$SHIMMY_AI_SKILL_ERROR"
  [ "$SHIMMY_AI_SKILL_PROFILE_ROOT" = "$SHIMMY_SHIM_PROFILE_ROOT" ] ||
    fail 'active AI-skill authority does not match the invoking shim profile'
  shimmy_ai_skill_reconcile_preflight "$SHIMMY_AI_SKILL_PROFILE_ROOT" \
    "$SHIMMY_CATALOG_REGISTRY_PATH" "$SHIMMY_AI_SKILL_GENERATION_ROOT" ||
    fail "$SHIMMY_AI_SKILL_ERROR"
}

[ "$#" -gt 0 ] || { usage; exit 0; }
case "$1" in -h|--help|help) usage; exit 0 ;; esac
shimmy_action=$1
shift
case "$shimmy_action" in list|add|remove|set-version|sync|test) ;; *) fail "unknown shim action: $shimmy_action" ;; esac
shimmy_config_root=${SHIMMY_CONFIG_ROOT:-}
[ -n "$shimmy_config_root" ] || fail 'shim commands must run through an installed profile launcher'
shimmy_invoking_profile=${SHIMMY_INVOKING_PROFILE:-}
shimmy_name_component_validate "$shimmy_invoking_profile" ||
  fail 'shim commands require a valid invoking profile identity'
shimmy_shim_context_resolve "$shimmy_config_root" "$shimmy_invoking_profile" || fail "$SHIMMY_SHIM_ERROR"
shimmy_shim_materialization_validate "$SHIMMY_SHIM_PROFILE_ROOT" "$SHIMMY_SHIM_CATALOG_ROOT" || fail 'invalid shim materialization'

case "$shimmy_action" in
  list)
    shimmy_format=human
    while [ "$#" -gt 0 ]; do
      case "$1" in --format) [ "$#" -ge 2 ] || fail 'missing value for --format'; shimmy_format=$2; shift 2 ;; *) fail "unknown argument: $1" ;; esac
    done
    shimmy_shim_list_render "$shimmy_format" || fail 'unable to render shims'
    ;;
  add)
    shimmy_shim_mutation_preflight
    [ "$#" -eq 1 ] || fail 'shim add requires exactly one tool[@version] selector'
    shimmy_selector_parse "$1" || fail "invalid shim selector: $1"
    if [ -n "$SHIMMY_SELECTOR_VERSION" ]; then shimmy_add_mode=pinned; shimmy_add_version=$SHIMMY_SELECTOR_VERSION
    else shimmy_add_mode=tracking; shimmy_add_version=$(shimmy_interactive_version_select "$SHIMMY_SELECTOR_TOOL")
    fi
    shimmy_shim_add "$SHIMMY_SELECTOR_TOOL" "$shimmy_add_version" "$shimmy_add_mode" || fail "$SHIMMY_SHIM_ERROR"
    ;;
  remove)
    shimmy_shim_mutation_preflight
    [ "$#" -eq 1 ] || fail 'shim remove requires exactly one tool[@version] selector'
    shimmy_selector_parse "$1" || fail "invalid shim selector: $1"
    shimmy_shim_remove "$SHIMMY_SELECTOR_TOOL" "$SHIMMY_SELECTOR_VERSION" || fail "$SHIMMY_SHIM_ERROR"
    ;;
  set-version)
    shimmy_shim_mutation_preflight
    [ "$#" -eq 1 ] || fail 'shim set-version requires exactly one tool@version selector'
    shimmy_selector_parse "$1" || fail "invalid shim selector: $1"
    [ -n "$SHIMMY_SELECTOR_VERSION" ] || fail 'shim set-version requires an exact tool@version selector'
    shimmy_shim_set_version "$SHIMMY_SELECTOR_TOOL" "$SHIMMY_SELECTOR_VERSION" || fail "$SHIMMY_SHIM_ERROR"
    ;;
  sync)
    shimmy_shim_mutation_preflight
    shimmy_sync_selectors=$(shimmy_selected_tools_resolve "$@")
    shimmy_shim_sync "$shimmy_sync_selectors" || fail "$SHIMMY_SHIM_ERROR"
    ;;
  test)
    shimmy_smoke_pairs=$(shimmy_smoke_pairs_resolve "$@")
    [ -n "$shimmy_smoke_pairs" ] || fail 'profile contains no shims to test'
    shimmy_shim_smoke_run "$shimmy_smoke_pairs"
    ;;
esac
