#!/bin/sh
# Named catalog resolution, schema-1 validation, and metadata discovery.

SHIMMY_CATALOG_ACCEPTED_SCHEMA=1
SHIMMY_CATALOG_AUTHORITY_ROOT=
SHIMMY_CATALOG_CONTENT_FINGERPRINT=
SHIMMY_CATALOG_ERROR=
SHIMMY_CATALOG_GENERATION=
SHIMMY_CATALOG_GENERATION_PREVIOUS=
SHIMMY_CATALOG_HEALTH=unknown
SHIMMY_CATALOG_NAME=
SHIMMY_CATALOG_REGISTRY_FILE=
SHIMMY_CATALOG_SCHEMA=
SHIMMY_CATALOG_SOURCE_COMMIT=
SHIMMY_CATALOG_SOURCE_PATH=
SHIMMY_CATALOG_SOURCE_TYPE=
SHIMMY_CATALOG_TOOLS_DIR=

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

shimmy__catalog_config_value_read() {
  catalog_config_file=$1
  catalog_config_key=$2

  awk -F= -v key="$catalog_config_key" '$1 == key { print substr($0, length($1) + 2); exit }' "$catalog_config_file"
}

shimmy__catalog_generation_metadata_validate() {
  catalog_generation_root=$1
  catalog_generation_file=$catalog_generation_root/generation.conf
  catalog_generation_allowed_keys='catalog_source_commit
catalog_content_fingerprint'

  [ -f "$catalog_generation_file" ] && [ ! -L "$catalog_generation_file" ] || {
    shimmy_catalog_error_set "invalid catalog generation: missing regular metadata file $catalog_generation_file"
    return 1
  }
  shimmy__catalog_config_keys_validate "$catalog_generation_file" "$catalog_generation_allowed_keys" || return 1
  shimmy__catalog_config_scalar_require "$catalog_generation_file" catalog_source_commit || return 1
  shimmy__catalog_config_scalar_require "$catalog_generation_file" catalog_content_fingerprint || return 1

  catalog_generation_commit=$(shimmy__catalog_config_value_read "$catalog_generation_file" catalog_source_commit)
  shimmy_catalog_git_commit_validate "$catalog_generation_commit" || {
    shimmy_catalog_error_set "invalid catalog generation metadata $catalog_generation_file: catalog_source_commit must be a Git object ID"
    return 1
  }
  catalog_generation_fingerprint=$(shimmy__catalog_config_value_read "$catalog_generation_file" catalog_content_fingerprint)
  shimmy_catalog_fingerprint_validate "$catalog_generation_fingerprint" || {
    shimmy_catalog_error_set "invalid catalog generation metadata $catalog_generation_file: catalog_content_fingerprint must be sha256:<64-lowercase-hex>"
    return 1
  }
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
  [ -d "$catalog_payload_root/plugins/shimmy/skills" ] && [ ! -L "$catalog_payload_root/plugins/shimmy/skills" ] || {
    shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: plugins/shimmy/skills must be a regular directory"
    return 1
  }

  if find "$catalog_payload_root/tools" "$catalog_payload_root/plugins/shimmy/skills" -type l -print -quit | grep . >/dev/null 2>&1; then
    shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: symbolic links are not allowed"
    return 1
  fi
  if find "$catalog_payload_root/tools" "$catalog_payload_root/plugins/shimmy/skills" ! -type d ! -type f -print -quit | grep . >/dev/null 2>&1; then
    shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: only regular files and directories are allowed"
    return 1
  fi

  find "$catalog_payload_root/tools" "$catalog_payload_root/plugins/shimmy/skills" -exec /bin/sh -c '
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

shimmy__catalog_skill_file_validate() {
  catalog_skill_file=$1
  catalog_skill_name=$2

  [ -f "$catalog_skill_file" ] && [ ! -L "$catalog_skill_file" ] || {
    shimmy_catalog_error_set "invalid catalog skill $catalog_skill_name: missing regular SKILL.md"
    return 1
  }
  awk -v expected_name="$catalog_skill_name" '
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
  ' "$catalog_skill_file" || {
    shimmy_catalog_error_set "invalid catalog skill $catalog_skill_name: SKILL.md must declare matching name and non-empty description frontmatter"
    return 1
  }
}

