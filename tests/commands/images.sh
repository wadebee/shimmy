#!/bin/sh

images_fixture_alpha_config_write() {
  fixture_root=$1
  version_label=$2
  registry_access=$3
  upstream_ref=$4
  default_ref=$5
  version_name=alpha_${version_label%%.*}_${version_label#*.}
  version_dir=$fixture_root/tools/alpha/versions/$version_label

  mkdir -p "$version_dir"
  cat > "$version_dir/image.conf" <<EOF
shimmy_image_config_version=1
image_source=external
image_upstream_ref=$upstream_ref
image_default_ref=$default_ref
image_registry_access=$registry_access
image_platform=linux/amd64
image_platform=linux/arm64
EOF
  printf 'shim_config_version=1\nshim_name=%s\nsmoke_arg=--version\n' "$version_name" > "$version_dir/smoke.conf"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$version_dir/run.sh"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$version_dir/refresh.sh"
  chmod 755 "$version_dir/run.sh" "$version_dir/refresh.sh"
}

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
while IFS='|' read -r response_mode response_ref response_value response_status; do
  [ "$response_mode" = "$mode" ] || continue
  [ "$response_ref" = "$remote_ref" ] || continue
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
  chmod 755 "$jq_run" "$skopeo_run"
}

images_fixture_response_write() {
  response_file=$1
  raw_fixture=$2
  alpha_upstream_digest=$3
  alpha_raw_status=${4:-ok}
  alpha_digest_status=${5:-$alpha_raw_status}
  cat > "$response_file" <<EOF
raw|registry.example/alpha@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc|$raw_fixture|$alpha_raw_status
digest|registry.example/alpha:current|$alpha_upstream_digest|$alpha_digest_status
raw|ghcr.io/jqlang/jq@sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91|oci-index.json|ok
digest|ghcr.io/jqlang/jq:1.8.1|sha256:4f34c6d23f4b1372ac789752cc955dc67c2ae177eb1b5860b75cdc5091ce6f91|ok
raw|quay.io/skopeo/stable@sha256:c7d3c512612f52805023cd38351081dad7e2729fc13d14b701e47c7c8bdd6615|docker-list.json|ok
digest|quay.io/skopeo/stable:latest|sha256:c7d3c512612f52805023cd38351081dad7e2729fc13d14b701e47c7c8bdd6615|ok
EOF
}

images_fixture_source_setup() {
  setup_scenario
  IMAGES_FIXTURE_ROOT=$SCENARIO_DIR/source
  IMAGES_FIXTURE_CALL_LOG=$SCENARIO_DIR/image-calls
  IMAGES_FIXTURE_RESPONSES=$SCENARIO_DIR/image-responses
  mkdir -p "$IMAGES_FIXTURE_ROOT" "$IMAGES_FIXTURE_ROOT/tools"
  cp "$ROOT_DIR/catalog.conf" "$IMAGES_FIXTURE_ROOT/catalog.conf"
  test_fixture_tree_copy "$ROOT_DIR/commands" "$IMAGES_FIXTURE_ROOT/commands"
  test_fixture_tree_copy "$ROOT_DIR/lib" "$IMAGES_FIXTURE_ROOT/lib"
  test_fixture_tree_copy "$ROOT_DIR/plugins" "$IMAGES_FIXTURE_ROOT/plugins"
  test_fixture_tree_copy "$ROOT_DIR/tools/jq" "$IMAGES_FIXTURE_ROOT/tools/jq"
  test_fixture_tree_copy "$ROOT_DIR/tools/skopeo" "$IMAGES_FIXTURE_ROOT/tools/skopeo"
  mkdir -p "$IMAGES_FIXTURE_ROOT/tools/alpha"
  printf '%s\n' 'shim_config_version=1' 'shim_name=alpha' 'tool_default_version=1.0' 'tool_selector_env=' 'smoke_arg=--version' > "$IMAGES_FIXTURE_ROOT/tools/alpha/tool.conf"
  printf '%s\n' '---' 'name: shimmy-tool-alpha' 'description: Image verification fixture skill.' '---' > "$IMAGES_FIXTURE_ROOT/tools/alpha/SKILL.md"
  images_fixture_alpha_config_write "$IMAGES_FIXTURE_ROOT" 1.0 public \
    registry.example/alpha:current \
    registry.example/alpha@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
  images_fixture_alpha_config_write "$IMAGES_FIXTURE_ROOT" 2.0 public \
    registry.example/alpha:current \
    registry.example/alpha@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
  images_fixture_fake_runtimes_write "$IMAGES_FIXTURE_ROOT"
  : > "$IMAGES_FIXTURE_CALL_LOG"
  images_fixture_response_write "$IMAGES_FIXTURE_RESPONSES" oci-index.json \
    sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
}

images_fixture_source_run() {
  env \
    SHIMMY_TEST_IMAGES_CALL_LOG="$IMAGES_FIXTURE_CALL_LOG" \
    SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures" \
    SHIMMY_TEST_IMAGES_RESPONSE_FILE="$IMAGES_FIXTURE_RESPONSES" \
    "$IMAGES_FIXTURE_ROOT/commands/images.sh" "$@"
}

