#!/bin/sh

test_commands_target_catalog_inspection() {
  setup_scenario
  target_catalog_checkout=$SCENARIO_DIR/checkout
  target_catalog_config=$SCENARIO_DIR/config/shimmy
  test_target_catalog_fixture_create "$target_catalog_checkout" "$target_catalog_config"
  target_catalog_generation=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_config/catalogs/default/registry.conf")

  target_catalog_status=$(env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" "$ROOT_DIR/commands/catalog-target.sh" status --format manifest)
  target_catalog_tools=$(env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" "$ROOT_DIR/commands/catalog-target.sh" tools --format manifest)
  target_catalog_retained=$(env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" "$ROOT_DIR/commands/catalog-target.sh" tools --generation "$target_catalog_generation" --format manifest)
  assert_contains "$target_catalog_status" "shimmy_catalog=default|$target_catalog_generation||"
  assert_equals "$target_catalog_tools" "$target_catalog_retained"
  assert_contains "$target_catalog_tools" "default|$target_catalog_generation|rg|"
  pass 'private target catalog command renders deterministic local status and retained tools'
}

test_commands_target_catalog_mutation() {
  setup_scenario
  target_catalog_checkout=$SCENARIO_DIR/checkout
  target_catalog_config=$SCENARIO_DIR/config/shimmy
  test_target_catalog_fixture_create "$target_catalog_checkout" "$target_catalog_config"
  target_catalog_initial=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_config/catalogs/default/registry.conf")
  test_target_catalog_source_advance "$target_catalog_checkout" 'Command publication.'
  target_catalog_publish_output=$(cd "$target_catalog_checkout" && env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" ./commands/catalog-target.sh publish)
  target_catalog_published=$(sed -n '3s/^catalog_generation_current=//p' "$target_catalog_config/catalogs/default/registry.conf")
  assert_contains "$target_catalog_publish_output" "shimmy_catalog=default|$target_catalog_published|$target_catalog_initial|"
  target_catalog_rollback_output=$(env SHIMMY_TARGET_CONFIG_ROOT="$target_catalog_config" "$ROOT_DIR/commands/catalog-target.sh" rollback)
  assert_contains "$target_catalog_rollback_output" "shimmy_catalog=default|$target_catalog_initial|$target_catalog_published|"
  pass 'private target catalog command publishes clean main and rolls back without public routing'
}

test_commands_target_catalog_run() {
  test_commands_target_catalog_inspection
  test_commands_target_catalog_mutation
}
