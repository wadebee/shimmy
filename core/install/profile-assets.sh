#!/bin/sh
# Control-plane and profile runtime asset installation.

install_file() {
  source_path=$1
  target_path=$2

  if [ "$source_path" = "$target_path" ]; then
    chmod 755 "$target_path"
    return 0
  fi

  rm -f "$target_path"
  cp "$source_path" "$target_path"
  chmod 755 "$target_path"
}

install_directory_copy() {
  source_path=$1
  target_path=$2

  if [ "$source_path" = "$target_path" ]; then
    return 0
  fi

  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
}

install_agent_skill_assets() {
  [ -d "$SOURCE_AGENT_SKILLS_DIR" ] || return 0

  target_root=$SHIMMY_CORE_DIR/.agents/skills
  mkdir -p "$target_root"

  for source_path in "$SOURCE_AGENT_SKILLS_DIR"/shimmy-*; do
    [ -d "$source_path" ] || continue
    skill_name=$(basename "$source_path")
    install_directory_copy "$source_path" "$target_root/$skill_name"
  done
}

shim_name_kind_resolve() {
  shim_name=$1

  if shimmy_is_kind "$shim_name"; then
    printf '%s\n' "$shim_name"
    return 0
  fi

  shimmy_version_kind "$shim_name"
}

shim_name_version_label_resolve() {
  shim_name=$1

  if shimmy_is_kind "$shim_name"; then
    return 1
  fi

  shimmy_version_label "$shim_name"
}

shim_source_config_path_resolve() {
  shim_name=$1
  source_root=$2
  kind_name=$(shim_name_kind_resolve "$shim_name") || return 1

  if shimmy_is_kind "$shim_name"; then
    printf '%s/tools/%s/tool.conf\n' "$source_root" "$kind_name"
    return 0
  fi

  version_label=$(shim_name_version_label_resolve "$shim_name") || return 1
  printf '%s/tools/%s/versions/%s/smoke.conf\n' "$source_root" "$kind_name" "$version_label"
}

install_shim_runtime_assets() {
  shim_name=$1
  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    install_shim_upstream_exec_wrapper "$shim_name"
  else
    install_shim_runtime_assets_to "$shim_name" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
  fi
}

install_shim_config_assets() {
  shim_name=$1
  shim_config_source_root=$ROOT_DIR

  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    shim_config_source_root=$SHIMMY_PROFILE_SOURCE_CHECKOUT
  fi

  install_shim_config_assets_to "$shim_name" "$shim_config_source_root" "$SHIMMY_PROFILE_CONFIG_DIR/shims"
}

install_shim_config_assets_to() {
  shim_name=$1
  shim_config_source_root=$2
  shim_config_target_dir=$3
  shim_config_source_path=$(shim_source_config_path_resolve "$shim_name" "$shim_config_source_root") || fail "missing Shimmy metadata for $shim_name"
  shim_config_target_path=$shim_config_target_dir/$shim_name.conf

  [ -f "$shim_config_source_path" ] || fail "missing shim config source: $shim_config_source_path"
  mkdir -p "$shim_config_target_dir"
  log_debug "Copying shim config $shim_name to $shim_config_target_path"
  rm -f "$shim_config_target_path"
  cp "$shim_config_source_path" "$shim_config_target_path"
  chmod 644 "$shim_config_target_path"
}

install_shim_runtime_assets_to() {
  shim_name=$1
  shim_dir=$2
  target_path=$shim_dir/$shim_name

  mkdir -p "$shim_dir"
  render_shim_exec_wrapper "$shim_name" "$SHIMMY_CORE_DIR" > "$target_path"
  chmod 755 "$target_path"
}

install_shim_dispatcher() {
  shim_name=$1
  dispatcher_path=$SHIMMY_BIN_DIR/$shim_name

  mkdir -p "$SHIMMY_BIN_DIR"
  rm -f "$dispatcher_path"
  ln -s ../core/commands/dispatch-tool.sh "$dispatcher_path"
}

install_shim_upstream_exec_wrapper() {
  shim_name=$1
  wrapper_path=$SHIMMY_PROFILE_IMPLEMENTATION_DIR/$shim_name

  mkdir -p "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
  render_shim_upstream_exec_wrapper "$shim_name" > "$wrapper_path"
  chmod 755 "$wrapper_path"
}

render_shim_upstream_exec_wrapper() {
  shim_name=$1
  render_shim_exec_wrapper "$shim_name" "$SHIMMY_PROFILE_SOURCE_CHECKOUT"
}

