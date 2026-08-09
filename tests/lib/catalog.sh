#!/bin/sh
# Metadata and source-dispatch behavior tests.

test_lib_catalog_context_tree() {
  "$ROOT_DIR/tests/context-tree.sh"
  pass "CONTEXT tree"
}

test_lib_catalog_discovery() {
  # shellcheck source=lib/catalog/catalog.sh
  . "$ROOT_DIR/lib/catalog/catalog.sh"

  kinds=$(shimmy_kind_list)
  assert_contains "$kinds" jq
  assert_contains "$kinds" opnsense-mcp-admin
  assert_equals "$(shimmy_kind_default_version oc)" oc_4_20
  assert_equals "$(shimmy_kind_version_for_label oc 4.18)" oc_4_18
  assert_equals "$(shimmy_version_kind rg_15_1)" rg
  assert_equals "$(shimmy_version_label gcloud_573_0)" 573.0
  pass "metadata-driven catalog discovery"
}

test_lib_catalog_preview_dispatch() {
  jq_preview=$("$ROOT_DIR/commands/run-tool.sh" jq --preview-shim --version)
  assert_contains "$jq_preview" ghcr.io/jqlang/jq:1.8.1

  oc_preview=$(SHIMMY_OC_VERSION=4.18 "$ROOT_DIR/commands/run-tool.sh" oc --preview-shim version)
  assert_contains "$oc_preview" shimmy-oc-4_18
  pass "generic tool dispatch and version selection"
}

test_lib_catalog_all_previews() {
  # shellcheck source=lib/catalog/catalog.sh
  . "$ROOT_DIR/lib/catalog/catalog.sh"

  for kind_name in $(shimmy_kind_list); do
    case "$kind_name" in
      gdrive|opnsense-mcp-admin|opnsense-mcp-read-only)
        output=$("$ROOT_DIR/commands/run-tool.sh" "$kind_name" --preview-shim 2>&1)
        ;;
      *)
        output=$("$ROOT_DIR/commands/run-tool.sh" "$kind_name" --preview-shim --help 2>&1)
        ;;
    esac
    assert_not_empty "$output"
  done
  pass "all tool preview paths"
}

test_lib_catalog_concrete_version_previews() {
  # shellcheck source=lib/catalog/catalog.sh
  . "$ROOT_DIR/lib/catalog/catalog.sh"

  for kind_name in $(shimmy_kind_list); do
    default_label=$(sed -n 's/^tool_default_version=//p' "$ROOT_DIR/tools/$kind_name/tool.conf" | sed -n '1p')
    selector_env=$(shimmy_kind_selector_env "$kind_name")

    for version_label in $(shimmy_kind_version_label_list "$kind_name"); do
      version_dir=$ROOT_DIR/tools/$kind_name/versions/$version_label
      smoke_file=$version_dir/smoke.conf
      version_name=$(shimmy_kind_version_for_label "$kind_name" "$version_label")
      smoke_name=$(sed -n 's/^shim_name=//p' "$smoke_file" | sed -n '1p')
      smoke_arg=$(sed -n 's/^smoke_arg=//p' "$smoke_file" | sed -n '1p')

      assert_equals "$smoke_name" "$version_name"
      assert_not_empty "$smoke_arg"

      runtime_output=$("$version_dir/run.sh" --preview-shim "$smoke_arg" 2>&1)
      assert_not_empty "$runtime_output"

      if [ -n "$selector_env" ]; then
        dispatch_output=$(env "$selector_env=$version_label" "$ROOT_DIR/commands/run-tool.sh" "$kind_name" --preview-shim "$smoke_arg" 2>&1)
      elif [ "$version_label" = "$default_label" ]; then
        dispatch_output=$("$ROOT_DIR/commands/run-tool.sh" "$kind_name" --preview-shim "$smoke_arg" 2>&1)
      else
        continue
      fi
      assert_not_empty "$dispatch_output"
    done
  done
  pass "all concrete runtimes honor declared smoke previews"
}

test_lib_catalog_metadata_complete() {
  for tool_file in "$ROOT_DIR"/tools/*/tool.conf; do
    [ -f "$tool_file" ] || continue
    tool_dir=$(dirname "$tool_file")
    assert_file_contains "$tool_file" tool_default_version=

    for version_dir in "$tool_dir"/versions/*; do
      [ -d "$version_dir" ] || continue
      assert_file_exists "$version_dir/smoke.conf"
      assert_file_exists "$version_dir/status.conf"
      assert_file_executable "$version_dir/run.sh"
      assert_file_contains "$version_dir/smoke.conf" shim_name=
      assert_file_contains "$version_dir/status.conf" shim_status_version=1
      assert_file_contains "$version_dir/status.conf" status_image=
      status_image=$(sed -n 's/^status_image=//p' "$version_dir/status.conf" | sed -n '1p')
      assert_not_empty "$status_image"
    done
  done
  pass "tool metadata and concrete runtimes are complete"
}

test_lib_catalog_run() {
  test_lib_catalog_context_tree
  test_lib_catalog_discovery
  test_lib_catalog_preview_dispatch
  test_lib_catalog_all_previews
  test_lib_catalog_concrete_version_previews
  test_lib_catalog_metadata_complete
}
