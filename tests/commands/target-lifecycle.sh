#!/bin/sh

test_target_lifecycle_command() {
  test_target_lifecycle_profile=$1
  shift
  env HOME="$TARGET_LIFECYCLE_HOME" XDG_CONFIG_HOME="$TARGET_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_LIFECYCLE_CONFIG" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_LIFECYCLE_PODMAN" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_LIFECYCLE_SMOKE_LOG" \
    SHIMMY_TEST_IMAGES_CALL_LOG="$TARGET_LIFECYCLE_VERIFY_LOG" \
    SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures" \
    SHIMMY_TEST_IMAGES_RESPONSE_FILE="$TARGET_LIFECYCLE_VERIFY_RESPONSES" \
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
  TARGET_LIFECYCLE_VERIFY_LOG=$SCENARIO_DIR/verify.log
  TARGET_LIFECYCLE_VERIFY_RESPONSES=$SCENARIO_DIR/verify-responses
  test_target_catalog_checkout_create "$TARGET_LIFECYCLE_CHECKOUT"
  test_target_shim_fake_versions_write "$TARGET_LIFECYCLE_CHECKOUT"
  images_fixture_fake_runtimes_write "$TARGET_LIFECYCLE_CHECKOUT"
  git -C "$TARGET_LIFECYCLE_CHECKOUT" add tools/jq/versions tools/oc/versions \
    tools/rg/versions tools/skopeo/versions
  git -C "$TARGET_LIFECYCLE_CHECKOUT" commit -qm target-lifecycle-fakes
  profile_activation_fake_create "$TARGET_LIFECYCLE_PODMAN"
  : > "$TARGET_LIFECYCLE_PODMAN_LOG"
  : > "$TARGET_LIFECYCLE_IMAGE_LOG"
  : > "$TARGET_LIFECYCLE_SMOKE_LOG"
  : > "$TARGET_LIFECYCLE_VERIFY_LOG"
  : > "$TARGET_LIFECYCLE_VERIFY_RESPONSES"
}