render_shim_exec_wrapper() {
  shim_name=$1
  source_root=$2
  kind_name=$(shim_name_kind_resolve "$shim_name") || fail "missing Shimmy tool metadata for $shim_name"
  quoted_kind_name=$(shimmy_quote_shell_word "$kind_name")
  quoted_source_root=$(shimmy_quote_shell_word "$source_root")

  if shimmy_is_kind "$shim_name"; then
    target_rel=commands/run-tool.sh
    target_args='$shimmy_tool_kind "$@"'
  else
    version_label=$(shim_name_version_label_resolve "$shim_name") || fail "missing version label for $shim_name"
    target_rel=tools/$kind_name/versions/$version_label/run.sh
    target_args='"$@"'
  fi
  quoted_target_rel=$(shimmy_quote_shell_word "$target_rel")

  cat <<EOF
#!/bin/sh
set -eu

shimmy_tool_kind=$quoted_kind_name
shimmy_source_root=$quoted_source_root
shimmy_runtime_target=\$shimmy_source_root/$target_rel

if [ ! -x "\$shimmy_runtime_target" ]; then
  printf 'ERROR: missing Shimmy tool runtime: %s\n' "\$shimmy_runtime_target" >&2
  exit 1
fi

exec "\$shimmy_runtime_target" $target_args
EOF
}

install_control_assets() {
  [ -f "$SOURCE_CONTROL_FILE" ] || fail "missing source management launcher: $SOURCE_CONTROL_FILE"
  [ -d "$SOURCE_COMMAND_DIR" ] || fail "missing source command directory: $SOURCE_COMMAND_DIR"
  [ -d "$SOURCE_CORE_DIR" ] || fail "missing source core directory: $SOURCE_CORE_DIR"
  [ -d "$SOURCE_TOOLS_DIR" ] || fail "missing source tool directory: $SOURCE_TOOLS_DIR"

  if [ "$ROOT_DIR" != "$SHIMMY_CORE_DIR" ]; then
    rm -rf "$SHIMMY_CORE_DIR"
  fi

  mkdir -p "$SHIMMY_BIN_DIR" "$SHIMMY_CORE_DIR"

  install_file "$SOURCE_CONTROL_FILE" "$SHIMMY_CONTROL_BIN"
  install_file "$SOURCE_CONTROL_FILE" "$SHIMMY_CORE_DIR/shimmy"

  install_directory_copy "$SOURCE_COMMAND_DIR" "$SHIMMY_CORE_DIR/commands"
  install_directory_copy "$SOURCE_CORE_DIR" "$SHIMMY_CORE_DIR/core"
  install_directory_copy "$SOURCE_TOOLS_DIR" "$SHIMMY_CORE_DIR/tools"
  install_directory_copy "$SOURCE_TESTS_DIR" "$SHIMMY_CORE_DIR/tests"
  if [ -d "$ROOT_DIR/agent" ]; then
    install_directory_copy "$ROOT_DIR/agent" "$SHIMMY_CORE_DIR/agent"
  fi
  if [ -d "$SOURCE_PLUGIN_DIR" ]; then
    install_directory_copy "$SOURCE_PLUGIN_DIR" "$SHIMMY_CORE_DIR/plugins"
  fi
  install_agent_skill_assets
}

skills_target_prompt() {
  [ -t 0 ] && [ -t 2 ] || return 1

  while :; do
    printf 'Share Shimmy agent skills? Choose target [repo/profile/plugin/none] (repo): ' >&2
    IFS= read -r skills_target_answer || return 1
    case "$skills_target_answer" in
      '')
        printf 'repo\n'
        return 0
        ;;
      repo|profile|plugin)
        printf '%s\n' "$skills_target_answer"
        return 0
        ;;
      none|skip|no)
        printf 'none\n'
        return 0
        ;;
      *)
        printf 'ERROR: enter repo, profile, plugin, or none\n' >&2
        ;;
    esac
  done
}

share_management_skills() {
  [ "$SKIP_SKILLS" -eq 0 ] || return 0

  if [ ! -x "$SKILLS_SCRIPT" ]; then
    fail "missing skills helper: $SKILLS_SCRIPT"
  fi

  skills_target=$REQUESTED_SKILLS_TARGET
  if [ -z "$skills_target" ]; then
    skills_target=$(skills_target_prompt || true)
  fi

  case "$skills_target" in
    '')
      return 0
      ;;
    none)
      log_info "Skipped Shimmy management skill sharing"
      return 0
      ;;
  esac

  validate_skills_target "$skills_target"
  "$SKILLS_SCRIPT" install --target "$skills_target" --manifest "$INSTALL_MANIFEST_FILE"
}
