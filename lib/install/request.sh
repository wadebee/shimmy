#!/bin/sh
# Install request parsing, shim selection, and install-path resolution.

requested_shim_append() {
  requested_shim=$1

  if [ -n "$REQUESTED_SHIMS" ]; then
    REQUESTED_SHIMS="$REQUESTED_SHIMS $requested_shim"
  else
    REQUESTED_SHIMS=$requested_shim
  fi
}

usage() {
  if [ "$UNINSTALL" -eq 1 ]; then
    cat <<'EOF'
Remove the invoking Shimmy profile or all Shimmy-owned state.

Usage:
  shimmy uninstall [--global] [--shell <name>] [--startup-file <path> ...]

Options:
  --global               Remove all owned profiles and shared catalogs.
  --shell <name>         Override shell detection for startup cleanup.
  --startup-file <path>  Select a startup file to clean. Repeatable.
  -h, --help             Show this help.

Without --global, uninstall removes only the profile containing the invoked
launcher. Source checkouts and external skill exports are preserved.

Examples:
  shimmy uninstall
  shimmy uninstall --startup-file "$HOME/.zshrc"
EOF
    return 0
  fi

  cat <<'EOF'
Add one or more tools to the invoking Shimmy profile.

Usage:
  shimmy install --shim <tool[@version]> [--shim <tool[@version]> ...]
                 [--shell <name>] [--startup-file <path> ...] [--no-startup]

Options:
  --shim <tool[@version]>  Select a tool or concrete version. Required; repeatable.
  --shell <name>           Override shell detection for startup-file updates.
  --startup-file <path>    Select a startup file to update. Repeatable.
  --no-startup             Skip persistent startup-file updates.
  -h, --help               Show this help.

Examples:
  shimmy install --shim task
  shimmy install --shim aws --shim terraform
  shimmy install --shim oc@4.20 --no-startup
EOF
}

selected_shim_list() {
  printf '%s\n' "$REQUESTED_SHIMS"
}

version_label_list_render() {
  tool_name=$1
  separator=

  for version_label in $(shimmy_tool_version_label_list "$tool_name"); do
    printf '%s%s' "$separator" "$version_label"
    separator=', '
  done
  printf '\n'
}

tool_list_render() {
  separator=

  for tool_name in $(shimmy_tool_list); do
    printf '%s%s' "$separator" "$tool_name"
    separator=', '
  done
  printf '\n'
}

tool_version_entry_print() {
  entry_tool_name=$1
  entry_version_label=$2
  entry_version_name=$3

  printf '%s|%s|%s\n' "$entry_tool_name" "$entry_version_label" "$entry_version_name"
}

request_tool_version_entries_resolve() {
  requested_shim=$1

  case "$requested_shim" in
    *@*)
      tool_name=${requested_shim%%@*}
      version_label=${requested_shim#*@}
      shimmy_tool_exists "$tool_name" || fail "unsupported shim tool: $tool_name. Available tools: $(tool_list_render)"
      version_name=$(shimmy_tool_version_label_resolve "$tool_name" "$version_label" || true)
      if [ -z "$version_name" ]; then
        fail "unsupported $tool_name version: $version_label. Available $tool_name versions: $(version_label_list_render "$tool_name"). Default $tool_name version: $(shimmy_version_label "$(shimmy_tool_version_default "$tool_name")")"
      fi
      default_version=$(shimmy_tool_version_default "$tool_name")
      tool_version_entry_print "$tool_name" default "$default_version"
      tool_version_entry_print "$tool_name" "$(shimmy_version_label "$default_version")" "$default_version"
      tool_version_entry_print "$tool_name" "$version_label" "$version_name"
      ;;
    *)
      if shimmy_tool_exists "$requested_shim"; then
        tool_name=$requested_shim
        default_version=$(shimmy_tool_version_default "$tool_name")
        tool_version_entry_print "$tool_name" default "$default_version"
        tool_version_entry_print "$tool_name" "$(shimmy_version_label "$default_version")" "$default_version"
      elif shimmy_is_version "$requested_shim"; then
        version_name=$requested_shim
        tool_name=$(shimmy_tool_version_tool "$version_name")
        default_version=$(shimmy_tool_version_default "$tool_name")
        tool_version_entry_print "$tool_name" default "$default_version"
        tool_version_entry_print "$tool_name" "$(shimmy_version_label "$default_version")" "$default_version"
        tool_version_entry_print "$tool_name" "$(shimmy_version_label "$version_name")" "$version_name"
      else
        fail "unsupported shim tool: $requested_shim. Available tools: $(tool_list_render)"
      fi
      ;;
  esac
}

