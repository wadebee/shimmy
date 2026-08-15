#!/bin/sh

# shellcheck source=lib/install/profile-assets.sh
. "$ROOT_DIR/lib/install/profile-assets.sh"

test_commands_lifecycle_prepare() {
  setup_scenario_with_profiles default upstream

  for asset_name in shell-init.sh registries.conf install-manifest.txt bin/shimmy commands config implementations lib tests tools; do
    [ -e "$DEFAULT_PROFILE_ROOT/$asset_name" ] || fail_test "missing materialized profile asset: $asset_name"
  done
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/core"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/agent"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/agent"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/.agents"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_manifest_version=2'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_layout=profile-materialized-root'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_profile_manifest_version=2'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_profile_name=default'
  assert_equals "$(readlink "$DEFAULT_PROFILE_ROOT/bin/jq")" '../commands/dispatch-tool.sh'
  assert_regular_file_not_symlink "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_executable "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_regular_file_not_symlink "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  assert_file_mode "$DEFAULT_PROFILE_ROOT/shell-init.sh" 644
  assert_regular_file_not_symlink "$DEFAULT_PROFILE_ROOT/registries.conf"
  assert_file_mode "$DEFAULT_PROFILE_ROOT/registries.conf" 644
  assert_file_contains "$DEFAULT_PROFILE_ROOT/registries.conf" '# shimmy_registry_redirects_version=1'
  assert_file_executable "$DEFAULT_PROFILE_ROOT/commands/install.sh"
  assert_file_executable "$DEFAULT_PROFILE_ROOT/lib/catalog/catalog.sh"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/plugins"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/plugins"
  for tool_name in jq rg; do
    assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/$tool_name/tool.conf"
    assert_file_exists "$UPSTREAM_PROFILE_ROOT/tools/$tool_name/tool.conf"
    assert_path_not_exists "$DEFAULT_PROFILE_ROOT/tools/$tool_name/SKILL.md"
    assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/tools/$tool_name/SKILL.md"
  done
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/tools/task"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/tools/task"

  output=$(XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version)
  assert_contains "$output" "ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91"
  pass "materialized default and upstream profiles contain only selected tools and default dispatch works"
}

test_commands_lifecycle_legacy_agent_refresh() {
  setup_scenario_with_profiles default
  mkdir -p "$DEFAULT_PROFILE_ROOT/agent/core"
  printf '%s\n' legacy > "$DEFAULT_PROFILE_ROOT/agent/core/sentinel"

  set +e
  refresh_output=$(bootstrap_default 2>&1)
  refresh_status=$?
  set -e
  [ "$refresh_status" -ne 0 ] || fail_test "mixed profile layout unexpectedly refreshed"
  assert_contains "$refresh_output" 'legacy, mixed, or damaged Shimmy profile'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/agent/core/sentinel" legacy
  default_shimmy uninstall >/dev/null
  bootstrap_default >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/agent"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/plugins"
  pass "mixed profile layout is rejected without mutation and clean uninstall plus recreation succeeds"
}

