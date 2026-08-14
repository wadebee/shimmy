#!/bin/sh

# shellcheck source=lib/install/catalog-lifecycle.sh
. "$ROOT_DIR/lib/install/catalog-lifecycle.sh"

test_catalog_tool_create() {
  catalog_checkout=$1
  catalog_tool_name=$2
  cp -R "$catalog_checkout/tools/jq" "$catalog_checkout/tools/$catalog_tool_name"
  sed "s/^shim_name=jq$/shim_name=$catalog_tool_name/" "$catalog_checkout/tools/$catalog_tool_name/tool.conf" > "$catalog_checkout/tools/$catalog_tool_name/tool.conf.tmp"
  mv "$catalog_checkout/tools/$catalog_tool_name/tool.conf.tmp" "$catalog_checkout/tools/$catalog_tool_name/tool.conf"
  sed "s/^shim_name=jq_1_8$/shim_name=${catalog_tool_name}_1_8/" "$catalog_checkout/tools/$catalog_tool_name/versions/1.8/smoke.conf" > "$catalog_checkout/tools/$catalog_tool_name/versions/1.8/smoke.conf.tmp"
  mv "$catalog_checkout/tools/$catalog_tool_name/versions/1.8/smoke.conf.tmp" "$catalog_checkout/tools/$catalog_tool_name/versions/1.8/smoke.conf"
  sed "s/^name: shimmy-tool-jq$/name: shimmy-tool-$catalog_tool_name/" "$catalog_checkout/tools/$catalog_tool_name/SKILL.md" > "$catalog_checkout/tools/$catalog_tool_name/SKILL.md.tmp"
  mv "$catalog_checkout/tools/$catalog_tool_name/SKILL.md.tmp" "$catalog_checkout/tools/$catalog_tool_name/SKILL.md"
}

test_commands_catalog_dirty_initial_publication_rejection() {
  setup_scenario
  dirty_checkout=$SCENARIO_DIR/dirty-checkout
  cp -R "$SHIMMY_TEST_CLEAN_SOURCE_ROOT" "$dirty_checkout"
  printf '%s\n' dirty > "$dirty_checkout/untracked-publication-sentinel"

  set +e
  dirty_output=$(
    cd "$dirty_checkout"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile default --no-startup 2>&1
  )
  dirty_status=$?
  set -e
  [ "$dirty_status" -ne 0 ] || fail_test 'dirty initial default publication unexpectedly succeeded'
  assert_contains "$dirty_output" 'refusing to publish catalog from dirty checkout'
  assert_contains "$dirty_output" 'commit all index, worktree, and untracked changes first'
  assert_path_not_exists "$DEFAULT_PROFILE_ROOT"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default"
  pass "dirty initial default publication rejects before profile, registry, staging, or generation mutation"
}

test_commands_catalog_registration_collision() {
  setup_scenario
  mkdir -p "$XDG_CONFIG_HOME_DIR/shimmy"
  cp -R "$SHIMMY_TEST_CATALOG_FIXTURES_ROOT" "$XDG_CONFIG_HOME_DIR/shimmy/catalogs"
  collision_checkout=$SCENARIO_DIR/collision-checkout
  cp -R "$SHIMMY_TEST_CLEAN_SOURCE_ROOT" "$collision_checkout"
  registry_file=$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf
  registry_checksum=$(cksum < "$registry_file")

  set +e
  collision_output=$(
    cd "$collision_checkout"
    env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" ./install.sh --profile upstream --no-startup 2>&1
  )
  collision_status=$?
  set -e
  [ "$collision_status" -ne 0 ] || fail_test 'second checkout silently replaced upstream registration'
  assert_contains "$collision_output" 'upstream catalog is already bound to'
  assert_contains "$collision_output" 'shimmy catalog rebind --checkout'
  assert_equals "$(cksum < "$registry_file")" "$registry_checksum"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
  pass "a second checkout cannot silently replace the upstream registry authority"
}

test_commands_catalog_registry_symlink_rejection() {
  setup_scenario
  mkdir -p "$XDG_CONFIG_HOME_DIR/shimmy" "$SCENARIO_DIR/catalog-target"
  ln -s "$SCENARIO_DIR/catalog-target" "$XDG_CONFIG_HOME_DIR/shimmy/catalogs"

  set +e
  symlink_output=$(bootstrap_upstream 2>&1)
  symlink_status=$?
  set -e
  [ "$symlink_status" -ne 0 ] || fail_test 'symlinked shared catalog root unexpectedly accepted'
  assert_contains "$symlink_output" 'catalog registry root has a symbolic-link path component'
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT"
  assert_path_not_exists "$SCENARIO_DIR/catalog-target/upstream"
  pass "shared catalog registry mutation rejects symlink traversal"
}

