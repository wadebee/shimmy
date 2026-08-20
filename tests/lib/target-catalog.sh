#!/bin/sh

test_target_catalog_checkout_create() {
  test_target_catalog_checkout=$1
  test_fixture_tree_copy "$ROOT_DIR" "$test_target_catalog_checkout"
  rm -rf "$test_target_catalog_checkout/.git"
  git -C "$test_target_catalog_checkout" init -q
  git -C "$test_target_catalog_checkout" symbolic-ref HEAD refs/heads/main
  git -C "$test_target_catalog_checkout" config user.email shimmy-target-tests@example.invalid
  git -C "$test_target_catalog_checkout" config user.name 'Shimmy Target Tests'
  git -C "$test_target_catalog_checkout" add -A
  git -C "$test_target_catalog_checkout" commit -qm initial
}

test_target_catalog_fixture_create() {
  test_target_catalog_fixture_checkout=$1
  test_target_catalog_fixture_config=$2
  mkdir -p "$test_target_catalog_fixture_config"
  test_target_catalog_checkout_create "$test_target_catalog_fixture_checkout"
  shimmy_target_catalog_default_create "$test_target_catalog_fixture_config" "$test_target_catalog_fixture_checkout" ||
    fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
}

test_target_catalog_source_advance() {
  test_target_catalog_advance_checkout=$1
  test_target_catalog_advance_marker=$2
  printf '\n%s\n' "$test_target_catalog_advance_marker" >> "$test_target_catalog_advance_checkout/plugins/shimmy/skills/shimmy-catalog/SKILL.md"
  git -C "$test_target_catalog_advance_checkout" add plugins/shimmy/skills/shimmy-catalog/SKILL.md
  git -C "$test_target_catalog_advance_checkout" commit -qm "$test_target_catalog_advance_marker"
}

test_lib_target_catalog_static_validation() {
  setup_scenario
  target_catalog_payload=$SCENARIO_DIR/payload
  mkdir "$target_catalog_payload"
  cp "$ROOT_DIR/catalog.conf" "$target_catalog_payload/catalog.conf"
  test_fixture_tree_copy "$ROOT_DIR/tools" "$target_catalog_payload/tools"
  test_fixture_tree_copy "$ROOT_DIR/plugins" "$target_catalog_payload/plugins"
  shimmy_target_catalog_payload_validate "$target_catalog_payload" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"

  target_catalog_fingerprint_before=$(shimmy_target_catalog_content_fingerprint_render "$target_catalog_payload")
  printf '\nTool skill fingerprint fixture.\n' >> "$target_catalog_payload/tools/jq/SKILL.md"
  shimmy_target_catalog_payload_validate "$target_catalog_payload" || fail_test 'valid tool skill content change was rejected'
  target_catalog_fingerprint_after=$(shimmy_target_catalog_content_fingerprint_render "$target_catalog_payload")
  [ "$target_catalog_fingerprint_before" != "$target_catalog_fingerprint_after" ] || fail_test 'tool skill bytes did not affect catalog fingerprint'

  sed 's/^name: shimmy-tool-jq$/name: shimmy-tool-wrong/' "$target_catalog_payload/tools/jq/SKILL.md" > "$target_catalog_payload/tools/jq/SKILL.md.tmp"
  mv "$target_catalog_payload/tools/jq/SKILL.md.tmp" "$target_catalog_payload/tools/jq/SKILL.md"
  if shimmy_target_catalog_payload_validate "$target_catalog_payload" >/dev/null 2>&1; then
    fail_test 'mismatched tool skill mapping was accepted'
  fi
  pass 'target catalog validates canonical skills, exact tool mapping, headers, and fingerprint input'
}

