#!/bin/sh

test_lib_ai_skill_link_fixture_create() {
  setup_scenario
  TEST_LINK_PROFILES_ROOT=$SCENARIO_DIR/config/shimmy/profiles
  TEST_LINK_USER_ROOT=$SCENARIO_DIR/home/.agents/skills
  TEST_LINK_BUNDLES_ROOT=$TEST_LINK_PROFILES_ROOT/team-one/ai-skills
  mkdir -p "$TEST_LINK_USER_ROOT" "$TEST_LINK_BUNDLES_ROOT"
  test_lib_ai_skill_bundle_fixture_create "$TEST_LINK_BUNDLES_ROOT"
  TEST_LINK_CONTROL_BUNDLE=$TEST_LINK_BUNDLES_ROOT/control
  TEST_LINK_SHIMS_BUNDLE=$TEST_LINK_BUNDLES_ROOT/shims
  TEST_LINK_CONTROL_NAME=$(sed -n '5s/^skill=\([^|]*\)|.*$/\1/p' \
    "$TEST_LINK_CONTROL_BUNDLE/bundle.conf")
  [ -n "$TEST_LINK_CONTROL_NAME" ] || fail_test 'control link fixture contains no skills'
}

test_lib_ai_skill_link_classification() {
  test_lib_ai_skill_link_fixture_create
  link_name=$TEST_LINK_CONTROL_NAME
  link_destination=$TEST_LINK_USER_ROOT/$link_name
  shimmy_ai_skill_link_plan "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_CONTROL_BUNDLE" "$link_name" || fail_test 'empty link plan failed'
  assert_equals "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" empty

  printf 'foreign-file\n' > "$link_destination"
  shimmy_ai_skill_link_plan "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_CONTROL_BUNDLE" "$link_name" || fail_test 'file link plan failed'
  assert_equals "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" file
  rm -f "$link_destination"

  mkdir "$link_destination"
  printf 'foreign-directory\n' > "$link_destination/payload"
  shimmy_ai_skill_link_plan "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_CONTROL_BUNDLE" "$link_name" || fail_test 'directory link plan failed'
  assert_equals "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" directory-nonempty
  rm -f "$link_destination/payload"
  rmdir "$link_destination"

  foreign_target=$SCENARIO_DIR/foreign-target
  printf 'foreign-link\n' > "$foreign_target"
  ln -s "$foreign_target" "$link_destination"
  shimmy_ai_skill_link_plan "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_CONTROL_BUNDLE" "$link_name" || fail_test 'foreign link plan failed'
  assert_equals "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" foreign-link
  rm -f "$link_destination"

  wrong_profile_target=$TEST_LINK_PROFILES_ROOT/team-two/ai-skills/control/skills/$link_name
  mkdir -p "$wrong_profile_target"
  ln -s "$wrong_profile_target" "$link_destination"
  shimmy_ai_skill_link_plan "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_CONTROL_BUNDLE" "$link_name" || fail_test 'wrong-profile link plan failed'
  assert_equals "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" shimmy-link-wrong-profile
  rm -f "$link_destination"

  ln -s "$SCENARIO_DIR/missing-foreign-target" "$link_destination"
  shimmy_ai_skill_link_plan "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_CONTROL_BUNDLE" "$link_name" || fail_test 'broken link plan failed'
  assert_equals "$SHIMMY_AI_SKILL_LINK_CLASSIFICATION" foreign-link-broken
  rm -f "$link_destination"
  pass 'exact link planning classifies empty, file, nonempty directory, foreign, wrong-profile, and broken occupants without mutation'
}

