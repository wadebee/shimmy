#!/bin/sh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
CATALOG_FILE=$ROOT_DIR/core/catalog/catalog.sh
TEST_COUNT=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  TEST_COUNT=$((TEST_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

assert_contains() {
  value=$1
  expected=$2
  case "$value" in
    *"$expected"*) ;;
    *) fail "expected output to contain: $expected" ;;
  esac
}

test_context_tree() {
  "$SCRIPT_DIR/context-tree.sh"
  pass "CONTEXT tree"
}

test_catalog_discovery() {
  # shellcheck source=core/catalog/catalog.sh
  . "$CATALOG_FILE"

  kinds=$(shimmy_kind_list)
  assert_contains "$kinds" jq
  assert_contains "$kinds" opnsense-mcp-admin
  [ "$(shimmy_kind_default_version oc)" = oc_4_20 ] || fail "oc default is not 4.20"
  [ "$(shimmy_kind_version_for_label oc 4.18)" = oc_4_18 ] || fail "oc 4.18 metadata is missing"
  [ "$(shimmy_version_kind rg_15_1)" = rg ] || fail "rg version metadata is missing"
  pass "metadata-driven catalog discovery"
}

test_preview_dispatch() {
  jq_preview=$("$ROOT_DIR/commands/run-tool.sh" jq --preview-shim --version)
  assert_contains "$jq_preview" ghcr.io/jqlang/jq:1.8.1

  oc_preview=$(SHIMMY_OC_VERSION=4.18 "$ROOT_DIR/commands/run-tool.sh" oc --preview-shim version)
  assert_contains "$oc_preview" shimmy-oc-4_18
  pass "generic tool dispatch and version selection"
}

test_all_tool_previews() {
  for kind_name in $(. "$CATALOG_FILE"; shimmy_kind_list); do
    case "$kind_name" in
      gdrive|opnsense-mcp-admin|opnsense-mcp-read-only)
        output=$("$ROOT_DIR/commands/run-tool.sh" "$kind_name" --preview-shim 2>&1)
        ;;
      *)
        output=$("$ROOT_DIR/commands/run-tool.sh" "$kind_name" --preview-shim --help 2>&1)
        ;;
    esac
    [ -n "$output" ] || fail "empty preview for $kind_name"
  done
  pass "all tool preview paths"
}

test_clean_install() {
  test_root=$(mktemp -d "${TMPDIR:-/tmp}/shimmy-layout-test.XXXXXX")
  trap 'rm -rf "$test_root"' EXIT HUP INT TERM

  HOME=$test_root/home "$ROOT_DIR/shimmy" install --install-dir "$test_root/install" --no-startup --no-skills >/dev/null
  status=$(HOME=$test_root/home "$test_root/install/bin/shimmy" status --format manifest)
  assert_contains "$status" shimmy_profile_kind=jq
  assert_contains "$status" shimmy_profile_kind=rg
  preview=$(HOME=$test_root/home "$test_root/install/bin/jq" --preview-shim --version)
  assert_contains "$preview" ghcr.io/jqlang/jq:1.8.1
  HOME=$test_root/home "$test_root/install/bin/shimmy" uninstall --install-dir "$test_root/install" --profile default --no-skills >/dev/null
  pass "layout-version-2 install, dispatch, and uninstall"
}

main() {
  test_context_tree
  test_catalog_discovery
  test_preview_dispatch
  test_all_tool_previews
  test_clean_install
  printf 'All %s Shimmy tests passed.\n' "$TEST_COUNT"
}

main "$@"