test_commands_lifecycle_legacy_agent_rollback() {
  setup_scenario
  transaction_profile_root=$SCENARIO_DIR/transaction-profile
  transaction_stage_root=$SCENARIO_DIR/transaction-stage
  transaction_profiles_root=$SCENARIO_DIR/profiles
  mkdir -p "$transaction_profile_root/bin" "$transaction_stage_root/bin" "$transaction_profiles_root"

  for asset_name in agent commands config implementations lib tools tests; do
    mkdir -p "$transaction_profile_root/$asset_name"
    printf '%s\n' "old-$asset_name" > "$transaction_profile_root/$asset_name/sentinel"
    if [ "$asset_name" != agent ]; then
      mkdir -p "$transaction_stage_root/$asset_name"
      printf '%s\n' "new-$asset_name" > "$transaction_stage_root/$asset_name/sentinel"
    fi
  done
  printf '%s\n' old-shell-init > "$transaction_profile_root/shell-init.sh"
  printf '%s\n' old-registries > "$transaction_profile_root/registries.conf"
  printf '%s\n' old-manifest > "$transaction_profile_root/install-manifest.txt"
  printf '%s\n' old-launcher > "$transaction_profile_root/bin/shimmy"
  ln -s old-dispatcher "$transaction_profile_root/bin/jq"
  printf '%s\n' new-shell-init > "$transaction_stage_root/shell-init.sh"
  printf '%s\n' new-registries > "$transaction_stage_root/registries.conf"
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
  SHIMMY_PROFILE_REGISTRIES_PATH=$transaction_profile_root/registries.conf
  SHIMMY_PROFILE_REGISTRIES_LOCK_PATH=$transaction_profile_root/.registries.lock
  INSTALL_MANIFEST_FILE=$transaction_profile_root/install-manifest.txt
  EXISTING_PROFILE_TOOLS=jq
  PROFILE_MANIFEST_TOOLS=jq
  SHIMMY_PROFILE_BACKUP_ROOT=
  SHIMMY_PROFILE_DIRECTORIES_REPLACED=
  SHIMMY_PROFILE_FILES_REPLACED=
  SHIMMY_MANIFEST_COMMIT_TMP=
  SHIMMY_REGISTRIES_COMMIT_TMP=
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

  for asset_name in agent commands config implementations lib tools tests; do
    assert_file_contains "$transaction_profile_root/$asset_name/sentinel" "old-$asset_name"
  done
  assert_file_contains "$transaction_profile_root/shell-init.sh" old-shell-init
  assert_file_contains "$transaction_profile_root/registries.conf" old-registries
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
  assert_file_exists "$DEFAULT_PROFILE_ROOT/registries.conf"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
  assert_file_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream"
  default_generation=$(profile_manifest_value "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf" catalog_generation_current)
  assert_file_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$default_generation/generation.conf"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'catalog=default'

  setup_scenario
  bootstrap_upstream >/dev/null
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/registries.conf"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_file_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default"
  assert_file_contains "$UPSTREAM_PROFILE_ROOT/install-manifest.txt" 'catalog=upstream'

  bootstrap_default >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  pass "default-only, upstream-only, and combined installs use independent materialized profile roots"
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

test_commands_lifecycle_registry_upgrade_and_preservation() {
  setup_scenario_with_profiles default upstream
  default_config=$DEFAULT_PROFILE_ROOT/registries.conf
  upstream_config=$UPSTREAM_PROFILE_ROOT/registries.conf
  default_shimmy profile redirect --prefix docker.io --location registry.corp.example/docker
  configured_bytes=$SCENARIO_DIR/configured-registries
  cp "$default_config" "$configured_bytes"
  upstream_checksum=$(cksum < "$upstream_config")

  default_shimmy install --shim task --no-startup >/dev/null
  cmp -s "$configured_bytes" "$default_config" || fail_test "additive install changed valid registry bytes"
  bootstrap_default >/dev/null
  cmp -s "$configured_bytes" "$default_config" || fail_test "profile refresh changed valid registry bytes"
  assert_equals "$(cksum < "$upstream_config")" "$upstream_checksum"

  setup_scenario_with_profiles default
  rm -f "$DEFAULT_PROFILE_ROOT/registries.conf"
  bootstrap_default >/dev/null
  assert_regular_file_not_symlink "$DEFAULT_PROFILE_ROOT/registries.conf"
  assert_file_mode "$DEFAULT_PROFILE_ROOT/registries.conf" 644
  assert_contains "$(default_shimmy profile redirect list --format manifest)" 'registry_policy=inactive'

  for invalid_shape in wrong_profile malformed symlink wrong_mode; do
    setup_scenario_with_profiles default
    registry_config=$DEFAULT_PROFILE_ROOT/registries.conf
    launcher_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")
    case "$invalid_shape" in
      wrong_profile) sed 's/profile "default"/profile "upstream"/' "$registry_config" > "$registry_config.tmp"; mv "$registry_config.tmp" "$registry_config" ;;
      malformed) printf '%s\n' unmanaged > "$registry_config" ;;
      symlink) printf '%s\n' keep > "$SCENARIO_DIR/registry-target"; rm -f "$registry_config"; ln -s "$SCENARIO_DIR/registry-target" "$registry_config" ;;
      wrong_mode) chmod 600 "$registry_config" ;;
    esac
    set +e
    invalid_output=$(bootstrap_default 2>&1)
    invalid_status=$?
    set -e
    [ "$invalid_status" -ne 0 ] || fail_test "invalid registry asset unexpectedly refreshed: $invalid_shape"
    assert_contains "$invalid_output" 'legacy, mixed, or damaged Shimmy profile'
    assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")" "$launcher_checksum"
    assert_path_not_exists "$DEFAULT_PROFILE_ROOT/.registries.lock"
  done

  setup_scenario_with_profiles default
  printf '%s\n' unmanaged > "$DEFAULT_PROFILE_ROOT/registries.conf"
  launcher_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")
  set +e
  uninstall_output=$(default_shimmy uninstall 2>&1)
  uninstall_status=$?
  set -e
  [ "$uninstall_status" -ne 0 ] || fail_test "uninstall unexpectedly removed malformed registry state"
  assert_contains "$uninstall_output" 'invalid or unmanaged registry configuration'
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")" "$launcher_checksum"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/registries.conf" unmanaged
  pass "pre-feature upgrade creates an empty config, valid installs preserve exact bytes, and invalid registry assets fail before profile mutation"
}