test_commands_images_authentication() {
  images_fixture_source_setup
  images_fixture_alpha_config_write "$IMAGES_FIXTURE_ROOT" 1.0 authenticated \
    registry.example/alpha:current \
    registry.example/alpha@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

  set +e
  auth_output=$(images_fixture_source_run verify --shim alpha --format manifest 2>&1)
  auth_status=$?
  set -e
  [ "$auth_status" -ne 0 ] || fail_test "authenticated image verification unexpectedly passed without credentials"
  assert_contains "$auth_output" '|missing|not-checked|fail|authentication-required'
  assert_equals "$(cat "$IMAGES_FIXTURE_CALL_LOG")" ''

  public_output=$(images_fixture_source_run verify --shim alpha --public-only --format manifest)
  assert_contains "$public_output" '|not-inspected|not-inspected|skipped|not-checked|skip|none'

  secret_output=$(SHIMMY_SKOPEO_AUTH_SECRET=do-not-print images_fixture_source_run verify --shim alpha --format manifest)
  assert_contains "$secret_output" '|authenticated|current|pass|none'
  assert_not_contains "$secret_output" 'do-not-print'
  pass "image verification requires explicit authentication or visibly skips authenticated entries"
}

test_commands_images_drift_and_failures() {
  images_fixture_source_setup
  images_fixture_response_write "$IMAGES_FIXTURE_RESPONSES" oci-index.json \
    sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd

  drift_output=$(images_fixture_source_run verify --shim alpha --format manifest)
  assert_contains "$drift_output" '|moved|warning|none'
  set +e
  strict_output=$(images_fixture_source_run verify --shim alpha --require-current-upstream --format manifest 2>&1)
  strict_status=$?
  set -e
  [ "$strict_status" -ne 0 ] || fail_test "strict upstream drift unexpectedly passed"
  assert_contains "$strict_output" '|moved|fail|upstream-drift'

  images_fixture_alpha_config_write "$IMAGES_FIXTURE_ROOT" 1.0 public \
    registry.example/alpha@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
    registry.example/alpha@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
  : > "$IMAGES_FIXTURE_CALL_LOG"
  digest_output=$(images_fixture_source_run verify --shim alpha --format manifest)
  assert_contains "$digest_output" '|not-applicable|pass|none'
  assert_equals "$(awk -F '|' '$1 == "digest" { count++ } END { print count + 0 }' "$IMAGES_FIXTURE_CALL_LOG")" 0

  images_fixture_alpha_config_write "$IMAGES_FIXTURE_ROOT" 1.0 public \
    registry.example/alpha:current \
    registry.example/alpha@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
  images_fixture_response_write "$IMAGES_FIXTURE_RESPONSES" oci-index.json \
    sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc ok fail
  set +e
  unreachable_output=$(images_fixture_source_run verify --shim alpha --format manifest 2>&1)
  unreachable_status=$?
  set -e
  [ "$unreachable_status" -ne 0 ] || fail_test "unreachable upstream reference unexpectedly passed"
  assert_contains "$unreachable_output" '|unreachable|fail|upstream-reference-unreachable'
  pass "image verification reports upstream drift, strict drift, digest-only upstreams, and unreachable references"
}