selected_tool_version_entries() {
  selected_entries=

  for requested_shim in $(selected_shim_list); do
    requested_entries=$(request_tool_version_entries_resolve "$requested_shim") || return 1
    while IFS= read -r tool_version_entry; do
      [ -n "$tool_version_entry" ] || continue
      if ! shimmy_contains_line_list "$selected_entries" "$tool_version_entry"; then
        selected_entries=$(shimmy_append_line_list "$selected_entries" "$tool_version_entry")
      fi
    done <<EOF
$requested_entries
EOF
  done

  printf '%s\n' "$selected_entries"
}

tool_list_from_entries() {
  tool_version_entries=$1
  tool_names=

  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    tool_name=${tool_version_entry%%|*}
    if ! shimmy_contains_line_list "$tool_names" "$tool_name"; then
      tool_names=$(shimmy_append_line_list "$tool_names" "$tool_name")
    fi
  done <<EOF
$tool_version_entries
EOF

  printf '%s\n' "$tool_names"
}

version_list_from_entries() {
  tool_version_entries=$1
  version_names=

  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    version_name=${tool_version_entry##*|}
    if ! shimmy_contains_line_list "$version_names" "$version_name"; then
      version_names=$(shimmy_append_line_list "$version_names" "$version_name")
    fi
  done <<EOF
$tool_version_entries
EOF

  printf '%s\n' "$version_names"
}

validate_requested_shims() {
  selected_tool_version_entries >/dev/null
}

resolve_install_paths() {
  if [ -n "${SHIMMY_BOOTSTRAP_PROFILE:-}" ] && [ -x "$ROOT_DIR/install.sh" ]; then
    shimmy_profile_paths_resolve "$SHIMMY_BOOTSTRAP_PROFILE" || fail "unable to resolve canonical Shimmy profile; XDG_CONFIG_HOME and HOME must be absolute"
  else
    shimmy_profile_context_resolve "$ROOT_DIR" || fail "installed Shimmy commands must run from a canonical profile root"
  fi

  SHIMMY_PROFILE_RESOLVED=$SHIMMY_PROFILE_NAME
  SHIMMY_BIN_DIR=$SHIMMY_PROFILE_BIN_DIR
  SHIMMY_CONTROL_BIN=$SHIMMY_BIN_DIR/shimmy
  SHIMMY_SHELL_INIT_FILE=$SHIMMY_PROFILE_ROOT/shell-init.sh
  INSTALL_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_PATH
}

shimmy_install_request_parse() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --shim)
        [ "$#" -ge 2 ] || fail "missing value for --shim"
        requested_shim_append "$2"
        shift 2
        ;;
      --shell)
        [ "$#" -ge 2 ] || fail "missing value for --shell"
        REQUESTED_SHELL=$2
        STARTUP_OPTION_REQUESTED=1
        shift 2
        ;;
      --startup-file)
        [ "$#" -ge 2 ] || fail "missing value for --startup-file"
        REQUESTED_STARTUP_FILES=$(shimmy_append_line_list "$REQUESTED_STARTUP_FILES" "$2")
        STARTUP_OPTION_REQUESTED=1
        shift 2
        ;;
      --no-startup)
        SKIP_STARTUP=1
        shift
        ;;
      --uninstall)
        UNINSTALL=1
        shift
        ;;
      --global)
        GLOBAL_UNINSTALL=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done

  resolve_install_paths

  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    [ -z "$REQUESTED_SHELL" ] || fail "upstream has no persistent startup integration; source $SHIMMY_SHELL_INIT_FILE after installation"
    [ -z "$REQUESTED_STARTUP_FILES" ] || fail "upstream has no persistent startup integration; source $SHIMMY_SHELL_INIT_FILE after installation"
    SKIP_STARTUP=1
  fi
}
