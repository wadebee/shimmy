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

test_tools_opnsense_mcp_read_only_run() {
  test_tools_opnsense_mcp_read_only_invalid_url
  test_tools_opnsense_mcp_read_only_preview_defaults
}
