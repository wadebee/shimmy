#!/bin/sh
# Mike Farah yq preview-contract tests.

test_tools_yq_isolation_preview() {
  output=$(run_in_repo ./commands/run-tool.sh yq --preview-shim '.service.name' 'config file.yaml')

  assert_contains "$output" "'run' '--rm' '-i'"
  assert_contains "$output" "'--network' 'none'"
  assert_contains "$output" "'--cap-drop' 'all'"
  assert_contains "$output" "'--security-opt' 'no-new-privileges'"
  assert_contains "$output" "'--userns' 'keep-id:uid=1000,gid=1000' '--user' '1000:1000'"
  assert_contains "$output" "'-v' '$ROOT_DIR:/work' '-w' '/work'"
  assert_contains "$output" "'.service.name' 'config file.yaml'"
  pass "yq supports pipeline input and local file arguments with isolated networking and mapped ownership"
}

test_tools_yq_inplace_preview() {
  output=$(SHIMMY_YQ_IMAGE=example.invalid/shimmy/yq:test SHIMMY_YQ_IMAGE_PULL=always \
    run_in_repo ./commands/run-tool.sh yq --preview-shim -i '.service.name = "new name"' 'config file.yaml')

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'example.invalid/shimmy/yq:test' '-i' '.service.name = \"new name\"' 'config file.yaml'"
  pass "yq forwards explicit in-place edits and honors image and pull overrides"
}

test_tools_yq_run() {
  test_tools_yq_isolation_preview
  test_tools_yq_inplace_preview
}
