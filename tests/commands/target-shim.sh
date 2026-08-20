#!/bin/sh

test_target_shim_fake_versions_write() {
  test_target_shim_fake_checkout=$1
  for test_target_shim_fake_pair in jq@1.8 oc@4.18 oc@4.20 oc@4.22; do
    test_target_shim_fake_tool=${test_target_shim_fake_pair%%@*}
    test_target_shim_fake_version=${test_target_shim_fake_pair#*@}
    test_target_shim_fake_root=$test_target_shim_fake_checkout/tools/$test_target_shim_fake_tool/versions/$test_target_shim_fake_version
    cat > "$test_target_shim_fake_root/run.sh" <<EOF
#!/bin/sh
set -eu
printf 'run|$test_target_shim_fake_tool|$test_target_shim_fake_version|%s\n' "\$*" >> "\${SHIMMY_TARGET_TEST_SMOKE_LOG:?}"
[ "\${SHIMMY_TARGET_TEST_AFFINITY_FAILURE:-}" != 1 ] || exit 19
[ "\${SHIMMY_TARGET_TEST_SMOKE_FAILURE:-}" != '$test_target_shim_fake_pair' ] || exit 23
printf 'fake-%s-%s\n' '$test_target_shim_fake_tool' '$test_target_shim_fake_version'
EOF
    cat > "$test_target_shim_fake_root/refresh.sh" <<EOF
#!/bin/sh
set -eu
printf 'image|$test_target_shim_fake_tool|$test_target_shim_fake_version|%s\n' "\${1:-}" >> "\${SHIMMY_TARGET_TEST_IMAGE_LOG:?}"
[ "\${SHIMMY_TARGET_TEST_IMAGE_FAILURE:-}" != '$test_target_shim_fake_pair' ] || exit 29
EOF
    chmod 0755 "$test_target_shim_fake_root/run.sh" "$test_target_shim_fake_root/refresh.sh"
  done
}

test_target_shim_fixture_setup() {
  setup_scenario
  TARGET_SHIM_CHECKOUT=$SCENARIO_DIR/checkout
  TARGET_SHIM_CONFIG=$SCENARIO_DIR/config/shimmy
  TARGET_SHIM_IMAGE_LOG=$SCENARIO_DIR/image.log
  TARGET_SHIM_SMOKE_LOG=$SCENARIO_DIR/smoke.log
  test_target_catalog_checkout_create "$TARGET_SHIM_CHECKOUT"
  test_target_shim_fake_versions_write "$TARGET_SHIM_CHECKOUT"
  git -C "$TARGET_SHIM_CHECKOUT" add tools/jq/versions tools/oc/versions
  git -C "$TARGET_SHIM_CHECKOUT" commit -qm target-shim-fakes
  mkdir -p "$TARGET_SHIM_CONFIG"
  shimmy_target_catalog_default_create "$TARGET_SHIM_CONFIG" "$TARGET_SHIM_CHECKOUT" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
  TARGET_SHIM_PINNED_GENERATION=$(sed -n '3s/^catalog_generation_current=//p' "$TARGET_SHIM_CONFIG/catalogs/default/registry.conf")
  TARGET_SHIM_PINNED_ROOT=$TARGET_SHIM_CONFIG/catalogs/default/generations/$TARGET_SHIM_PINNED_GENERATION
  TARGET_SHIM_PINNED_COMMIT=$(sed -n '1s/^catalog_source_commit=//p' "$TARGET_SHIM_PINNED_ROOT/generation.conf")
  TARGET_SHIM_PINNED_FINGERPRINT=$(sed -n '2s/^catalog_content_fingerprint=//p' "$TARGET_SHIM_PINNED_ROOT/generation.conf")
  TARGET_SHIM_PROFILE_ROOT=$TARGET_SHIM_CONFIG/profiles/default
  mkdir -p "$TARGET_SHIM_PROFILE_ROOT/bin" "$TARGET_SHIM_PROFILE_ROOT/tools" "$TARGET_SHIM_PROFILE_ROOT/config/shims" \
    "$TARGET_SHIM_PROFILE_ROOT/ai-skills" "$SCENARIO_DIR/home/.agents/skills"
  shimmy_target_active_profile_render default "$SCENARIO_DIR/home/.agents/skills" > "$TARGET_SHIM_CONFIG/active-profile.conf"
  shimmy_target_profile_manifest_render default https://example.invalid/shimmy.git "$TARGET_SHIM_PINNED_COMMIT" \
    "default|$TARGET_SHIM_PINNED_GENERATION|$TARGET_SHIM_PINNED_COMMIT|$TARGET_SHIM_PINNED_FINGERPRINT" '' '' \
    > "$TARGET_SHIM_PROFILE_ROOT/install-manifest.txt"
  shimmy_target_shim_bundle_input_render default "$TARGET_SHIM_PINNED_GENERATION" "$TARGET_SHIM_PINNED_FINGERPRINT" '' \
    > "$TARGET_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf"
  shimmy_target_ai_skill_control_bundle_materialize "$TARGET_SHIM_CHECKOUT" "$TARGET_SHIM_PINNED_COMMIT" \
    default "$TARGET_SHIM_PROFILE_ROOT/ai-skills/control" || fail_test 'unable to create target control bundle fixture'
  shimmy_target_ai_skill_shims_bundle_materialize "$TARGET_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf" \
    "$TARGET_SHIM_PINNED_ROOT" "$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims" || fail_test 'unable to create empty target shims bundle fixture'
  chmod 0644 "$TARGET_SHIM_PROFILE_ROOT/install-manifest.txt" "$TARGET_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf"
  : > "$TARGET_SHIM_IMAGE_LOG"
  : > "$TARGET_SHIM_SMOKE_LOG"
  shimmy_target_shim_materialization_validate "$TARGET_SHIM_PROFILE_ROOT" "$TARGET_SHIM_PINNED_ROOT" || fail_test 'empty target shim fixture is invalid'
}

test_target_shim_run() {
  env \
    HOME="$SCENARIO_DIR/home" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_SHIM_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_SHIM_SMOKE_LOG" \
    "$ROOT_DIR/commands/shim-target.sh" "$@"
}

test_commands_target_shim_selector_lifecycle() {
  test_target_shim_fixture_setup

  env HOME="$SCENARIO_DIR/home" SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_SHIM_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_SHIM_SMOKE_LOG" \
    SHIMMY_TARGET_TEST_MODE=1 SHIMMY_TARGET_TEST_INTERACTIVE_SELECTION=4.18 \
    "$ROOT_DIR/commands/shim-target.sh" add oc
  target_shim_list=$(test_target_shim_run list --format manifest)
  assert_contains "$target_shim_list" 'shimmy_shim=oc|4.18|tracking|4.18'
  assert_contains "$(cat "$TARGET_SHIM_IMAGE_LOG")" 'image|oc|4.18|build'

  test_target_shim_run add oc@4.20
  target_shim_list=$(test_target_shim_run list --format manifest)
  assert_contains "$target_shim_list" 'shimmy_shim=oc|4.18|tracking|4.18,4.20'
  env SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_SHIM_SMOKE_LOG" \
    "$TARGET_SHIM_PROFILE_ROOT/bin/oc" version >/dev/null
  assert_contains "$(cat "$TARGET_SHIM_SMOKE_LOG")" 'run|oc|4.18|version'
  /bin/sh -n "$TARGET_SHIM_PROFILE_ROOT/bin/oc"
  /bin/sh -n "$TARGET_SHIM_PROFILE_ROOT/config/shims/oc/shim.conf"

  sed 's/^tool_default_version=4.20$/tool_default_version=4.22/' "$TARGET_SHIM_CHECKOUT/tools/oc/tool.conf" > "$TARGET_SHIM_CHECKOUT/tools/oc/tool.conf.tmp"
  mv "$TARGET_SHIM_CHECKOUT/tools/oc/tool.conf.tmp" "$TARGET_SHIM_CHECKOUT/tools/oc/tool.conf"
  git -C "$TARGET_SHIM_CHECKOUT" add tools/oc/tool.conf
  git -C "$TARGET_SHIM_CHECKOUT" commit -qm newer-catalog-default
  shimmy_target_catalog_default_publish "$TARGET_SHIM_CONFIG" "$TARGET_SHIM_CHECKOUT" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"

  test_target_shim_run sync oc
  target_shim_list=$(test_target_shim_run list --format manifest)
  assert_contains "$target_shim_list" 'shimmy_shim=oc|4.20|tracking|4.20'
  assert_not_contains "$target_shim_list" '4.18'
  assert_not_contains "$target_shim_list" '4.22'

  test_target_shim_run add oc@4.22
  test_target_shim_run set-version oc@4.22
  target_shim_list=$(test_target_shim_run list --format manifest)
  assert_contains "$target_shim_list" 'shimmy_shim=oc|4.22|pinned|4.20,4.22'
  : > "$TARGET_SHIM_IMAGE_LOG"
  test_target_shim_run sync oc@4.22
  assert_equals "$(cat "$TARGET_SHIM_IMAGE_LOG")" 'image|oc|4.22|build'

  test_target_shim_run remove oc@4.20
  set +e
  target_shim_remove_output=$(test_target_shim_run remove oc@4.22 2>&1)
  target_shim_remove_status=$?
  set -e
  [ "$target_shim_remove_status" -ne 0 ] || fail_test 'target shim removed its selected default version'
  assert_contains "$target_shim_remove_output" 'cannot remove selected default version'
  test_target_shim_run remove oc
  assert_equals "$(test_target_shim_run list --format manifest)" ''
  assert_path_not_exists "$SCENARIO_DIR/home/.agents/skills/shimmy-tool-oc"

  test_target_shim_run add jq@1.8
  assert_contains "$(test_target_shim_run list --format manifest)" 'shimmy_shim=jq|1.8|pinned|1.8'
  assert_file_contains "$TARGET_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf" 'shim=jq'
  assert_path_symlink "$SCENARIO_DIR/home/.agents/skills/shimmy-tool-jq"
  assert_file_contains "$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf" 'skill=shimmy-tool-jq|'
  assert_file_not_contains "$TARGET_SHIM_PROFILE_ROOT/install-manifest.txt" 'implementation'
  assert_path_not_exists "$TARGET_SHIM_PROFILE_ROOT/implementations"
  pass 'private target shim lifecycle preserves first defaults, pinned sync, role swaps, removals, direct runtimes, and typed bundle input'
}

test_commands_target_shim_failure_atomicity() {
  test_target_shim_fixture_setup
  target_shim_manifest_before=$(cksum < "$TARGET_SHIM_PROFILE_ROOT/install-manifest.txt")
  target_shim_input_before=$(cksum < "$TARGET_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf")

  set +e
  target_shim_failure_output=$(env \
    HOME="$SCENARIO_DIR/home" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_SHIM_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_SHIM_SMOKE_LOG" \
    SHIMMY_TARGET_TEST_IMAGE_FAILURE=jq@1.8 \
    "$ROOT_DIR/commands/shim-target.sh" add jq@1.8 2>&1)
  target_shim_failure_status=$?
  set -e
  [ "$target_shim_failure_status" -ne 0 ] || fail_test 'target shim committed after image preparation failure'
  assert_contains "$target_shim_failure_output" 'image preparation failed for jq@1.8'
  assert_equals "$(cksum < "$TARGET_SHIM_PROFILE_ROOT/install-manifest.txt")" "$target_shim_manifest_before"
  assert_equals "$(cksum < "$TARGET_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf")" "$target_shim_input_before"
  assert_path_not_exists "$TARGET_SHIM_PROFILE_ROOT/tools/jq"
  assert_path_not_exists "$TARGET_SHIM_PROFILE_ROOT/bin/jq"

  set +e
  target_shim_failure_output=$(env \
    HOME="$SCENARIO_DIR/home" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_SHIM_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_SHIM_SMOKE_LOG" \
    SHIMMY_TARGET_TEST_MODE=1 SHIMMY_TARGET_TEST_SHIM_FAILURE=after-assets \
    "$ROOT_DIR/commands/shim-target.sh" add jq@1.8 2>&1)
  target_shim_failure_status=$?
  set -e
  [ "$target_shim_failure_status" -ne 0 ] || fail_test 'target shim committed after injected candidate failure'
  assert_contains "$target_shim_failure_output" 'injected target shim failure after asset replacement'
  assert_equals "$(cksum < "$TARGET_SHIM_PROFILE_ROOT/install-manifest.txt")" "$target_shim_manifest_before"
  assert_equals "$(cksum < "$TARGET_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf")" "$target_shim_input_before"
  assert_path_not_exists "$TARGET_SHIM_PROFILE_ROOT/tools/jq"
  assert_path_not_exists "$TARGET_SHIM_PROFILE_ROOT/bin/jq"

  set +e
  target_shim_failure_output=$(env \
    HOME="$SCENARIO_DIR/home" \
    SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_SHIM_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_SHIM_SMOKE_LOG" \
    SHIMMY_TARGET_TEST_MODE=1 SHIMMY_TARGET_TEST_AI_SKILL_FAILURE_AFTER=1 \
    "$ROOT_DIR/commands/shim-target.sh" add jq@1.8 2>&1)
  target_shim_failure_status=$?
  set -e
  [ "$target_shim_failure_status" -ne 0 ] || fail_test 'target shim committed after injected AI-skill link failure'
  assert_contains "$target_shim_failure_output" 'injected AI-skill reconciliation failure after link 1'
  assert_equals "$(cksum < "$TARGET_SHIM_PROFILE_ROOT/install-manifest.txt")" "$target_shim_manifest_before"
  assert_equals "$(cksum < "$TARGET_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf")" "$target_shim_input_before"
  assert_path_not_exists "$TARGET_SHIM_PROFILE_ROOT/tools/jq"
  assert_path_not_exists "$TARGET_SHIM_PROFILE_ROOT/bin/jq"
  assert_path_not_exists "$SCENARIO_DIR/home/.agents/skills/shimmy-catalog"
  assert_file_not_contains "$TARGET_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf" 'shimmy-tool-jq'
  pass 'image and post-asset failures restore the complete prior target shim materialization'
}

test_commands_target_shim_smoke_selection() {
  test_target_shim_fixture_setup
  test_target_shim_run add oc@4.20
  test_target_shim_run add oc@4.22
  : > "$TARGET_SHIM_SMOKE_LOG"

  target_shim_smoke_output=$(test_target_shim_run test oc)
  assert_contains "$target_shim_smoke_output" 'shimmy_shim_test=oc|4.20|pass'
  assert_equals "$(wc -l < "$TARGET_SHIM_SMOKE_LOG" | tr -d ' ')" 1
  : > "$TARGET_SHIM_SMOKE_LOG"
  target_shim_smoke_output=$(test_target_shim_run test oc@4.22)
  assert_contains "$target_shim_smoke_output" 'shimmy_shim_test=oc|4.22|pass'
  assert_equals "$(wc -l < "$TARGET_SHIM_SMOKE_LOG" | tr -d ' ')" 1
  : > "$TARGET_SHIM_SMOKE_LOG"
  target_shim_smoke_output=$(test_target_shim_run test)
  assert_contains "$target_shim_smoke_output" 'shimmy_shim_test=oc|4.20|pass'
  assert_contains "$target_shim_smoke_output" 'shimmy_shim_test=oc|4.22|pass'
  assert_equals "$(wc -l < "$TARGET_SHIM_SMOKE_LOG" | tr -d ' ')" 2

  set +e
  env HOME="$SCENARIO_DIR/home" SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_SHIM_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_SHIM_SMOKE_LOG" \
    SHIMMY_TARGET_TEST_AFFINITY_FAILURE=1 \
    "$ROOT_DIR/commands/shim-target.sh" test oc >/dev/null 2>&1
  target_shim_smoke_status=$?
  set -e
  assert_equals "$target_shim_smoke_status" 19

  set +e
  env HOME="$SCENARIO_DIR/home" SHIMMY_TARGET_CONFIG_ROOT="$TARGET_SHIM_CONFIG" \
    SHIMMY_TARGET_TEST_IMAGE_LOG="$TARGET_SHIM_IMAGE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_LOG="$TARGET_SHIM_SMOKE_LOG" \
    SHIMMY_TARGET_TEST_SMOKE_FAILURE=oc@4.22 \
    "$ROOT_DIR/commands/shim-target.sh" test oc@4.22 >/dev/null 2>&1
  target_shim_smoke_status=$?
  set -e
  assert_equals "$target_shim_smoke_status" 23
  pass 'private target shim smoke selection covers all, tool, exact version, affinity, and wrapped nonzero status'
}

test_commands_target_shim_run() {
  test_commands_target_shim_selector_lifecycle
  test_commands_target_shim_failure_atomicity
  test_commands_target_shim_smoke_selection
}
