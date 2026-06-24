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
  cat <<'EOF'
Install or uninstall Shimmy assets in a user-scoped location.

Usage:
  commands/install.sh [options]

Options:
  --install-dir <dir>    Base install directory. Default: ~/.config/shimmy
  --profile <name>          Install profile: default or upstream
  --shim <name>          Install the named shim if missing. Repeatable.
  --skills-target <name> Share or remove Shimmy agent skills in repo, profile, or plugin
  --no-skills            Do not prompt for, share, or remove Shimmy agent skills
  --shell <name>         Override shell detection for startup-file updates
  --startup-file <path>  Override startup file updates. Repeatable.
  --no-startup           Skip persistent startup-file updates during install
  --uninstall            Remove a profile; requires --profile default or upstream
  -h, --help             Show help
EOF
}

selected_shim_list() {
  if [ -n "$REQUESTED_SHIMS" ]; then
    printf '%s\n' "$REQUESTED_SHIMS"
    return 0
  fi

  shimmy_default_kind_list
}

version_label_list_render() {
  kind_name=$1
  separator=

  for version_label in $(shimmy_kind_version_label_list "$kind_name"); do
    printf '%s%s' "$separator" "$version_label"
    separator=', '
  done
  printf '\n'
}

kind_list_render() {
  separator=

  for kind_name in $(shimmy_kind_list); do
    printf '%s%s' "$separator" "$kind_name"
    separator=', '
  done
  printf '\n'
}

kind_version_entry_print() {
  entry_kind_name=$1
  entry_version_label=$2
  entry_version_name=$3

  printf '%s|%s|%s\n' "$entry_kind_name" "$entry_version_label" "$entry_version_name"
}

request_kind_version_entries_resolve() {
  requested_shim=$1

  case "$requested_shim" in
    *@*)
      kind_name=${requested_shim%%@*}
      version_label=${requested_shim#*@}
      shimmy_is_kind "$kind_name" || fail "unsupported shim kind: $kind_name. Available kinds: $(kind_list_render)"
      version_name=$(shimmy_kind_version_for_label "$kind_name" "$version_label" || true)
      if [ -z "$version_name" ]; then
        fail "unsupported $kind_name version: $version_label. Available $kind_name versions: $(version_label_list_render "$kind_name"). Default $kind_name version: $(shimmy_version_label "$(shimmy_kind_default_version "$kind_name")")"
      fi
      default_version=$(shimmy_kind_default_version "$kind_name")
      kind_version_entry_print "$kind_name" default "$default_version"
      kind_version_entry_print "$kind_name" "$(shimmy_version_label "$default_version")" "$default_version"
      kind_version_entry_print "$kind_name" "$version_label" "$version_name"
      ;;
    *)
      if shimmy_is_kind "$requested_shim"; then
        kind_name=$requested_shim
        default_version=$(shimmy_kind_default_version "$kind_name")
        kind_version_entry_print "$kind_name" default "$default_version"
        kind_version_entry_print "$kind_name" "$(shimmy_version_label "$default_version")" "$default_version"
      elif shimmy_is_version "$requested_shim"; then
        version_name=$requested_shim
        kind_name=$(shimmy_version_kind "$version_name")
        default_version=$(shimmy_kind_default_version "$kind_name")
        kind_version_entry_print "$kind_name" default "$default_version"
        kind_version_entry_print "$kind_name" "$(shimmy_version_label "$default_version")" "$default_version"
        kind_version_entry_print "$kind_name" "$(shimmy_version_label "$version_name")" "$version_name"
      else
        fail "unsupported shim kind: $requested_shim. Available kinds: $(kind_list_render)"
      fi
      ;;
  esac
}

selected_kind_version_entries() {
  selected_entries=

  for requested_shim in $(selected_shim_list); do
    requested_entries=$(request_kind_version_entries_resolve "$requested_shim") || return 1
    while IFS= read -r kind_version_entry; do
      [ -n "$kind_version_entry" ] || continue
      if ! shimmy_contains_line_list "$selected_entries" "$kind_version_entry"; then
        selected_entries=$(shimmy_append_line_list "$selected_entries" "$kind_version_entry")
      fi
    done <<EOF
$requested_entries
EOF
  done

  printf '%s\n' "$selected_entries"
}

kind_list_from_entries() {
  kind_version_entries=$1
  kind_names=

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    kind_name=${kind_version_entry%%|*}
    if ! shimmy_contains_line_list "$kind_names" "$kind_name"; then
      kind_names=$(shimmy_append_line_list "$kind_names" "$kind_name")
    fi
  done <<EOF
$kind_version_entries
EOF

  printf '%s\n' "$kind_names"
}

version_list_from_entries() {
  kind_version_entries=$1
  version_names=

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    version_name=${kind_version_entry##*|}
    if ! shimmy_contains_line_list "$version_names" "$version_name"; then
      version_names=$(shimmy_append_line_list "$version_names" "$version_name")
    fi
  done <<EOF
$kind_version_entries
EOF

  printf '%s\n' "$version_names"
}

validate_requested_shims() {
  selected_kind_version_entries >/dev/null
}

validate_skills_target() {
  case "$1" in
    repo|profile|plugin)
      ;;
    *)
      fail "unsupported skills target: $1"
      ;;
  esac
}

