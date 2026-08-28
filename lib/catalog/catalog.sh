#!/bin/sh
# Named catalog resolution, schema-1 validation, and metadata discovery.

SHIMMY_CATALOG_ACCEPTED_SCHEMA=1
SHIMMY_CATALOG_CONTENT_FINGERPRINT=
SHIMMY_CATALOG_ERROR=
SHIMMY_CATALOG_HEALTH=unknown
SHIMMY_CATALOG_SCHEMA=

shimmy__catalog_config_key_count() {
  catalog_config_file=$1
  catalog_config_key=$2

  awk -F= -v key="$catalog_config_key" '$1 == key { count++ } END { print count + 0 }' "$catalog_config_file"
}

shimmy__catalog_config_keys_validate() {
  catalog_config_file=$1
  catalog_allowed_keys=$2

  while IFS= read -r catalog_config_line || [ -n "$catalog_config_line" ]; do
    case "$catalog_config_line" in
      ''|'#'*) continue ;;
      *=*) ;;
      *) shimmy_catalog_error_set "invalid catalog metadata $catalog_config_file: every non-comment line must use key=value syntax"; return 1 ;;
    esac
    catalog_config_key=${catalog_config_line%%=*}
    case "
$catalog_allowed_keys
" in
      *"
$catalog_config_key
"*) ;;
      *) shimmy_catalog_error_set "invalid catalog metadata $catalog_config_file: unknown key $catalog_config_key"; return 1 ;;
    esac
  done < "$catalog_config_file"
}

shimmy__catalog_config_scalar_require() {
  catalog_config_file=$1
  catalog_config_key=$2

  [ "$(shimmy__catalog_config_key_count "$catalog_config_file" "$catalog_config_key")" -eq 1 ] || {
    shimmy_catalog_error_set "invalid catalog metadata $catalog_config_file: $catalog_config_key is required exactly once"
    return 1
  }
}

shimmy_catalog_image_validator_prepare() {
  command -v shimmy_image_config_validate >/dev/null 2>&1 && return 0
  [ -n "${SHIMMY_ROOT_DIR:-}" ] || SHIMMY_ROOT_DIR=${ROOT_DIR:-}
  [ -n "$SHIMMY_ROOT_DIR" ] && [ -f "$SHIMMY_ROOT_DIR/lib/runtime/image.sh" ] || {
    shimmy_catalog_error_set 'unable to locate control-plane image schema validator'
    return 1
  }
  SHIMMY_RUNTIME_DIR=$SHIMMY_ROOT_DIR/lib/runtime
  # shellcheck source=lib/runtime/image.sh
  . "$SHIMMY_RUNTIME_DIR/image.sh"
}

shimmy__catalog_config_value_read() {
  catalog_config_file=$1
  catalog_config_key=$2

  awk -F= -v key="$catalog_config_key" '$1 == key { print substr($0, length($1) + 2); exit }' "$catalog_config_file"
}

shimmy__catalog_hash_file() {
  catalog_hash_file=$1

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$catalog_hash_file" | awk '{ print $1 }'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$catalog_hash_file" | awk '{ print $1 }'
    return 0
  fi

  shimmy_catalog_error_set 'catalog validation requires sha256sum or shasum'
  return 1
}

shimmy__catalog_metadata_keys_validate() {
  catalog_metadata_file=$1
  catalog_metadata_allowed_keys=$2
  catalog_metadata_scalar_keys=$3

  shimmy__catalog_config_keys_validate "$catalog_metadata_file" "$catalog_metadata_allowed_keys" || return 1
  for catalog_metadata_key in $catalog_metadata_scalar_keys; do
    [ "$(shimmy__catalog_config_key_count "$catalog_metadata_file" "$catalog_metadata_key")" -le 1 ] || {
      shimmy_catalog_error_set "invalid catalog metadata $catalog_metadata_file: duplicate scalar key $catalog_metadata_key"
      return 1
    }
  done
}

