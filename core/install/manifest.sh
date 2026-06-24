#!/bin/sh
# Installation and profile manifest rendering and preservation.

manifest_shimmy_lines_preserve() {
  manifest_file=$1

  if [ ! -f "$manifest_file" ]; then
    return 0
  fi

  while IFS= read -r manifest_line; do
    case "$manifest_line" in
      shimmy_*=*)
        manifest_key=${manifest_line%%=*}
        case "$manifest_key" in
          shimmy_install_manifest_version|shimmy_manifest_version|shimmy_profile_manifest_version|shimmy_profile_name|shimmy_source_url|shimmy_source_ref|shimmy_previous_source_ref|shimmy_skill)
            ;;
          *)
            printf '%s\n' "$manifest_line"
            ;;
        esac
        ;;
    esac
  done < "$manifest_file"
}

manifest_kind_state_append() {
  manifest_file=$1
  kind_list=$2
  kind_version_entry_list=$3
  manifest_tmp=$manifest_file.tmp.$$

  {
    while IFS= read -r manifest_line || [ -n "$manifest_line" ]; do
      printf '%s\n' "$manifest_line"
    done < "$manifest_file"

    while IFS= read -r kind_name; do
      [ -n "$kind_name" ] || continue
      printf 'kind=%s\n' "$kind_name"
    done <<EOF
$kind_list
EOF

    while IFS= read -r kind_version_entry; do
      [ -n "$kind_version_entry" ] || continue
      printf 'kind_version=%s\n' "$kind_version_entry"
    done <<EOF
$kind_version_entry_list
EOF
  } > "$manifest_tmp"

  mv "$manifest_tmp" "$manifest_file"
}

profile_manifest_kind_list() {
  if [ -n "$PROFILE_MANIFEST_KINDS" ]; then
    printf '%s\n' "$PROFILE_MANIFEST_KINDS"
    return 0
  fi

  kind_list_from_entries "$(selected_kind_version_entries)"
}

profile_manifest_kind_version_list() {
  if [ -n "$PROFILE_MANIFEST_KIND_VERSIONS" ]; then
    printf '%s\n' "$PROFILE_MANIFEST_KIND_VERSIONS"
    return 0
  fi

  selected_kind_version_entries
}

source_ref_resolve() {
  command -v git >/dev/null 2>&1 || return 0

  git -C "$ROOT_DIR" rev-parse --verify HEAD 2>/dev/null || true
}

source_url_resolve() {
  command -v git >/dev/null 2>&1 || return 0

  git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null || true
}

write_manifest() {
  shimmy_source_ref=$(source_ref_resolve)
  shimmy_source_url=$(source_url_resolve)
  shimmy_previous_source_ref=${SHIMMY_PREVIOUS_SOURCE_REF:-}
  if [ -z "$shimmy_previous_source_ref" ]; then
    shimmy_previous_source_ref=$(shimmy_read_manifest_value "$INSTALL_MANIFEST_FILE" shimmy_previous_source_ref || true)
  fi

  write_root_manifest_file
  write_profile_manifest_file "$INSTALL_MANIFEST_FILE" "$shimmy_source_url" "$shimmy_source_ref" "$shimmy_previous_source_ref"
}

