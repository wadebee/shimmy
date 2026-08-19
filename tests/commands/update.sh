#!/bin/sh

test_update_source_repository_create() {
  source_repo=$1
  mkdir -p "$source_repo"
  cp "$ROOT_DIR/install.sh" "$source_repo/install.sh"
  cp "$ROOT_DIR/catalog.conf" "$source_repo/catalog.conf"
  for asset_name in commands lib plugins tests tools; do
    test_fixture_tree_copy "$ROOT_DIR/$asset_name" "$source_repo/$asset_name"
  done
  git -C "$source_repo" init -q
  git -C "$source_repo" config user.email shimmy-tests@example.invalid
  git -C "$source_repo" config user.name 'Shimmy Tests'
  git -C "$source_repo" add .
  git -C "$source_repo" commit -qm initial
}

test_manifest_source_url_replace() {
  manifest_file=$1
  source_url=$2
  manifest_tmp=$manifest_file.tmp
  awk -v source_url="$source_url" '
    BEGIN { replaced=0 }
    /^shimmy_source_url=/ { print "shimmy_source_url=" source_url; replaced=1; next }
    { print }
    END { if (!replaced) print "shimmy_source_url=" source_url }
  ' "$manifest_file" > "$manifest_tmp"
  mv "$manifest_tmp" "$manifest_file"
}

setup_session_update_source_fixture() {
  SHIMMY_TEST_UPDATE_SOURCE_REPOSITORY=$TMP_ROOT/update-source-repository
  test_update_source_repository_create "$SHIMMY_TEST_UPDATE_SOURCE_REPOSITORY"
}

test_commands_update_run() {
  setup_scenario_with_profiles default upstream
  default_shimmy install --shim task --shim oc@4.18 >/dev/null
  selection_before=$(sed -n '/^tool=/p; /^tool_version=/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  update_source=$SHIMMY_TEST_UPDATE_SOURCE_REPOSITORY
  test_manifest_source_url_replace "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "$update_source"
  test_manifest_source_url_replace "$UPSTREAM_PROFILE_ROOT/install-manifest.txt" "$update_source"
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/unmanaged-update-sentinel"
  printf '%s\n' keep > "$DEFAULT_PROFILE_ROOT/bin/unmanaged-bin-sentinel"
  printf '%s\n' '# stale shell init marker' >> "$DEFAULT_PROFILE_ROOT/shell-init.sh"
  upstream_launcher_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/bin/shimmy")
  upstream_manifest_checksum=$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")

  default_shimmy update --shim jq >/dev/null
  assert_file_exists "$DEFAULT_PROFILE_ROOT/unmanaged-update-sentinel"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/bin/unmanaged-bin-sentinel"
  assert_file_contains "$DEFAULT_PROFILE_ROOT/install-manifest.txt" "shimmy_source_url=$update_source"
  assert_file_not_contains "$DEFAULT_PROFILE_ROOT/shell-init.sh" '# stale shell init marker'
  assert_file_mode "$DEFAULT_PROFILE_ROOT/shell-init.sh" 644
  assert_equals "$(readlink "$DEFAULT_PROFILE_ROOT/bin/jq")" '../commands/dispatch-tool.sh'
  selection_after=$(sed -n '/^tool=/p; /^tool_version=/p' "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  assert_equals "$selection_after" "$selection_before"
  assert_path_symlink "$DEFAULT_PROFILE_ROOT/bin/task"
  assert_file_exists "$DEFAULT_PROFILE_ROOT/tools/oc/versions/4.18/run.sh"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/bin/shimmy")" "$upstream_launcher_checksum"
  assert_equals "$(cksum < "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")" "$upstream_manifest_checksum"

  default_launcher_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")
  default_manifest_checksum=$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")
  source_checkout_before=$(sed -n 's/^source_checkout=//p' "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")
  update_tmp=$SCENARIO_DIR/update-tmp
  mkdir -p "$update_tmp"
  env XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" TMPDIR="$update_tmp" "$UPSTREAM_PROFILE_ROOT/bin/shimmy" update --shim jq >/dev/null
  source_checkout_after=$(sed -n 's/^source_checkout=//p' "$UPSTREAM_PROFILE_ROOT/install-manifest.txt")
  assert_equals "$source_checkout_after" "$source_checkout_before"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/tools/jq/versions/1.8/run.sh"
  assert_file_exists "$UPSTREAM_PROFILE_ROOT/commands/run-tool.sh"
  assert_path_not_exists "$UPSTREAM_PROFILE_ROOT/implementations"
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/bin/shimmy")" "$default_launcher_checksum"
  assert_equals "$(cksum < "$DEFAULT_PROFILE_ROOT/install-manifest.txt")" "$default_manifest_checksum"
  for update_entry in "$update_tmp"/shimmy-self-update.*; do
    [ ! -e "$update_entry" ] && [ ! -L "$update_entry" ] || fail_test "self-update temporary source was not removed: $update_entry"
  done
  XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" "$UPSTREAM_PROFILE_ROOT/bin/jq" --preview-shim --version >/dev/null
  pass "self-update is profile-local, cleans temporary source, and preserves profile-owned upstream dispatch"
}