shimmy__catalog_registry_file_validate() {
  catalog_registry_file=$1
  catalog_expected_name=$2
  catalog_registry_common_keys='catalog_name
catalog_source_type'

  [ -f "$catalog_registry_file" ] && [ ! -L "$catalog_registry_file" ] || {
    shimmy_catalog_error_set "missing catalog registry entry: $catalog_registry_file"
    return 1
  }
  [ "$(shimmy__catalog_config_key_count "$catalog_registry_file" catalog_source_type)" -eq 1 ] || {
    shimmy_catalog_error_set "invalid catalog registry $catalog_registry_file: catalog_source_type is required exactly once"
    return 1
  }
  catalog_registry_source_type=$(shimmy__catalog_config_value_read "$catalog_registry_file" catalog_source_type)
  case "$catalog_registry_source_type" in
    checkout)
      catalog_registry_allowed_keys="$catalog_registry_common_keys
catalog_source_path"
      ;;
    generation)
      catalog_registry_allowed_keys="$catalog_registry_common_keys
catalog_generation_current
catalog_generation_previous
catalog_source_commit
catalog_content_fingerprint"
      ;;
    *)
      shimmy_catalog_error_set "invalid catalog registry $catalog_registry_file: catalog_source_type must equal checkout or generation"
      return 1
      ;;
  esac

  shimmy__catalog_config_keys_validate "$catalog_registry_file" "$catalog_registry_allowed_keys" || return 1
  for catalog_registry_key in $catalog_registry_allowed_keys; do
    shimmy__catalog_config_scalar_require "$catalog_registry_file" "$catalog_registry_key" || return 1
  done

  catalog_registry_name=$(shimmy__catalog_config_value_read "$catalog_registry_file" catalog_name)
  shimmy_catalog_name_validate "$catalog_registry_name" || {
    shimmy_catalog_error_set "invalid catalog registry $catalog_registry_file: unsafe catalog_name $catalog_registry_name"
    return 1
  }
  [ "$catalog_registry_name" = "$catalog_expected_name" ] || {
    shimmy_catalog_error_set "catalog registry name mismatch: profile requested $catalog_expected_name but $catalog_registry_file records $catalog_registry_name"
    return 1
  }

  SHIMMY_CATALOG_NAME=$catalog_registry_name
  SHIMMY_CATALOG_SOURCE_TYPE=$catalog_registry_source_type
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

  shimmy_tool_name_validate "$catalog_tool_name" || {
    shimmy_catalog_error_set "invalid catalog tool directory name: $catalog_tool_name"
    return 1
  }
  [ -f "$catalog_tool_file" ] && [ ! -L "$catalog_tool_file" ] || {
    shimmy_catalog_error_set "invalid catalog tool $catalog_tool_name: missing regular tool.conf"
    return 1
  }
  shimmy__catalog_skill_file_validate "$catalog_tool_dir/SKILL.md" "shimmy-tool-$catalog_tool_name" || return 1
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
shim_name
smoke_env
smoke_arg'
  catalog_version_scalar_keys='shim_config_version shim_name'

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
  shimmy__catalog_config_scalar_require "$catalog_version_smoke_file" shim_name || return 1
  [ "$(shimmy__catalog_config_value_read "$catalog_version_smoke_file" shim_config_version)" = 1 ] || {
    shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: shim_config_version must equal 1"
    return 1
  }
  [ "$(shimmy__catalog_config_key_count "$catalog_version_smoke_file" smoke_arg)" -gt 0 ] || {
    shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: smoke_arg is required"
    return 1
  }
  catalog_version_name=$(shimmy__catalog_config_value_read "$catalog_version_smoke_file" shim_name)
  shimmy_version_token_validate "$catalog_version_name" || {
    shimmy_catalog_error_set "invalid catalog version $catalog_version_tool@$catalog_version_label: unsafe shim_name $catalog_version_name"
    return 1
  }
  if shimmy_contains_line_list "$SHIMMY_CATALOG_VERSION_NAMES_SEEN" "$catalog_version_name"; then
    shimmy_catalog_error_set "invalid catalog payload: duplicate logical concrete version $catalog_version_name"
    return 1
  fi
  SHIMMY_CATALOG_VERSION_NAMES_SEEN=$(shimmy_append_line_list "$SHIMMY_CATALOG_VERSION_NAMES_SEEN" "$catalog_version_name")

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

