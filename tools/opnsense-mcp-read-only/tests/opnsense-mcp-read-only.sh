#!/bin/sh
# Preview-safe OPNsense read-only MCP runtime tests.

test_tools_opnsense_mcp_read_only_invalid_url() {
  set +e
  output=$(OPNSENSE_URL=https://firewall.example/other "$ROOT_DIR/commands/run-tool.sh" opnsense-mcp-read-only --preview-shim --help 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "read-only MCP accepted an unsupported OPNsense URL path"
  assert_contains "$output" "OPNSENSE_URL path must be empty, /, or /api for opnsense-mcp-read-only: /other"
  pass "read-only MCP rejects unsupported OPNsense URL paths"
}

test_tools_opnsense_mcp_read_only_preview_defaults() {
  output=$(OPNSENSE_URL=firewall.example "$ROOT_DIR/commands/run-tool.sh" opnsense-mcp-read-only --preview-shim --help)

  assert_contains "$output" "'OPNSENSE_URL=https://firewall.example/api'"
  assert_contains "$output" "'OPNSENSE_VERIFY_SSL=false'"
  assert_contains "$output" "'OPNSENSE_ALLOW_WRITES=false'"
  assert_contains "$output" "'opnsense_mcp_read_only_api_key,type=env,target=OPNSENSE_API_KEY'"
  assert_contains "$output" "'opnsense_mcp_read_only_api_secret,type=env,target=OPNSENSE_API_SECRET'"
  assert_not_contains "$output" "opnsense_mcp_admin_api_key"
  pass "read-only MCP preview preserves API and no-write defaults"
}

test_tools_opnsense_mcp_read_only_preview_ca_bundle() {
  setup_scenario
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  printf '%s\n' fixture-ca > "$ca_bundle"

  output=$(OPNSENSE_URL=firewall.example SHIMMY_HOST_CA_BUNDLE="$ca_bundle" SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE=example.invalid/shimmy/opnsense-mcp-read-only:test run_in_repo ./commands/run-tool.sh opnsense-mcp-read-only --preview-shim)

  assert_contains "$output" "'-v' '$ca_bundle:/tmp/shimmy-host-ca-bundle.pem:ro'"
  assert_contains "$output" "'-e' 'SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem'"
  assert_contains "$output" "'opnsense_mcp_read_only_api_key,type=env,target=OPNSENSE_API_KEY'"
  assert_contains "$output" "'opnsense_mcp_read_only_api_secret,type=env,target=OPNSENSE_API_SECRET'"
  pass "read-only MCP preview maps the host CA bundle without changing its secrets"
}

test_tools_opnsense_mcp_read_only_curl_ca_bundle() {
  setup_scenario
  fake_bin_dir=$SCENARIO_DIR/fake-bin
  fake_curl=$fake_bin_dir/curl
  fake_podman=$fake_bin_dir/podman
  curl_args=$SCENARIO_DIR/curl-args
  ca_bundle="$SCENARIO_DIR/host CA bundle.pem"
  mkdir -p "$fake_bin_dir"
  printf '%s\n' fixture-ca > "$ca_bundle"
  printf '%s\n' \
    '#!/bin/sh' \
    ': > "$FAKE_CURL_ARGS"' \
    'for arg do' \
    '  printf "%s\\n" "$arg" >> "$FAKE_CURL_ARGS"' \
    'done' \
    > "$fake_curl"
  printf '%s\n' \
    '#!/bin/sh' \
    'exit 0' \
    > "$fake_podman"
  chmod 0755 "$fake_curl" "$fake_podman"

  PATH="$fake_bin_dir:/usr/bin:/bin" \
    FAKE_CURL_ARGS="$curl_args" \
    OPNSENSE_URL=https://firewall.example \
    OPNSENSE_VERIFY_SSL=true \
    SHIMMY_HOST_CA_BUNDLE="$ca_bundle" \
    SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE=example.invalid/shimmy/opnsense-mcp-read-only:test \
    run_in_repo ./commands/run-tool.sh opnsense-mcp-read-only

  assert_equals "$(cat "$curl_args")" "--silent
--show-error
--output
/dev/null
--connect-timeout
10
--max-time
20
--cacert
$ca_bundle
https://firewall.example/api"

  PATH="$fake_bin_dir:/usr/bin:/bin" \
    FAKE_CURL_ARGS="$curl_args" \
    OPNSENSE_URL=https://firewall.example \
    OPNSENSE_VERIFY_SSL=false \
    SHIMMY_HOST_CA_BUNDLE="$ca_bundle" \
    SHIMMY_OPNSENSE_MCP_READ_ONLY_IMAGE=example.invalid/shimmy/opnsense-mcp-read-only:test \
    run_in_repo ./commands/run-tool.sh opnsense-mcp-read-only

  assert_equals "$(cat "$curl_args")" "--silent
--show-error
--output
/dev/null
--connect-timeout
10
--max-time
20
--insecure
https://firewall.example/api"
  pass "read-only MCP curl uses one exact CA path only when TLS verification is enabled"
}

test_tools_opnsense_mcp_read_only_run() {
  test_tools_opnsense_mcp_read_only_invalid_url
  test_tools_opnsense_mcp_read_only_preview_defaults
  test_tools_opnsense_mcp_read_only_preview_ca_bundle
  test_tools_opnsense_mcp_read_only_curl_ca_bundle
}
