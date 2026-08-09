#!/bin/sh
# Profile activation rendering and default-profile startup integration.

resolve_startup_settings() {
  STARTUP_SHELL=
  STARTUP_FILE_PATHS=

  if [ -f "$INSTALL_MANIFEST_FILE" ] && [ "$SHIMMY_PROFILE_RESOLVED" = default ]; then
    STARTUP_SHELL=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" startup_shell || true)
    STARTUP_FILE_PATHS=$(shimmy_read_manifest_values "$INSTALL_MANIFEST_FILE" startup_file || true)
  fi
  [ "$SKIP_STARTUP" -eq 0 ] || return 0

  STARTUP_SHELL=$(shimmy_shell_name_normalize "$REQUESTED_SHELL") || fail "unable to resolve startup shell"
  if [ -n "$REQUESTED_STARTUP_FILES" ]; then
    STARTUP_FILE_PATHS=$REQUESTED_STARTUP_FILES
  else
    STARTUP_FILE_PATHS=$(shimmy_startup_file_path_list_resolve "$STARTUP_SHELL" "$HOME") || fail "unable to resolve startup file path"
  fi
}

shimmy_install_startup_update() {
  [ "$SHIMMY_PROFILE_RESOLVED" = default ] || return 0
  [ "$SKIP_STARTUP" -eq 0 ] || return 0
  [ -n "$STARTUP_FILE_PATHS" ] || return 0

  activate_block=$(shimmy_activate_source_block_render "$SHIMMY_ACTIVATE_FILE") || fail "unable to render activate block for startup file"
  while IFS= read -r startup_file_path; do
    [ -n "$startup_file_path" ] || continue
    shimmy_startup_file_update "$startup_file_path" "$activate_block" || return 1
    log_info "Updated startup file: $startup_file_path"
  done <<EOF
$STARTUP_FILE_PATHS
EOF
}

startup_file_summary_render() {
  startup_file_paths=${1:-}
  [ -n "$startup_file_paths" ] || { printf 'manual activation only\n'; return 0; }

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
  activate_file=$1
  quoted_bin_dir=$(shimmy_quote_shell_word "$SHIMMY_BIN_DIR")

  {
    printf 'shimmy_activate_bin_dir=%s\n' "$quoted_bin_dir"
    printf 'if [ -d "$shimmy_activate_bin_dir" ]; then\n'
    printf '  shimmy_activate_path_input=${PATH-}\n'
    printf '  shimmy_activate_path_output=\n'
    printf '  shimmy_activate_path_has_entry=0\n'
    printf '  while :; do\n'
    printf '    case "$shimmy_activate_path_input" in\n'
    printf '      *:*)\n'
    printf '        shimmy_activate_path_entry=${shimmy_activate_path_input%%%%:*}\n'
    printf '        shimmy_activate_path_input=${shimmy_activate_path_input#*:}\n'
    printf '        shimmy_activate_path_more=1\n'
    printf '        ;;\n'
    printf '      *)\n'
    printf '        shimmy_activate_path_entry=$shimmy_activate_path_input\n'
    printf '        shimmy_activate_path_more=0\n'
    printf '        ;;\n'
    printf '    esac\n'
    printf '    if [ "$shimmy_activate_path_entry" != "$shimmy_activate_bin_dir" ]; then\n'
    printf '      if [ "$shimmy_activate_path_has_entry" -eq 1 ]; then\n'
    printf '        shimmy_activate_path_output=$shimmy_activate_path_output:$shimmy_activate_path_entry\n'
    printf '      else\n'
    printf '        shimmy_activate_path_output=$shimmy_activate_path_entry\n'
    printf '        shimmy_activate_path_has_entry=1\n'
    printf '      fi\n'
    printf '    fi\n'
    printf '    [ "$shimmy_activate_path_more" -eq 1 ] || break\n'
    printf '  done\n'
    printf '  PATH=$shimmy_activate_bin_dir\n'
    printf '  if [ "$shimmy_activate_path_has_entry" -eq 1 ]; then\n'
    printf '    PATH=$PATH:$shimmy_activate_path_output\n'
    printf '  fi\n'
    printf 'fi\n'
    printf 'unset shimmy_activate_bin_dir shimmy_activate_path_entry shimmy_activate_path_has_entry\n'
    printf 'unset shimmy_activate_path_input shimmy_activate_path_more shimmy_activate_path_output\n'
    printf "shimmy_activate_podman_dir='/opt/podman/bin'\n"
    printf 'if [ -x "$shimmy_activate_podman_dir/podman" ] && ! command -v podman >/dev/null 2>&1; then\n'
    printf '  PATH=${PATH:+$PATH:}$shimmy_activate_podman_dir\n'
    printf 'fi\n'
    printf 'unset shimmy_activate_podman_dir\n'
    printf 'export PATH\n'
  } > "$activate_file"
  chmod 644 "$activate_file"
}
