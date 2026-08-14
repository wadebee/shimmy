#!/bin/sh
# Canonical profile paths and version-1 manifest validation.

shimmy_config_home_resolve() {
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    case "$XDG_CONFIG_HOME" in
      /*) shimmy_trim_path_trailing_slash "$XDG_CONFIG_HOME" ;;
      *) return 1 ;;
    esac
    return 0
  fi

  case "${HOME:-}" in
    /*) printf '%s/.config\n' "$(shimmy_trim_path_trailing_slash "$HOME")" ;;
    *) return 1 ;;
  esac
}

shimmy_config_root_resolve() {
  config_home=$(shimmy_config_home_resolve) || return 1
  shimmy_join_path "$config_home" shimmy
}

shimmy_path_parent_chain_validate() {
  path_value=$1

  case "$path_value" in
    /*) ;;
    *) return 1 ;;
  esac

  while [ "$path_value" != / ]; do
    [ ! -L "$path_value" ] || return 1
    path_value=$(dirname -- "$path_value")
  done
}

shimmy_profile_name_validate() {
  case "${1:-}" in
    default|upstream) return 0 ;;
    *) return 1 ;;
  esac
}

shimmy_profile_paths_resolve() {
  profile_name=$1
  shimmy_profile_name_validate "$profile_name" || return 1

  SHIMMY_CONFIG_ROOT=$(shimmy_config_root_resolve) || return 1
  SHIMMY_PROFILES_ROOT=$SHIMMY_CONFIG_ROOT/profiles
  SHIMMY_PROFILE_NAME=$profile_name
  SHIMMY_PROFILE_ROOT=$SHIMMY_PROFILES_ROOT/$profile_name
  SHIMMY_PROFILE_MANIFEST_PATH=$SHIMMY_PROFILE_ROOT/install-manifest.txt
  SHIMMY_PROFILE_BIN_DIR=$SHIMMY_PROFILE_ROOT/bin
  SHIMMY_PROFILE_CONFIG_DIR=$SHIMMY_PROFILE_ROOT/config
  SHIMMY_PROFILE_IMPLEMENTATION_DIR=$SHIMMY_PROFILE_ROOT/implementations
  SHIMMY_PROFILE_MATERIALIZATION_TOOLS_DIR=$SHIMMY_PROFILE_ROOT/tools
  shimmy_path_parent_chain_validate "$SHIMMY_PROFILE_ROOT"
}

shimmy_profile_context_resolve() {
  profile_root=$1
  profile_name=$(basename -- "$profile_root")
  shimmy_profile_paths_resolve "$profile_name" || return 1

  [ -d "$profile_root" ] || return 1
  profile_root_real=$(cd -- "$profile_root" && pwd -P) || return 1
  [ "$profile_root_real" = "$SHIMMY_PROFILE_ROOT" ] || return 1
}

shimmy_profile_manifest_error() {
  manifest_file=$1
  profile_name=$2

  printf 'invalid or unsupported Shimmy profile manifest at %s (expected shimmy_install_manifest_version=1, shimmy_install_layout=profile-flat-root, shimmy_profile_manifest_version=1, shimmy_profile_name=%s, and one explicit catalog binding); uninstall it with the Shimmy version that created it, then recreate that profile\n' "$manifest_file" "$profile_name" >&2
}

shimmy_manifest_key_count() {
  manifest_file=$1
  manifest_key=$2

  awk -F= -v key="$manifest_key" '$1 == key { count++ } END { print count + 0 }' "$manifest_file"
}

shimmy_manifest_identity_value_validate() {
  manifest_file=$1
  manifest_key=$2
  expected_value=$3

  [ "$(shimmy_manifest_key_count "$manifest_file" "$manifest_key")" -eq 1 ] || return 1
  [ "$(shimmy_read_manifest_value "$manifest_file" "$manifest_key")" = "$expected_value" ]
}

shimmy_tool_name_validate() {
  case "${1:-}" in
    ''|-*|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_version_token_validate() {
  case "${1:-}" in
    ''|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_manifest_ownership_validate() {
  manifest_file=$1
  profile_name=$2
  tool_lines=
  tool_version_lines=
  tool_label_lines=
  startup_file_lines=
  catalog_count=0

  while IFS= read -r manifest_line || [ -n "$manifest_line" ]; do
    case "$manifest_line" in
      *=*) ;;
      *) return 1 ;;
    esac

    manifest_key=${manifest_line%%=*}
    manifest_value=${manifest_line#*=}
    case "$manifest_key" in
      shimmy_install_manifest_version|shimmy_install_layout|shimmy_profile_manifest_version|shimmy_profile_name)
        ;;
      catalog)
        catalog_count=$((catalog_count + 1))
        [ "$catalog_count" -eq 1 ] || return 1
        case "$manifest_value" in
          ''|-*|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return 1 ;;
        esac
        [ "$manifest_value" = "$profile_name" ] || return 1
        ;;
      tool)
        shimmy_tool_name_validate "$manifest_value" || return 1
        shimmy_contains_line_list "$tool_lines" "$manifest_value" && return 1
        tool_lines=$(shimmy_append_line_list "$tool_lines" "$manifest_value")
        ;;
      tool_version)
        case "$manifest_value" in
          *\|*\|*) ;;
          *) return 1 ;;
        esac
        entry_tool=${manifest_value%%|*}
        entry_remainder=${manifest_value#*|}
        entry_label=${entry_remainder%%|*}
        entry_version=${entry_remainder#*|}
        case "$entry_version" in *'|'*) return 1 ;; esac
        shimmy_tool_name_validate "$entry_tool" || return 1
        shimmy_version_token_validate "$entry_label" || return 1
        shimmy_version_token_validate "$entry_version" || return 1
        shimmy_contains_line_list "$tool_version_lines" "$manifest_value" && return 1
        tool_label=$entry_tool\|$entry_label
        shimmy_contains_line_list "$tool_label_lines" "$tool_label" && return 1
        tool_version_lines=$(shimmy_append_line_list "$tool_version_lines" "$manifest_value")
        tool_label_lines=$(shimmy_append_line_list "$tool_label_lines" "$tool_label")
        ;;
      source_checkout)
        [ "$profile_name" = upstream ] || return 1
        [ "$(shimmy_manifest_key_count "$manifest_file" source_checkout)" -eq 1 ] || return 1
        case "$manifest_value" in /*) ;; *) return 1 ;; esac
        ;;
      startup_shell)
        [ "$profile_name" = default ] || return 1
        [ "$(shimmy_manifest_key_count "$manifest_file" startup_shell)" -eq 1 ] || return 1
        [ -n "$manifest_value" ] || return 1
        ;;
      startup_file)
        [ "$profile_name" = default ] || return 1
        case "$manifest_value" in /*) ;; *) return 1 ;; esac
        shimmy_contains_line_list "$startup_file_lines" "$manifest_value" && return 1
        startup_file_lines=$(shimmy_append_line_list "$startup_file_lines" "$manifest_value")
        ;;
      shimmy_source_url|shimmy_source_ref|shimmy_previous_source_ref)
        [ -n "$manifest_value" ] || return 1
        [ "$(shimmy_manifest_key_count "$manifest_file" "$manifest_key")" -eq 1 ] || return 1
        ;;
      shimmy_layout|control_bin|install_dir|bin_dir|config_dir|profile_implementation_dir|activate_file|profile|default_tool|shim_source)
        return 1
        ;;
      shimmy_install_*|shimmy_profile_*|*)
        return 1
        ;;
    esac
  done < "$manifest_file"

  while IFS= read -r tool_version_entry; do
    [ -n "$tool_version_entry" ] || continue
    entry_tool=${tool_version_entry%%|*}
    shimmy_contains_line_list "$tool_lines" "$entry_tool" || return 1
  done <<EOF
$tool_version_lines
EOF

  if [ "$profile_name" = upstream ]; then
    [ "$(shimmy_manifest_key_count "$manifest_file" source_checkout)" -eq 1 ] || return 1
  else
    [ "$(shimmy_manifest_key_count "$manifest_file" source_checkout)" -eq 0 ] || return 1
  fi
  [ "$catalog_count" -eq 1 ]
}

shimmy_profile_manifest_validate() {
  manifest_file=$1
  profile_name=$2

  [ -f "$manifest_file" ] && [ ! -L "$manifest_file" ] || {
    shimmy_profile_manifest_error "$manifest_file" "$profile_name"
    return 1
  }
  shimmy_manifest_identity_value_validate "$manifest_file" shimmy_install_manifest_version 1 &&
    shimmy_manifest_identity_value_validate "$manifest_file" shimmy_install_layout profile-flat-root &&
    shimmy_manifest_identity_value_validate "$manifest_file" shimmy_profile_manifest_version 1 &&
    shimmy_manifest_identity_value_validate "$manifest_file" shimmy_profile_name "$profile_name" &&
    shimmy_manifest_ownership_validate "$manifest_file" "$profile_name" || {
      shimmy_profile_manifest_error "$manifest_file" "$profile_name"
      return 1
    }
}

shimmy_profile_structure_validate() {
  profile_root=$1
  profile_name=$2
  manifest_file=$profile_root/install-manifest.txt

  shimmy_profile_manifest_validate "$manifest_file" "$profile_name" || return 1
  [ -f "$profile_root/shell-init.sh" ] && [ ! -L "$profile_root/shell-init.sh" ] || return 1
  [ -x "$profile_root/bin/shimmy" ] && [ ! -L "$profile_root/bin/shimmy" ] || return 1
  for required_dir in commands config implementations lib plugins tests tools; do
    [ -d "$profile_root/$required_dir" ] && [ ! -L "$profile_root/$required_dir" ] || return 1
  done
}

shimmy_upstream_checkout_invalid_reason() {
  checkout_dir=${1:-}
  shim_name=${2:-}

  case "$checkout_dir" in
    '') printf '%s\n' missing_source_checkout; return 0 ;;
    /*) ;;
    *) printf '%s\n' relative_source_checkout; return 0 ;;
  esac
  [ -d "$checkout_dir" ] || { printf '%s\n' stale_source_checkout; return 0; }
  [ -x "$checkout_dir/install.sh" ] || { printf '%s\n' invalid_source_checkout_missing_install_sh; return 0; }
  for required_dir in commands lib tools; do
    [ -d "$checkout_dir/$required_dir" ] || {
      printf 'invalid_source_checkout_missing_%s\n' "$required_dir"
      return 0
    }
  done
  [ -f "$checkout_dir/lib/install/launcher-template.sh" ] || {
    printf '%s\n' invalid_source_checkout_missing_launcher_template
    return 0
  }
  if [ -n "$shim_name" ]; then
    tool_name=${shim_name%%@*}
    [ -f "$checkout_dir/tools/$tool_name/tool.conf" ] || {
      printf '%s\n' missing_upstream_shim_source
      return 0
    }
  fi
  return 1
}

shimmy_upstream_checkout_validate() {
  ! shimmy_upstream_checkout_invalid_reason "$@" >/dev/null
}
