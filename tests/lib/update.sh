#!/bin/sh

test_lib_update_run() {
  setup_scenario
  SHIMMY_PROFILE_ROOT=$SCENARIO_DIR/profile
  SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR=$SHIMMY_PROFILE_ROOT/tools
  refresh_dir=$SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR/jq/versions/1.8
  refresh_log=$SCENARIO_DIR/refresh.log
  mkdir -p "$refresh_dir"
  {
    printf '%s\n' '#!/bin/sh'
    printf 'printf "%%s\\n" "$1" > %s\n' "$(shimmy_quote_shell_word "$refresh_log")"
  } > "$refresh_dir/refresh.sh"
  chmod 755 "$refresh_dir/refresh.sh"

  # shellcheck source=lib/update/refresh.sh
  . "$ROOT_DIR/lib/update/refresh.sh"
  shimmy_update_refresh_hooks_run pull jq_1_8
  assert_file_contains "$refresh_log" pull
  pass "profile-local update refresh hook contract works"
}