test_commands_target_lifecycle_end_to_end() {
  test_target_lifecycle_fixture_setup
  target_lifecycle_user_skills=$TARGET_LIFECYCLE_HOME/.agents/skills
  target_lifecycle_remote_install=$target_lifecycle_user_skills/shimmy-install
  target_lifecycle_unrelated=$target_lifecycle_user_skills/unrelated-skill
  mkdir -p "$target_lifecycle_remote_install" "$target_lifecycle_unrelated"
  cp "$TARGET_LIFECYCLE_CHECKOUT/plugins/shimmy/skills/shimmy-install/SKILL.md" \
    "$target_lifecycle_remote_install/SKILL.md"
  printf '%s\n' 'remote-skill-installer-destination' > "$target_lifecycle_remote_install/.remote-source"
  printf '%s\n' 'user-bytes' > "$target_lifecycle_unrelated/SKILL.md"
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
  assert_path_symlink "$target_lifecycle_remote_install"
  assert_equals "$(readlink "$target_lifecycle_remote_install")" \
    "$target_lifecycle_default/ai-skills/control/skills/shimmy-install"
  assert_file_contains "$target_lifecycle_unrelated/SKILL.md" user-bytes

  TARGET_IMAGES_GENERATION_ROOT=$TARGET_LIFECYCLE_CONFIG/catalogs/default/generations/$(
    sed -n '3s/^catalog_generation_current=//p' \
      "$TARGET_LIFECYCLE_CONFIG/catalogs/default/registry.conf"
  )
  TARGET_IMAGES_RESPONSES=$TARGET_LIFECYCLE_VERIFY_RESPONSES
  test_target_images_responses_write oci-index.json \
    sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91

  target_lifecycle_catalog_status=$(test_target_lifecycle_command default catalog status --format manifest)
  target_lifecycle_catalog_tools=$(test_target_lifecycle_command default catalog tools --format manifest)
  target_lifecycle_catalog_verify=$(test_target_lifecycle_command default catalog verify --tool jq@1.8 --format manifest)
  assert_contains "$target_lifecycle_catalog_status" 'shimmy_catalog=default|sha256-'
  assert_contains "$target_lifecycle_catalog_tools" '|jq|1.8|1.8'
  assert_contains "$target_lifecycle_catalog_verify" 'image_verify=jq|1.8|runtime|'
  assert_contains "$(cat "$TARGET_LIFECYCLE_VERIFY_LOG")" 'raw|ghcr.io/jqlang/jq@sha256:'

  target_lifecycle_profile_status=$(test_target_lifecycle_command default profile status --format manifest)
  target_lifecycle_profile_list=$(test_target_lifecycle_command default profile list --format manifest)
  assert_contains "$target_lifecycle_profile_status" 'shimmy_profile_name=default'
  assert_contains "$target_lifecycle_profile_status" 'shimmy_profile_source_tracking_ref=refs/heads/main'
  assert_contains "$target_lifecycle_profile_status" 'shimmy_profile_ai_skill_bundle=control|valid|'
  assert_contains "$target_lifecycle_profile_list" 'shimmy_profile=default|yes|'

  target_lifecycle_redirect_dry=$(test_target_lifecycle_command default profile redirect set \
    --prefix registry.example --location mirror.example --dry-run)
  assert_contains "$target_lifecycle_redirect_dry" 'prefix = "registry.example"'
  assert_contains "$target_lifecycle_redirect_dry" 'location = "mirror.example"'
  test_target_lifecycle_command default profile redirect set \
    --prefix registry.example --location mirror.example >/dev/null
  target_lifecycle_redirects=$(test_target_lifecycle_command default profile redirect list --format manifest)
  assert_contains "$target_lifecycle_redirects" 'shimmy_profile_redirect=registry.example|mirror.example'
  test_target_lifecycle_command default profile redirect delete --prefix registry.example >/dev/null

  target_lifecycle_shims=$(test_target_lifecycle_command default shim list --format manifest)
  assert_contains "$target_lifecycle_shims" 'shimmy_shim=jq|1.8|tracking|1.8'
  test_target_lifecycle_command default shim add oc@4.18 >/dev/null
  test_target_lifecycle_command default shim add oc@4.20 >/dev/null
  test_target_lifecycle_command default shim set-version oc@4.20 >/dev/null
  test_target_lifecycle_command default shim sync oc@4.20 >/dev/null
  target_lifecycle_smoke=$(test_target_lifecycle_command default shim test oc@4.20)
  assert_contains "$target_lifecycle_smoke" 'shimmy_shim_test=oc|4.20|pass'
  test_target_lifecycle_command default shim remove oc@4.18 >/dev/null
  target_lifecycle_shims=$(test_target_lifecycle_command default shim list --format manifest)
  assert_contains "$target_lifecycle_shims" 'shimmy_shim=oc|4.20|pinned|4.20'
  target_lifecycle_ai=$(test_target_lifecycle_command default ai-skill list --format manifest)
  assert_contains "$target_lifecycle_ai" 'shimmy_ai_skill_bundle=control|valid|6|-'
  assert_contains "$target_lifecycle_ai" 'shimmy_ai_skill=shims|shimmy-tool-oc|shimmy-link-current|'
  test_target_lifecycle_command default ai-skill repair >/dev/null

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

  target_lifecycle_create_shell=$(env HOME="$TARGET_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$TARGET_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_LIFECYCLE_PODMAN" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TARGET_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TARGET_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    TEST_TARGET_LIFECYCLE_SHELL_INIT="$target_lifecycle_default/shell-init.sh" /bin/sh -c '
      . "$TEST_TARGET_LIFECYCLE_SHELL_INIT"
      shimmy profile create team-one
      printf "selected_bin=%s\n" "${PATH%%:*}"
      shimmy profile status --format manifest
    ')
  target_lifecycle_team=$TARGET_LIFECYCLE_CONFIG/profiles/team-one
  assert_contains "$target_lifecycle_create_shell" "selected_bin=$target_lifecycle_team/bin"
  assert_contains "$target_lifecycle_create_shell" 'shimmy_profile_name=team-one'
  assert_equals "$(sed -n '2s/^shimmy_active_profile_name=//p' "$TARGET_LIFECYCLE_CONFIG/active-profile.conf")" team-one
  assert_equals "$(readlink "$TARGET_LIFECYCLE_ACTIVE_LINK")" "$target_lifecycle_team/registries.conf"
  assert_file_contains "$target_lifecycle_team/install-manifest.txt" "shim=skopeo|tracking"
  assert_file_not_contains "$target_lifecycle_team/install-manifest.txt" 'startup_file='

  target_lifecycle_default_shims=$(test_target_lifecycle_command default shim list --format manifest)
  target_lifecycle_team_shims=$(test_target_lifecycle_command team-one shim list --format manifest)
  assert_contains "$target_lifecycle_default_shims" 'shimmy_shim=oc|4.20|pinned|4.20'
  assert_not_contains "$target_lifecycle_team_shims" 'shimmy_shim=oc|'
  target_lifecycle_inactive_image_before=$(cksum < "$TARGET_LIFECYCLE_IMAGE_LOG")
  set +e
  target_lifecycle_inactive_mutation=$(test_target_lifecycle_command default shim add oc@4.22 2>&1)
  target_lifecycle_inactive_status=$?
  set -e
  [ "$target_lifecycle_inactive_status" -ne 0 ] ||
    fail_test 'inactive invoking profile unexpectedly accepted shim mutation'
  assert_contains "$target_lifecycle_inactive_mutation" \
    'shim mutation requires the invoking profile to be active'
  assert_equals "$(cksum < "$TARGET_LIFECYCLE_IMAGE_LOG")" "$target_lifecycle_inactive_image_before"
  target_lifecycle_team_smoke=$(test_target_lifecycle_command team-one shim test rg)
  assert_contains "$target_lifecycle_team_smoke" 'shimmy_shim_test=rg|15.1|pass'
  target_lifecycle_team_ai=$(test_target_lifecycle_command team-one ai-skill list --format manifest)
  assert_contains "$target_lifecycle_team_ai" 'shimmy_ai_skill_bundle=shims|valid|3|-'
  test_target_lifecycle_command team-one ai-skill repair >/dev/null

  for target_lifecycle_asset_profile in default team-one; do
    target_lifecycle_asset_root=$TARGET_LIFECYCLE_CONFIG/profiles/$target_lifecycle_asset_profile
    for target_lifecycle_asset_command in admin-target.sh ai-skill-target.sh \
      catalog-target.sh help-target.sh profile-target.sh shim-target.sh; do
      assert_file_executable "$target_lifecycle_asset_root/commands/$target_lifecycle_asset_command"
      /bin/sh -n "$target_lifecycle_asset_root/commands/$target_lifecycle_asset_command"
    done
    assert_file_executable "$target_lifecycle_asset_root/bin/shimmy"
    /bin/sh -n "$target_lifecycle_asset_root/bin/shimmy"
    /bin/sh -n "$target_lifecycle_asset_root/shell-init.sh"
    for target_lifecycle_asset_shim in "$target_lifecycle_asset_root"/bin/*; do
      [ -f "$target_lifecycle_asset_shim" ] || continue
      /bin/sh -n "$target_lifecycle_asset_shim"
    done
  done

  printf 'broken startup\n' > "$TARGET_LIFECYCLE_HOME/.profile"
  test_target_lifecycle_command default profile repair-startup >/dev/null
  assert_file_contains "$TARGET_LIFECYCLE_HOME/.profile" '# >>> shimmy default profile >>>'

  test_target_catalog_source_advance "$TARGET_LIFECYCLE_CHECKOUT" 'Target lifecycle sync revision.'
  target_lifecycle_publish=$(cd "$TARGET_LIFECYCLE_CHECKOUT" &&
    test_target_lifecycle_command default catalog publish)
  assert_contains "$target_lifecycle_publish" 'shimmy_catalog=default|sha256-'
  target_lifecycle_new_ref=$(git -C "$TARGET_LIFECYCLE_CHECKOUT" rev-parse HEAD)
  test_target_lifecycle_command team-one profile sync >/dev/null
  assert_file_contains "$target_lifecycle_team/install-manifest.txt" "shimmy_source_ref=$target_lifecycle_new_ref"
  assert_equals "$(readlink "$TARGET_LIFECYCLE_ACTIVE_LINK")" "$target_lifecycle_team/registries.conf"
  target_lifecycle_synced_verify=$(test_target_lifecycle_command team-one catalog verify \
    --tool jq@1.8 --format manifest)
  assert_contains "$target_lifecycle_synced_verify" 'image_verify=jq|1.8|runtime|'
  test_target_lifecycle_command team-one catalog rollback >/dev/null
  test_target_lifecycle_command team-one catalog rollback >/dev/null

  mkdir "$TARGET_LIFECYCLE_CONFIG/profiles/broken"
  target_lifecycle_admin=$(test_target_lifecycle_command team-one admin status --format manifest)
  assert_contains "$target_lifecycle_admin" 'shimmy_admin_active_profile=team-one'
  assert_contains "$target_lifecycle_admin" 'shimmy_admin_profile=default|ok|-'
  assert_contains "$target_lifecycle_admin" 'shimmy_admin_profile=team-one|ok|-'
  assert_contains "$target_lifecycle_admin" 'shimmy_admin_profile=broken|error|'
  assert_contains "$target_lifecycle_admin" \
    'shimmy_admin_profile_record=default|shimmy_profile_catalog|default%7C'
  assert_contains "$target_lifecycle_admin" \
    'shimmy_admin_profile_record=team-one|shimmy_profile_name|team-one'
  rmdir "$TARGET_LIFECYCLE_CONFIG/profiles/broken"

  target_lifecycle_network=$(test_target_lifecycle_command team-one admin network \
    --target 198.51.100.1 --host-ip 198.51.100.20 --host-lan 198.51.100.0/24 \
    --format manifest)
  assert_contains "$target_lifecycle_network" 'perspective=shell'
  assert_contains "$target_lifecycle_network" 'host_ipv4=198.51.100.20'
  assert_contains "$target_lifecycle_network" 'host_lan=198.51.100.0/24'

  target_lifecycle_activate_shell=$(env HOME="$TARGET_LIFECYCLE_HOME" \
    XDG_CONFIG_HOME="$TARGET_LIFECYCLE_CONFIG_HOME" \
    SHIMMY_TEST_PROFILE_OS=Linux SHIMMY_TEST_PROFILE_PODMAN_BIN="$TARGET_LIFECYCLE_PODMAN" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_LIFECYCLE_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_LIFECYCLE_SMOKE_LOG" \
    FAKE_PODMAN_LOG="$TARGET_LIFECYCLE_PODMAN_LOG" \
    FAKE_ACTIVE_LINK="$TARGET_LIFECYCLE_ACTIVE_LINK" FAKE_LINUX_INFO=true\|false \
    TEST_TARGET_LIFECYCLE_SHELL_INIT="$target_lifecycle_team/shell-init.sh" /bin/sh -c '
      . "$TEST_TARGET_LIFECYCLE_SHELL_INIT"
      shimmy profile activate default
      printf "selected_bin=%s\n" "${PATH%%:*}"
      shimmy profile status --format manifest
    ')
  assert_contains "$target_lifecycle_activate_shell" "selected_bin=$target_lifecycle_default/bin"
  assert_contains "$target_lifecycle_activate_shell" 'shimmy_profile_name=default'
  test_target_lifecycle_command default profile delete team-one >/dev/null
  assert_path_not_exists "$target_lifecycle_team"

  test_target_lifecycle_command default admin uninstall >/dev/null
  assert_path_not_exists "$TARGET_LIFECYCLE_CONFIG"
  assert_path_not_exists "$TARGET_LIFECYCLE_ACTIVE_LINK"
  assert_path_not_exists "$TARGET_LIFECYCLE_HOME/.agents/skills/shimmy-catalog"
  assert_file_contains "$target_lifecycle_unrelated/SKILL.md" user-bytes
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
  assert_file_contains "$target_lifecycle_unrelated/SKILL.md" user-bytes
  pass 'private installed launcher completes onboarding, catalog, shim, profile, AI, network, shell, administration, and uninstall flows'
}

test_commands_target_lifecycle_run() {
  test_commands_target_lifecycle_end_to_end
}