shimmy__catalog_path_entries_validate() {
  catalog_payload_root=$1

  [ -d "$catalog_payload_root/tools" ] && [ ! -L "$catalog_payload_root/tools" ] || {
    shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: tools must be a regular directory"
    return 1
  }

  if find "$catalog_payload_root/tools" -type l -print -quit | grep . >/dev/null 2>&1; then
    shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: symbolic links are not allowed"
    return 1
  fi
  if find "$catalog_payload_root/tools" ! -type d ! -type f -print -quit | grep . >/dev/null 2>&1; then
    shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: only regular files and directories are allowed"
    return 1
  fi

  find "$catalog_payload_root/tools" -exec /bin/sh -c '
    root=$1
    shift
    for entry_path do
      case "$entry_path" in "$root"/*) relative_path=${entry_path#"$root"/} ;; *) exit 1 ;; esac
      old_ifs=$IFS
      IFS=/
      set -- $relative_path
      IFS=$old_ifs
      for path_part do
        case "$path_part" in ""|.|..|.*|*[!A-Za-z0-9._-]*) exit 1 ;; esac
      done
    done
  ' sh "$catalog_payload_root" {} + || {
    shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: paths must use safe non-hidden ASCII components"
    return 1
  }
}

shimmy__catalog_tool_skill_file_validate() {
  catalog_tool_skill_file=$1
  catalog_tool_skill_name=$2

  [ -f "$catalog_tool_skill_file" ] && [ ! -L "$catalog_tool_skill_file" ] || {
    shimmy_catalog_error_set "invalid catalog tool skill $catalog_tool_skill_name: missing regular SKILL.md"
    return 1
  }
  awk -v expected_name="$catalog_tool_skill_name" '
    NR == 1 {
      if ($0 != "---") exit 1
      in_frontmatter=1
      next
    }
    in_frontmatter && $0 == "---" {
      in_frontmatter=0
      frontmatter_closed=1
      next
    }
    in_frontmatter && /^name: / {
      name_count++
      if (substr($0, 7) != expected_name) exit 1
      next
    }
    in_frontmatter && /^description: / {
      description_count++
      if (length(substr($0, 14)) == 0) exit 1
      next
    }
    END {
      if (!frontmatter_closed || name_count != 1 || description_count != 1) exit 1
    }
  ' "$catalog_tool_skill_file" || {
    shimmy_catalog_error_set "invalid catalog tool skill $catalog_tool_skill_name: SKILL.md must declare matching name and non-empty description frontmatter"
    return 1
  }
}

shimmy__catalog_tool_validate() {
  catalog_tool_dir=$1
  catalog_tool_name=$(basename -- "$catalog_tool_dir")
  catalog_tool_file=$catalog_tool_dir/tool.conf
  catalog_tool_allowed_keys='shim_config_version
shim_name
tool_default_version
tool_selector_env
smoke_env
smoke_arg'
  catalog_tool_scalar_keys='shim_config_version shim_name tool_default_version tool_selector_env'

  shimmy_name_component_validate "$catalog_tool_name" || {
    shimmy_catalog_error_set "invalid catalog tool directory name: $catalog_tool_name"
    return 1
  }
  [ -f "$catalog_tool_file" ] && [ ! -L "$catalog_tool_file" ] || {
    shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: missing regular tool.conf"
    return 1
  }
  shimmy__catalog_tool_skill_file_validate "$catalog_tool_dir/SKILL.md" "shimmy-tool-$catalog_tool_name" || return 1
  [ -d "$catalog_tool_dir/versions" ] && [ ! -L "$catalog_tool_dir/versions" ] || {
    shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: missing regular versions directory"
    return 1
  }
  shimmy__catalog_metadata_keys_validate "$catalog_tool_file" "$catalog_tool_allowed_keys" "$catalog_tool_scalar_keys" || return 1
  shimmy__catalog_config_scalar_require "$catalog_tool_file" shim_config_version || return 1
  shimmy__catalog_config_scalar_require "$catalog_tool_file" tool_default_version || return 1
  [ "$(shimmy__catalog_config_value_read "$catalog_tool_file" shim_config_version)" = 1 ] || {
    shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: shim_config_version must equal 1"
    return 1
  }
  if [ "$(shimmy__catalog_config_key_count "$catalog_tool_file" shim_name)" -eq 1 ]; then
    [ "$(shimmy__catalog_config_value_read "$catalog_tool_file" shim_name)" = "$catalog_tool_name" ] || {
      shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: shim_name must match its directory"
      return 1
    }
  fi
  catalog_tool_default=$(shimmy__catalog_config_value_read "$catalog_tool_file" tool_default_version)
  shimmy_version_token_validate "$catalog_tool_default" || {
    shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: unsafe tool_default_version $catalog_tool_default"
    return 1
  }
  [ -d "$catalog_tool_dir/versions/$catalog_tool_default" ] || {
    shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: default version $catalog_tool_default is missing"
    return 1
  }
  catalog_tool_selector=$(shimmy__catalog_config_value_read "$catalog_tool_file" tool_selector_env)
  if [ -n "$catalog_tool_selector" ]; then
    case "$catalog_tool_selector" in SHIMMY_?*) ;; *) shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: tool_selector_env must use the SHIMMY_ prefix"; return 1 ;; esac
    case "$catalog_tool_selector" in *[!A-Z0-9_]*) shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: tool_selector_env must be a POSIX variable name"; return 1 ;; esac
  fi

  catalog_tool_version_count=0
  for catalog_version_dir in "$catalog_tool_dir"/versions/*; do
    [ -e "$catalog_version_dir" ] || continue
    [ -d "$catalog_version_dir" ] && [ ! -L "$catalog_version_dir" ] || {
      shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: versions may contain only regular directories"
      return 1
    }
    shimmy__catalog_version_validate "$catalog_tool_name" "$catalog_version_dir" || return 1
    catalog_tool_version_count=$((catalog_tool_version_count + 1))
  done
  [ "$catalog_tool_version_count" -gt 0 ] || {
    shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: at least one concrete version is required"
    return 1
  }
}

shimmy__catalog_version_validate() {
  catalog_version_tool=$1
  catalog_version_dir=$2
  catalog_version_label=$(basename -- "$catalog_version_dir")
  catalog_version_smoke_file=$catalog_version_dir/smoke.conf
  catalog_version_allowed_keys='shim_config_version
smoke_env
smoke_arg'
  catalog_version_scalar_keys='shim_config_version'

  shimmy_version_token_validate "$catalog_version_label" || {
    shimmy_catalog_error_set "invalid catalog version label for $catalog_version_tool: $catalog_version_label"
    return 1
  }
  for catalog_version_required_file in smoke.conf image.conf; do
    [ -f "$catalog_version_dir/$catalog_version_required_file" ] && [ ! -L "$catalog_version_dir/$catalog_version_required_file" ] || {
      shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: missing regular $catalog_version_required_file"
      return 1
    }
  done
  for catalog_version_executable in run.sh refresh.sh; do
    [ -f "$catalog_version_dir/$catalog_version_executable" ] && [ ! -L "$catalog_version_dir/$catalog_version_executable" ] && [ -x "$catalog_version_dir/$catalog_version_executable" ] || {
      shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: $catalog_version_executable must be an executable regular file"
      return 1
    }
  done

  shimmy__catalog_metadata_keys_validate "$catalog_version_smoke_file" "$catalog_version_allowed_keys" "$catalog_version_scalar_keys" || return 1
  shimmy__catalog_config_scalar_require "$catalog_version_smoke_file" shim_config_version || return 1
  [ "$(shimmy__catalog_config_value_read "$catalog_version_smoke_file" shim_config_version)" = 1 ] || {
    shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: shim_config_version must equal 1"
    return 1
  }
  [ "$(shimmy__catalog_config_key_count "$catalog_version_smoke_file" smoke_arg)" -gt 0 ] || {
    shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: smoke_arg is required"
    return 1
  }
  if ! catalog_image_error=$(shimmy_image_config_validate "$catalog_version_dir/image.conf" 2>&1); then
    shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: $catalog_image_error"
    return 1
  fi
  if [ "$(shimmy_image_config_scalar_read "$catalog_version_dir/image.conf" image_source)" = local-build ]; then
    catalog_image_context=$(shimmy_image_config_scalar_read "$catalog_version_dir/image.conf" image_context)
    catalog_image_context_dir=$catalog_version_dir/$catalog_image_context
    [ -d "$catalog_image_context_dir" ] && [ ! -L "$catalog_image_context_dir" ] && [ -f "$catalog_image_context_dir/Containerfile" ] && [ ! -L "$catalog_image_context_dir/Containerfile" ] || {
      shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: local image context must contain a regular Containerfile"
      return 1
    }
  fi
}

shimmy_catalog_error_set() {
  SHIMMY_CATALOG_ERROR=$*
  SHIMMY_CATALOG_HEALTH=invalid
  return 1
}

shimmy_catalog_fingerprint_render() {
  catalog_fingerprint_root=$1
  catalog_fingerprint_tmp_parent=${TMPDIR:-/tmp}
  case "$catalog_fingerprint_tmp_parent" in ''|/) catalog_fingerprint_tmp_parent=/tmp ;; */) catalog_fingerprint_tmp_parent=${catalog_fingerprint_tmp_parent%/} ;; esac
  catalog_fingerprint_manifest=$(mktemp "$catalog_fingerprint_tmp_parent/shimmy-catalog-fingerprint.XXXXXX") || {
    shimmy_catalog_error_set 'unable to create catalog fingerprint workspace'
    return 1
  }

  (
    cd -- "$catalog_fingerprint_root" || exit 1
    find catalog.conf tools -type f -print | LC_ALL=C sort | while IFS= read -r catalog_fingerprint_file; do
      [ -n "$catalog_fingerprint_file" ] || continue
      if [ -x "$catalog_fingerprint_file" ]; then catalog_fingerprint_mode=x; else catalog_fingerprint_mode=f; fi
      catalog_fingerprint_file_hash=$(shimmy__catalog_hash_file "$catalog_fingerprint_file") || exit 1
      printf '%s|%s|%s\n' "$catalog_fingerprint_mode" "$catalog_fingerprint_file_hash" "$catalog_fingerprint_file"
    done
  ) > "$catalog_fingerprint_manifest" || {
    rm -f "$catalog_fingerprint_manifest"
    shimmy_catalog_error_set "unable to fingerprint catalog payload $catalog_fingerprint_root"
    return 1
  }
  catalog_fingerprint_hash=$(shimmy__catalog_hash_file "$catalog_fingerprint_manifest") || {
    rm -f "$catalog_fingerprint_manifest"
    return 1
  }
  rm -f "$catalog_fingerprint_manifest"
  printf 'sha256:%s\n' "$catalog_fingerprint_hash"
}