test_commands_lifecycle_empty_container_cleanup() {
  setup_scenario_with_profiles default
  default_registry_config=$DEFAULT_PROFILE_ROOT/registries.conf
  default_shimmy uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$default_registry_config"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  assert_file_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf"

  setup_scenario_with_profiles default upstream
  upstream_registry_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/registries.conf")
  default_shimmy uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/registries.conf")" "$upstream_registry_checksum"
  assert_dir_exists "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  upstream_shimmy uninstall >/dev/null
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  assert_file_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf"
  pass "profile removal preserves sibling profiles and independently owned shared catalogs"
}

test_commands_lifecycle_global_uninstall() {
  setup_scenario_with_profiles default upstream
  replacement_checkout=$SCENARIO_DIR/global-uninstall-checkout
  cp -R "$SHIMMY_TEST_CLEAN_SOURCE_ROOT" "$replacement_checkout"
  upstream_shimmy catalog rebind --checkout "$replacement_checkout" >/dev/null
  (
    cd "$WORK_DIR"
    default_shimmy skills install --target repo >/dev/null
  )
  exported_skill_file=$WORK_DIR/.agents/skills/shimmy-install/SKILL.md
  exported_manifest=$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt
  assert_file_exists "$exported_skill_file"
  assert_file_exists "$exported_manifest"
  mkdir -p "$XDG_CONFIG_HOME_DIR/containers"
  printf '%s\n' operator-policy > "$XDG_CONFIG_HOME_DIR/containers/registries.conf"

  printf '%s\n' unmanaged > "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/unmanaged-sentinel"
  set +e
  unsafe_output=$(default_shimmy uninstall --global 2>&1)
  unsafe_status=$?
  set -e
  [ "$unsafe_status" -ne 0 ] || fail_test 'global uninstall unexpectedly removed unrecognized catalog state'
  assert_contains "$unsafe_output" 'refusing to remove unrecognized shared catalog state'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  rm -f "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/unmanaged-sentinel"

  mkdir "$UPSTREAM_PROFILE_ROOT/.registries.lock"
  set +e
  lock_output=$(default_shimmy uninstall --global 2>&1)
  lock_status=$?
  set -e
  [ "$lock_status" -ne 0 ] || fail_test 'global uninstall unexpectedly crossed a sibling registry transaction lock'
  assert_contains "$lock_output" 'registry transaction is active or damaged'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  rmdir "$UPSTREAM_PROFILE_ROOT/.registries.lock"

  relocated_checkout=$SCENARIO_DIR/relocated-global-uninstall-checkout
  mv "$replacement_checkout" "$relocated_checkout"
  default_shimmy uninstall --global >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs"
  assert_dir_exists "$relocated_checkout"
  assert_file_exists "$exported_skill_file"
  assert_file_exists "$exported_manifest"
  assert_file_contains "$XDG_CONFIG_HOME_DIR/containers/registries.conf" operator-policy
  pass "explicit global uninstall removes only owned profiles and catalogs while preserving checkouts and external skill exports"
}

