#!/bin/sh
# Shared selection, parsing, and inspection helpers for image verification.

SHIMMY_IMAGES_INDEX_FILTER='
if type != "object" then
  ["malformed-document", "-", "failed"]
elif (.mediaType != "application/vnd.oci.image.index.v1+json" and
      .mediaType != "application/vnd.docker.distribution.manifest.list.v2+json") then
  ["unsupported-media-type", "unsupported", "failed"]
elif (.manifests | type) != "array" or (.manifests | length) == 0 then
  ["missing-descriptors", .mediaType, "failed"]
elif (all(.manifests[]; type == "object")) | not then
  ["malformed-descriptors", .mediaType, "failed"]
else
  ([.manifests[] |
    select(.platform.os == "linux" and .platform.architecture == "amd64")] | length) as $amd64 |
  ([.manifests[] |
    select(.platform.os == "linux" and .platform.architecture == "arm64" and
      ((.platform.variant // "") == "" or .platform.variant == "v8"))] | length) as $arm64 |
  if $amd64 > 0 and $arm64 > 0 then
    ["verified", .mediaType, "verified"]
  else
    ["missing-required-platform", .mediaType, "failed"]
  end
end | @tsv
'

shimmy_images_cache_find() {
  cache_mode=$1
  cache_ref=$2

  SHIMMY_IMAGES_CACHE_STATUS=
  SHIMMY_IMAGES_CACHE_FILE=
  [ -f "$SHIMMY_IMAGES_CACHE_INDEX" ] || return 1
  while IFS='|' read -r entry_mode entry_ref entry_status entry_file; do
    if [ "$entry_mode" = "$cache_mode" ] && [ "$entry_ref" = "$cache_ref" ]; then
      SHIMMY_IMAGES_CACHE_STATUS=$entry_status
      SHIMMY_IMAGES_CACHE_FILE=$entry_file
      return 0
    fi
  done < "$SHIMMY_IMAGES_CACHE_INDEX"
  return 1
}

shimmy_images_cache_inspect() {
  cache_mode=$1
  cache_ref=$2

  if shimmy_images_cache_find "$cache_mode" "$cache_ref"; then
    return 0
  fi

  SHIMMY_IMAGES_CACHE_COUNT=$((SHIMMY_IMAGES_CACHE_COUNT + 1))
  cache_file=$SHIMMY_IMAGES_CACHE_DIR/inspect-$SHIMMY_IMAGES_CACHE_COUNT
  case "$cache_mode" in
    raw)
      if "$SHIMMY_IMAGES_SKOPEO_RUNTIME" inspect --raw "docker://$cache_ref" < /dev/null > "$cache_file" 2>/dev/null; then
        cache_status=ok
      else
        cache_status=unreachable
        : > "$cache_file"
      fi
      ;;
    digest)
      if "$SHIMMY_IMAGES_SKOPEO_RUNTIME" inspect --format '{{.Digest}}' "docker://$cache_ref" < /dev/null > "$cache_file" 2>/dev/null; then
        cache_status=ok
      else
        cache_status=unreachable
        : > "$cache_file"
      fi
      ;;
    *)
      printf 'ERROR: unsupported image inspection cache mode: %s\n' "$cache_mode" >&2
      return 1
      ;;
  esac
  printf '%s|%s|%s|%s\n' "$cache_mode" "$cache_ref" "$cache_status" "$cache_file" >> "$SHIMMY_IMAGES_CACHE_INDEX"
  SHIMMY_IMAGES_CACHE_STATUS=$cache_status
  SHIMMY_IMAGES_CACHE_FILE=$cache_file
}

shimmy_images_catalog_selection_all() {
  for tool_file in "$SHIMMY_CATALOG_TOOLS_DIR"/*/tool.conf; do
    [ -f "$tool_file" ] || continue
    tool_name=$(basename -- "$(dirname -- "$tool_file")")
    for version_dir in "$SHIMMY_CATALOG_TOOLS_DIR/$tool_name"/versions/*; do
      [ -d "$version_dir" ] || continue
      printf '%s|%s\n' "$tool_name" "$(basename -- "$version_dir")"
    done
  done
}

shimmy_images_config_records_print() {
  tool_name=$1
  version_label=$2
  shimmy_name_component_validate "$tool_name" || return 1
  shimmy_version_token_validate "$version_label" || return 1
  config_file=$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/versions/$version_label/image.conf
  version_identity=$tool_name@$version_label

  shimmy_image_config_validate "$config_file" || return 1
  image_source=$(shimmy_image_config_scalar_read "$config_file" image_source)
  case "$image_source" in
    external)
      printf '%s|%s|%s|runtime|%s|%s|%s\n' \
        "$tool_name" "$version_label" "$version_identity" \
        "$(shimmy_image_config_scalar_read "$config_file" image_upstream_ref)" \
        "$(shimmy_image_config_scalar_read "$config_file" image_default_ref)" \
        "$(shimmy_image_config_scalar_read "$config_file" image_registry_access)"
      ;;
    local-build)
      image_base_count=$(shimmy_image_config_scalar_read "$config_file" image_base_count)
      image_base_index=1
      while [ "$image_base_index" -le "$image_base_count" ]; do
        default_ref=$(shimmy_image_config_scalar_read "$config_file" "image_base_${image_base_index}_default_ref")
        if [ "$default_ref" != scratch ]; then
          printf '%s|%s|%s|base-%s|%s|%s|%s\n' \
            "$tool_name" "$version_label" "$version_identity" "$image_base_index" \
            "$(shimmy_image_config_scalar_read "$config_file" "image_base_${image_base_index}_upstream_ref")" \
            "$default_ref" \
            "$(shimmy_image_config_scalar_read "$config_file" "image_base_${image_base_index}_registry_access")"
        fi
        image_base_index=$((image_base_index + 1))
      done
      ;;
  esac
}

shimmy_images_digest_read() {
  image_ref=$1
  printf 'sha256:%s\n' "${image_ref##*@sha256:}"
}

shimmy_images_digest_validate() {
  image_digest=$1

  case "$image_digest" in sha256:*) ;; *) return 1 ;; esac
  image_digest_value=${image_digest#sha256:}
  [ "${#image_digest_value}" -eq 64 ] || return 1
  case "$image_digest_value" in *[!0-9a-f]*) return 1 ;; esac
}

shimmy_images_index_parse() {
  "$SHIMMY_IMAGES_JQ_RUNTIME" -er "$SHIMMY_IMAGES_INDEX_FILTER"
}

shimmy_images_request_selection() {
  requested_shims=$1
  selected_versions=

  for requested_shim in $requested_shims; do
    case "$requested_shim" in
      *@*)
        tool_name=${requested_shim%%@*}
        version_label=${requested_shim#*@}
        [ -f "$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/tool.conf" ] || {
          printf 'ERROR: unsupported shim tool: %s\n' "$tool_name" >&2
          return 1
        }
        [ -d "$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/versions/$version_label" ] || {
          printf 'ERROR: unsupported %s version: %s\n' "$tool_name" "$version_label" >&2
          return 1
        }
        ;;
      *)
        tool_name=$requested_shim
        if [ -f "$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/tool.conf" ]; then
          version_label=$(shimmy__catalog_config_value_read \
            "$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/tool.conf" tool_default_version)
        else
          printf 'ERROR: unsupported shim tool: %s\n' "$requested_shim" >&2
          return 1
        fi
        ;;
    esac
    version_pair=$tool_name\|$version_label
    if ! shimmy_contains_line_list "$selected_versions" "$version_pair"; then
      selected_versions=$(shimmy_append_line_list "$selected_versions" "$version_pair")
    fi
  done
  printf '%s\n' "$selected_versions"
}
