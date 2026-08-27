#!/bin/sh

images_fixture_fake_runtimes_write() {
  fixture_root=$1
  jq_run=$fixture_root/tools/jq/versions/1.8/run.sh
  skopeo_run=$fixture_root/tools/skopeo/versions/1.22/run.sh

  cat > "$jq_run" <<'EOF'
#!/bin/sh
payload=$(cat)
case "$payload" in
  *'"_fixture": "oci-valid"'*) printf 'verified\tapplication/vnd.oci.image.index.v1+json\tverified\n' ;;
  *'"_fixture": "docker-valid"'*) printf 'verified\tapplication/vnd.docker.distribution.manifest.list.v2+json\tverified\n' ;;
  *'"_fixture":"single-manifest"'*) printf 'unsupported-media-type\tunsupported\tfailed\n' ;;
  *'"_fixture":"child-digest"'*) printf 'unsupported-media-type\tunsupported\tfailed\n' ;;
  *'"_fixture":"missing-arm64"'*) printf 'missing-required-platform\tapplication/vnd.oci.image.index.v1+json\tfailed\n' ;;
  *'"_fixture":"unsupported-media"'*) printf 'unsupported-media-type\tunsupported\tfailed\n' ;;
  *'"_fixture":"empty-index"'*) printf 'missing-descriptors\tapplication/vnd.oci.image.index.v1+json\tfailed\n' ;;
  *'"_fixture":"absent-manifests"'*) printf 'missing-descriptors\tapplication/vnd.oci.image.index.v1+json\tfailed\n' ;;
  *) exit 4 ;;
esac
EOF

  cat > "$skopeo_run" <<'EOF'
#!/bin/sh
mode=digest
remote_ref=
for inspect_arg in "$@"; do
  [ "$inspect_arg" != --raw ] || mode=raw
  case "$inspect_arg" in docker://*) remote_ref=${inspect_arg#docker://} ;; esac
done
[ -n "$remote_ref" ] || exit 2
cat >/dev/null
printf '%s|%s\n' "$mode" "$remote_ref" >> "$SHIMMY_TEST_IMAGES_CALL_LOG"
matching_call=$(awk -F '|' -v mode="$mode" -v ref="$remote_ref" \
  '$1 == mode && $2 == ref { count++ } END { print count + 0 }' "$SHIMMY_TEST_IMAGES_CALL_LOG")
matching_response_total=$(awk -F '|' -v mode="$mode" -v ref="$remote_ref" \
  '$1 == mode && $2 == ref { count++ } END { print count + 0 }' "$SHIMMY_TEST_IMAGES_RESPONSE_FILE")
matching_response=0
while IFS='|' read -r response_mode response_ref response_value response_status; do
  [ "$response_mode" = "$mode" ] || continue
  [ "$response_ref" = "$remote_ref" ] || continue
  matching_response=$((matching_response + 1))
  [ "$matching_response_total" -eq 1 ] || [ "$matching_response" -eq "$matching_call" ] || continue
  [ "$response_status" = ok ] || exit 3
  if [ "$mode" = raw ]; then
    cat "$SHIMMY_TEST_IMAGES_FIXTURE_DIR/$response_value"
  else
    printf '%s\n' "$response_value"
  fi
  exit 0
done < "$SHIMMY_TEST_IMAGES_RESPONSE_FILE"
exit 4
EOF
  chmod 0755 "$jq_run" "$skopeo_run"
}