root_profile_list_resolve() {
  profile_names=

  for manifest_file in "$SHIMMY_INSTALL_DIR"/profiles/*/install-manifest.txt; do
    [ -f "$manifest_file" ] || continue
    profile_name=$(basename "$(dirname "$manifest_file")")
    if ! shimmy_contains_line_list "$profile_names" "$profile_name"; then
      profile_names=$(shimmy_append_line_list "$profile_names" "$profile_name")
    fi
  done

  if ! shimmy_contains_line_list "$profile_names" "$SHIMMY_PROFILE_RESOLVED"; then
    profile_names=$(shimmy_append_line_list "$profile_names" "$SHIMMY_PROFILE_RESOLVED")
  fi

  printf '%s\n' "$profile_names"
}

write_root_manifest_file() {
  mkdir -p "$(dirname "$SHIMMY_ROOT_MANIFEST_FILE")"

  {
    printf 'shimmy_install_manifest_version=2\n'
    printf 'shimmy_layout=metadata-tree\n'
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    printf 'bin_dir=%s\n' "$SHIMMY_BIN_DIR"
    printf 'control_bin=%s\n' "$SHIMMY_CONTROL_BIN"
    printf 'activate_file=%s\n' "$SHIMMY_ACTIVATE_FILE"
    printf 'shimmy_profile_default=default\n'
    for kind_name in $(shimmy_default_kind_list); do
      printf 'default_kind=%s\n' "$kind_name"
    done
    while IFS= read -r profile_name; do
      [ -n "$profile_name" ] || continue
      printf 'profile=%s\n' "$profile_name"
    done <<EOF
$(root_profile_list_resolve)
EOF
    if [ -n "$STARTUP_SHELL" ]; then
      printf 'startup_shell=%s\n' "$STARTUP_SHELL"
    fi
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      printf 'startup_file=%s\n' "$startup_file_path"
    done <<EOF
$STARTUP_FILE_PATHS
EOF
  } > "$SHIMMY_ROOT_MANIFEST_FILE"
}

write_profile_manifest_file() {
  manifest_file=$1
  shimmy_source_url=$2
  shimmy_source_ref=$3
  shimmy_previous_source_ref=$4

  mkdir -p "$(dirname "$manifest_file")"

  {
      printf 'shimmy_profile_manifest_version=2\n'
      printf 'shimmy_layout=metadata-tree\n'
      printf 'shimmy_profile_name=%s\n' "$SHIMMY_PROFILE_RESOLVED"
      printf 'config_dir=%s\n' "$SHIMMY_PROFILE_CONFIG_DIR"
      printf 'profile_implementation_dir=%s\n' "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"
    case "$SHIMMY_PROFILE_RESOLVED" in
      upstream)
        printf 'shim_source=generated-exec-wrapper\n'
        ;;
      default)
        printf 'shim_source=metadata-dispatch-wrapper\n'
        ;;
    esac
    if [ -n "$SHIMMY_PROFILE_SOURCE_CHECKOUT" ]; then
      printf 'source_checkout=%s\n' "$SHIMMY_PROFILE_SOURCE_CHECKOUT"
    fi
    for kind_name in $(profile_manifest_kind_list); do
      printf 'kind=%s\n' "$kind_name"
    done
    for kind_version_entry in $(profile_manifest_kind_version_list); do
      printf 'kind_version=%s\n' "$kind_version_entry"
    done
    if [ -n "$shimmy_source_url" ]; then
      printf 'shimmy_source_url=%s\n' "$shimmy_source_url"
    fi
    if [ -n "$shimmy_source_ref" ]; then
      printf 'shimmy_source_ref=%s\n' "$shimmy_source_ref"
    fi
    if [ -n "$shimmy_previous_source_ref" ]; then
      printf 'shimmy_previous_source_ref=%s\n' "$shimmy_previous_source_ref"
    fi
    if [ -n "$PRESERVED_SHIMMY_MANIFEST_LINES" ]; then
      printf '%s\n' "$PRESERVED_SHIMMY_MANIFEST_LINES"
    fi
  } > "$manifest_file"
}

write_root_manifest_existing_profiles() {
  [ -f "$SHIMMY_ROOT_MANIFEST_FILE" ] || return 0

  startup_shell=$(shimmy_read_manifest_value "$SHIMMY_ROOT_MANIFEST_FILE" startup_shell || true)
  startup_files=$(shimmy_read_manifest_values "$SHIMMY_ROOT_MANIFEST_FILE" startup_file || true)

  {
    printf 'shimmy_install_manifest_version=2\n'
    printf 'shimmy_layout=metadata-tree\n'
    printf 'install_dir=%s\n' "$SHIMMY_INSTALL_DIR"
    printf 'bin_dir=%s\n' "$SHIMMY_BIN_DIR"
    printf 'control_bin=%s\n' "$SHIMMY_CONTROL_BIN"
    printf 'activate_file=%s\n' "$SHIMMY_ACTIVATE_FILE"
    printf 'shimmy_profile_default=default\n'
    for kind_name in $(shimmy_default_kind_list); do
      printf 'default_kind=%s\n' "$kind_name"
    done
    for manifest_file in "$SHIMMY_INSTALL_DIR"/profiles/*/install-manifest.txt; do
      [ -f "$manifest_file" ] || continue
      printf 'profile=%s\n' "$(basename "$(dirname "$manifest_file")")"
    done
    if [ -n "$startup_shell" ]; then
      printf 'startup_shell=%s\n' "$startup_shell"
    fi
    while IFS= read -r startup_file_path; do
      [ -n "$startup_file_path" ] || continue
      printf 'startup_file=%s\n' "$startup_file_path"
    done <<EOF
$startup_files
EOF
  } > "$SHIMMY_ROOT_MANIFEST_FILE"
}
