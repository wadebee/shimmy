#!/bin/sh

test_shim_fake_versions_write() {
  test_shim_fake_checkout=$1
  for test_shim_fake_pair in jq@1.8 oc@4.18 oc@4.20 oc@4.22 rg@15.1 skopeo@1.22; do
    test_shim_fake_tool=${test_shim_fake_pair%%@*}
    test_shim_fake_version=${test_shim_fake_pair#*@}
    test_shim_fake_root=$test_shim_fake_checkout/tools/$test_shim_fake_tool/versions/$test_shim_fake_version
    cat > "$test_shim_fake_root/run.sh" <<EOF
#!/bin/sh
set -eu
printf 'run|$test_shim_fake_tool|$test_shim_fake_version|%s\n' "\$*" >> "\${SHIMMY_TEST_SMOKE_LOG:?}"
[ "\${SHIMMY_TEST_AFFINITY_FAILURE:-}" != 1 ] || exit 19
[ "\${SHIMMY_TEST_SMOKE_FAILURE:-}" != '$test_shim_fake_pair' ] || exit 23
printf 'fake-%s-%s\n' '$test_shim_fake_tool' '$test_shim_fake_version'
EOF
    cat > "$test_shim_fake_root/refresh.sh" <<EOF
#!/bin/sh
set -eu
if [ -n "\${SHIMMY_TEST_REQUIRED_ACTIVE_PROFILE:-}" ]; then
  test_shim_fake_active_path=\${SHIMMY_TEST_ACTIVE_PROFILE_PATH:?}
  [ -f "\$test_shim_fake_active_path" ] && [ ! -L "\$test_shim_fake_active_path" ]
  [ "\$(sed -n '2s/^shimmy_active_profile_name=//p' "\$test_shim_fake_active_path")" = \
    "\$SHIMMY_TEST_REQUIRED_ACTIVE_PROFILE" ]
fi
printf 'image|$test_shim_fake_tool|$test_shim_fake_version|%s\n' "\${1:-}" >> "\${SHIMMY_TEST_IMAGE_LOG:?}"
[ "\${SHIMMY_TEST_IMAGE_FAILURE:-}" != '$test_shim_fake_pair' ] || exit 29
EOF
    chmod 0755 "$test_shim_fake_root/run.sh" "$test_shim_fake_root/refresh.sh"
  done
}

test_shim_fixture_setup() {
  setup_scenario
  TEST_SHIM_CHECKOUT=$SCENARIO_DIR/checkout
  TEST_SHIM_CONFIG=$SCENARIO_DIR/config/shimmy
  TEST_SHIM_IMAGE_LOG=$SCENARIO_DIR/image.log
  TEST_SHIM_SMOKE_LOG=$SCENARIO_DIR/smoke.log
  test_catalog_checkout_create "$TEST_SHIM_CHECKOUT"
  test_shim_fake_versions_write "$TEST_SHIM_CHECKOUT"
  git -C "$TEST_SHIM_CHECKOUT" add tools/jq/versions tools/oc/versions tools/rg/versions tools/skopeo/versions
  git -C "$TEST_SHIM_CHECKOUT" commit -qm shim-fakes
  mkdir -p "$TEST_SHIM_CONFIG"
  shimmy_catalog_default_create "$TEST_SHIM_CONFIG" "$TEST_SHIM_CHECKOUT" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  TEST_SHIM_PINNED_GENERATION=$(sed -n '3s/^catalog_generation_current=//p' "$TEST_SHIM_CONFIG/catalogs/default/registry.conf")
  TEST_SHIM_PINNED_ROOT=$TEST_SHIM_CONFIG/catalogs/default/generations/$TEST_SHIM_PINNED_GENERATION
  TEST_SHIM_PINNED_COMMIT=$(sed -n '1s/^catalog_source_commit=//p' "$TEST_SHIM_PINNED_ROOT/generation.conf")
  TEST_SHIM_PINNED_FINGERPRINT=$(sed -n '2s/^catalog_content_fingerprint=//p' "$TEST_SHIM_PINNED_ROOT/generation.conf")
  TEST_SHIM_PROFILE_ROOT=$TEST_SHIM_CONFIG/profiles/default
  mkdir -p "$TEST_SHIM_PROFILE_ROOT/bin" "$TEST_SHIM_PROFILE_ROOT/tools" "$TEST_SHIM_PROFILE_ROOT/config/shims" \
    "$TEST_SHIM_PROFILE_ROOT/ai-skills" "$SCENARIO_DIR/home/.agents/skills"
  test_fixture_tree_copy "$TEST_SHIM_CHECKOUT/commands" "$TEST_SHIM_PROFILE_ROOT/commands"
  test_fixture_tree_copy "$TEST_SHIM_CHECKOUT/lib" "$TEST_SHIM_PROFILE_ROOT/lib"
  shimmy_active_profile_render default "$SCENARIO_DIR/home/.agents/skills" > "$TEST_SHIM_CONFIG/active-profile.conf"
  shimmy_profile_manifest_render default https://example.invalid/shimmy.git "$TEST_SHIM_PINNED_COMMIT" \
    "default|$TEST_SHIM_PINNED_GENERATION|$TEST_SHIM_PINNED_COMMIT|$TEST_SHIM_PINNED_FINGERPRINT" '' '' \
    > "$TEST_SHIM_PROFILE_ROOT/install-manifest.txt"
  shimmy_shim_bundle_input_render default "$TEST_SHIM_PINNED_GENERATION" "$TEST_SHIM_PINNED_FINGERPRINT" '' \
    > "$TEST_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf"
  shimmy_ai_skill_control_bundle_materialize "$TEST_SHIM_CHECKOUT" "$TEST_SHIM_PINNED_COMMIT" \
    default "$TEST_SHIM_PROFILE_ROOT/ai-skills/control" || fail_test 'unable to create control bundle fixture'
  TEST_SHIM_CONTROL_NAMES=$(sed -n '5,$s/^skill=\([^|]*\)|.*$/\1/p' \
    "$TEST_SHIM_PROFILE_ROOT/ai-skills/control/bundle.conf")
  [ -n "$TEST_SHIM_CONTROL_NAMES" ] || fail_test 'control bundle fixture contains no skills'
  TEST_SHIM_CONTROL_NAME=$(printf '%s\n' "$TEST_SHIM_CONTROL_NAMES" | sed -n '1p')
  TEST_SHIM_CONTROL_COUNT=$(printf '%s\n' "$TEST_SHIM_CONTROL_NAMES" | \
    awk 'NF { count++ } END { print count + 0 }')
  shimmy_ai_skill_shims_bundle_materialize "$TEST_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf" \
    "$TEST_SHIM_PINNED_ROOT" "$TEST_SHIM_PROFILE_ROOT/ai-skills/shims" || fail_test 'unable to create empty shims bundle fixture'
  shimmy_registries_config_render default '' > "$TEST_SHIM_PROFILE_ROOT/registries.conf"
  shimmy_profile_launcher_render "$TEST_SHIM_CONFIG" default > "$TEST_SHIM_PROFILE_ROOT/bin/shimmy"
  shimmy_profile_shell_init_render "$TEST_SHIM_CONFIG" default > "$TEST_SHIM_PROFILE_ROOT/shell-init.sh"
  chmod 0755 "$TEST_SHIM_PROFILE_ROOT/bin/shimmy"
  chmod 0644 "$TEST_SHIM_PROFILE_ROOT/install-manifest.txt" "$TEST_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf" \
    "$TEST_SHIM_PROFILE_ROOT/registries.conf" "$TEST_SHIM_PROFILE_ROOT/shell-init.sh"
  : > "$TEST_SHIM_IMAGE_LOG"
  : > "$TEST_SHIM_SMOKE_LOG"
  shimmy_shim_materialization_validate "$TEST_SHIM_PROFILE_ROOT" "$TEST_SHIM_PINNED_ROOT" || fail_test 'empty shim fixture is invalid'
}

test_shim_run() {
  env \
    HOME="$SCENARIO_DIR/home" \
    SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_INVOKING_PROFILE=default \
    SHIMMY_TEST_IMAGE_LOG="$TEST_SHIM_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_SHIM_SMOKE_LOG" \
    "$ROOT_DIR/commands/shim.sh" "$@"
}

test_commands_shim_selector_lifecycle() {
  test_shim_fixture_setup

  env HOME="$SCENARIO_DIR/home" SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_INVOKING_PROFILE=default \
    SHIMMY_TEST_IMAGE_LOG="$TEST_SHIM_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_SHIM_SMOKE_LOG" \
    SHIMMY_TEST_MODE=1 SHIMMY_TEST_INTERACTIVE_SELECTION=4.18 \
    "$ROOT_DIR/commands/shim.sh" add oc
  test_shim_list=$(test_shim_run list --format manifest)
  assert_contains "$test_shim_list" 'shimmy_shim=oc|4.18|tracking|4.18'
  assert_contains "$(cat "$TEST_SHIM_IMAGE_LOG")" 'image|oc|4.18|build'

  test_shim_run add oc@4.20
  test_shim_list=$(test_shim_run list --format manifest)
  assert_contains "$test_shim_list" 'shimmy_shim=oc|4.18|tracking|4.18,4.20'
  env SHIMMY_TEST_SMOKE_LOG="$TEST_SHIM_SMOKE_LOG" \
    "$TEST_SHIM_PROFILE_ROOT/bin/oc" version >/dev/null
  assert_contains "$(cat "$TEST_SHIM_SMOKE_LOG")" 'run|oc|4.18|version'
  /bin/sh -n "$TEST_SHIM_PROFILE_ROOT/bin/oc"
  /bin/sh -n "$TEST_SHIM_PROFILE_ROOT/config/shims/oc/shim.conf"

  sed 's/^tool_default_version=4.20$/tool_default_version=4.22/' "$TEST_SHIM_CHECKOUT/tools/oc/tool.conf" > "$TEST_SHIM_CHECKOUT/tools/oc/tool.conf.tmp"
  mv "$TEST_SHIM_CHECKOUT/tools/oc/tool.conf.tmp" "$TEST_SHIM_CHECKOUT/tools/oc/tool.conf"
  git -C "$TEST_SHIM_CHECKOUT" add tools/oc/tool.conf
  git -C "$TEST_SHIM_CHECKOUT" commit -qm newer-catalog-default
  shimmy_catalog_default_publish "$TEST_SHIM_CONFIG" "$TEST_SHIM_CHECKOUT" || fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"

  test_shim_run sync oc
  test_shim_list=$(test_shim_run list --format manifest)
  assert_contains "$test_shim_list" 'shimmy_shim=oc|4.20|tracking|4.20'
  assert_not_contains "$test_shim_list" '4.18'
  assert_not_contains "$test_shim_list" '4.22'

  test_shim_run add oc@4.22
  test_shim_run set-version oc@4.22
  test_shim_list=$(test_shim_run list --format manifest)
  assert_contains "$test_shim_list" 'shimmy_shim=oc|4.22|pinned|4.20,4.22'
  : > "$TEST_SHIM_IMAGE_LOG"
  test_shim_run sync oc@4.22
  assert_equals "$(cat "$TEST_SHIM_IMAGE_LOG")" 'image|oc|4.22|build'

  test_shim_run remove oc@4.20
  set +e
  test_shim_remove_output=$(test_shim_run remove oc@4.22 2>&1)
  test_shim_remove_status=$?
  set -e
  [ "$test_shim_remove_status" -ne 0 ] || fail_test 'shim removed its selected default version'
  assert_contains "$test_shim_remove_output" 'cannot remove selected default version'
  test_shim_run remove oc
  assert_equals "$(test_shim_run list --format manifest)" ''
  assert_path_not_exists "$SCENARIO_DIR/home/.agents/skills/shimmy-tool-oc"

  test_shim_run add jq@1.8
  assert_contains "$(test_shim_run list --format manifest)" 'shimmy_shim=jq|1.8|pinned|1.8'
  assert_file_contains "$TEST_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf" 'shim=jq'
  assert_path_symlink "$SCENARIO_DIR/home/.agents/skills/shimmy-tool-jq"
  assert_file_contains "$TEST_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf" 'skill=shimmy-tool-jq|'
  assert_file_not_contains "$TEST_SHIM_PROFILE_ROOT/install-manifest.txt" 'implementation'
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/implementations"
  pass 'shim lifecycle preserves first defaults, pinned sync, role swaps, removals, direct runtimes, and typed bundle input'
}

test_commands_shim_failure_atomicity() {
  test_shim_fixture_setup
  test_shim_manifest_before=$(cksum < "$TEST_SHIM_PROFILE_ROOT/install-manifest.txt")
  test_shim_input_before=$(cksum < "$TEST_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf")

  set +e
  test_shim_failure_output=$(env \
    HOME="$SCENARIO_DIR/home" \
    SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_INVOKING_PROFILE=default \
    SHIMMY_TEST_IMAGE_LOG="$TEST_SHIM_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_SHIM_SMOKE_LOG" \
    SHIMMY_TEST_IMAGE_FAILURE=jq@1.8 \
    "$ROOT_DIR/commands/shim.sh" add jq@1.8 2>&1)
  test_shim_failure_status=$?
  set -e
  [ "$test_shim_failure_status" -ne 0 ] || fail_test 'shim committed after image preparation failure'
  assert_contains "$test_shim_failure_output" 'image preparation failed for jq@1.8'
  assert_equals "$(cksum < "$TEST_SHIM_PROFILE_ROOT/install-manifest.txt")" "$test_shim_manifest_before"
  assert_equals "$(cksum < "$TEST_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf")" "$test_shim_input_before"
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/tools/jq"
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/bin/jq"

  set +e
  test_shim_failure_output=$(env \
    HOME="$SCENARIO_DIR/home" \
    SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_INVOKING_PROFILE=default \
    SHIMMY_TEST_IMAGE_LOG="$TEST_SHIM_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_SHIM_SMOKE_LOG" \
    SHIMMY_TEST_MODE=1 SHIMMY_TEST_SHIM_FAILURE=after-assets \
    "$ROOT_DIR/commands/shim.sh" add jq@1.8 2>&1)
  test_shim_failure_status=$?
  set -e
  [ "$test_shim_failure_status" -ne 0 ] || fail_test 'shim committed after injected candidate failure'
  assert_contains "$test_shim_failure_output" 'injected shim failure after asset replacement'
  assert_equals "$(cksum < "$TEST_SHIM_PROFILE_ROOT/install-manifest.txt")" "$test_shim_manifest_before"
  assert_equals "$(cksum < "$TEST_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf")" "$test_shim_input_before"
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/tools/jq"
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/bin/jq"

  set +e
  test_shim_failure_output=$(env \
    HOME="$SCENARIO_DIR/home" \
    SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_INVOKING_PROFILE=default \
    SHIMMY_TEST_IMAGE_LOG="$TEST_SHIM_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_SHIM_SMOKE_LOG" \
    SHIMMY_TEST_MODE=1 SHIMMY_TEST_AI_SKILL_FAILURE_AFTER=1 \
    "$ROOT_DIR/commands/shim.sh" add jq@1.8 2>&1)
  test_shim_failure_status=$?
  set -e
  [ "$test_shim_failure_status" -ne 0 ] || fail_test 'shim committed after injected AI-skill link failure'
  assert_contains "$test_shim_failure_output" 'injected AI-skill reconciliation failure after link 1'
  assert_equals "$(cksum < "$TEST_SHIM_PROFILE_ROOT/install-manifest.txt")" "$test_shim_manifest_before"
  assert_equals "$(cksum < "$TEST_SHIM_PROFILE_ROOT/config/shim-bundle-input.conf")" "$test_shim_input_before"
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/tools/jq"
  assert_path_not_exists "$TEST_SHIM_PROFILE_ROOT/bin/jq"
  assert_path_not_exists "$SCENARIO_DIR/home/.agents/skills/$TEST_SHIM_CONTROL_NAME"
  assert_file_not_contains "$TEST_SHIM_PROFILE_ROOT/ai-skills/shims/bundle.conf" 'shimmy-tool-jq'
  pass 'image and post-asset failures restore the complete prior shim materialization'
}

test_commands_shim_smoke_selection() {
  test_shim_fixture_setup
  test_shim_run add oc@4.20
  test_shim_run add oc@4.22
  : > "$TEST_SHIM_SMOKE_LOG"

  test_shim_smoke_output=$(test_shim_run test oc)
  assert_contains "$test_shim_smoke_output" 'shimmy_shim_test=oc|4.20|pass'
  assert_equals "$(wc -l < "$TEST_SHIM_SMOKE_LOG" | tr -d ' ')" 1
  : > "$TEST_SHIM_SMOKE_LOG"
  test_shim_smoke_output=$(test_shim_run test oc@4.22)
  assert_contains "$test_shim_smoke_output" 'shimmy_shim_test=oc|4.22|pass'
  assert_equals "$(wc -l < "$TEST_SHIM_SMOKE_LOG" | tr -d ' ')" 1
  : > "$TEST_SHIM_SMOKE_LOG"
  test_shim_smoke_output=$(test_shim_run test)
  assert_contains "$test_shim_smoke_output" 'shimmy_shim_test=oc|4.20|pass'
  assert_contains "$test_shim_smoke_output" 'shimmy_shim_test=oc|4.22|pass'
  assert_equals "$(wc -l < "$TEST_SHIM_SMOKE_LOG" | tr -d ' ')" 2

  set +e
  env HOME="$SCENARIO_DIR/home" SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_INVOKING_PROFILE=default \
    SHIMMY_TEST_IMAGE_LOG="$TEST_SHIM_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_SHIM_SMOKE_LOG" \
    SHIMMY_TEST_AFFINITY_FAILURE=1 \
    "$ROOT_DIR/commands/shim.sh" test oc >/dev/null 2>&1
  test_shim_smoke_status=$?
  set -e
  assert_equals "$test_shim_smoke_status" 19

  set +e
  env HOME="$SCENARIO_DIR/home" SHIMMY_CONFIG_ROOT="$TEST_SHIM_CONFIG" \
    SHIMMY_INVOKING_PROFILE=default \
    SHIMMY_TEST_IMAGE_LOG="$TEST_SHIM_IMAGE_LOG" \
    SHIMMY_TEST_SMOKE_LOG="$TEST_SHIM_SMOKE_LOG" \
    SHIMMY_TEST_SMOKE_FAILURE=oc@4.22 \
    "$ROOT_DIR/commands/shim.sh" test oc@4.22 >/dev/null 2>&1
  test_shim_smoke_status=$?
  set -e
  assert_equals "$test_shim_smoke_status" 23
  pass 'shim smoke selection covers all, tool, exact version, affinity, and wrapped nonzero status'
}

test_commands_shim_run() {
  test_commands_shim_selector_lifecycle
  test_commands_shim_failure_atomicity
  test_commands_shim_smoke_selection
}
