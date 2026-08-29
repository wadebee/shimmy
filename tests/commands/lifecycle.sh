#!/bin/sh

test_lifecycle_command() {
  test_lifecycle_profile=$1
  shift
  env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    SHIMMY_TEST_IMAGES_CALL_LOG="$TEST_LIFECYCLE_VERIFY_LOG" \
    SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures" \
    SHIMMY_TEST_IMAGES_RESPONSE_FILE="$TEST_LIFECYCLE_VERIFY_RESPONSES" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TEST_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    "$TEST_LIFECYCLE_CONFIG/profiles/$test_lifecycle_profile/bin/shimmy" "$@"
}

test_lifecycle_control_source_names_render() {
  test_lifecycle_control_source_checkout=$1
  test_lifecycle_control_source_ref=$2
  test_lifecycle_control_source_names=$(LC_ALL=C git \
    -C "$test_lifecycle_control_source_checkout" ls-tree --name-only \
    "$test_lifecycle_control_source_ref:plugins/shimmy/skills") || return 1
  printf '%s\n' "$test_lifecycle_control_source_names" | LC_ALL=C sort
}

test_lifecycle_control_bundle_names_render() {
  test_lifecycle_control_bundle=$1
  sed -n '5,$s/^skill=\([^|]*\)|.*$/\1/p' "$test_lifecycle_control_bundle"
}

test_lifecycle_migration_command() {
  env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_MACHINE_LIST='shimmy-default|applehv|false' \
    FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true' \
    FAKE_CREATED_MACHINE_STATE_FILE="$TEST_LIFECYCLE_CREATED_STATE" \
    FAKE_CREATED_MACHINE_NAME=shimmy FAKE_SERVICE_PID_FILE="$TEST_LIFECYCLE_SERVICE_PID" \
    FAKE_ENGINE_CONFIG_DIR="$SCENARIO_DIR/engine-config" \
    FAKE_ENGINE_SOCKET_PATH="$SCENARIO_DIR/engine-socket" \
    FAKE_ENGINE_IDENTITY_PATH="$SCENARIO_DIR/engine-identity" \
    FAKE_ENGINE_PROJECTION_CONFIG="$TEST_LIFECYCLE_CONFIG/engines/shared/registries.conf" \
    FAKE_WORKLOADS= FAKE_DARWIN_PROJECTION_STATE=absent \
    FAKE_PRIOR_MACHINE=shimmy-default FAKE_TARGET_MACHINE=shimmy \
    FAKE_PRIOR_DEFAULT=shimmy-default FAKE_FAIL_ACTION="${TEST_LIFECYCLE_FAIL_ACTION:-}" \
    FAKE_ROLLBACK_FAIL="${TEST_LIFECYCLE_ROLLBACK_FAIL:-}" \
    "$TEST_LIFECYCLE_CONFIG/profiles/default/bin/shimmy" admin engine "$@"
}

test_lifecycle_shared_profile_command() {
  env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" FAKE_MACHINE_LIST= \
    FAKE_CONNECTION_LIST='other|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false' \
    FAKE_CREATED_MACHINE_STATE_FILE="$TEST_LIFECYCLE_CREATED_STATE" \
    FAKE_CREATED_MACHINE_NAME=shimmy-default FAKE_SERVICE_PID_FILE="$TEST_LIFECYCLE_SERVICE_PID" \
    FAKE_ENGINE_CONFIG_DIR="$SCENARIO_DIR/engine-config" \
    FAKE_ENGINE_SOCKET_PATH="$SCENARIO_DIR/engine-socket" \
    FAKE_ENGINE_IDENTITY_PATH="$SCENARIO_DIR/engine-identity" \
    FAKE_ENGINE_PROJECTION_CONFIG="$TEST_LIFECYCLE_CONFIG/engines/shared/registries.conf" \
    FAKE_WORKLOADS='sentinel|bootstrap-sentinel' FAKE_DARWIN_PROJECTION_STATE=current \
    SHIMMY_TEST_PROFILE_FAILURE="${TEST_LIFECYCLE_PROFILE_FAILURE:-}" \
    "$TEST_LIFECYCLE_CONFIG/profiles/default/bin/shimmy" "$@"
}

test_lifecycle_isolated_profile_command() {
  test_lifecycle_isolated_invoking=$1
  shift
  test_lifecycle_isolated_created_name=${TEST_LIFECYCLE_ISOLATED_CREATED_NAME:-shimmy-isolated-one}
  test_lifecycle_isolated_engine_id=${TEST_LIFECYCLE_ISOLATED_ENGINE_ID:-profile-isolated-one}
  test_lifecycle_isolated_target=${TEST_LIFECYCLE_TARGET_MACHINE:-$test_lifecycle_isolated_created_name}
  env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_MACHINE_LIST="$TEST_LIFECYCLE_BASE_MACHINE_LIST" \
    FAKE_CONNECTION_LIST="$TEST_LIFECYCLE_BASE_CONNECTION_LIST" \
    FAKE_CREATED_MACHINE_STATE_FILE="$TEST_LIFECYCLE_ISOLATED_STATE" \
    FAKE_CREATED_MACHINE_NAME="$test_lifecycle_isolated_created_name" \
    FAKE_SERVICE_PID_FILE="$TEST_LIFECYCLE_SERVICE_PID" \
    FAKE_ENGINE_CONFIG_DIR="$SCENARIO_DIR/isolated-engine-config" \
    FAKE_ENGINE_SOCKET_PATH="$SCENARIO_DIR/isolated-engine-socket" \
    FAKE_ENGINE_IDENTITY_PATH="$SCENARIO_DIR/isolated-engine-identity" \
    FAKE_ENGINE_PROJECTION_CONFIG="$TEST_LIFECYCLE_CONFIG/engines/$test_lifecycle_isolated_engine_id/registries.conf" \
    FAKE_WORKLOADS="${TEST_LIFECYCLE_ISOLATED_WORKLOADS:-}" \
    FAKE_DARWIN_PROJECTION_STATE=current \
    FAKE_PRIOR_MACHINE="${TEST_LIFECYCLE_PRIOR_MACHINE:-shimmy}" \
    FAKE_TARGET_MACHINE="$test_lifecycle_isolated_target" \
    FAKE_PRIOR_DEFAULT="${TEST_LIFECYCLE_PRIOR_DEFAULT:-shimmy}" \
    SHIMMY_TEST_PROFILE_DELETE_FAILURE="${TEST_LIFECYCLE_DELETE_FAILURE:-}" \
    "$TEST_LIFECYCLE_CONFIG/profiles/$test_lifecycle_isolated_invoking/bin/shimmy" "$@"
}

test_lifecycle_global_uninstall_command() {
  env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" FAKE_MACHINE_LIST= \
    FAKE_CONNECTION_LIST= FAKE_MACHINE_STATE_DIR="$TEST_LIFECYCLE_MACHINE_STATE_DIR" \
    FAKE_MACHINE_METADATA_DIR="$TEST_LIFECYCLE_MACHINE_METADATA_DIR" \
    FAKE_WORKLOADS="${TEST_LIFECYCLE_GLOBAL_WORKLOADS:-}" \
    FAKE_DARWIN_PROJECTION_STATE=current \
    SHIMMY_TEST_UNINSTALL_FAILURE="${TEST_LIFECYCLE_UNINSTALL_FAILURE:-}" \
    "$TEST_LIFECYCLE_CONFIG/profiles/default/bin/shimmy" admin uninstall "$@"
}

test_lifecycle_checkout_template_required() {
  for test_lifecycle_group in \
    commands-lifecycle-bootstrap \
    commands-lifecycle-isolated \
    commands-lifecycle-migration \
    commands-lifecycle-uninstall \
    commands-lifecycle-end-to-end
  do
    test_runner_group_selected "$test_lifecycle_group" && return 0
  done
  return 1
}

test_lifecycle_checkout_template_prepare() {
  [ -n "${TEST_LIFECYCLE_CHECKOUT_TEMPLATE:-}" ] ||
    fail_test 'lifecycle checkout template path is unset'
  test_catalog_checkout_create "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE"
  git -C "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" clean -fdXq
  test_shim_fake_versions_write "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE"
  images_fixture_fake_runtimes_write "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE"
  git -C "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" add tools/jq/versions \
    tools/oc/versions tools/rg/versions tools/skopeo/versions
  git -C "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" commit -qm lifecycle-fakes
  [ -z "$(git -C "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" status --porcelain)" ] ||
    fail_test 'prepared lifecycle checkout template is dirty'
  [ -z "$(git -C "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" \
    ls-files --others --ignored --exclude-standard)" ] ||
    fail_test 'prepared lifecycle checkout template retains ignored content'
}

test_lifecycle_checkout_template_validate() {
  [ -n "${TEST_LIFECYCLE_CHECKOUT_TEMPLATE:-}" ] || return 0
  [ -n "${TEST_LIFECYCLE_CHECKOUT_TEMPLATE_HEAD:-}" ] || {
    printf '%s\n' 'FAIL: lifecycle checkout template HEAD is unset' >&2
    return 1
  }
  [ -d "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" ] &&
    [ ! -L "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" ] || {
      printf '%s\n' 'FAIL: lifecycle checkout template is missing or unsafe' >&2
      return 1
    }
  test_lifecycle_template_head=$(git -C "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" \
    rev-parse HEAD 2>/dev/null) || {
      printf '%s\n' 'FAIL: lifecycle checkout template HEAD is unreadable' >&2
      return 1
    }
  [ "$test_lifecycle_template_head" = "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE_HEAD" ] || {
    printf '%s\n' 'FAIL: lifecycle checkout template HEAD changed' >&2
    return 1
  }
  [ -z "$(git -C "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" status --porcelain)" ] || {
    printf '%s\n' 'FAIL: lifecycle checkout template worktree changed' >&2
    return 1
  }
  [ -z "$(git -C "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" \
    ls-files --others --ignored --exclude-standard)" ] || {
      printf '%s\n' 'FAIL: lifecycle checkout template gained ignored content' >&2
      return 1
    }
}