resolve_install_root() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(shimmy_trim_path_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(shimmy_trim_path_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

resolve_install_paths() {
  install_root=$(resolve_install_root)
  if ! shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$install_root" "$ROOT_DIR"; then
    fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
  fi

  SHIMMY_PROFILE_RESOLVED=$SHIMMY_PROFILE_NAME
  SHIMMY_INSTALL_DIR=$SHIMMY_PROFILE_INSTALL_DIR
  SHIMMY_BIN_DIR=$SHIMMY_INSTALL_BIN_DIR
  SHIMMY_PROFILE_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_PATH
  SHIMMY_ROOT_MANIFEST_FILE=$(shimmy_join_path "$SHIMMY_INSTALL_DIR" install-manifest.txt)
  SHIMMY_CONTROL_BIN=$(shimmy_join_path "$SHIMMY_BIN_DIR" shimmy)
  SHIMMY_CORE_DIR=$SHIMMY_INSTALL_CORE_DIR
  SHIMMY_CORE_COMMAND_DIR=$(shimmy_join_path "$SHIMMY_CORE_DIR" commands)
  SHIMMY_CORE_DISPATCHER=$(shimmy_join_path "$SHIMMY_CORE_COMMAND_DIR" dispatch-tool.sh)
  SHIMMY_CORE_TOOLS_DIR=$(shimmy_join_path "$SHIMMY_CORE_DIR" tools)
  SHIMMY_ACTIVATE_FILE=$(shimmy_join_path "$SHIMMY_INSTALL_DIR" activate.sh)
  INSTALL_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_FILE
}

load_install_root_from_manifest() {
  if [ ! -f "$SHIMMY_ROOT_MANIFEST_FILE" ]; then
    return 1
  fi

  manifest_install_dir=$(shimmy_read_manifest_value "$SHIMMY_ROOT_MANIFEST_FILE" install_dir || true)
  if [ -z "$manifest_install_dir" ]; then
    return 1
  fi

  SHIMMY_INSTALL_DIR=$(shimmy_trim_path_trailing_slash "$manifest_install_dir")
  shimmy_profile_paths_resolve "$SHIMMY_PROFILE_RESOLVED" "$SHIMMY_INSTALL_DIR" "$ROOT_DIR" || return 1
  SHIMMY_BIN_DIR=$SHIMMY_INSTALL_BIN_DIR
  SHIMMY_PROFILE_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_PATH
  SHIMMY_CONTROL_BIN=$(shimmy_join_path "$SHIMMY_BIN_DIR" shimmy)
  SHIMMY_CORE_DIR=$SHIMMY_INSTALL_CORE_DIR
  SHIMMY_CORE_COMMAND_DIR=$(shimmy_join_path "$SHIMMY_CORE_DIR" commands)
  SHIMMY_CORE_DISPATCHER=$(shimmy_join_path "$SHIMMY_CORE_COMMAND_DIR" dispatch-tool.sh)
  SHIMMY_CORE_TOOLS_DIR=$(shimmy_join_path "$SHIMMY_CORE_DIR" tools)
  SHIMMY_ACTIVATE_FILE=$(shimmy_join_path "$SHIMMY_INSTALL_DIR" activate.sh)
  SHIMMY_ROOT_MANIFEST_FILE=$(shimmy_join_path "$SHIMMY_INSTALL_DIR" install-manifest.txt)
  INSTALL_MANIFEST_FILE=$SHIMMY_PROFILE_MANIFEST_FILE
}

shimmy_install_request_parse() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
        shift 2
        ;;
      --profile)
        [ "$#" -ge 2 ] || fail "missing value for --profile"
        SHIMMY_PROFILE_REQUESTED=$2
        SHIMMY_PROFILE_ACTIVATED=1
        shift 2
        ;;
      --copy)
        shift
        ;;
      --refresh-shims)
        REFRESH_SHIMS=1
        shift
        ;;
      --skills-target)
        [ "$#" -ge 2 ] || fail "missing value for --skills-target"
        REQUESTED_SKILLS_TARGET=$2
        validate_skills_target "$REQUESTED_SKILLS_TARGET"
        shift 2
        ;;
      --no-skills)
        SKIP_SKILLS=1
        shift
        ;;
      --symlink)
        fail "symlink install mode has been removed on the posix-rewrite branch"
        ;;
      --shim)
        [ "$#" -ge 2 ] || fail "missing value for --shim"
        requested_shim_append "$2"
        shift 2
        ;;
      --shell)
        [ "$#" -ge 2 ] || fail "missing value for --shell"
        REQUESTED_SHELL=$2
        shift 2
        ;;
      --startup-file)
        [ "$#" -ge 2 ] || fail "missing value for --startup-file"
        REQUESTED_STARTUP_FILES=$(shimmy_append_line_list "$REQUESTED_STARTUP_FILES" "$2")
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
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done

  if [ -n "${SHIMMY_PROFILE_ACTIVE:-}" ]; then
    SHIMMY_PROFILE_ACTIVATED=1
  fi

  resolve_install_paths
}