shimmy__tool_dir() {
  tool_name=$1
  [ -n "$SHIMMY_CATALOG_TOOLS_DIR" ] || return 1
  printf '%s/%s\n' "$SHIMMY_CATALOG_TOOLS_DIR" "$tool_name"
}

shimmy__tool_metadata_read() {
  tool_file=$1
  key=$2

  sed -n "s/^${key}=//p" "$tool_file" | sed -n '1p'
}

shimmy__version_name_read() {
  version_dir=$1

  shimmy__tool_metadata_read "$version_dir/smoke.conf" shim_name
}

shimmy_catalog_checkout_resolve() {
  catalog_checkout_root=$1
  catalog_checkout_name=${2:-upstream}

  shimmy_catalog_state_reset
  shimmy_catalog_name_validate "$catalog_checkout_name" || {
    shimmy_catalog_error_set "unsafe catalog name: $catalog_checkout_name"
    return 1
  }
  catalog_checkout_root=$(shimmy_resolve_path_absolute "$catalog_checkout_root") || {
    shimmy_catalog_error_set "unable to resolve catalog checkout: $1"
    return 1
  }
  SHIMMY_CATALOG_NAME=$catalog_checkout_name
  SHIMMY_CATALOG_SOURCE_TYPE=checkout
  SHIMMY_CATALOG_SOURCE_PATH=$catalog_checkout_root
  shimmy_catalog_payload_validate "$catalog_checkout_root" "$catalog_checkout_name" || return 1
  SHIMMY_CATALOG_AUTHORITY_ROOT=$catalog_checkout_root
  SHIMMY_CATALOG_TOOLS_DIR=$catalog_checkout_root/tools
  SHIMMY_CATALOG_CONTENT_FINGERPRINT=$(shimmy_catalog_fingerprint_render "$catalog_checkout_root") || return 1
  SHIMMY_CATALOG_SOURCE_COMMIT=$(shimmy_catalog_git_head_read "$catalog_checkout_root" || true)
  SHIMMY_CATALOG_HEALTH=ok
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
    find catalog.conf tools plugins/shimmy/skills -type f -print | LC_ALL=C sort | while IFS= read -r catalog_fingerprint_file; do
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

shimmy_catalog_fingerprint_validate() {
  catalog_fingerprint_value=$1
  case "$catalog_fingerprint_value" in sha256:*) ;; *) return 1 ;; esac
  catalog_fingerprint_hash=${catalog_fingerprint_value#sha256:}
  [ "${#catalog_fingerprint_hash}" -eq 64 ] || return 1
  case "$catalog_fingerprint_hash" in *[!0-9a-f]*) return 1 ;; esac
}

shimmy_catalog_generation_name_render() {
  catalog_generation_fingerprint=$1
  shimmy_catalog_fingerprint_validate "$catalog_generation_fingerprint" || return 1
  printf 'sha256-%s\n' "${catalog_generation_fingerprint#sha256:}"
}

shimmy_catalog_generation_name_validate() {
  catalog_generation_name=$1
  case "$catalog_generation_name" in sha256-*) ;; *) return 1 ;; esac
  catalog_generation_hash=${catalog_generation_name#sha256-}
  [ "${#catalog_generation_hash}" -eq 64 ] || return 1
  case "$catalog_generation_hash" in *[!0-9a-f]*) return 1 ;; esac
}

shimmy_catalog_git_commit_validate() {
  catalog_git_commit=$1
  case "${#catalog_git_commit}" in 40|64) ;; *) return 1 ;; esac
  case "$catalog_git_commit" in *[!0-9a-f]*) return 1 ;; esac
}

shimmy_catalog_git_head_read() {
  catalog_git_root=$1
  command -v git >/dev/null 2>&1 || return 1
  git -C "$catalog_git_root" rev-parse --verify HEAD 2>/dev/null
}

