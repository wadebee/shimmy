#!/bin/sh
# Version-4 profile manifest rendering.

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

  printf 'shimmy_install_manifest_version=4\n'
  printf 'shimmy_install_layout=profile-flat-root\n'
  printf 'shimmy_profile_manifest_version=4\n'
  printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_RESOLVED"
  if [ "$SHIMMY_PROFILE_RESOLVED" = upstream ]; then
    printf 'source_checkout=%s\n' "$SHIMMY_PROFILE_SOURCE_CHECKOUT"
  fi
  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    printf 'kind=%s\n' "$kind_name"
  done <<EOF
$PROFILE_MANIFEST_KINDS
EOF
  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    printf 'kind_version=%s\n' "$kind_version_entry"
  done <<EOF
$PROFILE_MANIFEST_KIND_VERSIONS
EOF
  [ -z "$shimmy_source_url" ] || printf 'shimmy_source_url=%s\n' "$shimmy_source_url"
  [ -z "$shimmy_source_ref" ] || printf 'shimmy_source_ref=%s\n' "$shimmy_source_ref"
  shimmy_previous_source_ref=${SHIMMY_PREVIOUS_SOURCE_REF:-}
  if [ -z "$shimmy_previous_source_ref" ] && [ -f "$INSTALL_MANIFEST_FILE" ]; then
    shimmy_previous_source_ref=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" shimmy_previous_source_ref || true)
  fi
  [ -z "$shimmy_previous_source_ref" ] || printf 'shimmy_previous_source_ref=%s\n' "$shimmy_previous_source_ref"
  if [ "$SHIMMY_PROFILE_RESOLVED" = default ]; then
    [ -z "$STARTUP_SHELL" ] || printf 'startup_shell=%s\n' "$STARTUP_SHELL"
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
