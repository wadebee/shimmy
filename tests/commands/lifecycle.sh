#!/bin/sh

test_commands_lifecycle_prepare() {
  setup_scenario
  bootstrap_default >/dev/null
  bootstrap_upstream >/dev/null

  for asset_name in shell-init.sh install-manifest.txt bin/shimmy commands config implementations lib plugins tests tools agent; do
    [ -e "$DEFAULT_PROFILE_ROOT/$asset_name" ] || fail_test "missing flat profile asset: $asset_name"
  done
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/core"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/.agents"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_manifest_version=4'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_layout=profile-flat-root'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_profile_manifest_version=4'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_profile_name=default'
  assert_equals "$(readlink "$DEFAULT_PROFILE_ROOT/bin/jq")" '../commands/dispatch-tool.sh'
  assert_regular_file_not_symlink "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_executable "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_regular_file_not_symlink "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  assert_file_mode "$DEFAULT_PROFILE_ROOT/shell-init.sh" 644
  assert_file_executable "$DEFAULT_PROFILE_ROOT/commands/install.sh"
  assert_file_executable "$DEFAULT_PROFILE_ROOT/lib/catalog/catalog.sh"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/agent/core/shimmy-install/SKILL.md"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/shimmy-install/SKILL.md"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/.shimmy-skills-manifest.txt" 'shimmy_skills_target=plugin'

  output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version)
  assert_contains "$output" "ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91"
  pass "flat default and upstream profiles bootstrap and default dispatch works"
}

test_commands_lifecycle_install_shapes() {
  setup_scenario
  bootstrap_default >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"

  setup_scenario
  bootstrap_upstream >/dev/null
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"

  bootstrap_default >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  pass "default-only, upstream-only, and combined profile installs use independent flat roots"
}

test_commands_lifecycle_launcher_refresh() {
  setup_scenario
  bootstrap_default >/dev/null
  bootstrap_upstream >/dev/null
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/bin/unmanaged-bin"
  printf '%s\n' '# stale launcher marker' >> "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  printf '%s\n' '# stale shell init marker' >> "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  upstream_launcher_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/bin/shimmy")
  upstream_dispatcher_target=$(readlink "$UPSTREAM_PROFILE_ROOT/bin/rg")

  bootstrap_default >/dev/null
  default_shimmy install --shim task --no-startup >/dev/null
  assert_file_not_contains "$DEFAULT_PROFILE_ROOT/bin/shimmy" '# stale launcher marker'
  assert_file_not_contains "$DEFAULT_PROFILE_ROOT/shell-init.sh" '# stale shell init marker'
  assert_file_mode "$DEFAULT_PROFILE_ROOT/shell-init.sh" 644
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/unmanaged-bin"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/bin/shimmy")" "$upstream_launcher_checksum"
  assert_equals "$(readlink "$UPSTREAM_PROFILE_ROOT/bin/rg")" "$upstream_dispatcher_target"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/jq"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"
  pass "launcher refresh replaces only owned entries in the invoking profile bin directory"
}

test_commands_lifecycle_empty_container_cleanup() {
  setup_scenario
  bootstrap_default >/dev/null
  default_shimmy uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy"

  setup_scenario
  bootstrap_default >/dev/null
  bootstrap_upstream >/dev/null
  default_shimmy uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_dir_exists "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  upstream_shimmy uninstall >/dev/null
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy"
  pass "profile removal preserves siblings and removes only empty merge-owned containers"
}

test_commands_lifecycle_complete() {
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  printf '%s\n' sibling > "$UPSTREAM_PROFILE_ROOT/sibling-sentinel"
  default_shimmy install --shim task --no-startup >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/sibling-sentinel"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"

  default_shimmy uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/sibling-sentinel"
  pass "additive install and profile uninstall preserve unmanaged and sibling state"

  test_commands_lifecycle_install_shapes
  test_commands_lifecycle_launcher_refresh
  test_commands_lifecycle_empty_container_cleanup
}
