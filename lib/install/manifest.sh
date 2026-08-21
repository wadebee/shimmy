#!/bin/sh
# Sole profile manifest renderer (schema 2).
shimmy_profile_manifest_render() {
  shimmy_manifest_profile=$1
  shimmy_manifest_source_url=$2
  shimmy_manifest_source_ref=$3
  shimmy_manifest_catalog=$4
  shimmy_manifest_shims=${5:-}
  shimmy_manifest_versions=${6:-}
  shimmy_manifest_startup_shell=${7:-}
  shimmy_manifest_startup_files=${8:-}

  shimmy_name_component_validate "$shimmy_manifest_profile" || return 1
  [ -n "$shimmy_manifest_source_url" ] || return 1
  shimmy_scalar_value_validate "$shimmy_manifest_source_url" || return 1
  shimmy_git_commit_validate "$shimmy_manifest_source_ref" || return 1
  shimmy_catalog_pin_validate "$shimmy_manifest_catalog" || return 1
  shimmy_shim_records_validate "$shimmy_manifest_shims" "$shimmy_manifest_versions" || return 1
  if [ -n "$shimmy_manifest_startup_shell" ]; then
    case "$shimmy_manifest_startup_shell" in bash|zsh|sh|ksh|mksh) ;; *) return 1 ;; esac
  fi
  shimmy_line_list_lexical_unique_validate "$shimmy_manifest_startup_files" || return 1
  while IFS= read -r shimmy_manifest_startup_file; do
    [ -n "$shimmy_manifest_startup_file" ] || continue
    shimmy_path_absolute_normalized_validate "$shimmy_manifest_startup_file" || return 1
  done <<EOF
$shimmy_manifest_startup_files
EOF

  printf 'shimmy_install_manifest_version=2\n'
  printf 'shimmy_install_layout=profile-materialized-root\n'
  printf 'shimmy_profile_manifest_version=2\n'
  printf 'shimmy_profile_name=%s\n' "$shimmy_manifest_profile"
  printf 'shimmy_source_url=%s\n' "$shimmy_manifest_source_url"
  printf 'shimmy_source_tracking_ref=refs/heads/main\n'
  printf 'shimmy_source_ref=%s\n' "$shimmy_manifest_source_ref"
  printf 'catalog=%s\n' "$shimmy_manifest_catalog"
  while IFS= read -r shimmy_manifest_shim; do
    [ -n "$shimmy_manifest_shim" ] || continue
    printf 'shim=%s\n' "$shimmy_manifest_shim"
  done <<EOF
$shimmy_manifest_shims
EOF
  while IFS= read -r shimmy_manifest_version; do
    [ -n "$shimmy_manifest_version" ] || continue
    printf 'shim_version=%s\n' "$shimmy_manifest_version"
  done <<EOF
$shimmy_manifest_versions
EOF
  [ -z "$shimmy_manifest_startup_shell" ] || printf 'startup_shell=%s\n' "$shimmy_manifest_startup_shell"
  while IFS= read -r shimmy_manifest_startup_file; do
    [ -n "$shimmy_manifest_startup_file" ] || continue
    printf 'startup_file=%s\n' "$shimmy_manifest_startup_file"
  done <<EOF
$shimmy_manifest_startup_files
EOF
}
