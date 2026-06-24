#!/bin/sh
# Canonical skill source, export, update, and cleanup tests.

test_commands_skills_export_folder() {
  setup_scenario
  export_dir=$SCENARIO_DIR/exported-skills

  output=$(run_in_repo ./shimmy skills install --export "$export_dir" 2>&1)

  assert_contains "$output" "Exported skills folder: $export_dir"
  assert_file_exists "$export_dir/shimmy-install/SKILL.md"
  assert_file_exists "$export_dir/shimmy-init/SKILL.md"
  assert_file_exists "$export_dir/.shimmy-skills-manifest.txt"
  assert_file_contains "$export_dir/.shimmy-skills-manifest.txt" "shimmy_skills_target=export"
  diff -qr "$ROOT_DIR/agent/core/shimmy-install" "$export_dir/shimmy-install" >/dev/null
  pass "skills export writes a portable folder"
}

test_commands_skills_installed_kinds() {
  setup_scenario

  HOME="$HOME_DIR" run_in_repo ./shimmy install --install-dir "$INSTALL_DIR" --shim jq --shim task --no-startup --no-skills >/dev/null
  manifest_file=$INSTALL_DIR/profiles/default/install-manifest.txt
  output=$(cd "$WORK_DIR" && "$INSTALL_DIR/bin/shimmy" skills install --target repo --manifest "$manifest_file" 2>&1)

  assert_contains "$output" "Installed skill: shimmy-tool-jq"
  assert_contains "$output" "Installed skill: shimmy-tool-task"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-tool-jq/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-tool-task/SKILL.md"
  assert_file_contains "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt" "shimmy_skill=repo|shimmy-tool-jq|.agents/skills/shimmy-tool-jq|"
  assert_file_contains "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt" "shimmy_skill=repo|shimmy-tool-task|.agents/skills/shimmy-tool-task|"
  pass "skills select tool guidance from the installed kind manifest"
}

test_commands_skills_repo_portability() {
  setup_scenario

  output=$(cd "$WORK_DIR" && "$ROOT_DIR/shimmy" skills install --target repo 2>&1)
  manifest_file=$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt

  assert_contains "$output" "Installed skill: shimmy-install"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-install/SKILL.md"
  assert_file_exists "$WORK_DIR/.agents/skills/shimmy-escalation/SKILL.md"
  assert_file_contains "$manifest_file" "shimmy_skills_manifest_version=1"
  assert_file_contains "$manifest_file" "shimmy_skills_root=.agents/skills"
  assert_file_contains "$manifest_file" "shimmy_skill=repo|shimmy-install|.agents/skills/shimmy-install|"
  assert_not_contains "$(cat "$manifest_file")" "$WORK_DIR"
  pass "repo skills manifests use portable paths and canonical sources"
}

test_commands_skills_uninstall_manifest_tracked() {
  setup_scenario

  (cd "$WORK_DIR" && "$ROOT_DIR/shimmy" skills install --target repo >/dev/null)
  mkdir -p "$WORK_DIR/.agents/skills/unmanaged"
  printf 'unmanaged\n' > "$WORK_DIR/.agents/skills/unmanaged/SKILL.md"

  output=$(cd "$WORK_DIR" && "$ROOT_DIR/shimmy" skills uninstall --target repo 2>&1)

  assert_contains "$output" "Removed skill: shimmy-install"
  assert_path_not_exists "$WORK_DIR/.agents/skills/shimmy-install"
  assert_path_not_exists "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt"
  assert_file_exists "$WORK_DIR/.agents/skills/unmanaged/SKILL.md"
  pass "skills uninstall removes only manifest-tracked content"
}

test_commands_skills_update_manifest_tracked() {
  setup_scenario

  (cd "$WORK_DIR" && "$ROOT_DIR/shimmy" skills install --target repo shimmy-tool-task >/dev/null)
  printf 'stale\n' > "$WORK_DIR/.agents/skills/shimmy-tool-task/SKILL.md"

  output=$(cd "$WORK_DIR" && "$ROOT_DIR/shimmy" skills update --target repo 2>&1)

  assert_contains "$output" "Installed skill: shimmy-tool-task"
  diff -qr "$ROOT_DIR/tools/task/agent" "$WORK_DIR/.agents/skills/shimmy-tool-task" >/dev/null
  task_manifest_count=$(sed -n 's/^shimmy_skill=repo|shimmy-tool-task|.*/skill/p' "$WORK_DIR/.agents/skills/.shimmy-skills-manifest.txt" | wc -l | tr -d ' ')
  assert_equals "$task_manifest_count" 1
  pass "skills update refreshes manifest-tracked canonical content"
}

test_commands_skills_run() {
  test_commands_skills_export_folder
  test_commands_skills_installed_kinds
  test_commands_skills_repo_portability
  test_commands_skills_uninstall_manifest_tracked
  test_commands_skills_update_manifest_tracked
}