test_images_fixture_setup() {
  test_images_access=${1:-public}
  setup_scenario
  TEST_IMAGES_CHECKOUT=$SCENARIO_DIR/checkout
  TEST_IMAGES_CONFIG=$SCENARIO_DIR/config/shimmy
  TEST_IMAGES_CALL_LOG=$SCENARIO_DIR/image-calls
  TEST_IMAGES_RESPONSES=$SCENARIO_DIR/image-responses

  test_catalog_checkout_create "$TEST_IMAGES_CHECKOUT"
  for test_images_tool_dir in "$TEST_IMAGES_CHECKOUT"/tools/*; do
    [ -d "$test_images_tool_dir" ] || continue
    test_images_tool_name=$(basename -- "$test_images_tool_dir")
    case "$test_images_tool_name" in jq|rg|skopeo) continue ;; esac
    git -C "$TEST_IMAGES_CHECKOUT" rm -qr "tools/$test_images_tool_name"
  done
  if [ "$test_images_access" = authenticated ]; then
    sed 's/^image_registry_access=public$/image_registry_access=authenticated/' \
      "$TEST_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf" \
      > "$TEST_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf.tmp"
    mv "$TEST_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf.tmp" \
      "$TEST_IMAGES_CHECKOUT/tools/jq/versions/1.8/image.conf"
    git -C "$TEST_IMAGES_CHECKOUT" add tools/jq/versions/1.8/image.conf
  fi
  git -C "$TEST_IMAGES_CHECKOUT" commit -qm catalog-images-fixture
  mkdir -p "$TEST_IMAGES_CONFIG"
  shimmy_catalog_default_create "$TEST_IMAGES_CONFIG" "$TEST_IMAGES_CHECKOUT" ||
    fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"

  TEST_IMAGES_GENERATION=$(sed -n '3s/^catalog_generation_current=//p' \
    "$TEST_IMAGES_CONFIG/catalogs/default/registry.conf")
  TEST_IMAGES_GENERATION_ROOT=$TEST_IMAGES_CONFIG/catalogs/default/generations/$TEST_IMAGES_GENERATION
  TEST_IMAGES_COMMIT=$(sed -n '1s/^catalog_source_commit=//p' "$TEST_IMAGES_GENERATION_ROOT/generation.conf")
  TEST_IMAGES_FINGERPRINT=$(sed -n '2s/^catalog_content_fingerprint=//p' "$TEST_IMAGES_GENERATION_ROOT/generation.conf")
  TEST_IMAGES_PROFILE_ROOT=$TEST_IMAGES_CONFIG/profiles/default
  mkdir -p "$TEST_IMAGES_PROFILE_ROOT/tools" "$SCENARIO_DIR/home/.agents/skills"
  for test_images_tool_name in jq rg skopeo; do
    test_fixture_tree_copy "$TEST_IMAGES_GENERATION_ROOT/tools/$test_images_tool_name" \
      "$TEST_IMAGES_PROFILE_ROOT/tools/$test_images_tool_name"
  done
  images_fixture_fake_runtimes_write "$TEST_IMAGES_PROFILE_ROOT"
  shimmy_active_profile_render default "$SCENARIO_DIR/home/.agents/skills" \
    > "$TEST_IMAGES_CONFIG/active-profile.conf"
  shimmy_profile_manifest_render default https://example.invalid/shimmy.git "$TEST_IMAGES_COMMIT" \
    "default|$TEST_IMAGES_GENERATION|$TEST_IMAGES_COMMIT|$TEST_IMAGES_FINGERPRINT" \
    'jq|tracking
rg|tracking
skopeo|tracking' \
    'jq|1.8|default
rg|15.1|default
skopeo|1.22|default' > "$TEST_IMAGES_PROFILE_ROOT/install-manifest.txt"

  : > "$TEST_IMAGES_CALL_LOG"
  test_images_responses_write oci-index.json \
    sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91
}

test_images_fixture_run() {
  : > "$TEST_IMAGES_CALL_LOG"
  env \
    SHIMMY_TEST_IMAGES_CALL_LOG="$TEST_IMAGES_CALL_LOG" \
    SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures" \
    SHIMMY_TEST_IMAGES_RESPONSE_FILE="$TEST_IMAGES_RESPONSES" \
    SHIMMY_CONFIG_ROOT="$TEST_IMAGES_CONFIG" \
    "$ROOT_DIR/commands/catalog.sh" verify "$@"
}

test_images_responses_write() {
  test_images_jq_fixture=$1
  test_images_jq_digest=$2
  : > "$TEST_IMAGES_RESPONSES"
  for test_images_tool_name in jq rg skopeo; do
    test_images_tool_file=$TEST_IMAGES_GENERATION_ROOT/tools/$test_images_tool_name/tool.conf
    test_images_version=$(sed -n 's/^tool_default_version=//p' "$test_images_tool_file")
    test_images_config_file=$TEST_IMAGES_GENERATION_ROOT/tools/$test_images_tool_name/versions/$test_images_version/image.conf
    test_images_default_ref=$(sed -n 's/^image_default_ref=//p' "$test_images_config_file")
    test_images_upstream_ref=$(sed -n 's/^image_upstream_ref=//p' "$test_images_config_file")
    test_images_digest=$(shimmy_images_digest_read "$test_images_default_ref")
    test_images_fixture=oci-index.json
    [ "$test_images_tool_name" != skopeo ] || test_images_fixture=docker-list.json
    [ "$test_images_tool_name" != jq ] || {
      test_images_fixture=$test_images_jq_fixture
      test_images_digest=$test_images_jq_digest
    }
    printf 'raw|%s|%s|ok\n' "$test_images_default_ref" "$test_images_fixture" \
      >> "$TEST_IMAGES_RESPONSES"
    printf 'digest|%s|%s|ok\n' "$test_images_upstream_ref" "$test_images_digest" \
      >> "$TEST_IMAGES_RESPONSES"
  done
}

test_refresh_fixture_setup() {
  test_refresh_tool=${1:-jq}
  test_images_fixture_setup
  if [ "$test_refresh_tool" = netcat ]; then
    test_fixture_tree_copy "$ROOT_DIR/tools/netcat" "$TEST_IMAGES_CHECKOUT/tools/netcat"
    git -C "$TEST_IMAGES_CHECKOUT" add tools/netcat
    git -C "$TEST_IMAGES_CHECKOUT" commit -qm refresh-netcat-source
  fi
  TEST_REFRESH_SELECTOR=$test_refresh_tool@$(sed -n 's/^tool_default_version=//p' \
    "$TEST_IMAGES_CHECKOUT/tools/$test_refresh_tool/tool.conf")
  TEST_REFRESH_FILE=$TEST_IMAGES_CHECKOUT/tools/$test_refresh_tool/versions/${TEST_REFRESH_SELECTOR#*@}/image.conf
  TEST_REFRESH_UPSTREAM=$(sed -n 's/^image_\(base_1_\)\{0,1\}upstream_ref=//p' "$TEST_REFRESH_FILE")
  TEST_REFRESH_OLD_REF=$(sed -n 's/^image_\(base_1_\)\{0,1\}default_ref=//p' "$TEST_REFRESH_FILE")
  TEST_REFRESH_REGISTRY=$TEST_IMAGES_CONFIG/catalogs/default/registry.conf
  TEST_REFRESH_REGISTRY_CHECKSUM=$(cksum < "$TEST_REFRESH_REGISTRY")
}

test_refresh_responses_write() {
  test_refresh_fixture=$1
  test_refresh_first_digest=$2
  test_refresh_second_digest=${3:-$test_refresh_first_digest}
  test_refresh_repository=${TEST_REFRESH_UPSTREAM%:*}
  : > "$TEST_IMAGES_RESPONSES"
  printf 'digest|%s|%s|ok\n' "$TEST_REFRESH_UPSTREAM" "$test_refresh_first_digest" \
    >> "$TEST_IMAGES_RESPONSES"
  printf 'digest|%s|%s|ok\n' "$TEST_REFRESH_UPSTREAM" "$test_refresh_second_digest" \
    >> "$TEST_IMAGES_RESPONSES"
  printf 'raw|%s@%s|%s|ok\n' "$test_refresh_repository" "$test_refresh_first_digest" \
    "$test_refresh_fixture" >> "$TEST_IMAGES_RESPONSES"
}

test_refresh_fixture_run() {
  : > "$TEST_IMAGES_CALL_LOG"
  (
    cd "$TEST_IMAGES_CHECKOUT"
    env \
      SHIMMY_TEST_IMAGES_CALL_LOG="$TEST_IMAGES_CALL_LOG" \
      SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures" \
      SHIMMY_TEST_IMAGES_RESPONSE_FILE="$TEST_IMAGES_RESPONSES" \
      SHIMMY_TEST_MODE="${SHIMMY_TEST_MODE:-0}" \
      SHIMMY_TEST_CATALOG_REFRESH_FAILURE="${SHIMMY_TEST_CATALOG_REFRESH_FAILURE:-}" \
      SHIMMY_SKOPEO_AUTH_SECRET="${SHIMMY_SKOPEO_AUTH_SECRET:-}" \
      SHIMMY_CONFIG_ROOT="$TEST_IMAGES_CONFIG" \
      ./commands/catalog.sh refresh "$@"
  )
}

test_refresh_failure_run() {
  set +e
  TEST_REFRESH_FAILURE_OUTPUT=$(test_refresh_fixture_run "$@" 2>&1)
  TEST_REFRESH_FAILURE_STATUS=$?
  set -e
  [ "$TEST_REFRESH_FAILURE_STATUS" -ne 0 ] || fail_test 'catalog refresh failure scenario unexpectedly passed'
  [ -z "$(git -C "$TEST_IMAGES_CHECKOUT" status --porcelain --untracked-files=all)" ] ||
    fail_test 'failed catalog refresh changed its clean source checkout'
  assert_equals "$(cksum < "$TEST_REFRESH_REGISTRY")" "$TEST_REFRESH_REGISTRY_CHECKSUM"
}

test_commands_catalog_refresh_parser() {
  for test_refresh_parser_case in \
    'refresh|requires one exact tool@version selector' \
    'refresh jq|must be qualified as tool@version' \
    'refresh jq@1.8 rg@15.1|unexpected additional selector' \
    'refresh jq@1.8 --dry-run --dry-run|duplicate argument: --dry-run' \
    'refresh jq@@1.8|unsafe catalog refresh selector'; do
    test_refresh_parser_args=${test_refresh_parser_case%%|*}
    test_refresh_parser_error=${test_refresh_parser_case#*|}
    set -- $test_refresh_parser_args
    set +e
    test_refresh_parser_output=$(env SHIMMY_CONFIG_ROOT=/nonexistent \
      "$ROOT_DIR/commands/catalog.sh" "$@" 2>&1)
    test_refresh_parser_status=$?
    set -e
    [ "$test_refresh_parser_status" -ne 0 ] || fail_test "catalog parser accepted: $test_refresh_parser_args"
    assert_contains "$test_refresh_parser_output" "$test_refresh_parser_error"
  done
  pass 'catalog refresh accepts only one safe exact selector and one optional dry-run flag'
}

test_commands_catalog_refresh_external() {
  test_refresh_new_digest=sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
  test_refresh_fixture_setup jq
  test_refresh_before_checksum=$(cksum < "$TEST_REFRESH_FILE")
  test_refresh_responses_write oci-index.json "$test_refresh_new_digest"
  test_refresh_dry_output=$(test_refresh_fixture_run --dry-run "$TEST_REFRESH_SELECTOR")
  assert_contains "$test_refresh_dry_output" "REFRESH $TEST_REFRESH_SELECTOR runtime"
  assert_contains "$test_refresh_dry_output" 'platforms: linux/amd64, linux/arm64'
  assert_contains "$test_refresh_dry_output" "WOULD UPDATE tools/jq/versions/1.8/image.conf"
  assert_contains "$test_refresh_dry_output" 'PUBLISHED no'
  assert_equals "$(cksum < "$TEST_REFRESH_FILE")" "$test_refresh_before_checksum"
  assert_equals "$(git -C "$TEST_IMAGES_CHECKOUT" status --porcelain --untracked-files=all)" ''
  assert_equals "$(awk -F '|' '$1 == "digest" { count++ } END { print count + 0 }' "$TEST_IMAGES_CALL_LOG")" 2
  assert_equals "$(awk -F '|' '$1 == "raw" { count++ } END { print count + 0 }' "$TEST_IMAGES_CALL_LOG")" 1

  test_refresh_fixture_setup jq
  test_refresh_unrelated_before=$(sed '/^image_default_ref=/d' "$TEST_REFRESH_FILE")
  test_refresh_mode=$(shimmy_file_mode_render "$TEST_REFRESH_FILE")
  test_refresh_responses_write oci-index.json "$test_refresh_new_digest"
  test_refresh_apply_output=$(test_refresh_fixture_run "$TEST_REFRESH_SELECTOR")
  assert_contains "$test_refresh_apply_output" "UPDATED tools/jq/versions/1.8/image.conf"
  assert_contains "$test_refresh_apply_output" 'REVIEW tools/jq/guide.md'
  assert_contains "$test_refresh_apply_output" 'REVIEW tools/jq/SKILL.md'
  assert_contains "$test_refresh_apply_output" 'NATIVE SMOKE linux/amd64'
  assert_contains "$test_refresh_apply_output" 'NATIVE SMOKE darwin/arm64'
  assert_file_contains "$TEST_REFRESH_FILE" \
    "image_default_ref=ghcr.io/jqlang/jq@$test_refresh_new_digest"
  assert_equals "$(sed '/^image_default_ref=/d' "$TEST_REFRESH_FILE")" "$test_refresh_unrelated_before"
  assert_file_mode "$TEST_REFRESH_FILE" "$test_refresh_mode"
  assert_equals "$(git -C "$TEST_IMAGES_CHECKOUT" diff --name-only)" \
    'tools/jq/versions/1.8/image.conf'
  shimmy_catalog_authority_payload_validate "$TEST_IMAGES_CHECKOUT" ||
    fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  assert_equals "$(cksum < "$TEST_REFRESH_REGISTRY")" "$TEST_REFRESH_REGISTRY_CHECKSUM"

  test_refresh_fixture_setup jq
  test_refresh_current_digest=$(shimmy_images_digest_read "$TEST_REFRESH_OLD_REF")
  test_refresh_responses_write oci-index.json "$test_refresh_current_digest"
  test_refresh_current_output=$(test_refresh_fixture_run "$TEST_REFRESH_SELECTOR")
  assert_contains "$test_refresh_current_output" "CURRENT $TEST_REFRESH_SELECTOR runtime"
  assert_not_contains "$test_refresh_current_output" 'UPDATED '
  assert_equals "$(git -C "$TEST_IMAGES_CHECKOUT" status --porcelain --untracked-files=all)" ''
  pass 'catalog refresh dry-runs, applies one exact external-runtime diff, and preserves current source bytes'
}

test_commands_catalog_refresh_local_build() {
  test_refresh_first_digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  test_refresh_second_digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  test_refresh_fixture_setup netcat
  test_refresh_base_two_upstream=docker.io/library/alpine:3.22
  test_refresh_base_two_old=docker.io/library/alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce
  awk -v upstream="$test_refresh_base_two_upstream" -v old="$test_refresh_base_two_old" '
    $0 == "image_base_count=1" { print "image_base_count=3"; next }
    $0 == "image_platform=linux/amd64" {
      print "image_base_2_build_arg=SHIMMY_NETCAT_SECOND_BASE_IMAGE"
      print "image_base_2_upstream_ref=" upstream
      print "image_base_2_default_ref=" old
      print "image_base_2_registry_access=public"
      print "image_base_3_build_arg=SHIMMY_NETCAT_IMMUTABLE_BASE_IMAGE"
      print "image_base_3_upstream_ref=" old
      print "image_base_3_default_ref=" old
      print "image_base_3_registry_access=public"
    }
    { print }
  ' "$TEST_REFRESH_FILE" > "$TEST_REFRESH_FILE.tmp"
  mv "$TEST_REFRESH_FILE.tmp" "$TEST_REFRESH_FILE"
  git -C "$TEST_IMAGES_CHECKOUT" add "$TEST_REFRESH_FILE"
  git -C "$TEST_IMAGES_CHECKOUT" commit -qm refresh-two-base-source
  TEST_REFRESH_UPSTREAM=$(sed -n 's/^image_base_1_upstream_ref=//p' "$TEST_REFRESH_FILE")
  test_refresh_responses_write docker-list.json "$test_refresh_first_digest"
  printf 'digest|%s|%s|ok\n' "$test_refresh_base_two_upstream" "$test_refresh_second_digest" \
    >> "$TEST_IMAGES_RESPONSES"
  printf 'digest|%s|%s|ok\n' "$test_refresh_base_two_upstream" "$test_refresh_second_digest" \
    >> "$TEST_IMAGES_RESPONSES"
  printf 'raw|docker.io/library/alpine@%s|oci-index.json|ok\n' "$test_refresh_second_digest" \
    >> "$TEST_IMAGES_RESPONSES"
  test_refresh_output=$(test_refresh_fixture_run "$TEST_REFRESH_SELECTOR")
  assert_contains "$test_refresh_output" "REFRESH $TEST_REFRESH_SELECTOR base-1"
  assert_contains "$test_refresh_output" "REFRESH $TEST_REFRESH_SELECTOR base-2"
  assert_contains "$test_refresh_output" "SKIP $TEST_REFRESH_SELECTOR base-3 reason=immutable-only"
  assert_file_contains "$TEST_REFRESH_FILE" \
    "image_base_1_default_ref=registry.access.redhat.com/ubi9/ubi-minimal@$test_refresh_first_digest"
  assert_file_contains "$TEST_REFRESH_FILE" \
    "image_base_2_default_ref=docker.io/library/alpine@$test_refresh_second_digest"
  assert_equals "$(git -C "$TEST_IMAGES_CHECKOUT" diff --name-only)" \
    'tools/netcat/versions/7.92/image.conf'
  shimmy_catalog_authority_payload_validate "$TEST_IMAGES_CHECKOUT" ||
    fail_test "$SHIMMY_CATALOG_AUTHORITY_ERROR"
  pass 'catalog refresh updates every tag-backed local-build base as one valid source transaction'
}

test_commands_catalog_refresh_remote_rejections() {
  test_refresh_new_digest=sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
  test_refresh_fixture_setup jq

  test_refresh_responses_write oci-index.json invalid-digest
  test_refresh_failure_run "$TEST_REFRESH_SELECTOR"
  assert_contains "$TEST_REFRESH_FAILURE_OUTPUT" 'upstream-digest-invalid-or-unreachable'

  test_refresh_responses_write single-manifest.json "$test_refresh_new_digest"
  test_refresh_failure_run "$TEST_REFRESH_SELECTOR"
  assert_contains "$TEST_REFRESH_FAILURE_OUTPUT" 'unsupported-media-type'

  test_refresh_responses_write missing-arm64.json "$test_refresh_new_digest"
  test_refresh_failure_run "$TEST_REFRESH_SELECTOR"
  assert_contains "$TEST_REFRESH_FAILURE_OUTPUT" 'missing-required-platform'

  test_refresh_responses_write oci-index.json "$test_refresh_new_digest"
  sed 's/|oci-index.json|ok$/|oci-index.json|fail/' "$TEST_IMAGES_RESPONSES" > "$TEST_IMAGES_RESPONSES.tmp"
  mv "$TEST_IMAGES_RESPONSES.tmp" "$TEST_IMAGES_RESPONSES"
  test_refresh_failure_run "$TEST_REFRESH_SELECTOR"
  assert_contains "$TEST_REFRESH_FAILURE_OUTPUT" 'candidate-reference-unreachable'

  test_refresh_moved_digest=sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
  test_refresh_responses_write oci-index.json "$test_refresh_new_digest" "$test_refresh_moved_digest"
  test_refresh_failure_run "$TEST_REFRESH_SELECTOR"
  assert_contains "$TEST_REFRESH_FAILURE_OUTPUT" 'upstream-moved-during-refresh'
  pass 'catalog refresh rejects malformed, non-index, incomplete-platform, and moved tag candidates atomically'
}

test_commands_catalog_refresh_policy_rejections() {
  test_refresh_new_digest=sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd

  test_refresh_fixture_setup jq
  sed 's/^image_registry_access=public$/image_registry_access=authenticated/' "$TEST_REFRESH_FILE" > "$TEST_REFRESH_FILE.tmp"
  mv "$TEST_REFRESH_FILE.tmp" "$TEST_REFRESH_FILE"
  git -C "$TEST_IMAGES_CHECKOUT" add "$TEST_REFRESH_FILE"
  git -C "$TEST_IMAGES_CHECKOUT" commit -qm authenticated-refresh-source
  test_refresh_responses_write oci-index.json "$test_refresh_new_digest"
  test_refresh_failure_run "$TEST_REFRESH_SELECTOR"
  assert_contains "$TEST_REFRESH_FAILURE_OUTPUT" 'authentication-required'
  assert_equals "$(cat "$TEST_IMAGES_CALL_LOG")" ''
  test_refresh_auth_output=$(SHIMMY_SKOPEO_AUTH_SECRET='secret|value' \
    test_refresh_fixture_run "$TEST_REFRESH_SELECTOR")
  assert_contains "$test_refresh_auth_output" 'access:    authenticated'
  assert_not_contains "$test_refresh_auth_output" 'secret|value'

  test_refresh_fixture_setup jq
  sed 's|^image_default_ref=ghcr.io/jqlang/jq@|image_default_ref=quay.io/jqlang/jq@|' "$TEST_REFRESH_FILE" > "$TEST_REFRESH_FILE.tmp"
  mv "$TEST_REFRESH_FILE.tmp" "$TEST_REFRESH_FILE"
  git -C "$TEST_IMAGES_CHECKOUT" add "$TEST_REFRESH_FILE"
  git -C "$TEST_IMAGES_CHECKOUT" commit -qm mirror-refresh-source
  test_refresh_responses_write oci-index.json "$test_refresh_new_digest"
  test_refresh_failure_run "$TEST_REFRESH_SELECTOR"
  assert_contains "$TEST_REFRESH_FAILURE_OUTPUT" 'repository-mismatch'
  assert_equals "$(cat "$TEST_IMAGES_CALL_LOG")" ''

  test_refresh_fixture_setup jq
  sed "s|^image_upstream_ref=.*|image_upstream_ref=$TEST_REFRESH_OLD_REF|" "$TEST_REFRESH_FILE" > "$TEST_REFRESH_FILE.tmp"
  mv "$TEST_REFRESH_FILE.tmp" "$TEST_REFRESH_FILE"
  git -C "$TEST_IMAGES_CHECKOUT" add "$TEST_REFRESH_FILE"
  git -C "$TEST_IMAGES_CHECKOUT" commit -qm immutable-refresh-source
  : > "$TEST_IMAGES_RESPONSES"
  test_refresh_failure_run "$TEST_REFRESH_SELECTOR"
  assert_contains "$TEST_REFRESH_FAILURE_OUTPUT" 'not-refreshable'
  assert_equals "$(cat "$TEST_IMAGES_CALL_LOG")" ''
  pass 'catalog refresh preserves authentication, repository-retention, and immutable-upstream boundaries'
}

test_refresh_move_head() {
  test_refresh_move_checkout=$1
  printf 'moved\n' > "$test_refresh_move_checkout/refresh-moved-head"
  git -C "$test_refresh_move_checkout" add refresh-moved-head
  git -C "$test_refresh_move_checkout" commit -qm refresh-moved-head
}

test_commands_catalog_refresh_source_transaction() {
  test_refresh_new_digest=sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd

  test_refresh_fixture_setup jq
  printf 'dirty\n' > "$TEST_IMAGES_CHECKOUT/dirty"
  set +e
  test_refresh_dirty_output=$(test_refresh_fixture_run "$TEST_REFRESH_SELECTOR" 2>&1)
  test_refresh_dirty_status=$?
  set -e
  [ "$test_refresh_dirty_status" -ne 0 ] || fail_test 'catalog refresh accepted dirty source authority'
  assert_contains "$test_refresh_dirty_output" 'requires a clean index, worktree, and untracked state'
  rm "$TEST_IMAGES_CHECKOUT/dirty"

  test_refresh_fixture_setup jq
  test_refresh_responses_write oci-index.json "$test_refresh_new_digest"
  export SHIMMY_TEST_IMAGES_CALL_LOG="$TEST_IMAGES_CALL_LOG"
  export SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures"
  export SHIMMY_TEST_IMAGES_RESPONSE_FILE="$TEST_IMAGES_RESPONSES"
  SHIMMY_TEST_MODE=1
  SHIMMY_TEST_CATALOG_REFRESH_BEFORE_COMMIT_FUNCTION=test_refresh_move_head
  set +e
  test_refresh_moved_output=$(
    if shimmy_catalog_refresh_run "$TEST_IMAGES_CONFIG" \
      "$TEST_IMAGES_CHECKOUT" "$TEST_REFRESH_SELECTOR" 0; then
      exit 0
    else
      test_refresh_moved_result=$?
      printf '%s\n' "$SHIMMY_CATALOG_REFRESH_ERROR"
      exit "$test_refresh_moved_result"
    fi
  2>&1)
  test_refresh_moved_status=$?
  set -e
  SHIMMY_TEST_MODE=0
  SHIMMY_TEST_CATALOG_REFRESH_BEFORE_COMMIT_FUNCTION=
  shimmy_catalog_refresh_cleanup || true
  shimmy_images_cache_cleanup || true
  [ "$test_refresh_moved_status" -ne 0 ] || fail_test 'catalog refresh accepted moved source authority'
  assert_contains "$test_refresh_moved_output" 'source authority moved during discovery'
  assert_equals "$(cksum < "$TEST_REFRESH_FILE")" "$(git -C "$TEST_IMAGES_CHECKOUT" show HEAD^:tools/jq/versions/1.8/image.conf | cksum)"
  assert_equals "$(cksum < "$TEST_REFRESH_REGISTRY")" "$TEST_REFRESH_REGISTRY_CHECKSUM"

  test_refresh_fixture_setup jq
  test_refresh_before_checksum=$(cksum < "$TEST_REFRESH_FILE")
  test_refresh_responses_write oci-index.json "$test_refresh_new_digest"
  set +e
  test_refresh_candidate_output=$(SHIMMY_TEST_MODE=1 \
    SHIMMY_TEST_CATALOG_REFRESH_FAILURE=after-candidate \
    test_refresh_fixture_run "$TEST_REFRESH_SELECTOR" 2>&1)
  test_refresh_candidate_status=$?
  set -e
  [ "$test_refresh_candidate_status" -ne 0 ] || fail_test 'injected staged-candidate refresh failure passed'
  assert_contains "$test_refresh_candidate_output" 'after commit candidate staging'
  assert_equals "$(cksum < "$TEST_REFRESH_FILE")" "$test_refresh_before_checksum"
  assert_path_not_exists "$TEST_IMAGES_CHECKOUT/.git/shimmy-catalog-refresh.lock"

  test_refresh_fixture_setup jq
  test_refresh_before_checksum=$(cksum < "$TEST_REFRESH_FILE")
  test_refresh_responses_write oci-index.json "$test_refresh_new_digest"
  set +e
  test_refresh_rollback_output=$(SHIMMY_TEST_MODE=1 \
    SHIMMY_TEST_CATALOG_REFRESH_FAILURE=after-write \
    test_refresh_fixture_run "$TEST_REFRESH_SELECTOR" 2>&1)
  test_refresh_rollback_status=$?
  set -e
  [ "$test_refresh_rollback_status" -ne 0 ] || fail_test 'injected post-write catalog refresh failure passed'
  assert_contains "$test_refresh_rollback_output" 'rollback complete'
  assert_equals "$(cksum < "$TEST_REFRESH_FILE")" "$test_refresh_before_checksum"
  assert_equals "$(git -C "$TEST_IMAGES_CHECKOUT" status --porcelain --untracked-files=all)" ''
  assert_path_not_exists "$TEST_IMAGES_CHECKOUT/.git/shimmy-catalog-refresh.lock"
  assert_equals "$(cksum < "$TEST_REFRESH_REGISTRY")" "$TEST_REFRESH_REGISTRY_CHECKSUM"
  pass 'catalog refresh revalidates clean-main authority and exactly rolls back post-write failure'
}

test_commands_catalog_inspection() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_generation=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_config/catalogs/default/registry.conf")

  test_catalog_status=$(env SHIMMY_CONFIG_ROOT="$test_catalog_config" "$ROOT_DIR/commands/catalog.sh" status --format manifest)
  test_catalog_tools=$(env SHIMMY_CONFIG_ROOT="$test_catalog_config" "$ROOT_DIR/commands/catalog.sh" tools --format manifest)
  test_catalog_retained=$(env SHIMMY_CONFIG_ROOT="$test_catalog_config" "$ROOT_DIR/commands/catalog.sh" tools --generation "$test_catalog_generation" --format manifest)
  assert_contains "$test_catalog_status" "shimmy_catalog=default|$test_catalog_generation||"
  assert_equals "$test_catalog_tools" "$test_catalog_retained"
  assert_contains "$test_catalog_tools" "default|$test_catalog_generation|rg|"
  pass 'catalog command renders deterministic local status and retained tools'
}

test_commands_catalog_mutation() {
  setup_scenario
  test_catalog_checkout=$SCENARIO_DIR/checkout
  test_catalog_config=$SCENARIO_DIR/config/shimmy
  test_catalog_fixture_create "$test_catalog_checkout" "$test_catalog_config"
  test_catalog_initial=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_config/catalogs/default/registry.conf")
  test_catalog_source_advance "$test_catalog_checkout" 'Command publication.'
  test_catalog_publish_output=$(cd "$test_catalog_checkout" && env SHIMMY_CONFIG_ROOT="$test_catalog_config" ./commands/catalog.sh publish)
  test_catalog_published=$(sed -n '3s/^catalog_generation_current=//p' "$test_catalog_config/catalogs/default/registry.conf")
  assert_contains "$test_catalog_publish_output" "shimmy_catalog=default|$test_catalog_published|$test_catalog_initial|"
  test_catalog_rollback_output=$(env SHIMMY_CONFIG_ROOT="$test_catalog_config" "$ROOT_DIR/commands/catalog.sh" rollback)
  assert_contains "$test_catalog_rollback_output" "shimmy_catalog=default|$test_catalog_initial|$test_catalog_published|"
  pass 'catalog command publishes clean main and rolls back'
}

test_commands_catalog_verify_dependencies() {
  test_images_fixture_setup

  for test_images_dependency in jq skopeo; do
    case "$test_images_dependency" in
      jq) test_images_dependency_version=1.8 ;;
      skopeo) test_images_dependency_version=1.22 ;;
    esac
    test_images_runtime=$TEST_IMAGES_PROFILE_ROOT/tools/$test_images_dependency/versions/$test_images_dependency_version/run.sh
    mv "$test_images_runtime" "$test_images_runtime.missing"
    : > "$TEST_IMAGES_CALL_LOG"
    set +e
    test_images_missing_output=$(test_images_fixture_run --tool jq --format manifest 2>&1)
    test_images_missing_status=$?
    set -e
    [ "$test_images_missing_status" -ne 0 ] ||
      fail_test "catalog verification accepted missing $test_images_dependency runtime"
    assert_contains "$test_images_missing_output" \
      "shimmy shim add $test_images_dependency@$test_images_dependency_version"
    assert_equals "$(cat "$TEST_IMAGES_CALL_LOG")" ''
    mv "$test_images_runtime.missing" "$test_images_runtime"
  done

  cp "$TEST_IMAGES_PROFILE_ROOT/install-manifest.txt" "$SCENARIO_DIR/install-manifest.saved"
  sed '/^shim=jq|/d; /^shim_version=jq|/d' "$SCENARIO_DIR/install-manifest.saved" \
    > "$TEST_IMAGES_PROFILE_ROOT/install-manifest.txt"
  : > "$TEST_IMAGES_CALL_LOG"
  set +e
  test_images_missing_output=$(test_images_fixture_run --tool jq --format manifest 2>&1)
  test_images_missing_status=$?
  set -e
  [ "$test_images_missing_status" -ne 0 ] ||
    fail_test 'catalog verification accepted a stray jq runtime without manifest authority'
  assert_contains "$test_images_missing_output" 'shimmy shim add jq@1.8'
  assert_equals "$(cat "$TEST_IMAGES_CALL_LOG")" ''
  mv "$SCENARIO_DIR/install-manifest.saved" "$TEST_IMAGES_PROFILE_ROOT/install-manifest.txt"
  pass 'catalog verification resolves jq and Skopeo only from active materialization with exact add remediation'
}

test_commands_catalog_verify_fixtures() {
  test_images_fixture_setup

  test_images_all_output=$(test_images_fixture_run --format manifest)
  assert_equals "$(printf '%s\n' "$test_images_all_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 3
  assert_contains "$test_images_all_output" 'image_verify=jq|1.8|runtime|'
  assert_contains "$test_images_all_output" 'image_verify=skopeo|1.22|runtime|'

  : > "$TEST_IMAGES_CALL_LOG"
  test_images_repeated_output=$(test_images_fixture_run \
    --tool jq --tool skopeo --tool jq --format manifest)
  assert_equals "$(printf '%s\n' "$test_images_repeated_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 2
  assert_equals "$(awk -F '|' '$1 == "raw" { count++ } END { print count + 0 }' "$TEST_IMAGES_CALL_LOG")" 2
  assert_equals "$(awk -F '|' '$1 == "digest" { count++ } END { print count + 0 }' "$TEST_IMAGES_CALL_LOG")" 2

  for test_images_fixture_case in \
    'single-manifest.json|unsupported-media-type' \
    'malformed.json|malformed-json' \
    'missing-arm64.json|missing-required-platform' \
    'empty-index.json|missing-descriptors'
  do
    test_images_fixture_file=${test_images_fixture_case%%|*}
    test_images_fixture_error=${test_images_fixture_case#*|}
    test_images_responses_write "$test_images_fixture_file" \
      sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91
    set +e
    test_images_fixture_output=$(test_images_fixture_run --tool jq --format manifest 2>&1)
    test_images_fixture_status=$?
    set -e
    [ "$test_images_fixture_status" -ne 0 ] ||
      fail_test "$test_images_fixture_file unexpectedly passed catalog verification"
    assert_contains "$test_images_fixture_output" "|fail|$test_images_fixture_error"
  done

  test_images_responses_write oci-index.json \
    sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
  test_images_drift_output=$(test_images_fixture_run --tool jq --format manifest)
  assert_contains "$test_images_drift_output" '|moved|warning|none'
  set +e
  test_images_strict_output=$(test_images_fixture_run \
    --tool jq --require-current-upstream --format manifest 2>&1)
  test_images_strict_status=$?
  set -e
  [ "$test_images_strict_status" -ne 0 ] || fail_test 'strict catalog upstream drift unexpectedly passed'
  assert_contains "$test_images_strict_output" '|moved|fail|upstream-drift'

  test_images_fixture_setup authenticated
  set +e
  test_images_auth_output=$(test_images_fixture_run --tool jq --format manifest 2>&1)
  test_images_auth_status=$?
  set -e
  [ "$test_images_auth_status" -ne 0 ] || fail_test 'authenticated catalog verification passed without a secret'
  assert_contains "$test_images_auth_output" '|missing|not-checked|fail|authentication-required'
  test_images_public_output=$(test_images_fixture_run --tool jq --public-only --format manifest)
  assert_contains "$test_images_public_output" '|skipped|not-checked|skip|none'
  test_images_secret_output=$(SHIMMY_SKOPEO_AUTH_SECRET='secret|value' \
    test_images_fixture_run --tool jq --format manifest)
  assert_contains "$test_images_secret_output" '|authenticated|current|pass|none'
  assert_not_contains "$test_images_secret_output" 'secret|value'
  pass 'catalog verify preserves selection, cache, index, authentication, encoding, and drift semantics'
}

test_commands_catalog_run() {
  test_commands_catalog_inspection
  test_commands_catalog_mutation
  test_commands_catalog_verify_fixtures
  test_commands_catalog_verify_dependencies
  test_commands_catalog_refresh_parser
  test_commands_catalog_refresh_external
  test_commands_catalog_refresh_local_build
  test_commands_catalog_refresh_remote_rejections
  test_commands_catalog_refresh_policy_rejections
  test_commands_catalog_refresh_source_transaction
}
