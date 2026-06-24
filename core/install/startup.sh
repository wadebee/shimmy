#!/bin/sh
# Activation asset rendering and startup-file integration.

resolve_startup_settings() {
  if [ "$SKIP_STARTUP" -eq 1 ]; then
    if [ -n "$PRESERVED_STARTUP_FILE_PATHS" ]; then
      STARTUP_SHELL=$PRESERVED_STARTUP_SHELL
      STARTUP_FILE_PATHS=$PRESERVED_STARTUP_FILE_PATHS
    else
      STARTUP_SHELL=
      STARTUP_FILE_PATHS=
    fi
    return 0
  fi

  STARTUP_SHELL=$(shimmy_shell_name_normalize "$REQUESTED_SHELL") || fail "unable to resolve startup shell"
  if [ -n "$REQUESTED_STARTUP_FILES" ]; then
    STARTUP_FILE_PATHS=$REQUESTED_STARTUP_FILES
  else
    STARTUP_FILE_PATHS=$(shimmy_startup_file_path_list_resolve "$STARTUP_SHELL" "$HOME") || fail "unable to resolve startup file path"
  fi
}

shimmy_install_startup_update() {
  [ -n "$STARTUP_FILE_PATHS" ] || return 0

  activate_block=$(shimmy_activate_source_block_render "$SHIMMY_ACTIVATE_FILE") || fail "unable to render activate block for startup file"
  while IFS= read -r startup_file_path; do
    [ -n "$startup_file_path" ] || continue
    shimmy_startup_file_update "$startup_file_path" "$activate_block"
    log_info "Updated startup file: $startup_file_path"
  done <<EOF
$STARTUP_FILE_PATHS
EOF
}

startup_file_summary_render() {
  startup_file_paths=${1:-}

  if [ -z "$startup_file_paths" ]; then
    printf 'manual activation only\n'
    return 0
  fi

  separator=
  while IFS= read -r startup_file_path; do
    [ -n "$startup_file_path" ] || continue
    printf '%s%s' "$separator" "$startup_file_path"
    separator=', '
  done <<EOF
$startup_file_paths
EOF
  printf '\n'
}

write_activate_file() {
  quoted_bin_dir=$(shimmy_quote_shell_word "$SHIMMY_BIN_DIR")

  {
    printf "SHIMMY_PROFILE_ACTIVE='default'\n"
    printf 'export SHIMMY_PROFILE_ACTIVE\n'
    printf 'shimmy_activate_bin_dir=%s\n' "$quoted_bin_dir"
    printf 'if [ -d "$shimmy_activate_bin_dir" ]; then\n'
    printf '  case ":${PATH:-}:" in\n'
    printf '    *:"$shimmy_activate_bin_dir":*) ;;\n'
    printf '    *) PATH=$shimmy_activate_bin_dir${PATH:+":"$PATH"} ;;\n'
    printf '  esac\n'
    printf 'fi\n'
    printf 'unset shimmy_activate_bin_dir\n'
    printf "shimmy_activate_podman_dir='/opt/podman/bin'\n"
    printf 'if [ -x "$shimmy_activate_podman_dir/podman" ]; then\n'
    printf '  case ":${PATH:-}:" in\n'
    printf '    *:"$shimmy_activate_podman_dir":*) ;;\n'
    printf '    *)\n'
    printf '      if ! command -v podman >/dev/null 2>&1; then\n'
    printf '        PATH=${PATH:+$PATH:}$shimmy_activate_podman_dir\n'
    printf '      fi\n'
    printf '      ;;\n'
    printf '  esac\n'
    printf 'fi\n'
    printf 'unset shimmy_activate_podman_dir\n'
    printf 'export PATH\n'
  } > "$SHIMMY_ACTIVATE_FILE"
  chmod 644 "$SHIMMY_ACTIVATE_FILE"
}
