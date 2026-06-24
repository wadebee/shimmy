#!/bin/sh
# Installed-profile and shim-version selection for update requests.

shimmy_update_default_installed_kind_request_list() {
  manifest_file=$1
  installed_kinds=$(shimmy_read_manifest_kinds "$manifest_file")
  default_installed_requests=

  for kind_name in $(shimmy_default_kind_list); do
    if shimmy_contains_line_list "$installed_kinds" "$kind_name"; then
      default_installed_requests=$(shimmy_append_line_list "$default_installed_requests" "$kind_name")
      for version_name in $(shimmy_update_installed_kind_version_names "$manifest_file" "$kind_name"); do
        default_installed_requests=$(shimmy_append_line_list "$default_installed_requests" "$version_name")
      done
    fi
  done

  printf '%s\n' "$default_installed_requests"
}

shimmy_update_install_dir_resolve() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(shimmy_trim_path_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(shimmy_trim_path_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

shimmy_update_installed_kind_version_names() {
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
    if ! shimmy_contains_line_list "$version_names" "$version_name"; then
      version_names=$(shimmy_append_line_list "$version_names" "$version_name")
    fi
  done <<EOF
$(shimmy_read_manifest_kind_versions "$manifest_file" || true)
EOF

  printf '%s\n' "$version_names"
}

shimmy_update_manifest_file_resolve() {
  printf '%s\n' "$SHIMMY_PROFILE_MANIFEST_PATH"
}

shimmy_update_profile_paths_resolve() {
  install_dir=$1

  if ! shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$install_dir" "$ROOT_DIR"; then
    fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
  fi
}

shimmy_update_refresh_requests_for_shim() {
  manifest_file=$1
  requested_shim=$2
  installed_kinds=$(shimmy_read_manifest_kinds "$manifest_file" || true)

  case "$requested_shim" in
    *@*)
      kind_name=${requested_shim%%@*}
      version_label=${requested_shim#*@}
      shimmy_is_kind "$kind_name" || fail "unsupported shim kind: $kind_name"
      shimmy_contains_line_list "$installed_kinds" "$kind_name" || fail "$kind_name not installed; run shimmy install --shim $kind_name"
      version_name=$(shimmy_update_request_version_label_validate "$manifest_file" "$kind_name" "$version_label")
      printf '%s\n%s\n' "$kind_name" "$version_name"
      ;;
    *)
      if shimmy_is_kind "$requested_shim"; then
        kind_name=$requested_shim
        shimmy_contains_line_list "$installed_kinds" "$kind_name" || fail "$kind_name not installed; run shimmy install --shim $kind_name"
        printf '%s\n' "$kind_name"
        shimmy_update_installed_kind_version_names "$manifest_file" "$kind_name"
      elif shimmy_is_version "$requested_shim"; then
        version_name=$requested_shim
        kind_name=$(shimmy_version_kind "$version_name")
        shimmy_contains_line_list "$installed_kinds" "$kind_name" || fail "$kind_name not installed; run shimmy install --shim $kind_name"
        shimmy_update_request_version_label_validate "$manifest_file" "$kind_name" "$(shimmy_version_label "$version_name")" >/dev/null
        printf '%s\n%s\n' "$kind_name" "$version_name"
      else
        fail "unsupported shim kind: $requested_shim"
      fi
      ;;
  esac
}

shimmy_update_request_version_label_validate() {
  manifest_file=$1
  kind_name=$2
  version_label=$3
  version_name=$(shimmy_kind_version_for_label "$kind_name" "$version_label" || true)
  [ -n "$version_name" ] || fail "unsupported $kind_name version: $version_label"

  expected_entry=$kind_name\|$version_label\|$version_name
  if ! shimmy_contains_line_list "$(shimmy_read_manifest_kind_versions "$manifest_file" || true)" "$expected_entry"; then
    fail "$kind_name@$version_label not installed; run shimmy install --shim $kind_name@$version_label"
  fi

  printf '%s\n' "$version_name"
}
