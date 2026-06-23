#!/bin/sh
# Install, profile, dispatch, update, and uninstall tests.

test_commands_lifecycle_default_install() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim rg --shim oc@4.18 --no-startup --no-skills >/dev/null

  assert_file_exists "$INSTALL_DIR/install-manifest.txt"
  assert_file_exists "$INSTALL_DIR/profiles/default/install-manifest.txt"
  assert_file_executable "$INSTALL_DIR/bin/shimmy"
  assert_path_symlink "$INSTALL_DIR/bin/jq"
  assert_path_symlink "$INSTALL_DIR/bin/rg"
  assert_file_contains "$INSTALL_DIR/install-manifest.txt" shimmy_install_manifest_version=2
  assert_file_contains "$INSTALL_DIR/install-manifest.txt" default_kind=jq
  assert_file_contains "$INSTALL_DIR/install-manifest.txt" default_kind=rg
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" 'kind_version=jq|1.8|jq_1_8'
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" 'kind_version=rg|15.1|rg_15_1'

  status_output=$(HOME="$HOME_DIR" "$INSTALL_DIR/bin/shimmy" status --format manifest)
  assert_contains "$status_output" shimmy_installed=yes
  assert_contains "$status_output" shimmy_profile_kind=jq
  assert_contains "$status_output" shimmy_profile_kind=rg

  preview_output=$(HOME="$HOME_DIR" "$INSTALL_DIR/bin/jq" --preview-shim --version)
  assert_contains "$preview_output" ghcr.io/jqlang/jq:1.8.1
  pass "default install writes layout-version-2 manifests and dispatches"
}

test_commands_lifecycle_version_selection() {
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" 'kind_version=oc|4.18|oc_4_18'
  assert_file_contains "$INSTALL_DIR/profiles/default/install-manifest.txt" 'kind_version=oc|4.20|oc_4_20'
  assert_file_executable "$INSTALL_DIR/profiles/default/bin/oc_4_18"

  preview_output=$(HOME="$HOME_DIR" SHIMMY_OC_VERSION=4.18 "$INSTALL_DIR/bin/oc" --preview-shim version)
  assert_contains "$preview_output" shimmy-oc-4_18
  pass "install resolves explicit concrete tool versions"
}

test_commands_lifecycle_upstream_profile() {
  setup_scenario
  checkout_dir=$(cd -- "$ROOT_DIR" && pwd -P)

  HOME="$HOME_DIR" SHIMMY_UPSTREAM_CHECKOUT_DIR="$checkout_dir" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --profile upstream --shim jq --no-startup --no-skills >/dev/null

  profile_manifest=$INSTALL_DIR/profiles/upstream/install-manifest.txt
  assert_file_exists "$profile_manifest"
  assert_file_contains "$profile_manifest" shimmy_profile_name=upstream
  assert_file_contains "$profile_manifest" source_checkout="$checkout_dir"
  assert_file_contains "$profile_manifest" 'kind_version=jq|1.8|jq_1_8'

  preview_output=$(HOME="$HOME_DIR" SHIMMY_PROFILE_ACTIVE=upstream "$INSTALL_DIR/bin/jq" --preview-shim --version)
  assert_contains "$preview_output" ghcr.io/jqlang/jq:1.8.1
  pass "upstream profile dispatches through its recorded checkout"
}

test_commands_lifecycle_legacy_layout_rejected() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --no-startup --no-skills >/dev/null
  manifest_file=$INSTALL_DIR/install-manifest.txt
  manifest_tmp=$manifest_file.tmp
  sed 's/^shimmy_install_manifest_version=2$/shimmy_install_manifest_version=1/' "$manifest_file" > "$manifest_tmp"
  mv "$manifest_tmp" "$manifest_file"

  set +e
  output=$(HOME="$HOME_DIR" run_in_repo ./shimmy status --install-dir "$INSTALL_DIR" --format manifest 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "legacy layout was accepted"
  assert_contains "$output" "legacy Shimmy install layout detected; uninstall and reinstall"
  pass "legacy layout version is rejected consistently"
}

test_commands_lifecycle_update_refresh() {
  HOME="$HOME_DIR" run_in_repo ./shimmy update --install-dir "$INSTALL_DIR" --shim jq >/dev/null

  preview_output=$(HOME="$HOME_DIR" "$INSTALL_DIR/bin/jq" --preview-shim --version)
  assert_contains "$preview_output" ghcr.io/jqlang/jq:1.8.1
  pass "source-checkout update refreshes a selected installed shim"
}

test_commands_lifecycle_uninstall() {
  HOME="$HOME_DIR" run_in_repo ./shimmy uninstall --install-dir "$INSTALL_DIR" --profile default --no-skills >/dev/null

  assert_path_not_exists "$INSTALL_DIR/install-manifest.txt"
  assert_path_not_exists "$INSTALL_DIR/profiles/default"
  assert_path_not_exists "$INSTALL_DIR/bin/jq"
  pass "default profile uninstall removes the final install assets"
}

test_commands_lifecycle_prepare() {
  test_commands_lifecycle_default_install
  test_commands_lifecycle_version_selection
}

test_commands_lifecycle_complete() {
  test_commands_lifecycle_update_refresh
  test_commands_lifecycle_upstream_profile
  test_commands_lifecycle_legacy_layout_rejected
  test_commands_lifecycle_uninstall
}
