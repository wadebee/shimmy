#!/bin/sh
# Metadata-driven AI-agent preflight tests.

test_commands_agent_preflight_metadata() {
  set +e
  output=$(run_in_repo ./commands/agent-preflight.sh 2>&1)
  status_code=$?
  set -e

  case "$status_code" in
    0|1)
      ;;
    *)
      fail_test "agent preflight returned an unexpected status: $status_code"
      ;;
  esac

  assert_contains "$output" 'repo_shim=aws'
  assert_contains "$output" 'agent_prefix_rule=["./commands/run-tool.sh","aws","--version"]'
  assert_contains "$output" 'repo_shim=netcat'
  assert_contains "$output" 'agent_prefix_rule=["./commands/run-tool.sh","netcat","--preview-shim","--help"]'
  assert_contains "$output" 'repo_shim=oc'
  assert_contains "$output" 'agent_prefix_rule=["./commands/run-tool.sh","oc","--preview-shim","--help"]'
  assert_contains "$output" 'Direct `podman info` success does not approve or verify nested Podman access through a Shimmy wrapper.'
  assert_contains "$output" 'If a sandbox-only wrapper run reports a Podman denial or unreachable state'
  pass "agent preflight derives approval smokes from version metadata and explains the wrapper approval boundary"
}

test_commands_agent_preflight_run() {
  test_commands_agent_preflight_metadata
}
