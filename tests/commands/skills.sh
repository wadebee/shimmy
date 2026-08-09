#!/bin/sh

test_commands_skills_run() {
  setup_scenario
  bootstrap_default --shim jq >/dev/null
  (
    cd "$WORK_DIR"
    default_shimmy skills install --target repo >/dev/null
  )
  skills_root=$WORK_DIR/.agents/skills
  assert_file_exists "$skills_root/.shimmy-skills-manifest.txt"
  assert_file_exists "$skills_root/shimmy-install/SKILL.md"
  assert_file_exists "$skills_root/shimmy-tool-jq/SKILL.md"
  printf '%s\n' keep > "$skills_root/unknown-sibling"

  default_shimmy uninstall --no-skills >/dev/null
  assert_file_exists "$skills_root/shimmy-install/SKILL.md"
  (
    cd "$WORK_DIR"
    "$DEFAULT_PROFILE_ROOT/commands/skills.sh" uninstall --target repo >/dev/null
  ) 2>/dev/null || true
  # The supplying profile is gone, so explicit removal requires any remaining
  # profile's self-contained skills command. Reinstall to exercise that path.
  bootstrap_default --shim jq >/dev/null
  (
    cd "$WORK_DIR"
    default_shimmy skills uninstall --target repo >/dev/null
  )
  assert_path_not_exists "$skills_root/shimmy-install"
  assert_file_exists "$skills_root/unknown-sibling"
  pass "skills are target-manifest-owned and survive profile lifecycle"
}