test_lib_target_catalog_lifecycle() {
  setup_scenario
  target_catalog_checkout=$SCENARIO_DIR/checkout
  target_catalog_config=$SCENARIO_DIR/config/shimmy
  test_target_catalog_fixture_create "$target_catalog_checkout" "$target_catalog_config"
  target_catalog_registry=$target_catalog_config/catalogs/default/registry.conf
  target_catalog_initial=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_registry")

  target_catalog_status_one=$(shimmy_target_catalog_status_render "$target_catalog_config" manifest)
  target_catalog_status_two=$(shimmy_target_catalog_status_render "$target_catalog_config" manifest)
  assert_equals "$target_catalog_status_one" "$target_catalog_status_two"
  assert_contains "$target_catalog_status_one" "shimmy_catalog=default|$target_catalog_initial||"
  target_catalog_tools=$(shimmy_target_catalog_tools_render "$target_catalog_config" '' manifest)
  assert_contains "$target_catalog_tools" "shimmy_catalog_tool=default|$target_catalog_initial|jq|1.8|1.8"
  assert_contains "$(shimmy_target_catalog_tools_render "$target_catalog_config" '' human)" 'TOOL DEFAULT VERSIONS'

  test_target_catalog_source_advance "$target_catalog_checkout" 'Second catalog generation.'
  shimmy_target_catalog_default_publish "$target_catalog_config" "$target_catalog_checkout" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
  target_catalog_second=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_registry")
  [ "$target_catalog_second" != "$target_catalog_initial" ] || fail_test 'target publication did not advance current'
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$target_catalog_registry")" "$target_catalog_initial"
  target_catalog_registry_checksum=$(cksum < "$target_catalog_registry")
  shimmy_target_catalog_default_publish "$target_catalog_config" "$target_catalog_checkout" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
  assert_equals "$(cksum < "$target_catalog_registry")" "$target_catalog_registry_checksum"
  assert_contains "$(shimmy_target_catalog_tools_render "$target_catalog_config" "$target_catalog_initial" manifest)" "default|$target_catalog_initial|jq"

  shimmy_target_catalog_default_rollback "$target_catalog_config" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
  assert_equals "$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_registry")" "$target_catalog_initial"
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$target_catalog_registry")" "$target_catalog_second"
  assert_dir_exists "$target_catalog_config/catalogs/default/generations/$target_catalog_initial"
  assert_dir_exists "$target_catalog_config/catalogs/default/generations/$target_catalog_second"
  assert_equals "$(find "$target_catalog_config/catalogs/default/generations" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" 2
  pass 'target catalog create, publish, repeat publish, retained inspection, and rollback preserve generations'
}

test_lib_target_catalog_pristine_baseline() {
  setup_scenario
  target_catalog_checkout=$SCENARIO_DIR/checkout
  target_catalog_config=$SCENARIO_DIR/config/shimmy
  test_target_catalog_fixture_create "$target_catalog_checkout" "$target_catalog_config"
  target_catalog_generation=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_config/catalogs/default/registry.conf")
  target_catalog_generation_root=$target_catalog_config/catalogs/default/generations/$target_catalog_generation

  target_catalog_baseline=$(shimmy_target_profile_baseline_render "$target_catalog_generation_root") ||
    fail_test 'private pristine-profile baseline could not be rendered'
  assert_equals "$target_catalog_baseline" 'jq|1.8
rg|15.1
skopeo|1.22'
  pass 'private pristine bootstrap and create candidates select catalog-default jq, rg, and Skopeo'
}

test_lib_target_catalog_invalid_current_recovery() {
  setup_scenario
  target_catalog_checkout=$SCENARIO_DIR/checkout
  target_catalog_config=$SCENARIO_DIR/config/shimmy
  test_target_catalog_fixture_create "$target_catalog_checkout" "$target_catalog_config"
  target_catalog_registry=$target_catalog_config/catalogs/default/registry.conf
  target_catalog_initial=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_registry")
  test_target_catalog_source_advance "$target_catalog_checkout" 'Recovery generation two.'
  shimmy_target_catalog_default_publish "$target_catalog_config" "$target_catalog_checkout" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
  target_catalog_corrupt=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_registry")
  printf 'catalog_corruption=1\n' >> "$target_catalog_config/catalogs/default/generations/$target_catalog_corrupt/catalog.conf"

  shimmy_target_catalog_default_rollback "$target_catalog_config" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
  assert_equals "$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_registry")" "$target_catalog_initial"
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$target_catalog_registry")" ''
  assert_dir_exists "$target_catalog_config/catalogs/default/generations/$target_catalog_corrupt"

  test_target_catalog_source_advance "$target_catalog_checkout" 'Recovery generation three.'
  shimmy_target_catalog_default_publish "$target_catalog_config" "$target_catalog_checkout" || fail_test "$SHIMMY_TARGET_CATALOG_ERROR"
  target_catalog_recovered=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_registry")
  assert_equals "$(sed -n '4s/^catalog_generation_previous=//p' "$target_catalog_registry")" "$target_catalog_initial"
  [ "$target_catalog_recovered" != "$target_catalog_corrupt" ] || fail_test 'publication retained corrupt current authority'
  assert_dir_exists "$target_catalog_config/catalogs/default/generations/$target_catalog_corrupt"
  pass 'target rollback and publication recover invalid current authority without deleting retained generations'
}

