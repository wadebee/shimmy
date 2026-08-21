#!/bin/sh

test_target_lifecycle_command() {
  test_target_lifecycle_profile=$1
  shift
  env HOME="$TARGET_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TARGET_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_LIFECYCLE_CONFIG" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_LIFECYCLE_PODMAN" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TARGET_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TARGET_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    "$TARGET_LIFECYCLE_CONFIG/profiles/$test_target_lifecycle_profile/bin/shimmy" "$@"
}

test_target_lifecycle_fixture_setup() {
  setup_scenario
  TARGET_LIFECYCLE_CHECKOUT=$SCENARIO_DIR/checkout
  TARGET_LIFECYCLE_HOME=$SCENARIO_DIR/home
  TARGET_LIFECYCLE_CONFIG_HOME=$SCENARIO_DIR/config
  TARGET_LIFECYCLE_CONFIG=$TARGET_LIFECYCLE_CONFIG_HOME/shimmy
  TARGET_LIFECYCLE_ACTIVE_LINK=$TARGET_LIFECYCLE_CONFIG_HOME/containers/registries.conf.d/shimmy-active-profile.conf
  TARGET_LIFECYCLE_PODMAN=$SCENARIO_DIR/podman
  TARGET_LIFECYCLE_PODMAN_LOG=$SCENARIO_DIR/podman.log
  TARGET_LIFECYCLE_IMAGE_LOG=$SCENARIO_DIR/image.log
  TARGET_LIFECYCLE_SMOKE_LOG=$SCENARIO_DIR/smoke.log
  test_target_catalog_checkout_create "$TARGET_LIFECYCLE_CHECKOUT"
  test_target_shim_fake_versions_write "$TARGET_LIFECYCLE_CHECKOUT"
  git -C "$TARGET_LIFECYCLE_CHECKOUT" add tools/jq/versions tools/oc/versions \
    tools/rg/versions tools/skopeo/versions
  git -C "$TARGET_LIFECYCLE_CHECKOUT" commit -qm target-lifecycle-fakes
  profile_activation_fake_create "$TARGET_LIFECYCLE_PODMAN"
  : > "$TARGET_LIFECYCLE_PODMAN_LOG"
  : > "$TARGET_LIFECYCLE_IMAGE_LOG"
  : > "$TARGET_LIFECYCLE_SMOKE_LOG"
}

