#!/bin/sh
# Resolve installed kind and version selections within one profile.

shimmy_update_installed_version_names() {
  manifest_file=$1
  kind_filter=${2:-}
  version_names=
  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    kind_name=${kind_version_entry%%|*}
    entry_remainder=${kind_version_entry#*|}
    version_label=${entry_remainder%%|*}
    version_name=${kind_version_entry##*|}
    [ "$version_label" != default ] || continue
    [ -z "$kind_filter" ] || [ "$kind_filter" = "$kind_name" ] || continue
    shimmy_contains_line_list "$version_names" "$version_name" || version_names=$(shimmy_append_line_list "$version_names" "$version_name")
  done <<EOF
$(shimmy_read_manifest_kind_versions "$manifest_file" || true)
EOF
  printf '%s\n' "$version_names"
}

shimmy_update_selected_kinds_resolve() {
  manifest_file=$1
  installed_kinds=$(shimmy_read_manifest_kinds "$manifest_file" || true)
  if [ "$UPDATE_ALL" -eq 1 ] || [ -z "$REQUESTED_SHIMS" ]; then
    printf '%s\n' "$installed_kinds"
    return 0
  fi

  selected_kinds=
  for requested_shim in $REQUESTED_SHIMS; do
    kind_name=${requested_shim%%@*}
    shimmy_contains_line_list "$installed_kinds" "$kind_name" || fail "$kind_name not installed in profile $SHIMMY_PROFILE_NAME"
    shimmy_contains_line_list "$selected_kinds" "$kind_name" || selected_kinds=$(shimmy_append_line_list "$selected_kinds" "$kind_name")
  done
  printf '%s\n' "$selected_kinds"
}

shimmy_update_selected_versions_resolve() {
  manifest_file=$1
  selected_kinds=$2
  selected_versions=
  while IFS= read -r kind_name; do
    [ -n "$kind_name" ] || continue
    while IFS= read -r version_name; do
      [ -n "$version_name" ] || continue
      shimmy_contains_line_list "$selected_versions" "$version_name" || selected_versions=$(shimmy_append_line_list "$selected_versions" "$version_name")
    done <<EOF
$(shimmy_update_installed_version_names "$manifest_file" "$kind_name")
EOF
  done <<EOF
$selected_kinds
EOF
  printf '%s\n' "$selected_versions"
}
