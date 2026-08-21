#!/bin/sh
# Strict registry redirect parser and transaction tests.

test_lib_registries_endpoint_validation() {
  for accepted_endpoint in \
    docker.io \
    registry.redhat.io/openshift4 \
    registry.corp.example:5443/team/images \
    docker.io/team/subteam/images \
    docker.io/team--name \
    docker.io/team__name \
    localhost:5000/safe_namespace; do
    shimmy_registries_endpoint_validate "$accepted_endpoint" ||
      fail_test "valid registry endpoint rejected: $accepted_endpoint"
  done

  for rejected_endpoint in \
    registry \
    https://docker.io \
    '*.example.com' \
    docker.io/library/alpine:latest \
    'docker.io/library/alpine@sha256:abc' \
    docker.io/../escape \
    docker.io/team//image \
    docker.io/team/ \
    'docker.io/team name' \
    'docker.io/"team"' \
    docker.io/_private \
    registry.example:0/team \
    registry.example:65536/team; do
    if shimmy_registries_endpoint_validate "$rejected_endpoint"; then
      fail_test "invalid registry endpoint accepted: $rejected_endpoint"
    fi
  done
  pass "registry endpoints accept hosts, ports, and safe namespaces while rejecting ambiguous or unsafe references"
}

test_lib_registries_managed_format() {
  setup_scenario
  config_file=$SCENARIO_DIR/registries.conf
  entries='docker.io|registry.corp.example/docker
registry.redhat.io/openshift4|registry.corp.example/redhat'
  shimmy_registries_config_render default "$entries" > "$config_file"
  chmod 644 "$config_file"
  assert_equals "$(shimmy_registries_config_entries_read "$config_file" default)" "$entries"
  assert_file_mode "$config_file" 644

  valid_config=$SCENARIO_DIR/valid-registries
  cp "$config_file" "$valid_config"
  for mutation_name in wrong_profile wrong_version duplicate_prefix table_key trailing_blank missing_newline wrong_mode; do
    cp "$valid_config" "$config_file"
    chmod 644 "$config_file"
    case "$mutation_name" in
      wrong_profile) sed 's/profile "default"/profile "upstream"/' "$valid_config" > "$config_file" ;;
      wrong_version) sed 's/redirects_version=1/redirects_version=2/' "$valid_config" > "$config_file" ;;
      duplicate_prefix) sed 's/prefix = "registry.redhat.io\/openshift4"/prefix = "docker.io"/' "$valid_config" > "$config_file" ;;
      table_key) sed 's/\[\[registry\]\]/[[registry.mirror]]/' "$valid_config" > "$config_file" ;;
      trailing_blank) printf '\n' >> "$config_file" ;;
      missing_newline) printf '%s' "$(cat "$valid_config")" > "$config_file" ;;
      wrong_mode) chmod 600 "$config_file" ;;
    esac
    if shimmy_registries_config_validate "$config_file" default; then
      fail_test "invalid managed registry format accepted: $mutation_name"
    fi
  done
  pass "managed registry parsing requires exact ownership, version, ordering, table shape, and permissions"
}

