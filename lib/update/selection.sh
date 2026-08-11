#!/bin/sh
# Resolve installed tool and version selections within one profile.

shimmy_update_installed_version_names() {
  manifest_file=$1
  tool_filter=${2:-}
  version_names=
  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    tool_name=${tool_version_entry%%|*}
    entry_remainder=${tool_version_entry#*|}
    version_label=${entry_remainder%%|*}
    version_name=${tool_version_entry##*|}
    [ "$version_label" != default ] || continue
    [ -z "$tool_filter" ] || [ "$tool_filter" = "$tool_name" ] || continue
    shimmy_contains_line_list "$version_names" "$version_name" || version_names=$(shimmy_append_line_list "$version_names" "$version_name")
  done <<EOF
$(shimmy_manifest_tool_version_list_read "$manifest_file" || true)
EOF
  printf '%s\n' "$version_names"
}

shimmy_update_selected_tools_resolve() {
  manifest_file=$1
  installed_tools=$(shimmy_manifest_tool_list_read "$manifest_file" || true)
  if [ "$UPDATE_ALL" -eq 1 ] || [ -z "$REQUESTED_SHIMS" ]; then
    printf '%s\n' "$installed_tools"
    return 0
  fi

  selected_tools=
  for requested_shim in $REQUESTED_SHIMS; do
    tool_name=${requested_shim%%@*}
    shimmy_contains_line_list "$installed_tools" "$tool_name" || fail "$tool_name not installed in profile $SHIMMY_PROFILE_NAME"
    shimmy_contains_line_list "$selected_tools" "$tool_name" || selected_tools=$(shimmy_append_line_list "$selected_tools" "$tool_name")
  done
  printf '%s\n' "$selected_tools"
}

shimmy_update_selected_versions_resolve() {
  manifest_file=$1
  selected_tools=$2
  selected_versions=
  while IFS= read -r tool_name; do
    [ -n "$tool_name" ] || continue
    while IFS= read -r version_name; do
      [ -n "$version_name" ] || continue
      shimmy_contains_line_list "$selected_versions" "$version_name" || selected_versions=$(shimmy_append_line_list "$selected_versions" "$version_name")
    done <<EOF
$(shimmy_update_installed_version_names "$manifest_file" "$tool_name")
EOF
  done <<EOF
$selected_tools
EOF
  printf '%s\n' "$selected_versions"
}