shimmy_catalog_name_validate() {
  case "${1:-}" in
    ''|-*|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_catalog_path_parent_chain_validate() {
  catalog_path_value=$1
  case "$catalog_path_value" in /*) ;; *) return 1 ;; esac
  while [ "$catalog_path_value" != / ]; do
    [ ! -L "$catalog_path_value" ] || return 1
    catalog_path_value=$(dirname -- "$catalog_path_value")
  done
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
  shimmy_catalog_path_parent_chain_validate "$catalog_payload_root" || {
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
  catalog_management_skills='shimmy-catalog
shimmy-create-tool
shimmy-escalation
shimmy-init
shimmy-install
shimmy-tool-local-build'
  for catalog_management_entry in "$catalog_payload_root"/plugins/shimmy/skills/*; do
    [ -e "$catalog_management_entry" ] || continue
    [ -d "$catalog_management_entry" ] && [ ! -L "$catalog_management_entry" ] || {
      shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: every management skill entry must be a regular directory"
      return 1
    }
    catalog_management_entry_name=$(basename -- "$catalog_management_entry")
    shimmy_contains_line_list "$catalog_management_skills" "$catalog_management_entry_name" || {
      shimmy_catalog_error_set "invalid catalog payload $catalog_payload_root: unexpected management skill $catalog_management_entry_name"
      return 1
    }
  done
  for catalog_management_skill in shimmy-catalog shimmy-create-tool shimmy-escalation shimmy-init shimmy-install shimmy-tool-local-build; do
    catalog_management_skill_file=$catalog_payload_root/plugins/shimmy/skills/$catalog_management_skill/SKILL.md
    shimmy__catalog_skill_file_validate "$catalog_management_skill_file" "$catalog_management_skill" || return 1
  done

  if ! command -v shimmy_image_config_validate >/dev/null 2>&1; then
    [ -n "${SHIMMY_CONTROL_ROOT:-}" ] || SHIMMY_CONTROL_ROOT=${ROOT_DIR:-}
    [ -n "$SHIMMY_CONTROL_ROOT" ] && [ -f "$SHIMMY_CONTROL_ROOT/lib/runtime/image.sh" ] || {
      shimmy_catalog_error_set 'unable to locate control-plane image schema validator'
      return 1
    }
    SHIMMY_RUNTIME_DIR=$SHIMMY_CONTROL_ROOT/lib/runtime
    # shellcheck source=lib/runtime/image.sh
    . "$SHIMMY_RUNTIME_DIR/image.sh"
  fi

  SHIMMY_CATALOG_VERSION_NAMES_SEEN=
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

shimmy_catalog_profile_resolve() {
  catalog_profile_manifest=$1
  catalog_config_root=$2

  shimmy_catalog_state_reset
  [ -f "$catalog_profile_manifest" ] || {
    shimmy_catalog_error_set "missing profile manifest for catalog resolution: $catalog_profile_manifest"
    return 1
  }
  [ "$(shimmy__catalog_config_key_count "$catalog_profile_manifest" catalog)" -eq 1 ] || {
    shimmy_catalog_error_set "profile manifest must record catalog exactly once: $catalog_profile_manifest"
    return 1
  }
  catalog_profile_name=$(shimmy__catalog_config_value_read "$catalog_profile_manifest" catalog)
  shimmy_catalog_name_validate "$catalog_profile_name" || {
    shimmy_catalog_error_set "profile manifest records unsafe catalog name: $catalog_profile_name"
    return 1
  }
  [ "$(shimmy__catalog_config_key_count "$catalog_profile_manifest" shimmy_profile_name)" -eq 1 ] || {
    shimmy_catalog_error_set "profile manifest must record shimmy_profile_name exactly once for catalog resolution: $catalog_profile_manifest"
    return 1
  }
  catalog_profile_identity=$(shimmy__catalog_config_value_read "$catalog_profile_manifest" shimmy_profile_name)
  [ "$catalog_profile_name" = "$catalog_profile_identity" ] || {
    shimmy_catalog_error_set "profile $catalog_profile_identity must bind the fixed $catalog_profile_identity catalog, not $catalog_profile_name"
    return 1
  }
  shimmy_catalog_registry_resolve "$catalog_config_root" "$catalog_profile_name"
}

shimmy_catalog_registry_resolve() {
  catalog_config_root=$1
  catalog_registry_name=$2

  shimmy_catalog_state_reset
  shimmy_catalog_name_validate "$catalog_registry_name" || {
    shimmy_catalog_error_set "unsafe catalog name: $catalog_registry_name"
    return 1
  }
  case "$catalog_config_root" in /*) ;; *) shimmy_catalog_error_set "catalog configuration root must be absolute: $catalog_config_root"; return 1 ;; esac
  shimmy_catalog_path_parent_chain_validate "$catalog_config_root" || {
    shimmy_catalog_error_set "catalog configuration root has a symbolic-link path component: $catalog_config_root"
    return 1
  }

  catalog_registry_dir=$catalog_config_root/catalogs/$catalog_registry_name
  catalog_registry_file=$catalog_registry_dir/registry.conf
  SHIMMY_CATALOG_REGISTRY_FILE=$catalog_registry_file
  shimmy_catalog_path_parent_chain_validate "$catalog_registry_dir" || {
    shimmy_catalog_error_set "catalog registry path has a symbolic-link component: $catalog_registry_dir"
    return 1
  }
  shimmy__catalog_registry_file_validate "$catalog_registry_file" "$catalog_registry_name" || return 1

  case "$SHIMMY_CATALOG_SOURCE_TYPE" in
    checkout)
      catalog_registry_source_path=$(shimmy__catalog_config_value_read "$catalog_registry_file" catalog_source_path)
      case "$catalog_registry_source_path" in /*) ;; *) shimmy_catalog_error_set "catalog $catalog_registry_name records a relative checkout path: $catalog_registry_source_path"; return 1 ;; esac
      catalog_registry_source_real=$(shimmy_resolve_path_absolute "$catalog_registry_source_path") || {
        shimmy_catalog_error_set "catalog $catalog_registry_name checkout is unavailable: $catalog_registry_source_path"
        return 1
      }
      [ "$catalog_registry_source_real" = "$catalog_registry_source_path" ] || {
        shimmy_catalog_error_set "catalog $catalog_registry_name checkout must be a canonical non-symlink path: $catalog_registry_source_path"
        return 1
      }
      SHIMMY_CATALOG_SOURCE_PATH=$catalog_registry_source_path
      shimmy_catalog_payload_validate "$catalog_registry_source_path" "$catalog_registry_name" || return 1
      SHIMMY_CATALOG_SOURCE_COMMIT=$(shimmy_catalog_git_head_read "$catalog_registry_source_path" || true)
      shimmy_catalog_git_commit_validate "$SHIMMY_CATALOG_SOURCE_COMMIT" || {
        shimmy_catalog_error_set "catalog $catalog_registry_name checkout is not a Git worktree with a readable HEAD: $catalog_registry_source_path"
        return 1
      }
      SHIMMY_CATALOG_AUTHORITY_ROOT=$catalog_registry_source_path
      SHIMMY_CATALOG_CONTENT_FINGERPRINT=$(shimmy_catalog_fingerprint_render "$catalog_registry_source_path") || return 1
      ;;
    generation)
      catalog_registry_generation=$(shimmy__catalog_config_value_read "$catalog_registry_file" catalog_generation_current)
      shimmy_catalog_generation_name_validate "$catalog_registry_generation" || {
        shimmy_catalog_error_set "catalog $catalog_registry_name records an unsafe current generation: $catalog_registry_generation"
        return 1
      }
      catalog_registry_previous=$(shimmy__catalog_config_value_read "$catalog_registry_file" catalog_generation_previous)
      if [ -n "$catalog_registry_previous" ]; then
        shimmy_catalog_generation_name_validate "$catalog_registry_previous" || {
          shimmy_catalog_error_set "catalog $catalog_registry_name records an unsafe previous generation: $catalog_registry_previous"
          return 1
        }
        [ "$catalog_registry_previous" != "$catalog_registry_generation" ] || {
          shimmy_catalog_error_set "catalog $catalog_registry_name current and previous generations must differ"
          return 1
        }
      fi
      catalog_registry_commit=$(shimmy__catalog_config_value_read "$catalog_registry_file" catalog_source_commit)
      shimmy_catalog_git_commit_validate "$catalog_registry_commit" || {
        shimmy_catalog_error_set "catalog $catalog_registry_name records an invalid source commit: $catalog_registry_commit"
        return 1
      }
      catalog_registry_fingerprint=$(shimmy__catalog_config_value_read "$catalog_registry_file" catalog_content_fingerprint)
      shimmy_catalog_fingerprint_validate "$catalog_registry_fingerprint" || {
        shimmy_catalog_error_set "catalog $catalog_registry_name records an invalid content fingerprint: $catalog_registry_fingerprint"
        return 1
      }
      [ "$(shimmy_catalog_generation_name_render "$catalog_registry_fingerprint")" = "$catalog_registry_generation" ] || {
        shimmy_catalog_error_set "catalog $catalog_registry_name generation does not match its content fingerprint"
        return 1
      }
      catalog_current_generation_root=$catalog_registry_dir/generations/$catalog_registry_generation
      shimmy_catalog_payload_validate "$catalog_current_generation_root" "$catalog_registry_name" || return 1
      shimmy__catalog_generation_metadata_validate "$catalog_current_generation_root" || return 1
      catalog_generation_fingerprint=$(shimmy__catalog_config_value_read "$catalog_current_generation_root/generation.conf" catalog_content_fingerprint)
      [ "$catalog_generation_fingerprint" = "$catalog_registry_fingerprint" ] || {
        shimmy_catalog_error_set "catalog $catalog_registry_name generation metadata fingerprint does not match its registry"
        return 1
      }
      catalog_resolved_fingerprint=$(shimmy_catalog_fingerprint_render "$catalog_current_generation_root") || return 1
      [ "$catalog_resolved_fingerprint" = "$catalog_registry_fingerprint" ] || {
        shimmy_catalog_error_set "catalog $catalog_registry_name generation content fingerprint mismatch: $catalog_registry_generation"
        return 1
      }
      if [ -n "$catalog_registry_previous" ]; then
        catalog_previous_root=$catalog_registry_dir/generations/$catalog_registry_previous
        shimmy_catalog_payload_validate "$catalog_previous_root" "$catalog_registry_name previous generation" || return 1
        shimmy__catalog_generation_metadata_validate "$catalog_previous_root" || return 1
        catalog_previous_fingerprint=$(shimmy__catalog_config_value_read "$catalog_previous_root/generation.conf" catalog_content_fingerprint)
        [ "$(shimmy_catalog_generation_name_render "$catalog_previous_fingerprint")" = "$catalog_registry_previous" ] || {
          shimmy_catalog_error_set "catalog $catalog_registry_name previous generation metadata does not match its name: $catalog_registry_previous"
          return 1
        }
        catalog_previous_resolved_fingerprint=$(shimmy_catalog_fingerprint_render "$catalog_previous_root") || return 1
        [ "$catalog_previous_resolved_fingerprint" = "$catalog_previous_fingerprint" ] || {
          shimmy_catalog_error_set "catalog $catalog_registry_name previous generation content fingerprint mismatch: $catalog_registry_previous"
          return 1
        }
      fi
      SHIMMY_CATALOG_AUTHORITY_ROOT=$catalog_current_generation_root
      SHIMMY_CATALOG_CONTENT_FINGERPRINT=$catalog_registry_fingerprint
      SHIMMY_CATALOG_GENERATION=$catalog_registry_generation
      SHIMMY_CATALOG_GENERATION_PREVIOUS=$catalog_registry_previous
      SHIMMY_CATALOG_SOURCE_COMMIT=$catalog_registry_commit
      SHIMMY_CATALOG_SOURCE_PATH=$catalog_current_generation_root
      ;;
  esac

  SHIMMY_CATALOG_TOOLS_DIR=$SHIMMY_CATALOG_AUTHORITY_ROOT/tools
  SHIMMY_CATALOG_HEALTH=ok
}

shimmy_catalog_state_reset() {
  SHIMMY_CATALOG_AUTHORITY_ROOT=
  SHIMMY_CATALOG_CONTENT_FINGERPRINT=
  SHIMMY_CATALOG_ERROR=
  SHIMMY_CATALOG_GENERATION=
  SHIMMY_CATALOG_GENERATION_PREVIOUS=
  SHIMMY_CATALOG_HEALTH=unknown
  SHIMMY_CATALOG_NAME=
  SHIMMY_CATALOG_REGISTRY_FILE=
  SHIMMY_CATALOG_SCHEMA=
  SHIMMY_CATALOG_SOURCE_COMMIT=
  SHIMMY_CATALOG_SOURCE_PATH=
  SHIMMY_CATALOG_SOURCE_TYPE=
  SHIMMY_CATALOG_TOOLS_DIR=
}

shimmy_is_version() {
  shimmy_tool_version_tool "$1" >/dev/null 2>&1
}

shimmy_tool_exists() {
  [ -f "$(shimmy__tool_dir "$1")/tool.conf" ]
}

shimmy_tool_list() {
  [ -n "$SHIMMY_CATALOG_TOOLS_DIR" ] || return 1
  for tool_file in "$SHIMMY_CATALOG_TOOLS_DIR"/*/tool.conf; do
    [ -f "$tool_file" ] || continue
    basename "$(dirname "$tool_file")"
  done | sort
}

shimmy_tool_name_validate() {
  case "${1:-}" in
    ''|-*|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_tool_selector_env() {
  tool_name=$1
  tool_file=$(shimmy__tool_dir "$tool_name")/tool.conf
  [ -f "$tool_file" ] || return 1
  shimmy__tool_metadata_read "$tool_file" tool_selector_env
}

shimmy_tool_version_default() {
  tool_name=$1
  tool_file=$(shimmy__tool_dir "$tool_name")/tool.conf
  default_label=$(shimmy__tool_metadata_read "$tool_file" tool_default_version)

  shimmy_tool_version_label_resolve "$tool_name" "$default_label"
}

shimmy_tool_version_label_list() {
  tool_name=$1

  for version_dir in "$(shimmy__tool_dir "$tool_name")"/versions/*; do
    [ -d "$version_dir" ] || continue
    basename "$version_dir"
  done | sort
}

shimmy_tool_version_label_resolve() {
  tool_name=$1
  version_label=$2
  version_dir=$(shimmy__tool_dir "$tool_name")/versions/$version_label

  [ -d "$version_dir" ] || return 1
  shimmy__version_name_read "$version_dir"
}

shimmy_tool_version_list() {
  tool_name=$1

  for version_label in $(shimmy_tool_version_label_list "$tool_name"); do
    shimmy_tool_version_label_resolve "$tool_name" "$version_label"
  done
}

shimmy_tool_version_tool() {
  version_name=$1

  for tool_name in $(shimmy_tool_list); do
    for version_name_current in $(shimmy_tool_version_list "$tool_name"); do
      if [ "$version_name_current" = "$version_name" ]; then
        printf '%s\n' "$tool_name"
        return 0
      fi
    done
  done

  return 1
}

shimmy_version_dir() {
  version_name=$1
  tool_name=$(shimmy_tool_version_tool "$version_name") || return 1
  version_label=$(shimmy_version_label "$version_name") || return 1

  printf '%s/%s/versions/%s\n' "$SHIMMY_CATALOG_TOOLS_DIR" "$tool_name" "$version_label"
}

shimmy_version_image_config_file() {
  version_name=$1
  version_dir=$(shimmy_version_dir "$version_name") || return 1

  printf '%s/image.conf\n' "$version_dir"
}

shimmy_version_label() {
  version_name=$1

  for tool_name in $(shimmy_tool_list); do
    for version_label in $(shimmy_tool_version_label_list "$tool_name"); do
      if [ "$(shimmy_tool_version_label_resolve "$tool_name" "$version_label")" = "$version_name" ]; then
        printf '%s\n' "$version_label"
        return 0
      fi
    done
  done

  return 1
}

shimmy_version_token_validate() {
  case "${1:-}" in
    ''|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-]*) return 1 ;;
    *) return 0 ;;
  esac
}
