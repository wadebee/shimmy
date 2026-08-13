#!/bin/sh
# Community Ansible Development Tools preview and opt-in safety tests.

test_tools_community_ansible_dev_tools_default_preview() {
  output=$(SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE=example.invalid/shimmy/community-ansible-dev-tools:test SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE_PULL=always run_in_repo ./commands/run-tool.sh community-ansible-dev-tools --preview-shim --version)

  assert_contains "$output" "'--pull=always'"
  assert_contains "$output" "'$ROOT_DIR:/workdir:rw'"
  assert_contains "$output" "'-w' '/workdir'"
  assert_contains "$output" "'example.invalid/shimmy/community-ansible-dev-tools:test' 'adt' '--version'"
  assert_not_contains "$output" "'/root/.gitconfig:ro'"
  assert_not_contains "$output" "'SSH_AUTH_SOCK="
  assert_not_contains "$output" "'--cap-add'"
  assert_not_contains "$output" "'--security-opt'"
  pass "community-ansible-dev-tools preview keeps credentials and nested Podman privileges opt-in"
}

test_tools_community_ansible_dev_tools_mount_workdir_preview() {
  setup_scenario
  workdir_override=$SCENARIO_DIR/workdir-override
  mkdir -p "$workdir_override"

  output=$(run_in_repo ./commands/run-tool.sh community-ansible-dev-tools --preview-shim --mount-workdir "$workdir_override" ansible-playbook site.yml)

  assert_contains "$output" "'$workdir_override:/workdir:rw'"
  assert_contains "$output" "'ansible-playbook' 'site.yml'"
  pass "community-ansible-dev-tools can override the /workdir mount from the command line"
}

test_tools_community_ansible_dev_tools_nested_podman_preview() {
  output=$(SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN=1 run_in_repo ./commands/run-tool.sh community-ansible-dev-tools --preview-shim --version)

  assert_contains "$output" "'--cap-add' 'SYS_ADMIN'"
  assert_contains "$output" "'--cap-add' 'SYS_RESOURCE'"
  assert_contains "$output" "'--device' '/dev/fuse'"
  assert_contains "$output" "'--hostname' 'ansible-dev-container'"
  assert_contains "$output" "'--security-opt' 'apparmor=unconfined'"
  assert_contains "$output" "'--security-opt' 'label=disable'"
  assert_contains "$output" "'--security-opt' 'seccomp=unconfined'"
  assert_contains "$output" "'--user' 'root'"
  assert_contains "$output" "'--userns' 'host'"
  assert_not_contains "$output" "'--name'"
  pass "community-ansible-dev-tools nested Podman opt-in matches the upstream container guidance"
}

test_tools_community_ansible_dev_tools_credential_preview() {
  setup_scenario
  git_config=$HOME_DIR/.gitconfig
  ssh_auth_sock=$SCENARIO_DIR/ssh-agent.sock
  printf '%s\n' '[user]' > "$git_config"

  output=$(HOME="$HOME_DIR" SSH_AUTH_SOCK="$ssh_auth_sock" SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG=1 SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT=1 run_in_repo ./commands/run-tool.sh community-ansible-dev-tools --preview-shim ansible-playbook site.yml)

  assert_contains "$output" "'$git_config:/root/.gitconfig:ro'"
  assert_contains "$output" "'$ssh_auth_sock:$ssh_auth_sock:rw'"
  assert_contains "$output" "'SSH_AUTH_SOCK=$ssh_auth_sock'"
  assert_contains "$output" "'ansible-playbook' 'site.yml'"
  pass "community-ansible-dev-tools credential opt-ins mount git configuration and the SSH agent explicitly"
}

test_tools_community_ansible_dev_tools_option_validation() {
  disabled_output=$(SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN=0 run_in_repo ./commands/run-tool.sh community-ansible-dev-tools --preview-shim --version)
  assert_not_contains "$disabled_output" "'--cap-add'"

  set +e
  output=$(SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN=yes run_in_repo ./commands/run-tool.sh community-ansible-dev-tools --preview-shim --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "community-ansible-dev-tools accepted an invalid nested Podman setting"
  assert_contains "$output" "SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN must be 1, 0, or unset"

  set +e
  output=$(run_in_repo ./commands/run-tool.sh community-ansible-dev-tools --preview-shim --mount-workdir relative-path --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "community-ansible-dev-tools accepted a relative mount-workdir path"
  assert_contains "$output" "--mount-workdir requires an absolute host path: relative-path"

  set +e
  output=$(run_in_repo ./commands/run-tool.sh community-ansible-dev-tools --mount-workdir "$SCENARIO_DIR/missing-workdir" --version 2>&1)
  status_code=$?
  set -e

  [ "$status_code" -ne 0 ] || fail_test "community-ansible-dev-tools accepted a missing mount-workdir path"
  assert_contains "$output" "workdir host path does not exist: $SCENARIO_DIR/missing-workdir"
  pass "community-ansible-dev-tools validates security-sensitive opt-in values and workdir overrides"
}

test_tools_community_ansible_dev_tools_run() {
  test_tools_community_ansible_dev_tools_default_preview
  test_tools_community_ansible_dev_tools_mount_workdir_preview
  test_tools_community_ansible_dev_tools_nested_podman_preview
  test_tools_community_ansible_dev_tools_credential_preview
  test_tools_community_ansible_dev_tools_option_validation
}
