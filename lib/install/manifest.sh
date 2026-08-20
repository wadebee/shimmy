#!/bin/sh
# Version-1 profile materialization manifest rendering.

source_ref_resolve() {
  command -v git >/dev/null 2>&1 || return 0
  git -C "$ROOT_DIR" rev-parse --verify HEAD 2>/dev/null || true
}

source_url_resolve() {
  command -v git >/dev/null 2>&1 || return 0
  git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null || true
}

profile_manifest_render() {
  shimmy_source_ref=$(source_ref_resolve)
  shimmy_source_url=$(source_url_resolve)
  if [ -f "$INSTALL_MANIFEST_FILE" ]; then
    [ -n "$shimmy_source_ref" ] || shimmy_source_ref=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" shimmy_source_ref || true)
    [ -n "$shimmy_source_url" ] || shimmy_source_url=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" shimmy_source_url || true)
  fi

  printf 'shimmy_install_manifest_version=1\n'
  printf 'shimmy_install_layout=profile-materialized-root\n'
  printf 'shimmy_profile_manifest_version=1\n'
  printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_RESOLVED"
  printf 'catalog=%s\n' "$SHIMMY_PROFILE_CATALOG_NAME"
  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    printf 'source_checkout=%s\n' "$SHIMMY_PROFILE_SOURCE_CHECKOUT"
  fi
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    printf 'tool=%s\n' "$tool_name"
  done <<EOF
$PROFILE_MANIFEST_TOOLS
EOF
  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    printf 'tool_version=%s\n' "$tool_version_entry"
  done <<EOF
$PROFILE_MANIFEST_TOOL_VERSIONS
EOF
  [ -z "$shimmy_source_url" ] || printf 'shimmy_source_url=%s\n' "$shimmy_source_url"
  [ -z "$shimmy_source_ref" ] || printf 'shimmy_source_ref=%s\n' "$shimmy_source_ref"
  shimmy_previous_source_ref=${SHIMMY_PREVIOUS_SOURCE_REF:-}
  if [ -z "$shimmy_previous_source_ref" ] && [ -f "$INSTALL_MANIFEST_FILE" ]; then
    shimmy_previous_source_ref=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" shimmy_previous_source_ref || true)
  fi
  [ -z "$shimmy_previous_source_ref" ] || printf 'shimmy_previous_source_ref=%s\n' "$shimmy_previous_source_ref"
  if [ "$SHIMMY_PROFILE_RESOLVED" = default ]; then
    printf 'startup_shell=%s\n' "$STARTUP_SHELL"
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      printf 'startup_file=%s\n' "$startup_file_path"
    done <<EOF
$STARTUP_FILE_PATHS
EOF
  fi
}

profile_manifest_write_atomic() {
  manifest_file=$1
  manifest_tmp=$manifest_file.tmp.$$

  profile_manifest_render > "$manifest_tmp"
  chmod 644 "$manifest_tmp"
  mv "$manifest_tmp" "$manifest_file"
}

# Private version-2 renderer. Its explicit target prefix prevents accidental
# use by the current public installation lifecycle before the hard cutover.
shimmy_target_profile_manifest_render() {
  shimmy_target_manifest_profile=$1
  shimmy_target_manifest_source_url=$2
  shimmy_target_manifest_source_ref=$3
  shimmy_target_manifest_catalog=$4
  shimmy_target_manifest_shims=${5:-}
  shimmy_target_manifest_versions=${6:-}
  shimmy_target_manifest_startup_shell=${7:-}
  shimmy_target_manifest_startup_files=${8:-}

  shimmy_name_component_validate "$shimmy_target_manifest_profile" || return 1
  [ -n "$shimmy_target_manifest_source_url" ] || return 1
  shimmy_scalar_value_validate "$shimmy_target_manifest_source_url" || return 1
  shimmy_git_commit_validate "$shimmy_target_manifest_source_ref" || return 1
  shimmy_target_catalog_pin_validate "$shimmy_target_manifest_catalog" || return 1
  shimmy_target_shim_records_validate "$shimmy_target_manifest_shims" "$shimmy_target_manifest_versions" || return 1
  if [ -n "$shimmy_target_manifest_startup_shell" ]; then
    case "$shimmy_target_manifest_startup_shell" in bash|zsh|sh|ksh|mksh) ;; *) return 1 ;; esac
  fi
  shimmy_line_list_lexical_unique_validate "$shimmy_target_manifest_startup_files" || return 1
  while IFS= read -r shimmy_target_manifest_startup_file; do
    [ -n "$shimmy_target_manifest_startup_file" ] || continue
    shimmy_path_absolute_normalized_validate "$shimmy_target_manifest_startup_file" || return 1
  done <<EOF
$shimmy_target_manifest_startup_files
EOF

  printf 'shimmy_install_manifest_version=2\n'
  printf 'shimmy_install_layout=profile-materialized-root\n'
  printf 'shimmy_profile_manifest_version=2\n'
  printf 'shimmy_profile_name=%s\n' "$shimmy_target_manifest_profile"
  printf 'shimmy_source_url=%s\n' "$shimmy_target_manifest_source_url"
  printf 'shimmy_source_tracking_ref=refs/heads/main\n'
  printf 'shimmy_source_ref=%s\n' "$shimmy_target_manifest_source_ref"
  printf 'catalog=%s\n' "$shimmy_target_manifest_catalog"
  while IFS= read -r shimmy_target_manifest_shim; do
    [ -n "$shimmy_target_manifest_shim" ] || continue
    printf 'shim=%s\n' "$shimmy_target_manifest_shim"
  done <<EOF
$shimmy_target_manifest_shims
EOF
  while IFS= read -r shimmy_target_manifest_version; do
    [ -n "$shimmy_target_manifest_version" ] || continue
    printf 'shim_version=%s\n' "$shimmy_target_manifest_version"
  done <<EOF
$shimmy_target_manifest_versions
EOF
  [ -z "$shimmy_target_manifest_startup_shell" ] || printf 'startup_shell=%s\n' "$shimmy_target_manifest_startup_shell"
  while IFS= read -r shimmy_target_manifest_startup_file; do
    [ -n "$shimmy_target_manifest_startup_file" ] || continue
    printf 'startup_file=%s\n' "$shimmy_target_manifest_startup_file"
  done <<EOF
$shimmy_target_manifest_startup_files
EOF
}