test_commands_catalog_rebind_and_publish() {
  setup_scenario_with_profiles default upstream
  replacement_checkout=$SCENARIO_DIR/replacement-checkout
  cp -R "$SHIMMY_TEST_CLEAN_SOURCE_ROOT" "$replacement_checkout"
  upstream_registry=$XDG_CONFIG_HOME_DIR/shimmy/catalogs/upstream/registry.conf
  default_registry=$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/registry.conf
  upstream_registry_checksum=$(cksum < "$upstream_registry")

  invalid_checkout=$SCENARIO_DIR/invalid-checkout
  mkdir "$invalid_checkout"
  set +e
  invalid_output=$(upstream_shimmy catalog rebind --checkout "$invalid_checkout" 2>&1)
  invalid_status=$?
  set -e
  [ "$invalid_status" -ne 0 ] || fail_test 'invalid upstream rebind unexpectedly succeeded'
  assert_contains "$invalid_output" 'missing regular payload identity file'
  assert_equals "$(cksum < "$upstream_registry")" "$upstream_registry_checksum"

  rebind_output=$(upstream_shimmy catalog rebind --checkout "$replacement_checkout")
  assert_contains "$rebind_output" "prior_source_path=$ROOT_DIR"
  assert_contains "$rebind_output" "new_source_path=$replacement_checkout"
  assert_file_contains "$upstream_registry" "catalog_source_path=$replacement_checkout"
  assert_dir_exists "$ROOT_DIR"
  assert_dir_exists "$replacement_checkout"

  initial_default_generation=$(profile_manifest_value "$default_registry" catalog_generation_current)
  default_registry_checksum=$(cksum < "$default_registry")
  default_manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  upstream_manifest_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")
  test_catalog_tool_create "$replacement_checkout" instant
  cp -R "$replacement_checkout/tools/jq/versions/1.8" "$replacement_checkout/tools/jq/versions/1.9"
  sed 's/^shim_name=jq_1_8$/shim_name=jq_1_9/' "$replacement_checkout/tools/jq/versions/1.9/smoke.conf" > "$replacement_checkout/tools/jq/versions/1.9/smoke.conf.tmp"
  mv "$replacement_checkout/tools/jq/versions/1.9/smoke.conf.tmp" "$replacement_checkout/tools/jq/versions/1.9/smoke.conf"
  sed 's|^image_upstream_ref=ghcr.io/jqlang/jq:1.8.1$|image_upstream_ref=ghcr.io/jqlang/jq:catalog-new|' "$replacement_checkout/tools/jq/versions/1.8/image.conf" > "$replacement_checkout/tools/jq/versions/1.8/image.conf.tmp"
  mv "$replacement_checkout/tools/jq/versions/1.8/image.conf.tmp" "$replacement_checkout/tools/jq/versions/1.8/image.conf"

  upstream_available=$(upstream_shimmy status --available --format manifest)
  assert_contains "$upstream_available" 'shimmy_available_tool=instant'
  default_available=$(default_shimmy status --available --format manifest)
  assert_not_contains "$default_available" 'shimmy_available_tool=instant'

  set +e
  dirty_publish_output=$(upstream_shimmy catalog publish 2>&1)
  dirty_publish_status=$?
  set -e
  [ "$dirty_publish_status" -ne 0 ] || fail_test 'dirty upstream publication unexpectedly succeeded'
  assert_contains "$dirty_publish_output" 'refusing to publish catalog from dirty checkout'
  assert_contains "$dirty_publish_output" 'commit all index, worktree, and untracked changes first'
  assert_equals "$(cksum < "$default_registry")" "$default_registry_checksum"
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$default_manifest_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$upstream_manifest_checksum"
  for catalog_stage in "$XDG_CONFIG_HOME_DIR/shimmy/catalogs"/.default.stage.* "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default"/.publish-stage.*; do
    [ ! -e "$catalog_stage" ] && [ ! -L "$catalog_stage" ] || fail_test "dirty publication left staging state: $catalog_stage"
  done

  git -C "$replacement_checkout" add tools/instant tools/jq/versions/1.8/image.conf tools/jq/versions/1.9
  git -C "$replacement_checkout" commit -qm 'add instant catalog tool'
  published_head=$(git -C "$replacement_checkout" rev-parse HEAD)
  printf '%s\n' 'tools/instant/ignored-publication-sentinel' >> "$replacement_checkout/.git/info/exclude"
  printf '%s\n' ignored > "$replacement_checkout/tools/instant/ignored-publication-sentinel"
  [ -z "$(git -C "$replacement_checkout" status --porcelain --untracked-files=all)" ] || fail_test 'ignored publication fixture is unexpectedly dirty'

  publish_output=$(upstream_shimmy catalog publish)
  published_generation=$(profile_manifest_value "$default_registry" catalog_generation_current)
  published_previous=$(profile_manifest_value "$default_registry" catalog_generation_previous)
  published_fingerprint=$(profile_manifest_value "$default_registry" catalog_content_fingerprint)
  published_registry_checksum=$(cksum < "$default_registry")
  assert_contains "$publish_output" "Published default catalog generation: $published_generation"
  assert_contains "$publish_output" "source_commit=$published_head"
  assert_contains "$publish_output" "content_fingerprint=$published_fingerprint"
  [ "$published_generation" != "$initial_default_generation" ] || fail_test 'publication did not advance the default generation'
  assert_equals "$published_previous" "$initial_default_generation"
  assert_dir_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$published_previous"
  assert_dir_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$published_generation"
  assert_path_not_exists "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$published_generation/tools/instant/ignored-publication-sentinel"
  assert_file_contains "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$published_generation/generation.conf" "catalog_source_commit=$published_head"
  assert_file_contains "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$published_generation/generation.conf" "catalog_content_fingerprint=$published_fingerprint"
  published_default_status=$(default_shimmy status --available --format manifest)
  assert_contains "$published_default_status" 'shimmy_available_tool=instant'
  assert_contains "$published_default_status" 'shimmy_profile_tool_version=jq|1.8|jq_1_8'
  assert_not_contains "$published_default_status" 'shimmy_profile_tool_version=jq|1.9|jq_1_9'
  SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR=$DEFAULT_PROFILE_ROOT/tools
  SHIMMY_IMAGES_USE_PROFILE_METADATA=1
  materialized_image_records=$(shimmy_images_config_records_print jq jq_1_8)
  assert_contains "$materialized_image_records" 'ghcr.io/jqlang/jq:1.8.1'
  assert_not_contains "$materialized_image_records" 'ghcr.io/jqlang/jq:catalog-new'
  shimmy_catalog_registry_resolve "$XDG_CONFIG_HOME_DIR/shimmy" default || fail_test "$SHIMMY_CATALOG_ERROR"
  SHIMMY_IMAGES_USE_PROFILE_METADATA=0
  catalog_image_records=$(shimmy_images_config_records_print jq jq_1_8)
  assert_contains "$catalog_image_records" 'ghcr.io/jqlang/jq:catalog-new'
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$default_manifest_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$upstream_manifest_checksum"

  SHIMMY_CATALOG_PUBLICATION_CHECKOUT=$replacement_checkout
  SHIMMY_CATALOG_PUBLICATION_HEAD=$published_head
  printf '%s\n' changed > "$replacement_checkout/head-change-sentinel"
  git -C "$replacement_checkout" add head-change-sentinel
  git -C "$replacement_checkout" commit -qm 'advance checkout during publication fixture'
  if shimmy_catalog_checkout_recheck >/dev/null 2>&1; then
    fail_test 'publication checkout recheck accepted a changed HEAD'
  fi
  assert_contains "$SHIMMY_CATALOG_ERROR" 'HEAD changed during publication'

  printf '%s\n' 'catalog_test_corruption=1' >> "$XDG_CONFIG_HOME_DIR/shimmy/catalogs/default/generations/$published_previous/catalog.conf"
  set +e
  corrupt_rollback_output=$(default_shimmy status --format manifest 2>&1)
  corrupt_rollback_status=$?
  set -e
  [ "$corrupt_rollback_status" -ne 0 ] || fail_test 'corrupt retained rollback generation unexpectedly resolved'
  assert_contains "$corrupt_rollback_output" 'unknown key catalog_test_corruption'
  assert_equals "$(cksum < "$default_registry")" "$published_registry_checksum"
  SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR=
  SHIMMY_IMAGES_USE_PROFILE_METADATA=0
  test_lib_catalog_activate
  pass "explicit rebind and clean publication preserve authority, provenance, ignored-content, profile, checkout-race, and rollback boundaries"
}

test_commands_catalog_run() {
  test_commands_catalog_dirty_initial_publication_rejection
  test_commands_catalog_registration_collision
  test_commands_catalog_registry_symlink_rejection
  test_commands_catalog_rebind_and_publish
}