test_commands_target_lifecycle_end_to_end() {
  test_target_lifecycle_fixture_setup
  target_lifecycle_bootstrap_output=$(env HOME="$TARGET_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TARGET_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_LIFECYCLE_CONFIG" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_LIFECYCLE_PODMAN" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TARGET_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TARGET_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    TEST_TARGET_LIFECYCLE_CHECKOUT="$TARGET_LIFECYCLE_CHECKOUT" /bin/sh -c '
      cd "$TEST_TARGET_LIFECYCLE_CHECKOUT"
      . ./bootstrap-target.sh --shell sh
      printf "selected=%s\npath=%s\n" "$(command -v shimmy)" "$PATH"
    ')

  target_lifecycle_default=$TARGET_LIFECYCLE_CONFIG/profiles/default
  assert_contains "$target_lifecycle_bootstrap_output" 'selected=shimmy'
  assert_contains "$target_lifecycle_bootstrap_output" "path=$target_lifecycle_default/bin:"
  assert_regular_file_not_symlink "$TARGET_LIFECYCLE_CONFIG/active-profile.conf"
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TARGET_LIFECYCLE_CONFIG/active-profile.conf")" default
  assert_equals "$(readlink "$TARGET_LIFECYCLE_ACTIVE_LINK")" "$target_lifecycle_default/registries.conf"
  assert_file_contains "$target_lifecycle_default/install-manifest.txt" 'shimmy_install_manifest_version=2'
  for target_lifecycle_baseline in jq rg skopeo; do
    assert_file_executable "$target_lifecycle_default/bin/$target_lifecycle_baseline"
    assert_file_contains "$target_lifecycle_default/install-manifest.txt" "shim=$target_lifecycle_baseline|tracking"
  done
  assert_file_contains "$TARGET_LIFECYCLE_HOME/.profile" '# >>> shimmy default profile >>>'
  assert_path_symlink "$TARGET_LIFECYCLE_HOME/.agents/skills/shimmy-catalog"

  target_lifecycle_active_before=$(cksum < "$TARGET_LIFECYCLE_CONFIG/active-profile.conf")
  target_lifecycle_default_before=$(cksum < "$target_lifecycle_default/install-manifest.txt")
  target_lifecycle_image_before=$(cksum < "$TARGET_LIFECYCLE_IMAGE_LOG")
  target_lifecycle_link_before=$(readlink "$TARGET_LIFECYCLE_ACTIVE_LINK")
  target_lifecycle_startup_before=$(cksum < "$TARGET_LIFECYCLE_HOME/.profile")
  target_lifecycle_skill_before=$(readlink "$TARGET_LIFECYCLE_HOME/.agents/skills/shimmy-catalog")
  : > "$TARGET_LIFECYCLE_PODMAN_LOG"
  target_lifecycle_dry=$(test_target_lifecycle_command default profile create team-one --dry-run)
  assert_contains "$target_lifecycle_dry" 'dry_run=yes'
  assert_contains "$target_lifecycle_dry" 'would_prepare_image=jq|1.8|pull'
  assert_contains "$target_lifecycle_dry" 'would_activate_profile=team-one'
  assert_contains "$target_lifecycle_dry" 'would_reconcile_ai_skill=shimmy-catalog|'
  assert_equals "$(cksum < "$TARGET_LIFECYCLE_CONFIG/active-profile.conf")" "$target_lifecycle_active_before"
  assert_equals "$(cksum < "$target_lifecycle_default/install-manifest.txt")" "$target_lifecycle_default_before"
  assert_equals "$(cksum < "$TARGET_LIFECYCLE_IMAGE_LOG")" "$target_lifecycle_image_before"
  assert_equals "$(readlink "$TARGET_LIFECYCLE_ACTIVE_LINK")" "$target_lifecycle_link_before"
  assert_equals "$(cksum < "$TARGET_LIFECYCLE_HOME/.profile")" "$target_lifecycle_startup_before"
  assert_equals "$(readlink "$TARGET_LIFECYCLE_HOME/.agents/skills/shimmy-catalog")" "$target_lifecycle_skill_before"
  assert_not_contains "$(cat "$TARGET_LIFECYCLE_PODMAN_LOG")" 'machine stop '
  assert_not_contains "$(cat "$TARGET_LIFECYCLE_PODMAN_LOG")" 'machine start '
  assert_not_contains "$(cat "$TARGET_LIFECYCLE_PODMAN_LOG")" 'system connection default '
  assert_path_not_exists "$TARGET_LIFECYCLE_CONFIG/profiles/team-one"
  assert_path_not_exists "$TARGET_LIFECYCLE_CONFIG/.catalog.lock"
  assert_path_not_exists "$TARGET_LIFECYCLE_CONFIG/.activation.lock"

  test_target_lifecycle_command default profile create team-one >/dev/null
  target_lifecycle_team=$TARGET_LIFECYCLE_CONFIG/profiles/team-one
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TARGET_LIFECYCLE_CONFIG/active-profile.conf")" team-one
  assert_equals "$(readlink "$TARGET_LIFECYCLE_ACTIVE_LINK")" "$target_lifecycle_team/registries.conf"
  assert_file_contains "$target_lifecycle_team/install-manifest.txt" "shim=skopeo|tracking"
  assert_file_not_contains "$target_lifecycle_team/install-manifest.txt" 'startup_file='

  printf 'user-bytes\n' > "$TARGET_LIFECYCLE_HOME/.agents/skills/unrelated-skill"
  printf 'broken startup\n' > "$TARGET_LIFECYCLE_HOME/.profile"
  test_target_lifecycle_command default profile repair-startup >/dev/null
  assert_file_contains "$TARGET_LIFECYCLE_HOME/.profile" '# >>> shimmy default profile >>>'

  test_target_catalog_source_advance "$TARGET_LIFECYCLE_CHECKOUT" 'Target lifecycle sync revision.'
  shimmy_target_catalog_default_publish "$TARGET_LIFECYCLE_CONFIG" "$TARGET_LIFECYCLE_CHECKOUT" ||
    fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
  target_lifecycle_new_ref=$(git -C "$TARGET_LIFECYCLE_CHECKOUT" rev-parse HEAD)
  test_target_lifecycle_command team-one profile sync >/dev/null
  assert_file_contains "$target_lifecycle_team/install-manifest.txt" "shimmy_source_ref=$target_lifecycle_new_ref"
  assert_equals "$(readlink "$TARGET_LIFECYCLE_ACTIVE_LINK")" "$target_lifecycle_team/registries.conf"

  target_lifecycle_admin=$(test_target_lifecycle_command team-one admin status --format manifest)
  assert_contains "$target_lifecycle_admin" 'shimmy_admin_active_profile=team-one'
  assert_contains "$target_lifecycle_admin" 'shimmy_admin_profile_begin=default'
  assert_contains "$target_lifecycle_admin" 'shimmy_admin_profile_begin=team-one'
  test_target_lifecycle_command team-one profile activate default >/dev/null
  test_target_lifecycle_command default profile delete team-one >/dev/null
  assert_path_not_exists "$target_lifecycle_team"

  test_target_lifecycle_command default admin uninstall >/dev/null
  assert_path_not_exists "$TARGET_LIFECYCLE_CONFIG"
  assert_path_not_exists "$TARGET_LIFECYCLE_ACTIVE_LINK"
  assert_path_not_exists "$TARGET_LIFECYCLE_HOME/.agents/skills/shimmy-catalog"
  assert_file_contains "$TARGET_LIFECYCLE_HOME/.agents/skills/unrelated-skill" user-bytes
  assert_file_not_contains "$TARGET_LIFECYCLE_HOME/.profile" '# >>> shimmy default profile >>>'

  target_lifecycle_failed_config=$SCENARIO_DIR/failed-config/shimmy
  target_lifecycle_failed_link=$SCENARIO_DIR/failed-config/containers/registries.conf.d/shimmy-active-profile.conf
  set +e
  target_lifecycle_failed_output=$(env HOME="$TARGET_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$SCENARIO_DIR/failed-config" \
    SHIMMY_TARGET_CONFIG_ROOT="$target_lifecycle_failed_config" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_LIFECYCLE_PODMAN" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TARGET_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$target_lifecycle_failed_link" FAKE_LINUX_INFO=true\|false \
    FAKE_FAIL_LINUX_TARGET="$target_lifecycle_failed_config/profiles/default/registries.conf" \
    "$TARGET_LIFECYCLE_CHECKOUT/commands/bootstrap-target.sh" --no-startup 2>&1)
  target_lifecycle_failed_status=$?
  set -e
  [ "$target_lifecycle_failed_status" -ne 0 ] || fail_test 'failed initial engine activation unexpectedly bootstrapped a valid installation'
  assert_contains "$target_lifecycle_failed_output" 'prior active profile restored'
  assert_path_not_exists "$target_lifecycle_failed_config"
  assert_path_not_exists "$target_lifecycle_failed_link"
  assert_file_contains "$TARGET_LIFECYCLE_HOME/.agents/skills/unrelated-skill" user-bytes
  pass 'private target bootstrap, dry create, create, repair, sync, administration, delete, and uninstall preserve lifecycle boundaries'
}

test_commands_target_lifecycle_run() {
  test_commands_target_lifecycle_end_to_end
}
