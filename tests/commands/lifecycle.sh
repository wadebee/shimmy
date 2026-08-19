#!/bin/sh

# shellcheck source=lib/install/profile-assets.sh
. "$ROOT_DIR/lib/install/profile-assets.sh"

test_commands_lifecycle_prepare() {
  setup_scenario_with_profiles default upstream
  lifecycle_upstream_manifest_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")
  lifecycle_upstream_runtime_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/tools/jq/versions/1.8/run.sh")
  lifecycle_upstream_launcher_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/bin/shimmy")
  lifecycle_default_catalog_registry_checksum=$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf")
  lifecycle_upstream_catalog_registry_checksum=$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf")

  for asset_name in shell-init.sh registries.conf install-manifest.txt bin/shimmy commands config lib tests tools; do
    [ -e "$DEFAULT_PROFILE_ROOT/$asset_name" ] || fail_test "missing materialized profile asset: $asset_name"
  done
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/core"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/agent"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/agent"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/.agents"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_manifest_version=1'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_layout=profile-materialized-root'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_profile_manifest_version=1'
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
  assert_file_exists "$DEFAULT_PROFILE_ROOT/config/shims/jq.conf"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/config/shims/jq_1_8.conf"
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

  for asset_name in agent commands config lib tools tests; do
    mkdir -p "$transaction_profile_root/$asset_name"
    printf '%s\n' "old-$asset_name" > "$transaction_profile_root/$asset_name/sentinel"
    if [ "$asset_name" != agent ]; then
      mkdir -p "$transaction_stage_root/$asset_name"
      printf '%s\n' "new-$asset_name" > "$transaction_stage_root/$asset_name/sentinel"
    fi
  done
  printf '%s\n' old-shell-init > "$transaction_profile_root/shell-init.sh"
  printf '%s\n' old-registries > "$transaction_profile_root/registries.conf"
  printf '%s\n' old-machine-projection > "$transaction_profile_root/machine-projection.txt"
  printf '%s\n' old-manifest > "$transaction_profile_root/install-manifest.txt"
  printf '%s\n' old-launcher > "$transaction_profile_root/bin/shimmy"
  ln -s old-dispatcher "$transaction_profile_root/bin/jq"
  printf '%s\n' new-shell-init > "$transaction_stage_root/shell-init.sh"
  printf '%s\n' new-registries > "$transaction_stage_root/registries.conf"
  printf '%s\n' new-machine-projection > "$transaction_stage_root/machine-projection.txt"
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
  SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH=$transaction_profile_root/machine-projection.txt
  SHIMMY_PROFILE_REGISTRIES_LOCK_PATH=$transaction_profile_root/.registries.lock
  INSTALL_MANIFEST_FILE=$transaction_profile_root/install-manifest.txt
  EXISTING_PROFILE_TOOLS=jq
  PROFILE_MANIFEST_TOOLS=jq
  SHIMMY_PROFILE_BACKUP_ROOT=
  SHIMMY_PROFILE_DIRECTORIES_REPLACED=
  SHIMMY_PROFILE_FILES_REPLACED=
  SHIMMY_MANIFEST_COMMIT_TMP=
  SHIMMY_MACHINE_PROJECTION_COMMIT_TMP=
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

  for asset_name in agent commands config lib tools tests; do
    assert_file_contains "$transaction_profile_root/$asset_name/sentinel" "old-$asset_name"
  done
  assert_file_contains "$transaction_profile_root/shell-init.sh" old-shell-init
  assert_file_contains "$transaction_profile_root/registries.conf" old-registries
  assert_file_contains "$transaction_profile_root/machine-projection.txt" old-machine-projection
  assert_file_contains "$transaction_profile_root/install-manifest.txt" old-manifest
  assert_file_contains "$transaction_profile_root/bin/shimmy" old-launcher
  assert_equals "$(readlink "$transaction_profile_root/bin/jq")" old-dispatcher
  assert_path_not_exists "$transaction_profiles_root/.default.backup.$$"
  pass "late profile commit failure restores the retired agent directory and every current backed-up owned asset"
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
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_manifest_version=1'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_layout=profile-materialized-root'
  assert_file_contains "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$default_generation/catalog.conf" 'catalog_schema=1'
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" 'catalog=default'

  setup_scenario
  bootstrap_upstream >/dev/null
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/registries.conf"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_file_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default"
  assert_file_contains "$UPSTREAM_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_manifest_version=1'
  assert_file_contains "$UPSTREAM_PROFILE_ROOT/install-manifest.txt" 'shimmy_install_layout=profile-materialized-root'
  assert_file_contains "$ROOT_DIR/catalog.conf" 'catalog_schema=1'
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
  default_shimmy install --shim task >/dev/null
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
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  configured_projection=$SCENARIO_DIR/configured-machine-projection
  cp "$DEFAULT_PROFILE_ROOT/machine-projection.txt" "$configured_projection"
  upstream_checksum=$(cksum < "$upstream_config")

  default_shimmy install --shim task >/dev/null
  cmp -s "$configured_bytes" "$default_config" || fail_test "additive install changed valid registry bytes"
  cmp -s "$configured_projection" "$DEFAULT_PROFILE_ROOT/machine-projection.txt" || fail_test "additive install changed valid machine projection record bytes"
  bootstrap_default >/dev/null
  cmp -s "$configured_bytes" "$default_config" || fail_test "profile refresh changed valid registry bytes"
  cmp -s "$configured_projection" "$DEFAULT_PROFILE_ROOT/machine-projection.txt" || fail_test "profile refresh changed valid machine projection record bytes"
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

lifecycle_darwin_fake_prepare() {
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  : > "$FAKE_PODMAN_LOG"
  FAKE_CONNECTION_LIST=
  FAKE_DARWIN_APPLY_RESULT=
  FAKE_DARWIN_PROJECTION_STATE=current
  FAKE_FAIL_ACTION=
  FAKE_FAIL_MACHINE=
  FAKE_FAIL_ONCE_FILE=
  FAKE_MACHINE_LIST=
  FAKE_WORKLOADS=
  SHIMMY_TEST_UNINSTALL_FINALIZE_ACTION=
}

lifecycle_darwin_uninstall() {
  lifecycle_uninstall_launcher=$1
  shift
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" \
    FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_MACHINE_LIST="$FAKE_MACHINE_LIST" \
    FAKE_CONNECTION_LIST="$FAKE_CONNECTION_LIST" FAKE_WORKLOADS="$FAKE_WORKLOADS" \
    FAKE_DARWIN_PROJECTION_STATE="$FAKE_DARWIN_PROJECTION_STATE" \
    FAKE_DARWIN_APPLY_RESULT="$FAKE_DARWIN_APPLY_RESULT" \
    FAKE_FAIL_ACTION="$FAKE_FAIL_ACTION" FAKE_FAIL_MACHINE="$FAKE_FAIL_MACHINE" \
    FAKE_FAIL_ONCE_FILE="$FAKE_FAIL_ONCE_FILE" \
    SHIMMY_TEST_UNINSTALL_FINALIZE_ACTION="$SHIMMY_TEST_UNINSTALL_FINALIZE_ACTION" \
    "$lifecycle_uninstall_launcher" uninstall "$@"
}

lifecycle_darwin_uninstall_finalize_injection_install() {
  {
    printf '\n'
    printf '%s\n' 'shimmy_registries_machine_projection_detach_finalize() {'
    printf '%s\n' '  detach_backup_path=$1'
    printf '%s\n' '  case "$detach_backup_path" in'
    printf '%s\n' '    "$SHIMMY_PROFILE_ROOT"/.machine-projection.detach.*) ;;'
    printf '%s\n' '    *) return 1 ;;'
    printf '%s\n' '  esac'
    printf '%s\n' '  rm -f "$detach_backup_path"'
    printf '%s\n' '  [ "$SHIMMY_PROFILE_NAME" = upstream ] || return 0'
    printf '%s\n' '  case "${SHIMMY_TEST_UNINSTALL_FINALIZE_ACTION:-}" in'
    printf '%s\n' '    fail) return 1 ;;'
    printf '%s\n' '    INT) shimmy_install_signal_cleanup 130 ;;'
    printf '%s\n' '    TERM) shimmy_install_signal_cleanup 143 ;;'
    printf '%s\n' '  esac'
    printf '%s\n' '}'
  } >> "$DEFAULT_PROFILE_ROOT/lib/registries/registries.sh"
}

test_commands_lifecycle_darwin_projection_uninstall() {
  setup_scenario_with_profiles default upstream
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-default|true
shimmy-upstream|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'

  profile_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy")
  assert_contains "$profile_output" 'Detached Darwin registry projection for profile default'
  assert_contains "$profile_output" 'Restarting Podman machine to clear detached registry policy: shimmy-default'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  detach_line=$(sed -n '/^machine ssh --username root shimmy-default \/bin\/sh -s -- detach /=' "$FAKE_PODMAN_LOG")
  restart_stop_line=$(sed -n '/^machine stop shimmy-default$/=' "$FAKE_PODMAN_LOG")
  restart_start_line=$(sed -n '/^machine start shimmy-default$/=' "$FAKE_PODMAN_LOG")
  default_line=$(sed -n '/^system connection default shimmy-default$/=' "$FAKE_PODMAN_LOG")
  [ "$detach_line" -lt "$restart_stop_line" ] && [ "$restart_stop_line" -lt "$restart_start_line" ] &&
    [ "$restart_start_line" -lt "$default_line" ] ||
    fail_test 'running-profile uninstall did not detach, restart, and restore the default connection in order'
  pass 'ordinary Darwin uninstall detaches exact running policy, clears live cache, and preserves the sibling profile'
}

test_commands_lifecycle_darwin_stopped_guard_and_missing() {
  setup_scenario_with_profiles default upstream
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-default|false
shimmy-upstream|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  stopped_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy")
  assert_contains "$stopped_output" 'Starting Podman machine for registry cleanup: shimmy-default'
  assert_contains "$stopped_output" 'Restoring initial machine state by stopping: shimmy-default'
  assert_contains "$stopped_output" 'Restoring initial Podman default connection: shimmy-upstream'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"

  setup_scenario_with_profiles default upstream
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-default|false
shimmy-upstream|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_WORKLOADS='abc123|important'
  set +e
  guard_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  guard_status=$?
  set -e
  [ "$guard_status" -ne 0 ] || fail_test 'running alternate workloads unexpectedly allowed uninstall without acknowledgement'
  assert_contains "$guard_output" 'abc123|important'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop shimmy-upstream'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/machine-projection.txt"
  : > "$FAKE_PODMAN_LOG"
  acknowledged_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" --stop-running 2>&1)
  assert_contains "$acknowledged_output" 'acknowledged workloads were interrupted'
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine stop shimmy-upstream'
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine start shimmy-upstream'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"

  setup_scenario_with_profiles default upstream
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-upstream|false'
  FAKE_CONNECTION_LIST='shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  missing_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy")
  assert_contains "$missing_output" 'Removing projection record for proven-missing machine: shimmy-default'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh'
  assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine start'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  pass 'stopped cleanup restores state, alternate workloads require acknowledgement, and proven-missing machines use record-only cleanup'
}

test_commands_lifecycle_darwin_uninstall_refusals() {
  setup_scenario_with_profiles default
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-default|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  for projection_state in foreign absent; do
    FAKE_DARWIN_PROJECTION_STATE=$projection_state
    set +e
    projection_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
    projection_status=$?
    set -e
    [ "$projection_status" -ne 0 ] || fail_test "$projection_state Darwin projection unexpectedly allowed uninstall"
    assert_contains "$projection_output" 'foreign, absent, or invalid Darwin machine projection'
    assert_file_exists "$DEFAULT_PROFILE_ROOT/machine-projection.txt"
  done

  FAKE_DARWIN_PROJECTION_STATE=current
  export CONTAINER_HOST='ssh://secret.invalid/run/user/1/podman/podman.sock'
  set +e
  override_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  override_status=$?
  set -e
  unset CONTAINER_HOST
  [ "$override_status" -ne 0 ] || fail_test 'connection override unexpectedly allowed uninstall'
  assert_contains "$override_output" 'CONTAINER_HOST overrides Podman profile activation'
  assert_not_contains "$override_output" 'secret.invalid'

  FAKE_FAIL_ACTION=workload
  set +e
  workload_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  workload_status=$?
  set -e
  [ "$workload_status" -ne 0 ] || fail_test 'unavailable workload inspection unexpectedly allowed uninstall'
  assert_contains "$workload_output" 'unable to inspect running workloads'
  FAKE_FAIL_ACTION=

  FAKE_FAIL_ACTION=target_validation
  set +e
  unreachable_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  unreachable_status=$?
  set -e
  [ "$unreachable_status" -ne 0 ] || fail_test 'unreachable projected engine unexpectedly allowed uninstall'
  assert_contains "$unreachable_output" 'expected machine shimmy-default is unreachable'
  FAKE_FAIL_ACTION=

  mkdir "$XDG_CONFIG_HOME_DIR/shimmy/.profile-activation.lock"
  set +e
  lock_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  lock_status=$?
  set -e
  [ "$lock_status" -ne 0 ] || fail_test 'held activation lock unexpectedly allowed uninstall'
  assert_contains "$lock_output" 'another Shimmy profile activation holds'
  rmdir "$XDG_CONFIG_HOME_DIR/shimmy/.profile-activation.lock"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  pass 'Darwin uninstall refuses foreign projections, overrides, unavailable workload inspection, and held activation locks before deletion'
}

test_commands_lifecycle_darwin_uninstall_rollback() {
  for failure_action in projection_detach machine_stop; do
    setup_scenario_with_profiles default
    lifecycle_darwin_fake_prepare
    profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
    FAKE_MACHINE_LIST='shimmy-default|true'
    FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
    FAKE_DARWIN_APPLY_RESULT=changed
    FAKE_FAIL_ACTION=$failure_action
    set +e
    failure_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
    failure_status=$?
    set -e
    [ "$failure_status" -ne 0 ] || fail_test "injected Darwin uninstall failure unexpectedly succeeded: $failure_action"
    assert_contains "$failure_output" 'Rollback result:'
    assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
    assert_file_exists "$DEFAULT_PROFILE_ROOT/machine-projection.txt"
  done

  setup_scenario_with_profiles default
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-default|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_DARWIN_APPLY_RESULT=changed
  FAKE_FAIL_ACTION=machine_start
  set +e
  start_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  start_status=$?
  set -e
  [ "$start_status" -ne 0 ] || fail_test 'injected cleanup start failure unexpectedly succeeded'
  assert_contains "$start_output" 'Rollback result: prior projections and engine selection restored'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/machine-projection.txt"

  setup_scenario_with_profiles default upstream
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-default|false
shimmy-upstream|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_DARWIN_APPLY_RESULT=changed
  FAKE_FAIL_ACTION=machine_start
  FAKE_FAIL_MACHINE=shimmy-upstream
  set +e
  machine_restore_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  machine_restore_status=$?
  set -e
  [ "$machine_restore_status" -ne 0 ] || fail_test 'injected initial-machine restoration failure unexpectedly succeeded'
  assert_contains "$machine_restore_output" 'Rollback result: incomplete'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/machine-projection.txt"

  setup_scenario_with_profiles default
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-default|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_DARWIN_APPLY_RESULT=changed
  FAKE_FAIL_ACTION=default_restore
  FAKE_FAIL_ONCE_FILE=$SCENARIO_DIR/default-failed-once
  set +e
  restore_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  restore_status=$?
  set -e
  [ "$restore_status" -ne 0 ] || fail_test 'injected default restoration failure unexpectedly succeeded'
  assert_contains "$restore_output" 'Rollback result: prior projections and engine selection restored'
  assert_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-default /bin/sh -s -- apply'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/machine-projection.txt"

  setup_scenario_with_profiles default
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  FAKE_MACHINE_LIST='shimmy-default|true'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  FAKE_DARWIN_APPLY_RESULT=changed
  FAKE_FAIL_ACTION=default_restore
  set +e
  incomplete_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" 2>&1)
  incomplete_status=$?
  set -e
  [ "$incomplete_status" -ne 0 ] || fail_test 'persistent default restoration failure unexpectedly succeeded'
  assert_contains "$incomplete_output" 'Rollback result: incomplete'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/machine-projection.txt"
  pass 'Darwin uninstall failure injection retains profiles and reports complete or incomplete rollback across detach, start, restart, and default restoration'
}

test_commands_lifecycle_darwin_uninstall_finalize_commit_boundary() {
  for finalize_action in fail INT TERM; do
    setup_scenario_with_profiles default upstream
    lifecycle_darwin_fake_prepare
    lifecycle_darwin_uninstall_finalize_injection_install
    profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
    profile_projection_record_write "$UPSTREAM_PROFILE_ROOT" upstream
    FAKE_MACHINE_LIST='shimmy-default|true
shimmy-upstream|false'
    FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'
    SHIMMY_TEST_UNINSTALL_FINALIZE_ACTION=$finalize_action

    set +e
    finalize_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" --global 2>&1)
    finalize_status=$?
    set -e
    case "$finalize_action" in
      fail)
        [ "$finalize_status" -ne 0 ] || fail_test 'injected projection-backup finalize failure unexpectedly succeeded'
        assert_contains "$finalize_output" 'projection cleanup committed, but unable to finalize rollback backup for profile upstream'
        ;;
      INT) assert_equals "$finalize_status" 130 ;;
      TERM) assert_equals "$finalize_status" 143 ;;
    esac
    assert_not_contains "$finalize_output" 'Rollback:'
    assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-default /bin/sh -s -- apply'
    assert_not_contains "$(cat "$FAKE_PODMAN_LOG")" 'machine ssh --username root shimmy-upstream /bin/sh -s -- apply'
    assert_path_not_exists "$DEFAULT_PROFILE_ROOT/machine-projection.txt"
    assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/machine-projection.txt"
    for projection_profile_root in "$DEFAULT_PROFILE_ROOT" "$UPSTREAM_PROFILE_ROOT"; do
      for projection_backup in "$projection_profile_root"/.machine-projection.detach.*; do
        [ ! -e "$projection_backup" ] && [ ! -L "$projection_backup" ] ||
          fail_test "projection rollback backup remained after $finalize_action finalization interruption: $projection_backup"
      done
    done

    SHIMMY_TEST_UNINSTALL_FINALIZE_ACTION=
    lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" --global >/dev/null
    assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
    assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
    assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs"
  done
  pass 'projection-backup finalize failure and INT/TERM after commit never invoke rollback and remain retryable'
}

