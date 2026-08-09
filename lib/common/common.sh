# Shared path, manifest, and list helpers.
shimmy_append_line_list() {
  list_value=${1:-}
  line_value=$2

  if [ -n "$list_value" ]; then
    printf '%s\n%s\n' "$list_value" "$line_value"
  else
    printf '%s\n' "$line_value"
  fi
}

shimmy_contains_line_list() {
  list_value=${1:-}
  line_value=$2

  while IFS= read -r existing_line; do
    [ -n "$existing_line" ] || continue
    if [ "$existing_line" = "$line_value" ]; then
      return 0
    fi
  done <<EOF
$list_value
EOF

  return 1
}

shimmy_contains_manifest_kind() {
  manifest_file=$1
  kind_name=$2

  [ -f "$manifest_file" ] || return 1

  while IFS= read -r manifest_kind_name; do
    [ -n "$manifest_kind_name" ] || continue
    if [ "$manifest_kind_name" = "$kind_name" ]; then
      return 0
    fi
  done <<EOF
$(shimmy_read_manifest_kinds "$manifest_file")
EOF

  return 1
}

shimmy_contains_manifest_shim() {
  shimmy_contains_manifest_kind "$@"
}

shimmy_contains_profile_kind_other() {
  install_dir=$1
  kind_name=$2
  skip_manifest_one=${3:-}

  for manifest_file in "$install_dir"/profiles/*/install-manifest.txt; do
    [ -f "$manifest_file" ] || continue
    [ "$manifest_file" != "$skip_manifest_one" ] || continue
    if shimmy_contains_manifest_kind "$manifest_file" "$kind_name"; then
      return 0
    fi
  done

  return 1
}

shimmy_contains_profile_shim_other() {
  shimmy_contains_profile_kind_other "$@"
}

shimmy_count_profile_manifests() {
  install_dir=$1
  manifest_count=0

  for manifest_file in "$install_dir"/profiles/*/install-manifest.txt; do
    [ -f "$manifest_file" ] || continue
    manifest_count=$((manifest_count + 1))
  done

  printf '%s\n' "$manifest_count"
}

shimmy_join_path() {
  base_path=$1
  path_suffix=$2
  base_path=$(shimmy_trim_path_trailing_slash "$base_path")
  if [ "$base_path" = / ]; then
    printf '/%s\n' "$path_suffix"
  else
    printf '%s/%s\n' "$base_path" "$path_suffix"
  fi
}

shimmy_quote_shell_word() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

shimmy_read_manifest_kind_versions() {
  manifest_file=$1

  shimmy_read_manifest_values "$manifest_file" kind_version
}

shimmy_read_manifest_kinds() {
  manifest_file=$1

  shimmy_read_manifest_values "$manifest_file" kind
}

shimmy_read_manifest_shims() {
  manifest_file=$1

  shimmy_read_manifest_kinds "$manifest_file"
}

shimmy_read_manifest_value() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file" | sed -n '1p'
}

shimmy_read_manifest_values() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file"
}

shimmy_resolve_path_absolute() {
  path_value=${1:-}

  if [ -z "$path_value" ]; then
    return 1
  fi

  path_value=$(shimmy_trim_path_trailing_slash "$path_value")

  if [ -d "$path_value" ]; then
    (
      cd -- "$path_value" && pwd -P
    )
    return 0
  fi

  path_dir=$(dirname "$path_value")
  path_base=$(basename "$path_value")

  if [ -d "$path_dir" ]; then
    (
      cd -- "$path_dir" && printf '%s/%s\n' "$(pwd -P)" "$path_base"
    )
    return 0
  fi

  case "$path_value" in
    /*)
      printf '%s\n' "$path_value"
      ;;
    *)
      printf '%s/%s\n' "$(pwd -P)" "$path_value"
      ;;
  esac
}

shimmy_trim_path_trailing_slash() {
  path_value=${1:-}

  while [ "$path_value" != / ]; do
    case "$path_value" in
      */) path_value=${path_value%/} ;;
      *) break ;;
    esac
  done
  printf '%s\n' "$path_value"
}

shimmy_validate_remove_path_safe() {
  path_value=$1

  case "$path_value" in
    ''|/)
      return 1
      ;;
  esac

  return 0
}
