#!/bin/sh
# Invoke profile-local concrete-version refresh hooks.

shimmy_update_refresh_hooks_run() {
  refresh_action=$1
  version_list=$2
  case "$refresh_action" in pull|build) ;; *) fail "unsupported refresh action: $refresh_action" ;; esac

  while IFS= read -r version_name; do
    [ -n "$version_name" ] || continue
    kind_name=$(shimmy_version_kind "$version_name") || fail "unsupported shim version: $version_name"
    version_label=$(shimmy_version_label "$version_name") || fail "missing version label for $version_name"
    refresh_hook=$SHIMMY_PROFILE_ROOT/tools/$kind_name/versions/$version_label/refresh.sh
    [ -x "$refresh_hook" ] || fail "missing refresh hook for $version_name: $refresh_hook"
    "$refresh_hook" "$refresh_action"
  done <<EOF
$version_list
EOF
}
