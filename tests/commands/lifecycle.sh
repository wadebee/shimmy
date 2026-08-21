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
  test_catalog_checkout_create "$TEST_LIFECYCLE_CHECKOUT"
  test_shim_fake_versions_write "$TEST_LIFECYCLE_CHECKOUT"
  images_fixture_fake_runtimes_write "$TEST_LIFECYCLE_CHECKOUT"
  git -C "$TEST_LIFECYCLE_CHECKOUT" add tools/jq/versions tools/oc/versions \
    tools/rg/versions tools/skopeo/versions
  git -C "$TEST_LIFECYCLE_CHECKOUT" commit -qm lifecycle-fakes
  profile_activation_fake_create "$TEST_LIFECYCLE_PODMAN"
  : > "$TEST_LIFECYCLE_PODMAN_LOG"
  : > "$TEST_LIFECYCLE_IMAGE_LOG"
  : > "$TEST_LIFECYCLE_SMOKE_LOG"
  : > "$TEST_LIFECYCLE_VERIFY_LOG"
  : > "$TEST_LIFECYCLE_VERIFY_RESPONSES"
}

test_commands_lifecycle_darwin_running_idle_bootstrap() {
  test_lifecycle_fixture_setup
  test_lifecycle_bootstrap_output=$(env HOME="$TEST_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$TEST_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Darwin SHIMMY_TEST_PROFILE_PODMAN_BIN="$TEST_LIFECYCLE_PODMAN" \
    SHIMMY_TEST_IMAGE_LOG="$TEST_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TEST_LIFECYCLE_PODMAN_LOG" \
    FAKE_MACHINE_LIST='shimmy-default|true' \
    FAKE_CONNECTION_LIST='shimmy-default|ssh://core@127.0.0.1/run/user/1000/podman/podman.sock|true' \
    FAKE_WORKLOADS= FAKE_DARWIN_PROJECTION_STATE=absent \
    FAKE_PRIOR_MACHINE=shimmy-default FAKE_TARGET_MACHINE=shimmy-default \
    FAKE_PRIOR_DEFAULT=shimmy-default \
    "$TEST_LIFECYCLE_CHECKOUT/commands/bootstrap.sh" --no-startup)

  assert_contains "$test_lifecycle_bootstrap_output" 'Bootstrapped active Shimmy profile default'
  assert_regular_file_not_symlink \
    "$TEST_LIFECYCLE_CONFIG/profiles/default/machine-projection.txt"
  test_lifecycle_stop_line=$(sed -n '/^machine stop shimmy-default$/=' "$TEST_LIFECYCLE_PODMAN_LOG")
  test_lifecycle_start_line=$(sed -n '/^machine start shimmy-default$/=' "$TEST_LIFECYCLE_PODMAN_LOG")
  test_lifecycle_projection_line=$(sed -n \
    '/^machine ssh shimmy-default \/bin\/sh -s -- projection /=' \
    "$TEST_LIFECYCLE_PODMAN_LOG")
  test_lifecycle_validation_line=$(sed -n \
    '/^--connection shimmy-default info /=' "$TEST_LIFECYCLE_PODMAN_LOG" | tail -n 1)
  [ "$test_lifecycle_stop_line" -lt "$test_lifecycle_start_line" ] &&
    [ "$test_lifecycle_start_line" -lt "$test_lifecycle_projection_line" ] &&
    [ "$test_lifecycle_projection_line" -lt "$test_lifecycle_validation_line" ] ||
    fail_test 'running idle Darwin bootstrap did not restart, project, and validate in order'
  pass 'Darwin bootstrap restarts an idle running default machine and commits its registry projection'
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
  assert_contains "$test_lifecycle_ai" 'shimmy_ai_skill_bundle=control|valid|6|-'
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

  test_catalog_source_advance "$TEST_LIFECYCLE_CHECKOUT" 'Lifecycle sync revision.'
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

test_commands_lifecycle_run() {
  test_commands_lifecycle_darwin_running_idle_bootstrap
  test_commands_lifecycle_end_to_end
}