test_lifecycle_fixture_setup() {
  setup_scenario
  TEST_LIFECYCLE_CHECKOUT=$SCENARIO_DIR/checkout
  TEST_LIFECYCLE_HOME=$SCENARIO_DIR/home
  TEST_LIFECYCLE_CONFIG_HOME=$SCENARIO_DIR/config
  TEST_LIFECYCLE_CONFIG=$TEST_LIFECYCLE_CONFIG_HOME/shimmy
  TEST_LIFECYCLE_ACTIVE_LINK=$TEST_LIFECYCLE_CONFIG_HOME/containers/registries.conf.d/shimmy-active-profile.conf
  TEST_LIFECYCLE_PODMAN=$SCENARIO_DIR/podman
  TEST_LIFECYCLE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  TEST_LIFECYCLE_IMAGE_LOG=$SCENARIO_DIR/image.log
  TEST_LIFECYCLE_SMOKE_LOG=$SCENARIO_DIR/smoke.log
  TEST_LIFECYCLE_VERIFY_LOG=$SCENARIO_DIR/verify.log
  TEST_LIFECYCLE_VERIFY_RESPONSES=$SCENARIO_DIR/verify-responses
  [ -d "${TEST_LIFECYCLE_CHECKOUT_TEMPLATE:-}" ] &&
    [ ! -L "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" ] ||
    fail_test 'lifecycle checkout template is unavailable'
  test_fixture_tree_copy "$TEST_LIFECYCLE_CHECKOUT_TEMPLATE" \
    "$TEST_LIFECYCLE_CHECKOUT"
  profile_activation_fake_create "$TEST_LIFECYCLE_PODMAN"
  : > "$TEST_LIFECYCLE_PODMAN_LOG"
  : > "$TEST_LIFECYCLE_IMAGE_LOG"
  : > "$TEST_LIFECYCLE_SMOKE_LOG"
  : > "$TEST_LIFECYCLE_VERIFY_LOG"
  : > "$TEST_LIFECYCLE_VERIFY_RESPONSES"
}

test_lifecycle_darwin_bootstrap_command() {
  env HOME="$TEST_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_ACTIVE_PROFILE_PATH="$TEST_LIFECYCLE_CONFIG/active-profile.conf" \
    SHIMMY_TEST_REQUIRED_ACTIVE_PROFILE=default \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    SHIMMY_TEST_IMAGE_FAILURE="${TEST_LIFECYCLE_IMAGE_FAILURE:-}" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_MACHINE_LIST= \
    FAKE_CONNECTION_LIST='other|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true' \
    FAKE_CREATED_MACHINE_STATE_FILE="$TEST_LIFECYCLE_CREATED_STATE" \
    FAKE_CREATED_MACHINE_NAME=shimmy-default FAKE_SERVICE_PID_FILE="$TEST_LIFECYCLE_SERVICE_PID" \
    FAKE_ENGINE_CONFIG_DIR="$SCENARIO_DIR/engine-config" \
    FAKE_ENGINE_SOCKET_PATH="$SCENARIO_DIR/engine-socket" \
    FAKE_ENGINE_IDENTITY_PATH="$SCENARIO_DIR/engine-identity" \
    FAKE_ENGINE_PROJECTION_CONFIG="$TEST_LIFECYCLE_CONFIG/engines/shared/registries.conf" \
    FAKE_WORKLOADS= FAKE_DARWIN_PROJECTION_STATE=absent \
    FAKE_PRIOR_MACHINE= FAKE_TARGET_MACHINE=shimmy-default FAKE_PRIOR_DEFAULT=other \
    FAKE_FAIL_ACTION="${TEST_LIFECYCLE_FAIL_ACTION:-}" \
    FAKE_ROLLBACK_FAIL="${TEST_LIFECYCLE_ROLLBACK_FAIL:-}" \
    "$TEST_LIFECYCLE_CHECKOUT/commands/bootstrap.sh" --no-startup
}

test_commands_lifecycle_darwin_bootstrap_case() {
  test_lifecycle_case=$1
  test_lifecycle_fixture_setup
  test_lifecycle_created_state=$SCENARIO_DIR/created-machine-state
  test_lifecycle_service_pid=$SCENARIO_DIR/service-pid
  TEST_LIFECYCLE_CREATED_STATE=$test_lifecycle_created_state
  TEST_LIFECYCLE_SERVICE_PID=$test_lifecycle_service_pid
  printf '%s\n' absent > "$test_lifecycle_created_state"
  printf '%s\n' 800 > "$test_lifecycle_service_pid"
  test_lifecycle_bootstrap_output=$(test_lifecycle_darwin_bootstrap_command)

  assert_contains "$test_lifecycle_bootstrap_output" 'Bootstrapped active Shimmy profile default'
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf"
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/projection.conf"
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/profiles/default/engine-binding.conf"
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/profiles/default/engine-binding.conf" 'mode=shared'
  test_lifecycle_init_line=$(sed -n '/^machine init shimmy-default$/=' "$TEST_LIFECYCLE_PODMAN_LOG")
  test_lifecycle_start_line=$(sed -n '/^machine start shimmy-default$/=' "$TEST_LIFECYCLE_PODMAN_LOG")
  test_lifecycle_projection_line=$(sed -n \
    '/^machine ssh shimmy-default systemctl --user stop podman.service$/=' \
    "$TEST_LIFECYCLE_PODMAN_LOG" | head -n 1)
  test_lifecycle_validation_line=$(sed -n \
    '/^--connection shimmy-default info /=' "$TEST_LIFECYCLE_PODMAN_LOG" | tail -n 1)
  test_lifecycle_image_line=$(sed -n '/^image|jq|1.8|pull$/=' \
    "$TEST_LIFECYCLE_PODMAN_LOG")
  [ "$test_lifecycle_init_line" -lt "$test_lifecycle_start_line" ] &&
    [ "$test_lifecycle_start_line" -lt "$test_lifecycle_projection_line" ] &&
    [ "$test_lifecycle_projection_line" -lt "$test_lifecycle_validation_line" ] ||
    fail_test 'Darwin bootstrap did not initialize, start, project, and validate in order'
  [ "$test_lifecycle_validation_line" -lt "$test_lifecycle_image_line" ] ||
    fail_test 'Darwin bootstrap prepared images before engine activation'

  : > "$TEST_LIFECYCLE_PODMAN_LOG"
  test_lifecycle_shared_dry=$(test_lifecycle_shared_profile_command profile redirect set \
    --prefix docker.io --location registry.example.invalid/docker --dry-run)
  assert_contains "$test_lifecycle_shared_dry" 'would_recycle_podman_service=yes'
  test_lifecycle_shared_profile_command profile redirect set \
    --prefix docker.io --location registry.example.invalid/docker >/dev/null
  assert_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" \
    'machine ssh shimmy-default systemctl --user stop podman.service'
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine stop '
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine start '
  test_lifecycle_shared_source_before=$(cksum < \
    "$TEST_LIFECYCLE_CONFIG/profiles/default/registries.conf")
  test_lifecycle_shared_projection_before=$(cksum < \
    "$TEST_LIFECYCLE_CONFIG/engines/shared/registries.conf")
  test_lifecycle_shared_active_before=$(cksum < "$TEST_LIFECYCLE_CONFIG/active-profile.conf")
  TEST_LIFECYCLE_PROFILE_FAILURE=after-engine-projection
  set +e
  test_lifecycle_shared_failure=$(test_lifecycle_shared_profile_command profile redirect set \
    --prefix docker.io --location registry.fail.invalid/docker 2>&1)
  test_lifecycle_shared_failure_status=$?
  set -e
  TEST_LIFECYCLE_PROFILE_FAILURE=
  [ "$test_lifecycle_shared_failure_status" -ne 0 ] ||
    fail_test 'injected active shared redirect failure unexpectedly succeeded'
  assert_contains "$test_lifecycle_shared_failure" 'source and engine projection restored'
  assert_equals "$(cksum < "$TEST_LIFECYCLE_CONFIG/profiles/default/registries.conf")" \
    "$test_lifecycle_shared_source_before"
  assert_equals "$(cksum < "$TEST_LIFECYCLE_CONFIG/engines/shared/registries.conf")" \
    "$test_lifecycle_shared_projection_before"
  assert_equals "$(cksum < "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" \
    "$test_lifecycle_shared_active_before"
}