test_commands_lifecycle_linux_registry_activation_cleanup() {
  setup_scenario_with_profiles default upstream
  FAKE_PODMAN_BIN=$SCENARIO_DIR/podman
  FAKE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  profile_activation_fake_create "$FAKE_PODMAN_BIN"
  active_link=$XDG_CONFIG_HOME_DIR/containers/registries.conf.d/shimmy-active-profile.conf
  operator_file=$XDG_CONFIG_HOME_DIR/containers/registries.conf
  mkdir -p "$XDG_CONFIG_HOME_DIR/containers"
  printf '%s\n' operator-policy > "$operator_file"
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_TEST_PROFILE_OS=Linux \
    SHIMMY_TEST_PROFILE_PODMAN_BIN="$FAKE_PODMAN_BIN" FAKE_PODMAN_LOG="$FAKE_PODMAN_LOG" FAKE_LINUX_INFO='true|false' \
    FAKE_ACTIVE_LINK="$active_link" FAKE_ACTIVE_CONFIG="$DEFAULT_PROFILE_ROOT/registries.conf" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" profile activate >/dev/null
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_TEST_PROFILE_OS=Linux \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$active_link"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/registries.conf"
  assert_file_contains "$operator_file" operator-policy

  setup_scenario_with_profiles default
  active_link=$XDG_CONFIG_HOME_DIR/containers/registries.conf.d/shimmy-active-profile.conf
  mkdir -p "$(dirname "$active_link")"
  printf '%s\n' foreign > "$active_link"
  set +e
  foreign_output=$(env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" SHIMMY_TEST_PROFILE_OS=Linux \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" uninstall 2>&1)
  foreign_status=$?
  set -e
  [ "$foreign_status" -ne 0 ] || fail_test 'profile uninstall unexpectedly removed foreign Linux registry state'
  assert_contains "$foreign_output" 'invalid or foreign registry activation state'
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_contains "$active_link" foreign
  pass 'Linux profile uninstall removes only its exact active link and refuses foreign state'
}

