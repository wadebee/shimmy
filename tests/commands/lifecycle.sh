#!/bin/sh

# shellcheck source=lib/install/profile-assets.sh
. "$ROOT_DIR/lib/install/profile-assets.sh"

test_commands_lifecycle_prepare() {
  setup_scenario_with_profiles default upstream

  for asset_name in shell-init.sh install-manifest.txt bin/shimmy commands config implementations lib plugins tests tools; do
    [ -e "$DEFAULT_PROFILE_ROOT/$asset_name" ] || fail_test "missing flat profile asset: $asset_name"
  done
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/core"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/agent"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/agent"
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
  assert_file_exists "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/shimmy-install/SKILL.md"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/shimmy-tool-local-build/SKILL.md"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/.shimmy-skills-manifest.txt"
  for kind_name in $(shimmy_kind_list); do
    assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/$kind_name/SKILL.md"
    assert_file_exists "$UPSTREAM_PROFILE_ROOT/tools/$kind_name/SKILL.md"
    assert_path_not_exists "$DEFAULT_PROFILE_ROOT/tools/$kind_name/agent"
    assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/tools/$kind_name/agent"
  done

  output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version)
  assert_contains "$output" "ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91"
  pass "flat default and upstream profiles bootstrap and default dispatch works"
}

test_commands_lifecycle_legacy_agent_refresh() {
  setup_scenario_with_profiles default
  mkdir -p "$DEFAULT_PROFILE_ROOT/agent/core"
  printf '%s\n' legacy > "$DEFAULT_PROFILE_ROOT/agent/core/sentinel"

  bootstrap_default >/dev/null

  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/agent"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/plugins/shimmy/skills/shimmy-install/SKILL.md"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/jq/SKILL.md"
  pass "successful profile refresh removes the retired legacy agent payload"
}

test_commands_lifecycle_legacy_agent_rollback() {
  setup_scenario
  transaction_profile_root=$SCENARIO_DIR/transaction-profile
  transaction_stage_root=$SCENARIO_DIR/transaction-stage
  transaction_profiles_root=$SCENARIO_DIR/profiles
  mkdir -p "$transaction_profile_root/bin" "$transaction_stage_root/bin" "$transaction_profiles_root"

  for asset_name in agent commands config implementations lib tools tests plugins; do
    mkdir -p "$transaction_profile_root/$asset_name"
    printf '%s\n' "old-$asset_name" > "$transaction_profile_root/$asset_name/sentinel"
    if [ "$asset_name" != agent ]; then
      mkdir -p "$transaction_stage_root/$asset_name"
      printf '%s\n' "new-$asset_name" > "$transaction_stage_root/$asset_name/sentinel"
    fi
  done
  printf '%s\n' old-shell-init > "$transaction_profile_root/shell-init.sh"
  printf '%s\n' old-manifest > "$transaction_profile_root/install-manifest.txt"
  printf '%s\n' old-launcher > "$transaction_profile_root/bin/shimmy"
  ln -s old-dispatcher "$transaction_profile_root/bin/jq"
  printf '%s\n' new-shell-init > "$transaction_stage_root/shell-init.sh"
  printf '%s\n' new-manifest > "$transaction_stage_root/install-manifest.txt"
  printf '%s\n' new-launcher > "$transaction_stage_root/bin/shimmy"

  SHIMMY_CONFIG_ROOT=$SCENARIO_DIR/config
  SHIMMY_PROFILE_ROOT=$transaction_profile_root
  SHIMMY_STAGE_ROOT=$transaction_stage_root
  SHIMMY_PROFILES_ROOT=$transaction_profiles_root
  SHIMMY_PROFILE_RESOLVED=default
  SHIMMY_BIN_DIR=$transaction_profile_root/bin
  SHIMMY_CONTROL_BIN=$transaction_profile_root/bin/shimmy
  SHIMMY_SHELL_INIT_FILE=$transaction_profile_root/shell-init.sh
  INSTALL_MANIFEST_FILE=$transaction_profile_root/install-manifest.txt
  EXISTING_PROFILE_KINDS=jq
  PROFILE_MANIFEST_KINDS=jq
  SHIMMY_PROFILE_BACKUP_ROOT=
  SHIMMY_PROFILE_DIRECTORIES_REPLACED=
  SHIMMY_PROFILE_FILES_REPLACED=
  SHIMMY_MANIFEST_COMMIT_TMP=
  SHIMMY_SHELL_INIT_COMMIT_TMP=

  set +e
  (
    set -e
    test_commit_failure_pending=1
    mv() {
      if [ "$#" -eq 2 ] && [ "$2" = "$INSTALL_MANIFEST_FILE" ] &&
        [ "$test_commit_failure_pending" -eq 1 ]; then
        test_commit_failure_pending=0
        return 1
      fi
      command mv "$@"
    }
    trap 'profile_commit_temporary_files_cleanup; if [ -n "$SHIMMY_PROFILE_BACKUP_ROOT" ] && [ -d "$SHIMMY_PROFILE_BACKUP_ROOT" ]; then profile_commit_restore; fi' EXIT
    profile_assets_commit
  ) 2>/dev/null
  commit_status=$?
  set -e
  if [ "$commit_status" -eq 0 ]; then
    fail_test "induced late profile commit failure unexpectedly succeeded"
  fi

  for asset_name in agent commands config implementations lib tools tests plugins; do
    assert_file_contains "$transaction_profile_root/$asset_name/sentinel" "old-$asset_name"
  done
  assert_file_contains "$transaction_profile_root/shell-init.sh" old-shell-init
  assert_file_contains "$transaction_profile_root/install-manifest.txt" old-manifest
  assert_file_contains "$transaction_profile_root/bin/shimmy" old-launcher
  assert_equals "$(readlink "$transaction_profile_root/bin/jq")" old-dispatcher
  assert_path_not_exists "$transaction_profiles_root/.default.backup.$$"
  pass "late profile commit failure restores legacy agent and every backed-up owned asset"
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
  setup_scenario_with_profiles default upstream
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
  setup_scenario_with_profiles default
  default_shimmy uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy"

  setup_scenario_with_profiles default upstream
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
  mkdir -p "$DEFAULT_PROFILE_ROOT/agent"
  printf '%s\n' legacy > "$DEFAULT_PROFILE_ROOT/agent/sentinel"

  default_shimmy uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/agent"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/sibling-sentinel"
  pass "additive install and profile uninstall preserve unmanaged and sibling state"

  test_commands_lifecycle_install_shapes
  test_commands_lifecycle_launcher_refresh
  test_commands_lifecycle_legacy_agent_refresh
  test_commands_lifecycle_legacy_agent_rollback
  test_commands_lifecycle_empty_container_cleanup
}