test_target_catalog_move_head() {
  test_target_catalog_move_checkout=$1
  printf 'moved\n' > "$test_target_catalog_move_checkout/moved-head"
  git -C "$test_target_catalog_move_checkout" add moved-head
  git -C "$test_target_catalog_move_checkout" commit -qm moved-head
}

test_lib_target_catalog_publication_rejections() {
  setup_scenario
  target_catalog_checkout=$SCENARIO_DIR/checkout
  target_catalog_config=$SCENARIO_DIR/config/shimmy
  test_target_catalog_fixture_create "$target_catalog_checkout" "$target_catalog_config"
  target_catalog_registry=$target_catalog_config/catalogs/default/registry.conf
  target_catalog_registry_checksum=$(cksum < "$target_catalog_registry")

  printf 'dirty\n' > "$target_catalog_checkout/dirty"
  if shimmy_target_catalog_checkout_validate "$target_catalog_checkout" >/dev/null 2>&1; then fail_test 'dirty target publication source was accepted'; fi
  rm "$target_catalog_checkout/dirty"
  git -C "$target_catalog_checkout" checkout -qb topic
  if shimmy_target_catalog_checkout_validate "$target_catalog_checkout" >/dev/null 2>&1; then fail_test 'non-main target publication source was accepted'; fi
  git -C "$target_catalog_checkout" checkout -q main
  git -C "$target_catalog_checkout" checkout -q --detach
  if shimmy_target_catalog_checkout_validate "$target_catalog_checkout" >/dev/null 2>&1; then fail_test 'detached target publication source was accepted'; fi
  git -C "$target_catalog_checkout" checkout -q main

  sed 's/^> Shimmy active-profile reconciliation.*/> malformed/' "$target_catalog_checkout/tools/jq/SKILL.md" > "$target_catalog_checkout/tools/jq/SKILL.md.tmp"
  mv "$target_catalog_checkout/tools/jq/SKILL.md.tmp" "$target_catalog_checkout/tools/jq/SKILL.md"
  git -C "$target_catalog_checkout" add tools/jq/SKILL.md
  git -C "$target_catalog_checkout" commit -qm malformed-skill
  if shimmy_target_catalog_default_publish "$target_catalog_config" "$target_catalog_checkout" >/dev/null 2>&1; then fail_test 'malformed catalog skill was published'; fi
  shimmy_target_catalog_lifecycle_cleanup || true
  shimmy_target_locks_release_all || true
  git -C "$target_catalog_checkout" reset -q --hard HEAD^

  test_target_catalog_source_advance "$target_catalog_checkout" 'Moved HEAD publication.'
  SHIMMY_TARGET_TEST_MODE=1
  SHIMMY_TARGET_TEST_CATALOG_BEFORE_COMMIT_FUNCTION=test_target_catalog_move_head
  if shimmy_target_catalog_default_publish "$target_catalog_config" "$target_catalog_checkout" >/dev/null 2>&1; then fail_test 'moved HEAD target publication was accepted'; fi
  SHIMMY_TARGET_TEST_MODE=0
  SHIMMY_TARGET_TEST_CATALOG_BEFORE_COMMIT_FUNCTION=
  shimmy_target_filesystem_transaction_cleanup || true
  shimmy_target_catalog_lifecycle_cleanup || true
  shimmy_target_locks_release_all || true
  assert_equals "$(cksum < "$target_catalog_registry")" "$target_catalog_registry_checksum"

  target_catalog_current=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_registry")
  printf 'catalog_collision=1\n' >> "$target_catalog_config/catalogs/default/generations/$target_catalog_current/catalog.conf"
  git -C "$target_catalog_checkout" reset -q --hard HEAD^^
  if shimmy_target_catalog_default_publish "$target_catalog_config" "$target_catalog_checkout" >/dev/null 2>&1; then fail_test 'target fingerprint collision was accepted'; fi
  shimmy_target_catalog_lifecycle_cleanup || true
  shimmy_target_locks_release_all || true
  assert_equals "$(cksum < "$target_catalog_registry")" "$target_catalog_registry_checksum"

  mkdir "$target_catalog_config/catalogs/default/generations/UNSAFE"
  if shimmy_target_catalog_status_render "$target_catalog_config" manifest >/dev/null 2>&1; then fail_test 'unsafe retained generation state was accepted'; fi
  pass 'target publication rejects dirty, detached, non-main, moved-HEAD, malformed-skill, collision, and unsafe state'
}

test_lib_target_catalog_run() {
  test_lib_target_catalog_static_validation
  test_lib_target_catalog_lifecycle
  test_lib_target_catalog_pristine_baseline
  test_lib_target_catalog_invalid_current_recovery
  test_lib_target_catalog_publication_rejections
}