test_lib_ai_skill_link_exact_mutation() {
  test_lib_ai_skill_link_fixture_create
  root_marker=$TEST_LINK_USER_ROOT/root-marker
  sibling_root=$TEST_LINK_USER_ROOT/custom-skill
  mkdir "$sibling_root"
  printf 'root-survives\n' > "$root_marker"
  printf 'sibling-survives\n' > "$sibling_root/SKILL.md"
  root_before=$(cksum < "$root_marker")
  sibling_before=$(cksum < "$sibling_root/SKILL.md")

  control_destination=$TEST_LINK_USER_ROOT/$TEST_LINK_CONTROL_NAME
  alpha_destination=$TEST_LINK_USER_ROOT/shimmy-tool-alpha
  beta_destination=$TEST_LINK_USER_ROOT/shimmy-tool-beta
  printf 'foreign-file\n' > "$control_destination"
  mkdir "$alpha_destination"
  printf 'foreign-directory\n' > "$alpha_destination/payload"
  foreign_link_target=$SCENARIO_DIR/foreign-link-target
  printf 'foreign-link\n' > "$foreign_link_target"
  ln -s "$foreign_link_target" "$beta_destination"

  shimmy_external_transaction_begin || fail_test 'link external transaction begin failed'
  shimmy_ai_skill_link_replace "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" \
    "$TEST_LINK_CONTROL_BUNDLE" "$TEST_LINK_CONTROL_NAME" || fail_test 'file collision replacement failed'
  shimmy_ai_skill_link_replace "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_SHIMS_BUNDLE" shimmy-tool-alpha || fail_test 'directory collision replacement failed'
  shimmy_ai_skill_link_replace "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_SHIMS_BUNDLE" shimmy-tool-beta || fail_test 'foreign-link collision replacement failed'
  assert_path_symlink "$control_destination"
  assert_path_symlink "$alpha_destination"
  assert_path_symlink "$beta_destination"
  assert_equals "$(cksum < "$root_marker")" "$root_before"
  assert_equals "$(cksum < "$sibling_root/SKILL.md")" "$sibling_before"
  link_rollback_output=$SCENARIO_DIR/link-rollback.out
  if shimmy_external_transaction_rollback 'injected link failure' 2> "$link_rollback_output"; then
    fail_test 'foreign collision rollback unexpectedly reported complete'
  fi
  assert_equals "$SHIMMY_EXTERNAL_ROLLBACK_RESULT" incomplete
  [ ! -L "$control_destination" ] && [ ! -e "$control_destination" ] || fail_test 'created control link survived rollback'
  [ ! -L "$alpha_destination" ] && [ ! -e "$alpha_destination" ] || fail_test 'created alpha link survived rollback'
  [ ! -L "$beta_destination" ] && [ ! -e "$beta_destination" ] || fail_test 'created beta link survived rollback'
  assert_equals "$(cksum < "$root_marker")" "$root_before"
  assert_equals "$(cksum < "$sibling_root/SKILL.md")" "$sibling_before"
  assert_file_contains "$link_rollback_output" 'foreign content is not recoverable'

  undeclared_destination=$TEST_LINK_USER_ROOT/not-declared
  printf 'untouched\n' > "$undeclared_destination"
  shimmy_external_transaction_begin || fail_test 'undeclared transaction begin failed'
  if shimmy_ai_skill_link_replace "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_CONTROL_BUNDLE" not-declared; then
    fail_test 'undeclared bundle destination unexpectedly replaced'
  fi
  assert_equals "$(cat "$undeclared_destination")" untouched
  shimmy_external_transaction_commit || fail_test 'undeclared no-op transaction cleanup failed'
  pass 'bundle-declared exact collisions overwrite narrowly while unrelated sibling names and the user root survive byte-for-byte'
}

test_lib_ai_skill_link_recognized_rollback() {
  test_lib_ai_skill_link_fixture_create
  link_name=$TEST_LINK_CONTROL_NAME
  link_destination=$TEST_LINK_USER_ROOT/$link_name
  wrong_profile_target=$TEST_LINK_PROFILES_ROOT/team-two/ai-skills/control/skills/$link_name
  mkdir -p "$wrong_profile_target"
  ln -s "$wrong_profile_target" "$link_destination"
  shimmy_external_transaction_begin || fail_test 'recognized link transaction begin failed'
  shimmy_ai_skill_link_replace "$TEST_LINK_USER_ROOT" "$TEST_LINK_PROFILES_ROOT" "$TEST_LINK_CONTROL_BUNDLE" "$link_name" || fail_test 'recognized link replacement failed'
  assert_equals "$(readlink "$link_destination")" "$TEST_LINK_CONTROL_BUNDLE/skills/$link_name"
  recognized_output=$SCENARIO_DIR/recognized-rollback.out
  shimmy_external_transaction_rollback 'injected recognized-link failure' 2> "$recognized_output" || fail_test 'recognized link rollback reported incomplete'
  assert_equals "$SHIMMY_EXTERNAL_ROLLBACK_RESULT" complete
  assert_equals "$(readlink "$link_destination")" "$wrong_profile_target"
  assert_file_contains "$recognized_output" 'restore prior recognized Shimmy link'
  pass 'recognized Shimmy links roll back exactly and identify the restored Shimmy state'
}

test_lib_ai_skill_link_run() {
  test_lib_ai_skill_link_classification
  test_lib_ai_skill_link_exact_mutation
  test_lib_ai_skill_link_recognized_rollback
}