test_commands_lifecycle_global_uninstall() {
  setup_scenario_with_profiles default upstream
  replacement_checkout=$SCENARIO_DIR/global-uninstall-checkout
  test_fixture_tree_copy "$SHIMMY_TEST_CLEAN_SOURCE_ROOT" "$replacement_checkout"
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
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_dir_exists "$relocated_checkout"
  assert_file_exists "$exported_skill_file"
  assert_file_exists "$exported_manifest"
  assert_file_contains "$XDG_CONFIG_HOME_DIR/containers/registries.conf" operator-policy
  pass "explicit global uninstall removes only owned state while preserving checkouts, and external skills directory"
}

test_commands_lifecycle_global_uninstall_darwin_transaction() {
  setup_scenario_with_profiles default upstream
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  profile_projection_record_write "$UPSTREAM_PROFILE_ROOT" upstream
  FAKE_MACHINE_LIST='shimmy-default|true
shimmy-upstream|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'
  global_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" --global)
  assert_contains "$global_output" 'Detached Darwin registry projection for profile default'
  assert_contains "$global_output" 'Detached Darwin registry projection for profile upstream'
  default_detach_line=$(sed -n '/^machine ssh --username root shimmy-default \/bin\/sh -s -- detach /=' "$FAKE_PODMAN_LOG")
  upstream_detach_line=$(sed -n '/^machine ssh --username root shimmy-upstream \/bin\/sh -s -- detach /=' "$FAKE_PODMAN_LOG")
  [ "$default_detach_line" -lt "$upstream_detach_line" ] ||
    fail_test 'global uninstall did not detach profiles in deterministic order'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs"

  setup_scenario_with_profiles default upstream
  lifecycle_darwin_fake_prepare
  profile_projection_record_write "$DEFAULT_PROFILE_ROOT" default
  profile_projection_record_write "$UPSTREAM_PROFILE_ROOT" upstream
  default_record_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/machine-projection.txt")
  upstream_record_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/machine-projection.txt")
  FAKE_MACHINE_LIST='shimmy-default|true
shimmy-upstream|false'
  FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true
shimmy-upstream|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false'
  FAKE_FAIL_ACTION=projection_detach
  FAKE_FAIL_MACHINE=shimmy-upstream
  FAKE_DARWIN_APPLY_RESULT=changed
  set +e
  rollback_output=$(lifecycle_darwin_uninstall "$DEFAULT_PROFILE_ROOT/bin/shimmy" --global 2>&1)
  rollback_status=$?
  set -e
  [ "$rollback_status" -ne 0 ] || fail_test 'later global projection detach failure unexpectedly removed owned state'
  assert_contains "$rollback_output" 'Rollback: registry projection restored for default'
  assert_contains "$rollback_output" 'Rollback result: prior projections and engine selection restored'
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/machine-projection.txt")" "$default_record_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/machine-projection.txt")" "$upstream_record_checksum"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_dir_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default"
  assert_dir_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream"
  pass 'global Darwin uninstall detaches every profile before deletion and reprojects earlier profiles after a later failure'
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
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./bootstrap.sh --profile upstream
  ) >/dev/null

  printf '%s\n' '# chunk-2 command marker' >> "$control_checkout/commands/status.sh"
  printf '%s\n' '# chunk-2 library marker' >> "$control_checkout/lib/common/common.sh"
  assert_file_not_contains "$UPSTREAM_PROFILE_ROOT/commands/status.sh" 'chunk-2 command marker'
  assert_file_not_contains "$UPSTREAM_PROFILE_ROOT/lib/common/common.sh" 'chunk-2 library marker'
  upstream_shimmy status --format manifest >/dev/null

  (
    cd "$control_checkout"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./bootstrap.sh --profile upstream
  ) >/dev/null
  assert_file_contains "$UPSTREAM_PROFILE_ROOT/commands/status.sh" 'chunk-2 command marker'
  assert_file_contains "$UPSTREAM_PROFILE_ROOT/lib/common/common.sh" 'chunk-2 library marker'
  pass "upstream control-plane edits remain inactive until explicit profile refresh"
}

