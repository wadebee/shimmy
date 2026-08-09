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
Install or uninstall assets in the invoking Shimmy profile.

Usage:
  commands/install.sh [options]

Options:
  --shim <name>          Install the named shim if missing. Required; repeatable.
  --skills-target <name> Explicitly install agent skills in repo, profile, or plugin
  --no-skills            Do not install agent skills
  --shell <name>         Override shell detection for startup-file updates
  --startup-file <path>  Override startup file updates. Repeatable.
  --no-startup           Skip persistent startup-file updates during install
  --uninstall            Remove the invoking profile
  -h, --help             Show help
EOF
}

selected_shim_list() {
  printf '%s\n' "$REQUESTED_SHIMS"
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

resolve_install_paths() {
  if [ -n "${SHIMMY_BOOTSTRAP_PROFILE:-}" ] && [ -x "$ROOT_DIR/install.sh" ]; then
    shimmy_profile_paths_resolve "$SHIMMY_BOOTSTRAP_PROFILE" || fail "unable to resolve canonical Shimmy profile; XDG_CONFIG_HOME and HOME must be absolute"
    SHIMMY_INSTALL_SOURCE_MODE=bootstrap
  else
    shimmy_profile_context_resolve "$ROOT_DIR" || fail "installed Shimmy commands must run from a canonical profile root"
    SHIMMY_INSTALL_SOURCE_MODE=installed
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
