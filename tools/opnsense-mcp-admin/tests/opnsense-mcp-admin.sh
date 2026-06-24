#!/bin/sh
# Preview-safe OPNsense admin MCP runtime tests.

test_tools_opnsense_mcp_admin_help() {
  output=$("$ROOT_DIR/commands/run-tool.sh" opnsense-mcp-admin --help)

  assert_contains "$output" "WARNING: opnsense-mcp-admin exposes change-capable OPNsense management tools."
  assert_contains "$output" "explicit change window with a rollback and verification path"
  pass "admin MCP help requires an explicit change-window workflow"
}

test_tools_opnsense_mcp_admin_invalid_url() {
  set +e
  output=$(OPNSENSE_URL=https://firewall.example/other "$ROOT_DIR/commands/run-tool.sh" opnsense-mcp-admin --preview-shim --help 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "admin MCP accepted an unsupported OPNsense URL path"
  assert_contains "$output" "OPNSENSE_URL path must be empty, /, or /api for opnsense-mcp-admin: /other"
  pass "admin MCP rejects unsupported OPNsense URL paths"
}

test_tools_opnsense_mcp_admin_preview_defaults() {
  output=$(OPNSENSE_URL=http://firewall.example/api "$ROOT_DIR/commands/run-tool.sh" opnsense-mcp-admin --preview-shim --help)

  assert_contains "$output" "'OPNSENSE_URL=http://firewall.example'"
  assert_contains "$output" "'OPNSENSE_VERIFY_SSL=false'"
  assert_contains "$output" "'opnsense_mcp_admin_api_key,type=env,target=OPNSENSE_API_KEY'"
  assert_contains "$output" "'opnsense_mcp_admin_api_secret,type=env,target=OPNSENSE_API_SECRET'"
  assert_not_contains "$output" "'OPNSENSE_ALLOW_WRITES=false'"
  assert_not_contains "$output" "opnsense_mcp_read_only_api_key"
  pass "admin MCP preview keeps separate admin API configuration"
}

test_tools_opnsense_mcp_admin_run() {
  test_tools_opnsense_mcp_admin_help
  test_tools_opnsense_mcp_admin_invalid_url
  test_tools_opnsense_mcp_admin_preview_defaults
}