test_commands_lifecycle_catalog_independent_execution() {
  setup_scenario_with_profiles default upstream
  default_registry=$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf
  upstream_registry=$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf
  mv "$default_registry" "$default_registry.unavailable"
  mv "$upstream_registry" "$upstream_registry.unavailable"

  default_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$DEFAULT_PROFILE_ROOT/bin/jq" --preview-shim --version)
  upstream_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$UPSTREAM_PROFILE_ROOT/bin/rg" --preview-shim --version)
  assert_contains "$default_output" 'ghcr.io/jqlang/jq@sha256:'
  assert_contains "$upstream_output" 'docker.io/vszl/ripgrep@sha256:'
  set +e
  catalog_list_output=$(default_shimmy catalog list --format manifest 2>&1)
  catalog_list_code=$?
  set -e
  [ "$catalog_list_code" -ne 0 ] || fail_test "catalog list unexpectedly accepted a missing registry"
  assert_contains "$catalog_list_output" 'missing catalog registry entry:'
  assert_not_contains "$catalog_list_output" 'shimmy_catalog_name='
  assert_not_contains "$catalog_list_output" 'shimmy_catalog_tool='
  set +e
  status_output=$(default_shimmy status --format manifest 2>&1)
  status_code=$?
  set -e
  [ "$status_code" -ne 0 ] || fail_test "catalog-dependent status unexpectedly accepted a missing registry"
  assert_contains "$status_output" 'shimmy_catalog_health=invalid'
  pass "materialized tool execution survives catalog loss while catalog-dependent management fails closed"
}

test_commands_lifecycle_control_plane_refresh() {
  setup_scenario
  control_checkout=$SCENARIO_DIR/control-checkout
  setup_clean_source_fixture "$control_checkout"
  (
    cd "$control_checkout"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile upstream --no-startup
  ) >/dev/null

  printf '%s\n' '# chunk-2 command marker' >> "$control_checkout/commands/status.sh"
  printf '%s\n' '# chunk-2 library marker' >> "$control_checkout/lib/common/common.sh"
  assert_file_not_contains "$UPSTREAM_PROFILE_ROOT/commands/status.sh" 'chunk-2 command marker'
  assert_file_not_contains "$UPSTREAM_PROFILE_ROOT/lib/common/common.sh" 'chunk-2 library marker'
  upstream_shimmy status --format manifest >/dev/null

  (
    cd "$control_checkout"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile upstream --no-startup
  ) >/dev/null
  assert_file_contains "$UPSTREAM_PROFILE_ROOT/commands/status.sh" 'chunk-2 command marker'
  assert_file_contains "$UPSTREAM_PROFILE_ROOT/lib/common/common.sh" 'chunk-2 library marker'
  pass "upstream control-plane edits remain inactive until explicit profile refresh"
}

test_commands_lifecycle_profile_materialization_isolation() {
  setup_scenario_with_profiles default upstream
  upstream_manifest_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")
  upstream_implementation_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/implementations/jq")
  default_registry_checksum=$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf")
  upstream_registry_checksum=$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf")

  default_shimmy install --shim task --no-startup >/dev/null
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/task/tool.conf"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/task/versions/3.45/run.sh"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/tools/task/SKILL.md"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/bin/task"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/tools/task"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$upstream_manifest_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/implementations/jq")" "$upstream_implementation_checksum"
  assert_equals "$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf")" "$default_registry_checksum"
  assert_equals "$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf")" "$upstream_registry_checksum"
  pass "tool installation changes only the invoking profile materialization and manifest"
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
  test_commands_lifecycle_registry_upgrade_and_preservation
  test_commands_lifecycle_profile_materialization_isolation
  test_commands_lifecycle_catalog_independent_execution
  test_commands_lifecycle_control_plane_refresh
  test_commands_lifecycle_legacy_agent_refresh
  test_commands_lifecycle_legacy_agent_rollback
  test_commands_lifecycle_empty_container_cleanup
  test_commands_lifecycle_global_uninstall
}