test_commands_lifecycle_complete() {
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  default_shimmy install --shim task >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/task/tool.conf"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/task/versions/3.45/run.sh"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/tools/task/SKILL.md"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/bin/task"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/tools/task"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$lifecycle_upstream_manifest_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/tools/jq/versions/1.8/run.sh")" "$lifecycle_upstream_runtime_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/bin/shimmy")" "$lifecycle_upstream_launcher_checksum"
  assert_equals "$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf")" "$lifecycle_default_catalog_registry_checksum"
  assert_equals "$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf")" "$lifecycle_upstream_catalog_registry_checksum"
  pass "tool installation changes only the invoking profile materialization and manifest"

  mkdir -p "$DEFAULT_PROFILE_ROOT/agent"
  printf '%s\n' legacy > "$DEFAULT_PROFILE_ROOT/agent/sentinel"

  default_shimmy uninstall >/dev/null
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/bin/shimmy"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/registries.conf"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT/agent"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/bin/shimmy"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$lifecycle_upstream_manifest_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/tools/jq/versions/1.8/run.sh")" "$lifecycle_upstream_runtime_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/bin/shimmy")" "$lifecycle_upstream_launcher_checksum"
  assert_dir_exists "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  pass "additive install and profile uninstall preserve unmanaged and sibling state"

  rm "$DEFAULT_PROFILE_ROOT/unmanaged-sentinel"
  rmdir "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  upstream_shimmy uninstall >/dev/null
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/profiles"
  assert_equals "$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf")" "$lifecycle_default_catalog_registry_checksum"
  assert_equals "$(cksum < "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf")" "$lifecycle_upstream_catalog_registry_checksum"
  pass "profile removal preserves sibling profiles and independently owned shared catalogs"

  test_commands_lifecycle_install_shapes
  test_commands_lifecycle_launcher_refresh
  test_commands_lifecycle_registry_upgrade_and_preservation
  test_commands_lifecycle_catalog_independent_execution
  test_commands_lifecycle_control_plane_refresh
  test_commands_lifecycle_legacy_agent_refresh
  test_commands_lifecycle_legacy_agent_rollback
  test_commands_lifecycle_linux_registry_activation_cleanup
  test_commands_lifecycle_darwin_projection_uninstall
  test_commands_lifecycle_darwin_stopped_guard_and_missing
  test_commands_lifecycle_darwin_uninstall_refusals
  test_commands_lifecycle_darwin_uninstall_rollback
  test_commands_lifecycle_darwin_uninstall_finalize_commit_boundary
  test_commands_lifecycle_global_uninstall
  test_commands_lifecycle_global_uninstall_darwin_transaction
}