test_commands_images_fixture_parsing() {
  images_fixture_source_setup

  for fixture_case in \
    'oci-index.json|application/vnd.oci.image.index.v1+json' \
    'docker-list.json|application/vnd.docker.distribution.manifest.list.v2+json'
  do
    fixture_file=${fixture_case%%|*}
    fixture_media=${fixture_case#*|}
    images_fixture_response_write "$IMAGES_FIXTURE_RESPONSES" "$fixture_file" \
      sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
    fixture_output=$(images_fixture_source_run verify --shim alpha --format manifest)
    assert_contains "$fixture_output" "|$fixture_media|verified|public|current|pass|none"
  done
  human_output=$(images_fixture_source_run verify --shim alpha)
  assert_contains "$human_output" 'PASS alpha@1.0 runtime digest=sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
  assert_contains "$human_output" 'platforms=verified access=public upstream=current'

  for fixture_case in \
    'single-manifest.json|unsupported-media-type' \
    'child-digest.json|unsupported-media-type' \
    'malformed.json|malformed-json' \
    'missing-arm64.json|missing-required-platform' \
    'unsupported-media.json|unsupported-media-type' \
    'empty-index.json|missing-descriptors' \
    'absent-manifests.json|missing-descriptors'
  do
    fixture_file=${fixture_case%%|*}
    fixture_error=${fixture_case#*|}
    images_fixture_response_write "$IMAGES_FIXTURE_RESPONSES" "$fixture_file" \
      sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
    set +e
    fixture_output=$(images_fixture_source_run verify --shim alpha --format manifest 2>&1)
    fixture_status=$?
    set -e
    [ "$fixture_status" -ne 0 ] || fail_test "$fixture_file unexpectedly passed image verification"
    assert_contains "$fixture_output" "|fail|$fixture_error"
  done
  pass "OCI and Docker index fixtures accept required variants while invalid manifests fail stably"
}

test_commands_images_installed_selection() {
  setup_scenario_with_profiles default
  default_shimmy install --shim skopeo >/dev/null
  images_fixture_fake_runtimes_write "$DEFAULT_PROFILE_ROOT"
  IMAGES_FIXTURE_CALL_LOG=$SCENARIO_DIR/image-calls
  IMAGES_FIXTURE_RESPONSES=$SCENARIO_DIR/image-responses
  : > "$IMAGES_FIXTURE_CALL_LOG"
  : > "$IMAGES_FIXTURE_RESPONSES"

  for tool_name in jq rg; do
    version_name=$(shimmy_tool_version_default "$tool_name")
    config_file=$(shimmy_version_image_config_file "$version_name")
    default_ref=$(shimmy_image_config_scalar_read "$config_file" image_default_ref)
    upstream_ref=$(shimmy_image_config_scalar_read "$config_file" image_upstream_ref)
    printf 'raw|%s|oci-index.json|ok\n' "$default_ref" >> "$IMAGES_FIXTURE_RESPONSES"
    printf 'digest|%s|%s|ok\n' "$upstream_ref" "$(shimmy_images_digest_read "$default_ref")" >> "$IMAGES_FIXTURE_RESPONSES"
  done

  installed_output=$(env \
    SHIMMY_TEST_IMAGES_CALL_LOG="$IMAGES_FIXTURE_CALL_LOG" \
    SHIMMY_TEST_IMAGES_FIXTURE_DIR="$ROOT_DIR/tests/commands/image-fixtures" \
    SHIMMY_TEST_IMAGES_RESPONSE_FILE="$IMAGES_FIXTURE_RESPONSES" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME_DIR" HOME="$HOME_DIR" \
    "$DEFAULT_PROFILE_ROOT/bin/shimmy" images verify --shim jq --shim rg --format manifest)
  assert_equals "$(printf '%s\n' "$installed_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 2
  assert_contains "$installed_output" 'image_verify=jq|1.8|runtime|'
  assert_contains "$installed_output" 'image_verify=rg|15.1|runtime|'

  help_output=$(default_shimmy images verify --help)
  assert_contains "$help_output" 'shimmy images verify'
  pass "installed image verification defaults to manifest-recorded concrete versions"
}

test_commands_images_selection_and_deduplication() {
  images_fixture_source_setup

  set +e
  source_output=$(images_fixture_source_run verify 2>&1)
  source_status=$?
  set -e
  [ "$source_status" -ne 0 ] || fail_test "source image verification unexpectedly accepted an empty selection"
  assert_contains "$source_output" 'requires --all or at least one --shim'

  all_output=$(images_fixture_source_run verify --all --format manifest)
  assert_equals "$(printf '%s\n' "$all_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 4

  : > "$IMAGES_FIXTURE_CALL_LOG"
  repeated_output=$(images_fixture_source_run verify --shim alpha --shim alpha@2.0 --shim alpha --format manifest)
  assert_equals "$(printf '%s\n' "$repeated_output" | awk '/^image_verify=/ { count++ } END { print count + 0 }')" 2
  assert_equals "$(awk -F '|' '$1 == "raw" { count++ } END { print count + 0 }' "$IMAGES_FIXTURE_CALL_LOG")" 1
  assert_equals "$(awk -F '|' '$1 == "digest" { count++ } END { print count + 0 }' "$IMAGES_FIXTURE_CALL_LOG")" 1

  for invalid_selection in unknown alpha@9.9; do
    set +e
    selection_output=$(images_fixture_source_run verify --shim "$invalid_selection" 2>&1)
    selection_status=$?
    set -e
    [ "$selection_status" -ne 0 ] || fail_test "invalid selection unexpectedly passed: $invalid_selection"
    assert_contains "$selection_output" 'unsupported'
  done

  invalid_config=$IMAGES_FIXTURE_ROOT/tools/alpha/versions/1.0/image.conf
  printf 'image_platform=linux/amd64\n' >> "$invalid_config"
  : > "$IMAGES_FIXTURE_CALL_LOG"
  set +e
  metadata_output=$(images_fixture_source_run verify --shim alpha --format manifest 2>&1)
  metadata_status=$?
  set -e
  [ "$metadata_status" -ne 0 ] || fail_test "invalid selected metadata unexpectedly passed"
  assert_contains "$metadata_output" 'image_platform must declare exactly two values'
  assert_equals "$(cat "$IMAGES_FIXTURE_CALL_LOG")" ''
  pass "source selection validates offline and deduplicates shared remote references"
}

test_commands_images_run() {
  test_commands_images_fixture_parsing
  test_commands_images_selection_and_deduplication
  test_commands_images_authentication
  test_commands_images_drift_and_failures
  test_commands_images_installed_selection
}