test_lib_registries_transaction() {
  setup_scenario
  SHIMMY_CONFIG_ROOT=$XDG_CONFIG_HOME_DIR/shimmy
  SHIMMY_PROFILES_ROOT=$SHIMMY_CONFIG_ROOT/profiles
  SHIMMY_PROFILE_NAME=default
  SHIMMY_PROFILE_ROOT=$SHIMMY_PROFILES_ROOT/default
  SHIMMY_PROFILE_REGISTRIES_PATH=$SHIMMY_PROFILE_ROOT/registries.conf
  SHIMMY_PROFILE_REGISTRIES_LOCK_PATH=$SHIMMY_PROFILE_ROOT/.registries.lock
  mkdir -p "$SHIMMY_PROFILE_ROOT"
  shimmy_registries_config_render default '' > "$SHIMMY_PROFILE_REGISTRIES_PATH"
  chmod 644 "$SHIMMY_PROFILE_REGISTRIES_PATH"
  SHIMMY_REGISTRIES_LOCK_HELD=0

  shimmy_registries_mutate upsert docker.io registry.corp.example/docker 0
  first_checksum=$(cksum < "$SHIMMY_PROFILE_REGISTRIES_PATH")
  shimmy_registries_mutate upsert docker.io registry.corp.example/docker 0
  assert_equals "$(cksum < "$SHIMMY_PROFILE_REGISTRIES_PATH")" "$first_checksum"
  assert_path_not_exists "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH"

  before_dry_run=$first_checksum
  dry_run_output=$(shimmy_registries_mutate upsert quay.io registry.corp.example/quay 1)
  assert_contains "$dry_run_output" 'prefix = "quay.io"'
  assert_equals "$(cksum < "$SHIMMY_PROFILE_REGISTRIES_PATH")" "$before_dry_run"
  assert_path_not_exists "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH"

  before_rollback=$(cksum < "$SHIMMY_PROFILE_REGISTRIES_PATH")
  set +e
  (
    shimmy_registries_post_commit_validate() { return 1; }
    shimmy_registries_mutate upsert docker.io registry.fail.example/docker 0
  ) >/dev/null 2>&1
  rollback_status=$?
  set -e
  [ "$rollback_status" -ne 0 ] || fail_test "post-commit registry failure unexpectedly succeeded"
  assert_equals "$(cksum < "$SHIMMY_PROFILE_REGISTRIES_PATH")" "$before_rollback"
  assert_path_not_exists "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH"
  assert_path_not_exists "$SHIMMY_PROFILE_ROOT/.registries.tmp.$$"
  assert_path_not_exists "$SHIMMY_PROFILE_ROOT/.registries.rollback.$$"

  mkdir "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH"
  set +e
  lock_output=$(shimmy_registries_mutate remove docker.io '' 0 2>&1)
  lock_status=$?
  set -e
  [ "$lock_status" -ne 0 ] || fail_test "concurrent registry lock unexpectedly succeeded"
  assert_contains "$lock_output" 'another registry transaction holds'
  rmdir "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH"
  assert_equals "$(cksum < "$SHIMMY_PROFILE_REGISTRIES_PATH")" "$before_rollback"

  printf '%s\n' collision > "$SHIMMY_PROFILE_ROOT/.registries.tmp.$$"
  set +e
  stage_output=$(shimmy_registries_mutate remove docker.io '' 0 2>&1)
  stage_status=$?
  set -e
  [ "$stage_status" -ne 0 ] || fail_test "registry staging collision unexpectedly succeeded"
  assert_contains "$stage_output" 'registry transaction path collision'
  assert_file_contains "$SHIMMY_PROFILE_ROOT/.registries.tmp.$$" collision
  rm -f "$SHIMMY_PROFILE_ROOT/.registries.tmp.$$"
  assert_path_not_exists "$SHIMMY_PROFILE_REGISTRIES_LOCK_PATH"
  assert_equals "$(cksum < "$SHIMMY_PROFILE_REGISTRIES_PATH")" "$before_rollback"

  safe_profile_root=$SHIMMY_PROFILE_ROOT
  unsafe_target=$SCENARIO_DIR/unsafe-target
  unsafe_profile_root=$SCENARIO_DIR/unsafe-profile
  mkdir "$unsafe_target"
  ln -s "$unsafe_target" "$unsafe_profile_root"
  SHIMMY_PROFILE_ROOT=$unsafe_profile_root
  SHIMMY_PROFILE_REGISTRIES_PATH=$unsafe_profile_root/registries.conf
  SHIMMY_PROFILE_REGISTRIES_LOCK_PATH=$unsafe_profile_root/.registries.lock
  set +e
  unsafe_output=$(shimmy_registries_lock_acquire 2>&1)
  unsafe_status=$?
  set -e
  [ "$unsafe_status" -ne 0 ] || fail_test "symlinked registry transaction root unexpectedly locked"
  assert_contains "$unsafe_output" 'unsafe profile registry transaction paths'
  assert_path_not_exists "$unsafe_target/.registries.lock"
  SHIMMY_PROFILE_ROOT=$safe_profile_root
  SHIMMY_PROFILE_REGISTRIES_PATH=$safe_profile_root/registries.conf
  SHIMMY_PROFILE_REGISTRIES_LOCK_PATH=$safe_profile_root/.registries.lock
  pass "registry edits are deterministic, dry-run is side-effect free, locking is fail-closed, and post-commit failure restores exact bytes"
}