shimmy_catalog_payload_validate() {
  catalog_payload_root=$1
  catalog_payload_name=${2:-unknown}
  catalog_payload_file=$catalog_payload_root/catalog.conf
  catalog_payload_allowed_keys='catalog_format
catalog_schema'

  case "$catalog_payload_root" in /*) ;; *) shimmy_catalog_error_set "catalog $catalog_payload_name authority must be an absolute path: $catalog_payload_root"; return 1 ;; esac
  [ -d "$catalog_payload_root" ] && [ ! -L "$catalog_payload_root" ] || {
    shimmy_catalog_error_set "catalog $catalog_payload_name authority is unavailable: $catalog_payload_root"
    return 1
  }
  shimmy_path_parent_chain_validate "$catalog_payload_root" || {
    shimmy_catalog_error_set "catalog $catalog_payload_name authority has a symbolic-link path component: $catalog_payload_root"
    return 1
  }
  [ -f "$catalog_payload_file" ] && [ ! -L "$catalog_payload_file" ] || {
    shimmy_catalog_error_set "catalog $catalog_payload_name is missing regular payload identity file $catalog_payload_file"
    return 1
  }
  shimmy__catalog_config_keys_validate "$catalog_payload_file" "$catalog_payload_allowed_keys" || return 1
  shimmy__catalog_config_scalar_require "$catalog_payload_file" catalog_format || return 1
  shimmy__catalog_config_scalar_require "$catalog_payload_file" catalog_schema || return 1
  catalog_payload_format=$(shimmy__catalog_config_value_read "$catalog_payload_file" catalog_format)
  [ "$catalog_payload_format" = shimmy-catalog ] || {
    shimmy_catalog_error_set "catalog $catalog_payload_name has unsupported format '$catalog_payload_format'; expected shimmy-catalog"
    return 1
  }
  catalog_payload_schema=$(shimmy__catalog_config_value_read "$catalog_payload_file" catalog_schema)
  [ "$catalog_payload_schema" = "$SHIMMY_CATALOG_ACCEPTED_SCHEMA" ] || {
    shimmy_catalog_error_set "catalog $catalog_payload_name has schema '$catalog_payload_schema'; accepted schema: $SHIMMY_CATALOG_ACCEPTED_SCHEMA"
    return 1
  }

  shimmy__catalog_path_entries_validate "$catalog_payload_root" || return 1

  shimmy_catalog_image_validator_prepare || return 1

  catalog_payload_tool_count=0
  for catalog_tool_entry in "$catalog_payload_root"/tools/*; do
    [ -e "$catalog_tool_entry" ] || continue
    [ -d "$catalog_tool_entry" ] && [ ! -L "$catalog_tool_entry" ] || {
      shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: every direct tools entry must be a regular directory"
      return 1
    }
    shimmy__catalog_tool_validate "$catalog_tool_entry" || return 1
    catalog_payload_tool_count=$((catalog_payload_tool_count + 1))
  done
  [ "$catalog_payload_tool_count" -gt 0 ] || {
    shimmy_catalog_error_set "catalog $catalog_payload_name contains no valid tools"
    return 1
  }
  SHIMMY_CATALOG_SCHEMA=$catalog_payload_schema
}