test_commands_lifecycle_darwin_bootstrap_engine_states() {
  test_commands_lifecycle_darwin_bootstrap_case fresh

  test_lifecycle_fixture_setup
  TEST_LIFECYCLE_CREATED_STATE=$SCENARIO_DIR/created-machine-state
  TEST_LIFECYCLE_SERVICE_PID=$SCENARIO_DIR/service-pid
  printf '%s\n' absent > "$TEST_LIFECYCLE_CREATED_STATE"
  printf '%s\n' 800 > "$TEST_LIFECYCLE_SERVICE_PID"
  TEST_LIFECYCLE_IMAGE_FAILURE=skopeo@1.22
  set +e
  test_lifecycle_image_failure=$(test_lifecycle_darwin_bootstrap_command 2>&1)
  test_lifecycle_image_failure_status=$?
  set -e
  TEST_LIFECYCLE_IMAGE_FAILURE=
  [ "$test_lifecycle_image_failure_status" -ne 0 ] ||
    fail_test 'injected bootstrap image-preparation failure unexpectedly succeeded'
  test_lifecycle_image_reference=$(sed -n 's/^image_default_ref=//p' \
    "$TEST_LIFECYCLE_CHECKOUT/tools/skopeo/versions/1.22/image.conf")
  assert_contains "$test_lifecycle_image_failure" \
    "image-preparation-failed: tool=skopeo version=1.22 action=pull reference=$test_lifecycle_image_reference"
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG"

  test_lifecycle_fixture_setup
  TEST_LIFECYCLE_CREATED_STATE=$SCENARIO_DIR/created-machine-state
  TEST_LIFECYCLE_SERVICE_PID=$SCENARIO_DIR/service-pid
  printf '%s\n' absent > "$TEST_LIFECYCLE_CREATED_STATE"
  printf '%s\n' 800 > "$TEST_LIFECYCLE_SERVICE_PID"
  TEST_LIFECYCLE_FAIL_ACTION=machine_start
  set +e
  test_lifecycle_start_failure=$(test_lifecycle_darwin_bootstrap_command 2>&1)
  test_lifecycle_start_failure_status=$?
  set -e
  TEST_LIFECYCLE_FAIL_ACTION=
  [ "$test_lifecycle_start_failure_status" -ne 0 ] ||
    fail_test 'injected shared machine-start bootstrap failure unexpectedly succeeded'
  assert_equals "$(cat "$TEST_LIFECYCLE_CREATED_STATE")" absent
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG"
  assert_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine rm --force shimmy-default'

  TEST_LIFECYCLE_CREATED_STATE=$SCENARIO_DIR/created-machine-state
  TEST_LIFECYCLE_SERVICE_PID=$SCENARIO_DIR/service-pid
  printf '%s\n' absent > "$TEST_LIFECYCLE_CREATED_STATE"
  printf '%s\n' 800 > "$TEST_LIFECYCLE_SERVICE_PID"
  : > "$TEST_LIFECYCLE_PODMAN_LOG"
  TEST_LIFECYCLE_FAIL_ACTION=machine_init_after_create
  set +e
  test_lifecycle_init_failure=$(test_lifecycle_darwin_bootstrap_command 2>&1)
  test_lifecycle_init_failure_status=$?
  set -e
  TEST_LIFECYCLE_FAIL_ACTION=
  [ "$test_lifecycle_init_failure_status" -ne 0 ] ||
    fail_test 'injected post-create machine-init bootstrap failure unexpectedly succeeded'
  assert_equals "$(cat "$TEST_LIFECYCLE_CREATED_STATE")" stopped
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/lifecycle.conf"
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/engines/shared/lifecycle.conf" 'phase=initializing'
  assert_contains "$test_lifecycle_init_failure" 'Rollback result: incomplete'
  assert_contains "$test_lifecycle_init_failure" \
    "$TEST_LIFECYCLE_CONFIG/engines/shared/lifecycle.conf"
  assert_not_contains "$test_lifecycle_init_failure" 'ownership_token='

  TEST_LIFECYCLE_CONFIG_HOME=$SCENARIO_DIR/remove-failure-config
  TEST_LIFECYCLE_CONFIG=$TEST_LIFECYCLE_CONFIG_HOME/shimmy
  TEST_LIFECYCLE_ACTIVE_LINK=$TEST_LIFECYCLE_CONFIG_HOME/containers/registries.conf.d/shimmy-active-profile.conf
  TEST_LIFECYCLE_CREATED_STATE=$SCENARIO_DIR/remove-failure-machine-state
  TEST_LIFECYCLE_SERVICE_PID=$SCENARIO_DIR/remove-failure-service-pid
  printf '%s\n' absent > "$TEST_LIFECYCLE_CREATED_STATE"
  printf '%s\n' 800 > "$TEST_LIFECYCLE_SERVICE_PID"
  : > "$TEST_LIFECYCLE_PODMAN_LOG"
  TEST_LIFECYCLE_FAIL_ACTION=machine_start
  TEST_LIFECYCLE_ROLLBACK_FAIL=machine_rm
  set +e
  test_lifecycle_remove_failure=$(test_lifecycle_darwin_bootstrap_command 2>&1)
  test_lifecycle_remove_failure_status=$?
  set -e
  TEST_LIFECYCLE_FAIL_ACTION=
  TEST_LIFECYCLE_ROLLBACK_FAIL=
  [ "$test_lifecycle_remove_failure_status" -ne 0 ] ||
    fail_test 'injected shared machine rollback removal failure unexpectedly succeeded'
  assert_equals "$(cat "$TEST_LIFECYCLE_CREATED_STATE")" stopped
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/lifecycle.conf"
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/engines/shared/lifecycle.conf" 'phase=starting'
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf"
  assert_contains "$test_lifecycle_remove_failure" 'Rollback result: incomplete'

  TEST_LIFECYCLE_CONFIG_HOME=$SCENARIO_DIR/collision-config
  TEST_LIFECYCLE_CONFIG=$TEST_LIFECYCLE_CONFIG_HOME/shimmy
  TEST_LIFECYCLE_ACTIVE_LINK=$TEST_LIFECYCLE_CONFIG_HOME/containers/registries.conf.d/shimmy-active-profile.conf
  : > "$TEST_LIFECYCLE_PODMAN_LOG"
  set +e
  test_lifecycle_collision_output=$(env HOME="$TEST_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_MACHINE_LIST='shimmy-default|applehv|false' FAKE_CONNECTION_LIST= \
    "$TEST_LIFECYCLE_CHECKOUT/commands/bootstrap.sh" --no-startup 2>&1)
  test_lifecycle_collision_status=$?
  set -e
  [ "$test_lifecycle_collision_status" -ne 0 ] ||
    fail_test 'Darwin bootstrap unexpectedly adopted a colliding shared machine'
  assert_contains "$test_lifecycle_collision_output" 'machine or connection name collision: shimmy-default'
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine init '
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG"
  pass 'Darwin bootstrap creates the owned shared engine and rejects an exact pre-existing machine without mutation'
}

test_commands_lifecycle_owned_isolated() {
  test_commands_lifecycle_darwin_bootstrap_case isolated
  TEST_LIFECYCLE_ISOLATED_STATE=$SCENARIO_DIR/isolated-machine-state
  printf '%s\n' absent > "$TEST_LIFECYCLE_ISOLATED_STATE"
  TEST_LIFECYCLE_BASE_MACHINE_LIST='shimmy-default|true'
  TEST_LIFECYCLE_BASE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  TEST_LIFECYCLE_ISOLATED_WORKLOADS=
  TEST_LIFECYCLE_PRIOR_MACHINE=shimmy-default
  TEST_LIFECYCLE_PRIOR_DEFAULT=shimmy-default
  TEST_LIFECYCLE_DELETE_FAILURE=
  : > "$TEST_LIFECYCLE_PODMAN_LOG"

  TEST_LIFECYCLE_ISOLATED_STATE=$SCENARIO_DIR/isolated-fail-machine-state
  printf '%s\n' absent > "$TEST_LIFECYCLE_ISOLATED_STATE"
  TEST_LIFECYCLE_ISOLATED_CREATED_NAME=shimmy-isolated-fail
  TEST_LIFECYCLE_ISOLATED_ENGINE_ID=profile-isolated-fail
  TEST_LIFECYCLE_TARGET_MACHINE=shimmy-isolated-fail
  TEST_LIFECYCLE_ISOLATED_WORKLOADS='sentinel|shared-sentinel'
  set +e
  test_lifecycle_isolated_failure=$(test_lifecycle_isolated_profile_command default \
    profile create isolated-fail --isolated 2>&1)
  test_lifecycle_isolated_failure_status=$?
  set -e
  [ "$test_lifecycle_isolated_failure_status" -ne 0 ] ||
    fail_test 'isolated create unexpectedly interrupted a running shared workload without acknowledgement'
  assert_contains "$test_lifecycle_isolated_failure" 'running containers block the engine transition'
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/profiles/isolated-fail"
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/engines/profile-isolated-fail"
  assert_equals "$(cat "$TEST_LIFECYCLE_ISOLATED_STATE")" absent
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' \
    "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" default

  TEST_LIFECYCLE_ISOLATED_STATE=$SCENARIO_DIR/isolated-machine-state
  printf '%s\n' absent > "$TEST_LIFECYCLE_ISOLATED_STATE"
  TEST_LIFECYCLE_ISOLATED_CREATED_NAME=shimmy-isolated-one
  TEST_LIFECYCLE_ISOLATED_ENGINE_ID=profile-isolated-one
  TEST_LIFECYCLE_TARGET_MACHINE=shimmy-isolated-one
  TEST_LIFECYCLE_ISOLATED_WORKLOADS=
  : > "$TEST_LIFECYCLE_PODMAN_LOG"

  test_lifecycle_isolated_dry=$(test_lifecycle_isolated_profile_command default \
    profile create isolated-one --isolated --dry-run)
  assert_contains "$test_lifecycle_isolated_dry" 'would_bind_engine=isolated|profile-isolated-one'
  assert_contains "$test_lifecycle_isolated_dry" 'would_create_machine=shimmy-isolated-one'
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine init '
  test_lifecycle_isolated_profile_command default profile create isolated-one \
    --isolated >/dev/null
  test_lifecycle_isolated_root=$TEST_LIFECYCLE_CONFIG/profiles/isolated-one
  test_lifecycle_isolated_engine=$TEST_LIFECYCLE_CONFIG/engines/profile-isolated-one
  assert_file_contains "$test_lifecycle_isolated_root/engine-binding.conf" 'mode=isolated'
  assert_file_contains "$test_lifecycle_isolated_engine/engine.conf" 'scope=profile'
  assert_file_contains "$test_lifecycle_isolated_engine/engine.conf" 'origin=shimmy-created'
  assert_path_not_exists "$test_lifecycle_isolated_engine/lifecycle.conf"
  assert_equals "$(cat "$TEST_LIFECYCLE_ISOLATED_STATE")" running
  test_lifecycle_isolated_init_line=$(sed -n \
    '/^machine init shimmy-isolated-one$/=' \
    "$TEST_LIFECYCLE_PODMAN_LOG")
  test_lifecycle_isolated_stop_line=$(sed -n '/^machine stop shimmy-default$/=' \
    "$TEST_LIFECYCLE_PODMAN_LOG")
  test_lifecycle_isolated_start_line=$(sed -n '/^machine start shimmy-isolated-one$/=' \
    "$TEST_LIFECYCLE_PODMAN_LOG")
  test_lifecycle_isolated_image_line=$(sed -n '/^image|jq|1.8|pull$/=' \
    "$TEST_LIFECYCLE_IMAGE_LOG" | tail -n 1)
  [ "$test_lifecycle_isolated_init_line" -lt "$test_lifecycle_isolated_stop_line" ] &&
    [ "$test_lifecycle_isolated_stop_line" -lt "$test_lifecycle_isolated_start_line" ] ||
    fail_test 'isolated create did not init, stop the prior engine, and start the target in order'
  [ -n "$test_lifecycle_isolated_image_line" ] ||
    fail_test 'isolated create did not prepare target images'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' \
    "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" isolated-one

  TEST_LIFECYCLE_ISOLATED_STATE=
  TEST_LIFECYCLE_BASE_MACHINE_LIST='shimmy-default|false
shimmy-isolated-one|true'
  TEST_LIFECYCLE_BASE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|false
shimmy-isolated-one|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  set +e
  test_lifecycle_isolated_clone_dry=$(test_lifecycle_isolated_profile_command isolated-one \
    profile clone isolated-one isolated-two --dry-run 2>&1)
  test_lifecycle_isolated_clone_dry_status=$?
  set -e
  [ "$test_lifecycle_isolated_clone_dry_status" -eq 0 ] ||
    fail_test "isolated clone default dry-run failed: $test_lifecycle_isolated_clone_dry"
  assert_contains "$test_lifecycle_isolated_clone_dry" \
    'would_clone_binding=isolated|profile-isolated-two'
  set +e
  test_lifecycle_isolated_clone_shared=$(test_lifecycle_isolated_profile_command isolated-one \
    profile clone isolated-one shared-from-isolated --shared --dry-run 2>&1)
  test_lifecycle_isolated_clone_shared_status=$?
  set -e
  [ "$test_lifecycle_isolated_clone_shared_status" -eq 0 ] ||
    fail_test "isolated clone shared dry-run failed: $test_lifecycle_isolated_clone_shared"
  assert_contains "$test_lifecycle_isolated_clone_shared" \
    'would_clone_binding=shared|shared'

  printf '%s\n' stopped > "$TEST_LIFECYCLE_CREATED_STATE"
  env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_MACHINE_LIST='shimmy-isolated-one|true' \
    FAKE_CONNECTION_LIST='shimmy-isolated-one|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true' \
    FAKE_CREATED_MACHINE_STATE_FILE="$TEST_LIFECYCLE_CREATED_STATE" \
    FAKE_CREATED_MACHINE_NAME=shimmy-default FAKE_SERVICE_PID_FILE="$TEST_LIFECYCLE_SERVICE_PID" \
    FAKE_ENGINE_CONFIG_DIR="$SCENARIO_DIR/engine-config" \
    FAKE_ENGINE_SOCKET_PATH="$SCENARIO_DIR/engine-socket" \
    FAKE_ENGINE_IDENTITY_PATH="$SCENARIO_DIR/engine-identity" \
    FAKE_ENGINE_PROJECTION_CONFIG="$TEST_LIFECYCLE_CONFIG/engines/shared/registries.conf" \
    FAKE_WORKLOADS= FAKE_DARWIN_PROJECTION_STATE=current \
    FAKE_PRIOR_MACHINE=shimmy-isolated-one FAKE_TARGET_MACHINE=shimmy-default \
    FAKE_PRIOR_DEFAULT=shimmy-isolated-one \
    "$test_lifecycle_isolated_root/bin/shimmy" profile activate default >/dev/null
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' \
    "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" default

  TEST_LIFECYCLE_ISOLATED_STATE=$SCENARIO_DIR/isolated-two-machine-state
  printf '%s\n' absent > "$TEST_LIFECYCLE_ISOLATED_STATE"
  TEST_LIFECYCLE_ISOLATED_CREATED_NAME=shimmy-isolated-two
  TEST_LIFECYCLE_ISOLATED_ENGINE_ID=profile-isolated-two
  TEST_LIFECYCLE_TARGET_MACHINE=shimmy-isolated-two
  TEST_LIFECYCLE_BASE_MACHINE_LIST='shimmy-default|true'
  TEST_LIFECYCLE_BASE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  TEST_LIFECYCLE_PRIOR_MACHINE=shimmy-default
  TEST_LIFECYCLE_PRIOR_DEFAULT=shimmy-default
  set +e
  test_lifecycle_isolated_clone_output=$(test_lifecycle_isolated_profile_command default \
    profile clone isolated-one isolated-two 2>&1)
  test_lifecycle_isolated_clone_status=$?
  set -e
  [ "$test_lifecycle_isolated_clone_status" -eq 0 ] ||
    fail_test "isolated clone failed: $(printf '%s\n' "$test_lifecycle_isolated_clone_output" | tail -n 100)"
  test_lifecycle_isolated_two_root=$TEST_LIFECYCLE_CONFIG/profiles/isolated-two
  test_lifecycle_isolated_two_engine=$TEST_LIFECYCLE_CONFIG/engines/profile-isolated-two
  assert_file_contains "$test_lifecycle_isolated_two_root/engine-binding.conf" 'mode=isolated'
  assert_regular_file_not_symlink "$test_lifecycle_isolated_two_engine/engine.conf"
  test_lifecycle_isolated_one_token=$(sed -n \
    's/^ownership_token=//p' "$test_lifecycle_isolated_engine/engine.conf")
  test_lifecycle_isolated_two_token=$(sed -n \
    's/^ownership_token=//p' "$test_lifecycle_isolated_two_engine/engine.conf")
  [ -n "$test_lifecycle_isolated_one_token" ] &&
    [ -n "$test_lifecycle_isolated_two_token" ] ||
    fail_test 'isolated clone ownership tokens were not recorded'
  [ "$test_lifecycle_isolated_one_token" != "$test_lifecycle_isolated_two_token" ] ||
    fail_test 'isolated clone copied source engine ownership evidence'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' \
    "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" isolated-two

  printf '%s\n' stopped > "$TEST_LIFECYCLE_CREATED_STATE"
  env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_MACHINE_LIST='shimmy-isolated-two|true' \
    FAKE_CONNECTION_LIST='shimmy-isolated-two|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true' \
    FAKE_CREATED_MACHINE_STATE_FILE="$TEST_LIFECYCLE_CREATED_STATE" \
    FAKE_CREATED_MACHINE_NAME=shimmy-default FAKE_SERVICE_PID_FILE="$TEST_LIFECYCLE_SERVICE_PID" \
    FAKE_ENGINE_CONFIG_DIR="$SCENARIO_DIR/engine-config" \
    FAKE_ENGINE_SOCKET_PATH="$SCENARIO_DIR/engine-socket" \
    FAKE_ENGINE_IDENTITY_PATH="$SCENARIO_DIR/engine-identity" \
    FAKE_ENGINE_PROJECTION_CONFIG="$TEST_LIFECYCLE_CONFIG/engines/shared/registries.conf" \
    FAKE_WORKLOADS= FAKE_DARWIN_PROJECTION_STATE=current \
    FAKE_PRIOR_MACHINE=shimmy-isolated-two FAKE_TARGET_MACHINE=shimmy-default \
    FAKE_PRIOR_DEFAULT=shimmy-isolated-two \
    "$test_lifecycle_isolated_two_root/bin/shimmy" profile activate default >/dev/null
  printf '%s\n' stopped > "$TEST_LIFECYCLE_ISOLATED_STATE"
  TEST_LIFECYCLE_BASE_MACHINE_LIST='shimmy-default|true'
  TEST_LIFECYCLE_BASE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  test_lifecycle_isolated_profile_command default profile delete isolated-two >/dev/null
  assert_path_not_exists "$test_lifecycle_isolated_two_root"
  assert_path_not_exists "$test_lifecycle_isolated_two_engine"

  TEST_LIFECYCLE_ISOLATED_STATE=$SCENARIO_DIR/isolated-machine-state
  TEST_LIFECYCLE_ISOLATED_CREATED_NAME=shimmy-isolated-one
  TEST_LIFECYCLE_ISOLATED_ENGINE_ID=profile-isolated-one
  TEST_LIFECYCLE_TARGET_MACHINE=shimmy-isolated-one
  printf '%s\n' stopped > "$TEST_LIFECYCLE_ISOLATED_STATE"
  TEST_LIFECYCLE_BASE_MACHINE_LIST='shimmy-default|true'
  TEST_LIFECYCLE_BASE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  test_lifecycle_delete_dry=$(test_lifecycle_isolated_profile_command default \
    profile delete isolated-one --dry-run)
  assert_contains "$test_lifecycle_delete_dry" 'deletion_action=remove'
  assert_contains "$test_lifecycle_delete_dry" \
    'irreversible_vm_data=containers,images,volumes,build-cache,all-vm-local-data'
  TEST_LIFECYCLE_DELETE_FAILURE=after-machine-remove
  set +e
  test_lifecycle_delete_interrupted=$(test_lifecycle_isolated_profile_command default \
    profile delete isolated-one 2>&1)
  test_lifecycle_delete_interrupted_status=$?
  set -e
  TEST_LIFECYCLE_DELETE_FAILURE=
  [ "$test_lifecycle_delete_interrupted_status" -ne 0 ] ||
    fail_test 'injected isolated deletion interruption unexpectedly succeeded'
  assert_regular_file_not_symlink "$test_lifecycle_isolated_engine/lifecycle.conf"
  assert_file_contains "$test_lifecycle_isolated_engine/lifecycle.conf" 'phase=removed'
  assert_dir_exists "$test_lifecycle_isolated_root"
  assert_equals "$(cat "$TEST_LIFECYCLE_ISOLATED_STATE")" absent
  rm -f "$test_lifecycle_isolated_root/shell-init.sh"
  test_lifecycle_delete_resume_dry=$(test_lifecycle_isolated_profile_command default \
    profile delete isolated-one --dry-run)
  assert_contains "$test_lifecycle_delete_resume_dry" 'deletion_action=resume-cleanup'
  test_lifecycle_isolated_profile_command default profile delete isolated-one >/dev/null
  assert_path_not_exists "$test_lifecycle_isolated_root"
  assert_path_not_exists "$test_lifecycle_isolated_engine"
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf"
  pass 'owned isolated create stages before transition, prepares images on target, and deletion resumes after machine removal'
}

test_commands_lifecycle_explicit_migration() {
  test_lifecycle_fixture_setup
  env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TEST_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    "$TEST_LIFECYCLE_CHECKOUT/commands/bootstrap.sh" --no-startup >/dev/null
  rm -f "$TEST_LIFECYCLE_CONFIG/profiles/default/engine-binding.conf"
  rm -rf "$TEST_LIFECYCLE_CONFIG/engines"
  test_lifecycle_command default profile sync >/dev/null
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/profiles/default/engine-binding.conf"
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/engines"
  assert_regular_file_not_symlink \
    "$TEST_LIFECYCLE_CONFIG/profiles/default/lib/engine/registry.sh"
  TEST_LIFECYCLE_CREATED_STATE=$SCENARIO_DIR/migration-created-state
  TEST_LIFECYCLE_SERVICE_PID=$SCENARIO_DIR/migration-service-pid
  printf '%s\n' absent > "$TEST_LIFECYCLE_CREATED_STATE"
  printf '%s\n' 900 > "$TEST_LIFECYCLE_SERVICE_PID"

  test_lifecycle_migration_dry=$(test_lifecycle_migration_command migrate --dry-run)
  assert_contains "$test_lifecycle_migration_dry" 'profile_binding=default|legacy-isolated|profile-default|shimmy-default'
  assert_contains "$test_lifecycle_migration_dry" 'shared_engine=shared|shimmy|would-create'
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/engines"
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine init '

  TEST_LIFECYCLE_FAIL_ACTION=machine_start
  set +e
  test_lifecycle_migration_failure=$(test_lifecycle_migration_command migrate 2>&1)
  test_lifecycle_migration_failure_status=$?
  set -e
  TEST_LIFECYCLE_FAIL_ACTION=
  [ "$test_lifecycle_migration_failure_status" -ne 0 ] ||
    fail_test 'injected migration failure unexpectedly succeeded'
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/engines"
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/profiles/default/engine-binding.conf"
  assert_equals "$(cat "$TEST_LIFECYCLE_CREATED_STATE")" absent

  TEST_LIFECYCLE_FAIL_ACTION=machine_start
  TEST_LIFECYCLE_ROLLBACK_FAIL=machine_rm
  set +e
  test_lifecycle_migration_retained=$(test_lifecycle_migration_command migrate 2>&1)
  test_lifecycle_migration_retained_status=$?
  set -e
  TEST_LIFECYCLE_FAIL_ACTION=
  TEST_LIFECYCLE_ROLLBACK_FAIL=
  [ "$test_lifecycle_migration_retained_status" -ne 0 ] ||
    fail_test 'migration with an injected rollback failure unexpectedly succeeded'
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/.engine-migration.conf"
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/lifecycle.conf"
  assert_equals "$(cat "$TEST_LIFECYCLE_CREATED_STATE")" stopped

  : > "$TEST_LIFECYCLE_PODMAN_LOG"
  test_lifecycle_migration_output=$(test_lifecycle_migration_command migrate)
  assert_contains "$test_lifecycle_migration_output" 'engine_schema_after=migrated'
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/profiles/default/engine-binding.conf" 'mode=legacy-isolated'
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/engines/profile-default/engine.conf" 'origin=legacy-external'
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf" 'origin=shimmy-created'
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf" 'name=shimmy'
  test_lifecycle_migration_status_output=$(test_lifecycle_migration_command status --format manifest)
  assert_contains "$test_lifecycle_migration_status_output" \
    'shimmy_engine_profile=default|migrated|legacy-isolated|profile-default|shimmy-default|legacy-external|external|not-applicable'
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine stop shimmy-default'
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine start shimmy-default'
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine rm --force shimmy-default'
  pass 'explicit migration is dry-run safe, preserves legacy machines, rolls back failure, and retries to a complete schema'
}

test_commands_lifecycle_global_owned_uninstall() {
  test_commands_lifecycle_darwin_bootstrap_case global-uninstall

  TEST_LIFECYCLE_ISOLATED_STATE=$SCENARIO_DIR/isolated-state
  printf '%s\n' absent > "$TEST_LIFECYCLE_ISOLATED_STATE"
  TEST_LIFECYCLE_BASE_MACHINE_LIST='shimmy-default|true'
  TEST_LIFECYCLE_BASE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true'
  TEST_LIFECYCLE_ISOLATED_CREATED_NAME=shimmy-isolated-one
  TEST_LIFECYCLE_ISOLATED_ENGINE_ID=profile-isolated-one
  TEST_LIFECYCLE_TARGET_MACHINE=shimmy-isolated-one
  TEST_LIFECYCLE_PRIOR_MACHINE=shimmy-default
  TEST_LIFECYCLE_PRIOR_DEFAULT=shimmy-default
  TEST_LIFECYCLE_ISOLATED_WORKLOADS=
  test_lifecycle_isolated_profile_command default profile create isolated-one \
    --isolated >/dev/null
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' \
    "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" isolated-one
  assert_file_contains \
    "$TEST_LIFECYCLE_CONFIG/profiles/isolated-one/engine-binding.conf" \
    'mode=isolated'
  assert_file_contains \
    "$TEST_LIFECYCLE_CONFIG/profiles/isolated-one/engine-binding.conf" \
    'engine=profile-isolated-one'

  TEST_LIFECYCLE_MACHINE_STATE_DIR=$SCENARIO_DIR/global-machine-state
  TEST_LIFECYCLE_MACHINE_METADATA_DIR=$SCENARIO_DIR/global-machine-metadata
  mkdir -p "$TEST_LIFECYCLE_MACHINE_STATE_DIR" "$TEST_LIFECYCLE_MACHINE_METADATA_DIR"
  printf '%s\n' stopped > "$TEST_LIFECYCLE_MACHINE_STATE_DIR/shimmy-default"
  printf '%s\n' running > "$TEST_LIFECYCLE_MACHINE_STATE_DIR/shimmy-isolated-one"
  printf '%s\n%s\n%s\n' "$SCENARIO_DIR/engine-config" \
    "$SCENARIO_DIR/engine-socket" "$SCENARIO_DIR/engine-identity" \
    > "$TEST_LIFECYCLE_MACHINE_METADATA_DIR/shimmy-default"
  printf '%s\n%s\n%s\n' "$SCENARIO_DIR/isolated-engine-config" \
    "$SCENARIO_DIR/isolated-engine-socket" "$SCENARIO_DIR/isolated-engine-identity" \
    > "$TEST_LIFECYCLE_MACHINE_METADATA_DIR/shimmy-isolated-one"

  test_lifecycle_external_root=$TEST_LIFECYCLE_CONFIG/engines/profile-external
  mkdir "$test_lifecycle_external_root"
  shimmy_engine_record_render profile-external darwin-machine profile \
    external-machine external-machine applehv legacy-external '' '' \
    > "$test_lifecycle_external_root/engine.conf"
  chmod 0644 "$test_lifecycle_external_root/engine.conf"
  printf '%s\n' stopped > "$TEST_LIFECYCLE_MACHINE_STATE_DIR/external-machine"
  printf '%s\n%s\n%s\n' "$SCENARIO_DIR/external-config" \
    "$SCENARIO_DIR/external-socket" "$SCENARIO_DIR/external-identity" \
    > "$TEST_LIFECYCLE_MACHINE_METADATA_DIR/external-machine"

  test_lifecycle_ambiguous_root=$TEST_LIFECYCLE_CONFIG/engines/profile-ambiguous
  mkdir "$test_lifecycle_ambiguous_root"
  test_lifecycle_ambiguous_token=$(sed -n \
    's/^ownership_token=//p' \
    "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf")
  test_lifecycle_ambiguous_identity=sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
  shimmy_engine_record_render profile-ambiguous darwin-machine profile \
    ambiguous-machine ambiguous-machine applehv shimmy-created \
    "$test_lifecycle_ambiguous_token" "$test_lifecycle_ambiguous_identity" \
    > "$test_lifecycle_ambiguous_root/engine.conf"
  chmod 0644 "$test_lifecycle_ambiguous_root/engine.conf"
  printf '%s\n' stopped > "$TEST_LIFECYCLE_MACHINE_STATE_DIR/ambiguous-machine"
  printf '%s\n%s\n%s\n' "$SCENARIO_DIR/ambiguous-config" \
    "$SCENARIO_DIR/ambiguous-socket" "$SCENARIO_DIR/ambiguous-identity" \
    > "$TEST_LIFECYCLE_MACHINE_METADATA_DIR/ambiguous-machine"

  TEST_LIFECYCLE_GLOBAL_WORKLOADS='abcdef012345|global-sentinel'
  test_lifecycle_global_before=$(cksum < "$TEST_LIFECYCLE_CONFIG/active-profile.conf")
  test_lifecycle_global_dry=$(test_lifecycle_global_uninstall_command --dry-run 2>&1)
  assert_contains "$test_lifecycle_global_dry" \
    'planned_engines=shared,profile-isolated-one'
  assert_contains "$test_lifecycle_global_dry" \
    'profile-external:external-origin'
  assert_contains "$test_lifecycle_global_dry" \
    'profile-ambiguous:inspect-mismatch'
  assert_contains "$test_lifecycle_global_dry" \
    'build caches, and all other VM-local data'
  assert_contains "$test_lifecycle_global_dry" \
    'running_container=profile-isolated-one|abcdef012345|global-sentinel'
  assert_equals "$(cksum < "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" \
    "$test_lifecycle_global_before"
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/.uninstall.conf"

  set +e
  test_lifecycle_global_blocked=$(test_lifecycle_global_uninstall_command 2>&1)
  test_lifecycle_global_blocked_status=$?
  set -e
  [ "$test_lifecycle_global_blocked_status" -ne 0 ] ||
    fail_test 'global uninstall deleted a running workload without acknowledgement'
  assert_contains "$test_lifecycle_global_blocked" \
    'retry with explicit --stop-running acknowledgement'
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/.uninstall.conf"
  TEST_LIFECYCLE_GLOBAL_WORKLOADS=

  TEST_LIFECYCLE_UNINSTALL_FAILURE=after-shared-remove
  set +e
  test_lifecycle_global_failure=$(test_lifecycle_global_uninstall_command 2>&1)
  test_lifecycle_global_failure_status=$?
  set -e
  TEST_LIFECYCLE_UNINSTALL_FAILURE=
  [ "$test_lifecycle_global_failure_status" -ne 0 ] ||
    fail_test 'injected global uninstall interruption unexpectedly succeeded'
  assert_contains "$test_lifecycle_global_failure" \
    'installation state was retained for exact retry'
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/.uninstall.conf"
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/.uninstall.conf" \
    'completed_engines=none'
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/.uninstall.conf" \
    'pending_engines=shared,profile-isolated-one'
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/engines/shared/lifecycle.conf" \
    'phase=removed'
  assert_equals "$(cat "$TEST_LIFECYCLE_MACHINE_STATE_DIR/shimmy-default")" absent
  assert_equals "$(cat "$TEST_LIFECYCLE_MACHINE_STATE_DIR/shimmy-isolated-one")" stopped

  printf '%s\n' stopped > "$TEST_LIFECYCLE_MACHINE_STATE_DIR/shimmy-default"
  set +e
  test_lifecycle_global_collision=$(test_lifecycle_global_uninstall_command 2>&1)
  test_lifecycle_global_collision_status=$?
  set -e
  [ "$test_lifecycle_global_collision_status" -ne 0 ] ||
    fail_test 'global uninstall targeted a replacement at a reused machine name'
  assert_contains "$test_lifecycle_global_collision" 'engine name reappeared after recorded removal'
  printf '%s\n' absent > "$TEST_LIFECYCLE_MACHINE_STATE_DIR/shimmy-default"

  test_lifecycle_global_uninstall_command >/dev/null
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG"
  assert_equals "$(cat "$TEST_LIFECYCLE_MACHINE_STATE_DIR/shimmy-default")" absent
  assert_equals "$(cat "$TEST_LIFECYCLE_MACHINE_STATE_DIR/shimmy-isolated-one")" absent
  assert_equals "$(cat "$TEST_LIFECYCLE_MACHINE_STATE_DIR/external-machine")" stopped
  assert_equals "$(cat "$TEST_LIFECYCLE_MACHINE_STATE_DIR/ambiguous-machine")" stopped
  pass 'global uninstall removes exact owned engines in order, preserves external and mismatched state, and retries without targeting a reused name'
}

test_commands_lifecycle_end_to_end() {
  test_lifecycle_fixture_setup
  test_lifecycle_user_skills=$TEST_LIFECYCLE_HOME/.agents/skills
  test_lifecycle_remote_install=$test_lifecycle_user_skills/shimmy-install
  test_lifecycle_unrelated=$test_lifecycle_user_skills/unrelated-skill
  mkdir -p "$test_lifecycle_remote_install" "$test_lifecycle_unrelated"
  cp "$TEST_LIFECYCLE_CHECKOUT/plugins/shimmy/skills/shimmy-install/SKILL.md" \
    "$test_lifecycle_remote_install/SKILL.md"
  printf '%s\n' 'remote-skill-installer-destination' > "$test_lifecycle_remote_install/.remote-source"
  printf '%s\n' 'user-bytes' > "$test_lifecycle_unrelated/SKILL.md"
  test_lifecycle_bootstrap_output=$(env HOME="$TEST_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TEST_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    TEST_LIFECYCLE_CHECKOUT_COMMAND="$TEST_LIFECYCLE_CHECKOUT" /bin/sh -c '
      cd "$TEST_LIFECYCLE_CHECKOUT_COMMAND"
      . ./bootstrap.sh --shell sh
      printf "selected=%s\npath=%s\n" "$(command -v shimmy)" "$PATH"
    ')

  test_lifecycle_default=$TEST_LIFECYCLE_CONFIG/profiles/default
  assert_contains "$test_lifecycle_bootstrap_output" 'selected=shimmy'
  assert_contains "$test_lifecycle_bootstrap_output" "path=$test_lifecycle_default/bin:"
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/active-profile.conf"
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf"
  assert_file_contains "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf" 'origin=host-local'
  assert_file_contains "$test_lifecycle_default/engine-binding.conf" 'mode=shared'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" default
  assert_equals "$(readlink "$TEST_LIFECYCLE_ACTIVE_LINK")" "$test_lifecycle_default/registries.conf"
  assert_file_contains "$test_lifecycle_default/install-manifest.txt" 'shimmy_install_manifest_version=2'
  for test_lifecycle_baseline in jq rg skopeo; do
    assert_file_executable "$test_lifecycle_default/bin/$test_lifecycle_baseline"
    assert_file_contains "$test_lifecycle_default/install-manifest.txt" "shim=$test_lifecycle_baseline|tracking"
  done
  assert_file_contains "$TEST_LIFECYCLE_HOME/.profile" '# >>> shimmy default profile >>>'
  assert_path_symlink "$TEST_LIFECYCLE_HOME/.agents/skills/shimmy-catalog"
  assert_path_symlink "$test_lifecycle_remote_install"
  assert_equals "$(readlink "$test_lifecycle_remote_install")" \
    "$test_lifecycle_default/ai-skills/control/skills/shimmy-install"
  assert_file_contains "$test_lifecycle_unrelated/SKILL.md" user-bytes

  TEST_IMAGES_GENERATION_ROOT=$TEST_LIFECYCLE_CONFIG/catalogs/default/generations/$(
    sed -n '3s/^catalog_generation_current=//p' \
      "$TEST_LIFECYCLE_CONFIG/catalogs/default/registry.conf"
  )
  TEST_IMAGES_RESPONSES=$TEST_LIFECYCLE_VERIFY_RESPONSES
  test_images_responses_write oci-index.json \
    sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91

  test_lifecycle_catalog_status=$(test_lifecycle_command default catalog status --format manifest)
  test_lifecycle_catalog_tools=$(test_lifecycle_command default catalog tools --format manifest)
  test_lifecycle_catalog_verify=$(test_lifecycle_command default catalog verify --tool jq@1.8 --format manifest)
  assert_contains "$test_lifecycle_catalog_status" 'shimmy_catalog=default|sha256-'
  assert_contains "$test_lifecycle_catalog_tools" '|jq|1.8|1.8'
  assert_contains "$test_lifecycle_catalog_verify" 'image_verify=jq|1.8|runtime|'
  assert_contains "$(cat "$TEST_LIFECYCLE_VERIFY_LOG")" 'raw|ghcr.io/jqlang/jq@sha256:'

  test_lifecycle_profile_status=$(test_lifecycle_command default profile status --format manifest)
  test_lifecycle_profile_list=$(test_lifecycle_command default profile list --format manifest)
  assert_contains "$test_lifecycle_profile_status" 'shimmy_profile_name=default'
  assert_contains "$test_lifecycle_profile_status" 'shimmy_profile_source_tracking_ref=refs/heads/main'
  assert_contains "$test_lifecycle_profile_status" 'shimmy_profile_ai_skill_bundle=control|valid|'
  assert_contains "$test_lifecycle_profile_list" 'shimmy_profile=default|yes|'
  test_lifecycle_engine_status=$(test_lifecycle_command default admin engine status --format manifest)
  assert_contains "$test_lifecycle_engine_status" 'shimmy_engine_schema=migrated'
  assert_contains "$test_lifecycle_engine_status" 'shimmy_engine_profile=default|migrated|shared|shared|local|host-local|host-local|'

  test_lifecycle_redirect_dry=$(test_lifecycle_command default profile redirect set \
    --prefix registry.example --location mirror.example --dry-run)
  assert_contains "$test_lifecycle_redirect_dry" 'prefix = "registry.example"'
  assert_contains "$test_lifecycle_redirect_dry" 'location = "mirror.example"'
  test_lifecycle_command default profile redirect set \
    --prefix registry.example --location mirror.example >/dev/null
  test_lifecycle_redirects=$(test_lifecycle_command default profile redirect list --format manifest)
  assert_contains "$test_lifecycle_redirects" 'shimmy_profile_redirect=registry.example|mirror.example'
  test_lifecycle_command default profile redirect delete --prefix registry.example >/dev/null

  test_lifecycle_shims=$(test_lifecycle_command default shim list --format manifest)
  assert_contains "$test_lifecycle_shims" 'shimmy_shim=jq|1.8|tracking|1.8'
  test_lifecycle_command default shim add oc@4.18 >/dev/null
  test_lifecycle_command default shim add oc@4.20 >/dev/null
  test_lifecycle_command default shim set-version oc@4.20 >/dev/null
  test_lifecycle_command default shim sync oc@4.20 >/dev/null
  test_lifecycle_smoke=$(test_lifecycle_command default shim test oc@4.20)
  assert_contains "$test_lifecycle_smoke" 'shimmy_shim_test=oc|4.20|pass'
  test_lifecycle_command default shim remove oc@4.18 >/dev/null
  test_lifecycle_shims=$(test_lifecycle_command default shim list --format manifest)
  assert_contains "$test_lifecycle_shims" 'shimmy_shim=oc|4.20|pinned|4.20'
  test_lifecycle_ai=$(test_lifecycle_command default ai-skill list --format manifest)
  test_lifecycle_control_count=$(sed -n '5,$s/^skill=//p' \
    "$test_lifecycle_default/ai-skills/control/bundle.conf" | \
    awk 'NF { count++ } END { print count + 0 }')
  assert_contains "$test_lifecycle_ai" \
    "shimmy_ai_skill_bundle=control|valid|$test_lifecycle_control_count|-"
  assert_contains "$test_lifecycle_ai" 'shimmy_ai_skill=shims|shimmy-tool-oc|shimmy-link-current|'
  test_lifecycle_command default ai-skill repair >/dev/null

  test_lifecycle_active_before=$(cksum < "$TEST_LIFECYCLE_CONFIG/active-profile.conf")
  test_lifecycle_default_before=$(cksum < "$test_lifecycle_default/install-manifest.txt")
  test_lifecycle_image_before=$(cksum < "$TEST_LIFECYCLE_IMAGE_LOG")
  test_lifecycle_link_before=$(readlink "$TEST_LIFECYCLE_ACTIVE_LINK")
  test_lifecycle_startup_before=$(cksum < "$TEST_LIFECYCLE_HOME/.profile")
  test_lifecycle_skill_before=$(readlink "$TEST_LIFECYCLE_HOME/.agents/skills/shimmy-catalog")
  : > "$TEST_LIFECYCLE_PODMAN_LOG"
  test_lifecycle_dry=$(test_lifecycle_command default profile create team-one --dry-run)
  assert_contains "$test_lifecycle_dry" 'dry_run=yes'
  assert_contains "$test_lifecycle_dry" 'would_prepare_image=jq|1.8|pull'
  assert_contains "$test_lifecycle_dry" 'would_activate_profile=team-one'
  assert_contains "$test_lifecycle_dry" 'would_reconcile_ai_skill=shimmy-catalog|'
  assert_equals "$(cksum < "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" "$test_lifecycle_active_before"
  assert_equals "$(cksum < "$test_lifecycle_default/install-manifest.txt")" "$test_lifecycle_default_before"
  assert_equals "$(cksum < "$TEST_LIFECYCLE_IMAGE_LOG")" "$test_lifecycle_image_before"
  assert_equals "$(readlink "$TEST_LIFECYCLE_ACTIVE_LINK")" "$test_lifecycle_link_before"
  assert_equals "$(cksum < "$TEST_LIFECYCLE_HOME/.profile")" "$test_lifecycle_startup_before"
  assert_equals "$(readlink "$TEST_LIFECYCLE_HOME/.agents/skills/shimmy-catalog")" "$test_lifecycle_skill_before"
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine stop '
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine start '
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'system connection default '
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/profiles/team-one"
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/.catalog.lock"
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/.activation.lock"

  test_lifecycle_create_shell=$(env HOME="$TEST_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TEST_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    TEST_LIFECYCLE_SHELL_INIT="$test_lifecycle_default/shell-init.sh" /bin/sh -c '
      . "$TEST_LIFECYCLE_SHELL_INIT"
      shimmy profile create team-one
      printf "selected_bin=%s\n" "${PATH%%:*}"
      shimmy profile status --format manifest
    ')
  test_lifecycle_team=$TEST_LIFECYCLE_CONFIG/profiles/team-one
  assert_contains "$test_lifecycle_create_shell" "selected_bin=$test_lifecycle_team/bin"
  assert_contains "$test_lifecycle_create_shell" 'shimmy_profile_name=team-one'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TEST_LIFECYCLE_CONFIG/active-profile.conf")" team-one
  assert_equals "$(readlink "$TEST_LIFECYCLE_ACTIVE_LINK")" "$test_lifecycle_team/registries.conf"
  assert_file_contains "$test_lifecycle_team/install-manifest.txt" "shim=skopeo|tracking"
  assert_file_contains "$test_lifecycle_team/engine-binding.conf" 'mode=shared'
  assert_not_contains "$(cat "$TEST_LIFECYCLE_PODMAN_LOG")" 'machine init '
  assert_file_not_contains "$test_lifecycle_team/install-manifest.txt" 'startup_file='

  test_lifecycle_default_shims=$(test_lifecycle_command default shim list --format manifest)
  test_lifecycle_team_shims=$(test_lifecycle_command team-one shim list --format manifest)
  assert_contains "$test_lifecycle_default_shims" 'shimmy_shim=oc|4.20|pinned|4.20'
  assert_not_contains "$test_lifecycle_team_shims" 'shimmy_shim=oc|'
  test_lifecycle_inactive_image_before=$(cksum < "$TEST_LIFECYCLE_IMAGE_LOG")
  set +e
  test_lifecycle_inactive_mutation=$(test_lifecycle_command default shim add oc@4.22 2>&1)
  test_lifecycle_inactive_status=$?
  set -e
  [ "$test_lifecycle_inactive_status" -ne 0 ] ||
    fail_test 'inactive invoking profile unexpectedly accepted shim mutation'
  assert_contains "$test_lifecycle_inactive_mutation" \
    'shim mutation requires the invoking profile to be active'
  assert_equals "$(cksum < "$TEST_LIFECYCLE_IMAGE_LOG")" "$test_lifecycle_inactive_image_before"
  test_lifecycle_team_smoke=$(test_lifecycle_command team-one shim test rg)
  assert_contains "$test_lifecycle_team_smoke" 'shimmy_shim_test=rg|15.1|pass'
  test_lifecycle_team_ai=$(test_lifecycle_command team-one ai-skill list --format manifest)
  assert_contains "$test_lifecycle_team_ai" 'shimmy_ai_skill_bundle=shims|valid|3|-'
  test_lifecycle_command team-one ai-skill repair >/dev/null

  test_lifecycle_command default profile redirect set \
    --prefix clone.example --location mirror.clone.example >/dev/null
  test_lifecycle_clone_dry=$(test_lifecycle_command team-one profile clone \
    default clone-one --dry-run)
  assert_contains "$test_lifecycle_clone_dry" 'would_clone_profile=default'
  assert_contains "$test_lifecycle_clone_dry" 'would_clone_binding=shared|shared'
  test_lifecycle_command team-one profile clone default clone-one >/dev/null
  test_lifecycle_clone=$TEST_LIFECYCLE_CONFIG/profiles/clone-one
  assert_file_contains "$test_lifecycle_clone/engine-binding.conf" 'mode=shared'
  assert_file_contains "$test_lifecycle_clone/install-manifest.txt" 'shim=oc|pinned'
  assert_file_contains "$test_lifecycle_clone/install-manifest.txt" 'shim_version=oc|4.20|default'
  assert_file_contains "$test_lifecycle_clone/registries.conf" \
    '# Managed by Shimmy for profile "clone-one".'
  assert_file_contains "$test_lifecycle_clone/registries.conf" 'prefix = "clone.example"'
  assert_file_not_contains "$test_lifecycle_clone/install-manifest.txt" 'startup_file='
  set +e
  test_lifecycle_linux_isolated=$(test_lifecycle_command clone-one profile clone \
    default invalid-isolated --isolated --dry-run 2>&1)
  test_lifecycle_linux_isolated_status=$?
  set -e
  [ "$test_lifecycle_linux_isolated_status" -ne 0 ] ||
    fail_test 'Linux isolated clone unexpectedly succeeded'
  assert_contains "$test_lifecycle_linux_isolated" \
    'isolated profiles require a managed macOS Podman machine'
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG/profiles/invalid-isolated"
  test_lifecycle_command clone-one profile activate team-one >/dev/null
  test_lifecycle_command team-one profile delete clone-one >/dev/null
  assert_path_not_exists "$test_lifecycle_clone"
  assert_regular_file_not_symlink "$TEST_LIFECYCLE_CONFIG/engines/shared/engine.conf"

  for test_lifecycle_asset_profile in default team-one; do
    test_lifecycle_asset_root=$TEST_LIFECYCLE_CONFIG/profiles/$test_lifecycle_asset_profile
    test_lifecycle_asset_commands=$(find "$test_lifecycle_asset_root/commands" \
      -mindepth 1 -maxdepth 1 -type f -exec basename {} \; | LC_ALL=C sort)
    assert_equals "$test_lifecycle_asset_commands" 'admin.sh
ai-skill.sh
catalog.sh
help.sh
profile.sh
shim.sh'
    for test_lifecycle_asset_command in admin.sh ai-skill.sh \
      catalog.sh help.sh profile.sh shim.sh; do
      assert_file_executable "$test_lifecycle_asset_root/commands/$test_lifecycle_asset_command"
      /bin/sh -n "$test_lifecycle_asset_root/commands/$test_lifecycle_asset_command"
    done
    assert_file_executable "$test_lifecycle_asset_root/bin/shimmy"
    /bin/sh -n "$test_lifecycle_asset_root/bin/shimmy"
    /bin/sh -n "$test_lifecycle_asset_root/shell-init.sh"
    for test_lifecycle_asset_shim in "$test_lifecycle_asset_root"/bin/*; do
      [ -f "$test_lifecycle_asset_shim" ] || continue
      /bin/sh -n "$test_lifecycle_asset_shim"
    done
  done

  printf 'broken startup\n' > "$TEST_LIFECYCLE_HOME/.profile"
  test_lifecycle_command default profile repair-startup >/dev/null
  assert_file_contains "$TEST_LIFECYCLE_HOME/.profile" '# >>> shimmy default profile >>>'

  test_lifecycle_registry=$TEST_LIFECYCLE_CONFIG/catalogs/default/registry.conf
  test_lifecycle_catalog_generation=$(sed -n \
    '3s/^catalog_generation_current=//p' "$test_lifecycle_registry")
  test_lifecycle_catalog_generation_root=$TEST_LIFECYCLE_CONFIG/catalogs/default/generations/$test_lifecycle_catalog_generation
  test_lifecycle_catalog_generation_count=$(find \
    "$TEST_LIFECYCLE_CONFIG/catalogs/default/generations" \
    -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  test_lifecycle_registry_saved=$SCENARIO_DIR/registry.management-only.saved
  test_lifecycle_generation_saved=$SCENARIO_DIR/generation.management-only.saved
  cp "$test_lifecycle_registry" "$test_lifecycle_registry_saved"
  cp "$test_lifecycle_catalog_generation_root/generation.conf" \
    "$test_lifecycle_generation_saved"
  test_lifecycle_team_catalog_pin=$(sed -n '/^catalog=/p' \
    "$test_lifecycle_team/install-manifest.txt")
  test_lifecycle_control_bundle=$test_lifecycle_team/ai-skills/control/bundle.conf
  test_lifecycle_control_base_ref=$(git -C "$TEST_LIFECYCLE_CHECKOUT" rev-parse HEAD)
  test_lifecycle_control_base_names=$(test_lifecycle_control_source_names_render \
    "$TEST_LIFECYCLE_CHECKOUT" "$test_lifecycle_control_base_ref")
  assert_equals "$(test_lifecycle_control_bundle_names_render \
    "$test_lifecycle_control_bundle")" "$test_lifecycle_control_base_names"
  test_lifecycle_unrelated_before=$(cksum < "$test_lifecycle_unrelated/SKILL.md")
  test_lifecycle_dynamic_name=shimmy-dynamic-control
  test_lifecycle_dynamic_dir=$TEST_LIFECYCLE_CHECKOUT/plugins/shimmy/skills/$test_lifecycle_dynamic_name
  mkdir "$test_lifecycle_dynamic_dir"
  printf '%s\n' \
    '---' \
    "name: $test_lifecycle_dynamic_name" \
    'description: Synthetic dynamic control-skill lifecycle fixture.' \
    '---' \
    '' \
    "$SHIMMY_AI_SKILL_MANAGED_HEADER" \
    '' \
    '# Synthetic dynamic control skill' \
    > "$test_lifecycle_dynamic_dir/SKILL.md"
  git -C "$TEST_LIFECYCLE_CHECKOUT" add \
    "plugins/shimmy/skills/$test_lifecycle_dynamic_name/SKILL.md"
  git -C "$TEST_LIFECYCLE_CHECKOUT" commit -qm lifecycle-dynamic-control-add
  test_lifecycle_dynamic_add_ref=$(git -C "$TEST_LIFECYCLE_CHECKOUT" rev-parse HEAD)
  test_lifecycle_control_add_names=$(test_lifecycle_control_source_names_render \
    "$TEST_LIFECYCLE_CHECKOUT" "$test_lifecycle_dynamic_add_ref")

  (cd "$TEST_LIFECYCLE_CHECKOUT" &&
    test_lifecycle_command default catalog publish >/dev/null)
  cmp -s "$test_lifecycle_registry" "$test_lifecycle_registry_saved" ||
    fail_test 'management-only add rewrote catalog registry bytes'
  cmp -s "$test_lifecycle_catalog_generation_root/generation.conf" \
    "$test_lifecycle_generation_saved" ||
    fail_test 'management-only add rewrote retained generation metadata'
  assert_equals "$(find "$TEST_LIFECYCLE_CONFIG/catalogs/default/generations" \
    -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" \
    "$test_lifecycle_catalog_generation_count"
  assert_file_not_contains "$test_lifecycle_team/ai-skills/control/bundle.conf" \
    "skill=$test_lifecycle_dynamic_name|"
  assert_equals "$(test_lifecycle_control_bundle_names_render \
    "$test_lifecycle_control_bundle")" "$test_lifecycle_control_base_names"
  assert_path_not_exists "$test_lifecycle_user_skills/$test_lifecycle_dynamic_name"

  test_lifecycle_command team-one profile sync >/dev/null
  assert_file_contains "$test_lifecycle_team/install-manifest.txt" \
    "shimmy_source_ref=$test_lifecycle_dynamic_add_ref"
  assert_equals "$(sed -n '/^catalog=/p' \
    "$test_lifecycle_team/install-manifest.txt")" "$test_lifecycle_team_catalog_pin"
  assert_file_contains "$test_lifecycle_team/ai-skills/control/bundle.conf" \
    "skill=$test_lifecycle_dynamic_name|"
  assert_equals "$(test_lifecycle_control_bundle_names_render \
    "$test_lifecycle_control_bundle")" "$test_lifecycle_control_add_names"
  assert_path_symlink "$test_lifecycle_user_skills/$test_lifecycle_dynamic_name"
  assert_equals "$(readlink "$test_lifecycle_user_skills/$test_lifecycle_dynamic_name")" \
    "$test_lifecycle_team/ai-skills/control/skills/$test_lifecycle_dynamic_name"
  assert_equals "$(cksum < "$test_lifecycle_unrelated/SKILL.md")" \
    "$test_lifecycle_unrelated_before"

  git -C "$TEST_LIFECYCLE_CHECKOUT" rm -qr \
    "plugins/shimmy/skills/$test_lifecycle_dynamic_name"
  git -C "$TEST_LIFECYCLE_CHECKOUT" commit -qm lifecycle-dynamic-control-remove
  test_lifecycle_dynamic_remove_ref=$(git -C "$TEST_LIFECYCLE_CHECKOUT" rev-parse HEAD)
  test_lifecycle_control_remove_names=$(test_lifecycle_control_source_names_render \
    "$TEST_LIFECYCLE_CHECKOUT" "$test_lifecycle_dynamic_remove_ref")
  assert_equals "$test_lifecycle_control_remove_names" \
    "$test_lifecycle_control_base_names"
  (cd "$TEST_LIFECYCLE_CHECKOUT" &&
    test_lifecycle_command default catalog publish >/dev/null)
  cmp -s "$test_lifecycle_registry" "$test_lifecycle_registry_saved" ||
    fail_test 'management-only removal rewrote catalog registry bytes'
  cmp -s "$test_lifecycle_catalog_generation_root/generation.conf" \
    "$test_lifecycle_generation_saved" ||
    fail_test 'management-only removal rewrote retained generation metadata'
  assert_equals "$(find "$TEST_LIFECYCLE_CONFIG/catalogs/default/generations" \
    -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" \
    "$test_lifecycle_catalog_generation_count"
  assert_equals "$(test_lifecycle_control_bundle_names_render \
    "$test_lifecycle_control_bundle")" "$test_lifecycle_control_add_names"
  assert_path_symlink "$test_lifecycle_user_skills/$test_lifecycle_dynamic_name"

  test_lifecycle_command team-one profile sync >/dev/null
  assert_file_contains "$test_lifecycle_team/install-manifest.txt" \
    "shimmy_source_ref=$test_lifecycle_dynamic_remove_ref"
  assert_equals "$(sed -n '/^catalog=/p' \
    "$test_lifecycle_team/install-manifest.txt")" "$test_lifecycle_team_catalog_pin"
  assert_file_not_contains "$test_lifecycle_team/ai-skills/control/bundle.conf" \
    "skill=$test_lifecycle_dynamic_name|"
  assert_equals "$(test_lifecycle_control_bundle_names_render \
    "$test_lifecycle_control_bundle")" "$test_lifecycle_control_remove_names"
  assert_path_not_exists "$test_lifecycle_user_skills/$test_lifecycle_dynamic_name"
  assert_equals "$(cksum < "$test_lifecycle_unrelated/SKILL.md")" \
    "$test_lifecycle_unrelated_before"

  test_catalog_tool_source_advance "$TEST_LIFECYCLE_CHECKOUT" \
    'Lifecycle catalog sync revision.'
  test_lifecycle_publish=$(cd "$TEST_LIFECYCLE_CHECKOUT" &&
    test_lifecycle_command default catalog publish)
  assert_contains "$test_lifecycle_publish" 'shimmy_catalog=default|sha256-'
  test_lifecycle_new_ref=$(git -C "$TEST_LIFECYCLE_CHECKOUT" rev-parse HEAD)
  test_lifecycle_command team-one profile sync >/dev/null
  assert_file_contains "$test_lifecycle_team/install-manifest.txt" "shimmy_source_ref=$test_lifecycle_new_ref"
  assert_equals "$(readlink "$TEST_LIFECYCLE_ACTIVE_LINK")" "$test_lifecycle_team/registries.conf"
  test_lifecycle_synced_verify=$(test_lifecycle_command team-one catalog verify \
    --tool jq@1.8 --format manifest)
  assert_contains "$test_lifecycle_synced_verify" 'image_verify=jq|1.8|runtime|'
  test_lifecycle_command team-one catalog rollback >/dev/null
  test_lifecycle_command team-one catalog rollback >/dev/null

  mkdir "$TEST_LIFECYCLE_CONFIG/profiles/broken"
  test_lifecycle_admin=$(test_lifecycle_command team-one admin status --format manifest)
  assert_contains "$test_lifecycle_admin" 'shimmy_admin_active_profile=team-one'
  assert_contains "$test_lifecycle_admin" 'shimmy_admin_profile=default|ok|-'
  assert_contains "$test_lifecycle_admin" 'shimmy_admin_profile=team-one|ok|-'
  assert_contains "$test_lifecycle_admin" 'shimmy_admin_profile=broken|error|'
  assert_contains "$test_lifecycle_admin" \
    'shimmy_admin_profile_record=default|shimmy_profile_catalog|default%7C'
  assert_contains "$test_lifecycle_admin" \
    'shimmy_admin_profile_record=team-one|shimmy_profile_name|team-one'
  rmdir "$TEST_LIFECYCLE_CONFIG/profiles/broken"

  test_lifecycle_network=$(test_lifecycle_command team-one admin network \
    --target 198.51.100.1 --host-ip 198.51.100.20 --host-lan 198.51.100.0/24 \
    --format manifest)
  assert_contains "$test_lifecycle_network" 'perspective=shell'
  assert_contains "$test_lifecycle_network" 'host_ipv4=198.51.100.20'
  assert_contains "$test_lifecycle_network" 'host_lan=198.51.100.0/24'

  test_lifecycle_activate_shell=$(env HOME="$TEST_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TEST_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    TEST_LIFECYCLE_SHELL_INIT="$test_lifecycle_team/shell-init.sh" /bin/sh -c '
      . "$TEST_LIFECYCLE_SHELL_INIT"
      shimmy profile activate default
      printf "selected_bin=%s\n" "${PATH%%:*}"
      shimmy profile status --format manifest
    ')
  assert_contains "$test_lifecycle_activate_shell" "selected_bin=$test_lifecycle_default/bin"
  assert_contains "$test_lifecycle_activate_shell" 'shimmy_profile_name=default'
  test_lifecycle_command default profile delete team-one >/dev/null
  assert_path_not_exists "$test_lifecycle_team"

  test_lifecycle_command default admin uninstall >/dev/null
  assert_path_not_exists "$TEST_LIFECYCLE_CONFIG"
  assert_path_not_exists "$TEST_LIFECYCLE_ACTIVE_LINK"
  assert_path_not_exists "$TEST_LIFECYCLE_HOME/.agents/skills/shimmy-catalog"
  assert_file_contains "$test_lifecycle_unrelated/SKILL.md" user-bytes
  assert_file_not_contains "$TEST_LIFECYCLE_HOME/.profile" '# >>> shimmy default profile >>>'

  test_lifecycle_failed_config=$SCENARIO_DIR/failed-config/shimmy
  test_lifecycle_failed_link=$SCENARIO_DIR/failed-config/containers/registries.conf.d/shimmy-active-profile.conf
  set +e
  test_lifecycle_failed_output=$(env HOME="$TEST_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$SCENARIO_DIR/failed-config" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$test_lifecycle_failed_link" FAKE_LINUX_INFO=true\|false \
    FAKE_FAIL_LINUX_TARGET="$test_lifecycle_failed_config/profiles/default/registries.conf" \
    "$TEST_LIFECYCLE_CHECKOUT/commands/bootstrap.sh" --no-startup 2>&1)
  test_lifecycle_failed_status=$?
  set -e
  [ "$test_lifecycle_failed_status" -ne 0 ] || fail_test 'failed initial engine activation unexpectedly bootstrapped a valid installation'
  assert_contains "$test_lifecycle_failed_output" 'prior active profile restored'
  assert_path_not_exists "$test_lifecycle_failed_config"
  assert_path_not_exists "$test_lifecycle_failed_link"
  assert_file_contains "$test_lifecycle_unrelated/SKILL.md" user-bytes
  pass 'public bootstrap and installed launcher complete onboarding, catalog, shim, profile, AI, network, shell, administration, and uninstall flows'
}
