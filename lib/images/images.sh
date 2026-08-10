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
  for kind_name in $(shimmy_kind_list); do
    shimmy_kind_version_list "$kind_name"
  done
}

shimmy_images_config_records_print() {
  kind_name=$1
  version_name=$2
  version_label=$(shimmy_version_label "$version_name") || return 1
  config_file=$(shimmy_version_image_config_file "$version_name") || return 1

  shimmy_image_config_validate "$config_file" || return 1
  image_source=$(shimmy_image_config_scalar_read "$config_file" image_source)
  case "$image_source" in
    external)
      printf '%s|%s|%s|runtime|%s|%s|%s\n' \
        "$kind_name" "$version_label" "$version_name" \
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
            "$kind_name" "$version_label" "$version_name" "$image_base_index" \
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

shimmy_images_manifest_selection() {
  manifest_file=$1
  selected_versions=

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    version_name=${kind_version_entry##*|}
    if ! shimmy_contains_line_list "$selected_versions" "$version_name"; then
      selected_versions=$(shimmy_append_line_list "$selected_versions" "$version_name")
    fi
  done <<EOF
$(shimmy_read_manifest_kind_versions "$manifest_file")
EOF
  printf '%s\n' "$selected_versions"
}

shimmy_images_request_selection() {
  requested_shims=$1
  selected_versions=

  for requested_shim in $requested_shims; do
    case "$requested_shim" in
      *@*)
        kind_name=${requested_shim%%@*}
        version_label=${requested_shim#*@}
        shimmy_is_kind "$kind_name" || {
          printf 'ERROR: unsupported shim kind: %s\n' "$kind_name" >&2
          return 1
        }
        version_name=$(shimmy_kind_version_for_label "$kind_name" "$version_label" || true)
        [ -n "$version_name" ] || {
          printf 'ERROR: unsupported %s version: %s\n' "$kind_name" "$version_label" >&2
          return 1
        }
        ;;
      *)
        if shimmy_is_kind "$requested_shim"; then
          version_name=$(shimmy_kind_default_version "$requested_shim")
        elif shimmy_is_version "$requested_shim"; then
          version_name=$requested_shim
        else
          printf 'ERROR: unsupported shim kind: %s\n' "$requested_shim" >&2
          return 1
        fi
        ;;
    esac
    if ! shimmy_contains_line_list "$selected_versions" "$version_name"; then
      selected_versions=$(shimmy_append_line_list "$selected_versions" "$version_name")
    fi
  done
  printf '%s\n' "$selected_versions"
}

shimmy_images_runtime_resolve() {
  runtime_kind=$1
  runtime_version=$(shimmy_kind_default_version "$runtime_kind") || return 1
  runtime_dir=$(shimmy_version_dir "$runtime_version") || return 1
  runtime_file=$runtime_dir/run.sh
  [ -x "$runtime_file" ] || return 1
  printf '%s\n' "$runtime_file"
}