test_lib_registries_machine_projection_record() {
  setup_scenario
  SHIMMY_CONFIG_ROOT=$XDG_CONFIG_HOME_DIR/shimmy
  SHIMMY_PROFILE_NAME=default
  SHIMMY_PROFILE_ROOT=$SHIMMY_CONFIG_ROOT/profiles/default
  SHIMMY_PROFILE_REGISTRIES_PATH=$SHIMMY_PROFILE_ROOT/registries.conf
  SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH=$SHIMMY_PROFILE_ROOT/machine-projection.txt
  mkdir -p "$SHIMMY_PROFILE_ROOT"
  shimmy_registries_config_render default '' > "$SHIMMY_PROFILE_REGISTRIES_PATH"
  chmod 0644 "$SHIMMY_PROFILE_REGISTRIES_PATH"
  projection_fingerprint=$(shimmy_registries_config_fingerprint_render "$SHIMMY_PROFILE_REGISTRIES_PATH")
  shimmy_registries_machine_projection_record_render default "$projection_fingerprint" > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
  chmod 0644 "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
  shimmy_registries_machine_projection_record_validate "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" default ||
    fail_test 'valid machine projection record was rejected'

  valid_record=$SCENARIO_DIR/valid-machine-projection
  cp "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" "$valid_record"
  for mutation_name in wrong_version wrong_profile wrong_machine wrong_target wrong_fingerprint extra_line wrong_mode symlink; do
    cp "$valid_record" "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
    chmod 0644 "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
    case "$mutation_name" in
      wrong_version) sed 's/projection_version=1/projection_version=2/' "$valid_record" > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
      wrong_profile) sed 's/profile=default/profile=upstream/' "$valid_record" > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
      wrong_machine) sed 's/machine=shimmy-default/machine=other/' "$valid_record" > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
      wrong_target) sed 's#target=.*#target=/tmp/other#' "$valid_record" > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
      wrong_fingerprint) sed 's/config_fingerprint=.*/config_fingerprint=sha256:bad/' "$valid_record" > "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
      extra_line) printf '%s\n' extra >> "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
      wrong_mode) chmod 0600 "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ;;
      symlink)
        cp "$valid_record" "$SCENARIO_DIR/projection-target"
        rm -f "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
        ln -s "$SCENARIO_DIR/projection-target" "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
        ;;
    esac
    if shimmy_registries_machine_projection_record_validate "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" default; then
      fail_test "invalid machine projection record accepted: $mutation_name"
    fi
  done

  rm -f "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
  shimmy_registries_machine_projection_record_apply "$projection_fingerprint"
  assert_regular_file_not_symlink "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH"
  shimmy_registries_machine_projection_record_commit
  previous_record=$SCENARIO_DIR/previous-machine-projection
  cp "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" "$previous_record"
  shimmy_registries_config_render default 'docker.io|registry.corp.example/docker' > "$SHIMMY_PROFILE_REGISTRIES_PATH"
  chmod 0644 "$SHIMMY_PROFILE_REGISTRIES_PATH"
  changed_fingerprint=$(shimmy_registries_config_fingerprint_render "$SHIMMY_PROFILE_REGISTRIES_PATH")
  shimmy_registries_machine_projection_record_apply "$changed_fingerprint"
  assert_file_contains "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" "config_fingerprint=$changed_fingerprint"
  shimmy_registries_machine_projection_record_rollback
  cmp -s "$previous_record" "$SHIMMY_PROFILE_MACHINE_PROJECTION_RECORD_PATH" ||
    fail_test 'machine projection record rollback did not restore exact prior bytes'
  assert_path_not_exists "$SHIMMY_PROFILE_ROOT/.machine-projection.rollback.$$"
  pass 'machine projection records enforce exact identity, target, fingerprint, mode, atomic replacement, and rollback'
}

test_lib_registries_arbitrary_profile_active_link() {
  setup_scenario
  SHIMMY_CONFIG_ROOT=$XDG_CONFIG_HOME_DIR/shimmy
  SHIMMY_PROFILE_NAME=team-one
  SHIMMY_PROFILE_ROOT=$SHIMMY_CONFIG_ROOT/profiles/team-one
  SHIMMY_PROFILE_REGISTRIES_PATH=$SHIMMY_PROFILE_ROOT/registries.conf
  SHIMMY_REGISTRIES_CONFIG_DIR=$XDG_CONFIG_HOME_DIR/containers
  SHIMMY_REGISTRIES_DROPIN_DIR=$SHIMMY_REGISTRIES_CONFIG_DIR/registries.conf.d
  SHIMMY_REGISTRIES_ACTIVE_LINK=$SHIMMY_REGISTRIES_DROPIN_DIR/shimmy-active-profile.conf
  mkdir -p "$SHIMMY_PROFILE_ROOT" "$SHIMMY_REGISTRIES_DROPIN_DIR"
  shimmy_registries_config_render team-one '' > "$SHIMMY_PROFILE_REGISTRIES_PATH"
  chmod 0644 "$SHIMMY_PROFILE_REGISTRIES_PATH"
  ln -s "$SHIMMY_PROFILE_REGISTRIES_PATH" "$SHIMMY_REGISTRIES_ACTIVE_LINK"
  SHIMMY_TEST_PROFILE_OS=Linux shimmy_registries_active_link_state_read
  assert_equals "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" current
  assert_equals "$SHIMMY_REGISTRIES_ACTIVE_PROFILE" team-one

  rm -f "$SHIMMY_REGISTRIES_ACTIVE_LINK"
  mkdir "$SHIMMY_PROFILE_ROOT/nested"
  shimmy_registries_config_render team-one '' > "$SHIMMY_PROFILE_ROOT/nested/registries.conf"
  chmod 0644 "$SHIMMY_PROFILE_ROOT/nested/registries.conf"
  ln -s "$SHIMMY_PROFILE_ROOT/nested/registries.conf" "$SHIMMY_REGISTRIES_ACTIVE_LINK"
  SHIMMY_TEST_PROFILE_OS=Linux shimmy_registries_active_link_state_read
  assert_equals "$SHIMMY_REGISTRIES_ACTIVE_LINK_STATE" invalid
  assert_equals "$SHIMMY_REGISTRIES_ACTIVE_PROFILE" unknown
  pass 'arbitrary safe profile links resolve exactly while nested lookalike registry paths fail closed'
}

test_lib_registries_run() {
  test_lib_registries_endpoint_validation
  test_lib_registries_managed_format
  test_lib_registries_machine_projection_record
  test_lib_registries_arbitrary_profile_active_link
  test_lib_registries_transaction
}
