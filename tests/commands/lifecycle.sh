#!/bin/sh

test_commands_lifecycle_prepare() {
  setup_scenario
  bootstrap_default --shim jq --shim rg >/dev/null
  bootstrap_upstream --shim jq >/dev/null

  for asset_name in activate.sh install-manifest.txt bin/shimmy commands config implementations lib plugins tests tools agent; do
    [ -e "$DEFAULT_PROFILE_ROOT/$asset_name" ] || fail_test "missing flat profile asset: $asset_name"
  done
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/core"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/.agents"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_manifest_version=3'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_layout=profile-flat-root'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_profile_name=default'
  assert_equals "$(readlink "$DEFAULT_PROFILE_ROOT/bin/jq")" '../commands/dispatch-tool.sh'

  output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version)
  assert_contains "$output" "ghcr.io/jqlang/jq:1.8.1"
  pass "flat default and upstream profiles bootstrap and default dispatch works"
}

test_commands_lifecycle_complete() {
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  printf '%s\n' sibling > "$UPSTREAM_PROFILE_ROOT/sibling-sentinel"
  default_shimmy install --shim task --no-startup --no-skills >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/sibling-sentinel"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"

  default_shimmy uninstall --no-skills >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/sibling-sentinel"
  pass "additive install and profile uninstall preserve unmanaged and sibling state"
}
