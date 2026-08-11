#!/bin/sh
# Verify configured remote image indexes without pulling their layers.
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
COMMON_HELPER_FILE=$ROOT_DIR/lib/common/common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/lib/catalog/catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/lib/profile/profile.sh
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh
IMAGES_HELPER_FILE=$ROOT_DIR/lib/images/images.sh
OUTPUT_FORMAT=human
PUBLIC_ONLY=0
REQUIRE_CURRENT_UPSTREAM=0
SELECT_ALL=0
REQUESTED_SHIMS=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

. "$COMMON_HELPER_FILE"
. "$CATALOG_HELPER_FILE"
. "$IMAGE_HELPER_FILE"
. "$PROFILE_HELPER_FILE"
. "$IMAGES_HELPER_FILE"

usage() {
  cat <<'EOF'
Verify configured remote image indexes without pulling image layers.

Usage:
  shimmy images verify [--all | --shim <tool[@version]> ...]
                       [--public-only] [--require-current-upstream]
                       [--format human|manifest]
  ./commands/images.sh verify --all [the same verification options]

Installed use defaults to concrete versions recorded in the invoking profile.
Source-checkout use requires --all or at least one --shim selection.
EOF
}

cleanup() {
  [ -n "${SHIMMY_IMAGES_CACHE_DIR:-}" ] || return 0
  [ -d "$SHIMMY_IMAGES_CACHE_DIR" ] || return 0
  case "$SHIMMY_IMAGES_CACHE_DIR" in
    "$SHIMMY_IMAGES_CACHE_PARENT"/shimmy-images.*) ;;
    *) return 1 ;;
  esac
  rm -rf "$SHIMMY_IMAGES_CACHE_DIR"
}

output_result() {
  result_tool=$1
  result_version=$2
  result_role=$3
  result_digest=$4
  result_media_type=$5
  result_platforms=$6
  result_access=$7
  result_drift=$8
  result_state=$9
  shift 9
  result_error=$1

  if [ "$OUTPUT_FORMAT" = manifest ]; then
    printf 'image_verify=%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$result_tool" "$result_version" "$result_role" "$result_digest" \
      "$result_media_type" "$result_platforms" "$result_access" \
      "$result_drift" "$result_state" "$result_error"
  else
    printf '%s %s@%s %s digest=%s media=%s platforms=%s access=%s upstream=%s' \
      "$(printf '%s' "$result_state" | tr '[:lower:]' '[:upper:]')" \
      "$result_tool" "$result_version" "$result_role" "$result_digest" \
      "$result_media_type" "$result_platforms" "$result_access" "$result_drift"
    [ "$result_error" = none ] || printf ' error=%s' "$result_error"
    printf '\n'
  fi
}

parse_request() {
  [ "${1:-}" = verify ] || {
    case "${1:-}" in -h|--help|'') usage; exit 0 ;; esac
    fail "unknown images command: ${1:-}"
  }
  shift

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --all) SELECT_ALL=1; shift ;;
      --shim)
        [ "$#" -ge 2 ] || fail "missing value for --shim"
        REQUESTED_SHIMS=$(shimmy_append_line_list "$REQUESTED_SHIMS" "$2")
        shift 2
        ;;
      --public-only) PUBLIC_ONLY=1; shift ;;
      --require-current-upstream) REQUIRE_CURRENT_UPSTREAM=1; shift ;;
      --format)
        [ "$#" -ge 2 ] || fail "missing value for --format"
        OUTPUT_FORMAT=$2
        shift 2
        ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown argument: $1" ;;
    esac
  done

  case "$OUTPUT_FORMAT" in human|manifest) ;; *) fail "unsupported images format: $OUTPUT_FORMAT" ;; esac
  [ "$SELECT_ALL" -eq 0 ] || [ -z "$REQUESTED_SHIMS" ] || fail "--all cannot be combined with --shim"
}

selection_resolve() {
  if shimmy_profile_context_resolve "$ROOT_DIR" 2>/dev/null; then
    shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_PROFILE_NAME" || exit 1
    if [ "$SELECT_ALL" -eq 1 ]; then
      shimmy_images_catalog_selection_all
    elif [ -n "$REQUESTED_SHIMS" ]; then
      shimmy_images_request_selection "$REQUESTED_SHIMS"
    else
      shimmy_images_manifest_selection "$SHIMMY_PROFILE_MANIFEST_PATH"
    fi
    return
  fi

  [ "$SELECT_ALL" -eq 1 ] || [ -n "$REQUESTED_SHIMS" ] || fail "source-checkout image verification requires --all or at least one --shim"
  if [ "$SELECT_ALL" -eq 1 ]; then
    shimmy_images_catalog_selection_all
  else
    shimmy_images_request_selection "$REQUESTED_SHIMS"
  fi
}

verify_record() {
  record_tool=$1
  record_version=$2
  record_role=$3
  upstream_ref=$4
  default_ref=$5
  registry_access=$6
  configured_digest=$(shimmy_images_digest_read "$default_ref")
  media_type=not-inspected
  platform_result=not-inspected
  access_result=$registry_access
  drift_result=not-checked
  result_state=pass
  error_category=none

  if [ "$registry_access" = authenticated ]; then
    if [ "$PUBLIC_ONLY" -eq 1 ]; then
      output_result "$record_tool" "$record_version" "$record_role" "$configured_digest" \
        "$media_type" "$platform_result" skipped "$drift_result" skip none
      return 0
    fi
    if [ -z "${SHIMMY_SKOPEO_AUTH_SECRET:-}" ]; then
      output_result "$record_tool" "$record_version" "$record_role" "$configured_digest" \
        "$media_type" "$platform_result" missing "$drift_result" fail authentication-required
      return 1
    fi
  fi

  shimmy_images_cache_inspect raw "$default_ref"
  if [ "$SHIMMY_IMAGES_CACHE_STATUS" != ok ]; then
    output_result "$record_tool" "$record_version" "$record_role" "$configured_digest" \
      "$media_type" "$platform_result" "$access_result" "$drift_result" fail pinned-reference-unreachable
    return 1
  fi

  if parsed_index=$(shimmy_images_index_parse < "$SHIMMY_IMAGES_CACHE_FILE" 2>/dev/null); then
    parse_category=$(printf '%s\n' "$parsed_index" | awk -F '\t' '{print $1}')
    media_type=$(printf '%s\n' "$parsed_index" | awk -F '\t' '{print $2}')
    platform_result=$(printf '%s\n' "$parsed_index" | awk -F '\t' '{print $3}')
  else
    parse_category=malformed-json
    media_type=unknown
    platform_result=failed
  fi
  if [ "$parse_category" != verified ]; then
    output_result "$record_tool" "$record_version" "$record_role" "$configured_digest" \
      "$media_type" "$platform_result" "$access_result" "$drift_result" fail "$parse_category"
    return 1
  fi

  case "$upstream_ref" in
    *@sha256:*) drift_result=not-applicable ;;
    *)
      shimmy_images_cache_inspect digest "$upstream_ref"
      if [ "$SHIMMY_IMAGES_CACHE_STATUS" != ok ]; then
        output_result "$record_tool" "$record_version" "$record_role" "$configured_digest" \
          "$media_type" "$platform_result" "$access_result" unreachable fail upstream-reference-unreachable
        return 1
      fi
      upstream_digest=$(sed -n '1p' "$SHIMMY_IMAGES_CACHE_FILE")
      if ! shimmy_images_digest_validate "$upstream_digest"; then
        output_result "$record_tool" "$record_version" "$record_role" "$configured_digest" \
          "$media_type" "$platform_result" "$access_result" invalid fail upstream-digest-invalid
        return 1
      elif [ "$upstream_digest" = "$configured_digest" ]; then
        drift_result=current
      else
        drift_result=moved
        if [ "$REQUIRE_CURRENT_UPSTREAM" -eq 1 ]; then
          result_state=fail
          error_category=upstream-drift
        else
          result_state=warning
        fi
      fi
      ;;
  esac

  output_result "$record_tool" "$record_version" "$record_role" "$configured_digest" \
    "$media_type" "$platform_result" "$access_result" "$drift_result" "$result_state" "$error_category"
  [ "$result_state" != fail ]
}

main() {
  parse_request "$@"

  selected_versions=$(selection_resolve) || exit 1
  [ -n "$selected_versions" ] || fail "image verification selection is empty"

  SHIMMY_IMAGES_SKOPEO_RUNTIME=$(shimmy_images_runtime_resolve skopeo) || fail "catalog-default Skopeo runtime is unavailable"
  SHIMMY_IMAGES_JQ_RUNTIME=$(shimmy_images_runtime_resolve jq) || fail "catalog-default jq runtime is unavailable"

  tmp_parent=${TMPDIR:-/tmp}
  case "$tmp_parent" in ''|/) tmp_parent=/tmp ;; */) tmp_parent=${tmp_parent%/} ;; esac
  SHIMMY_IMAGES_CACHE_PARENT=$(cd -- "$tmp_parent" && pwd -P) || fail "invalid image verification temporary directory"
  SHIMMY_IMAGES_CACHE_DIR=$(mktemp -d "$SHIMMY_IMAGES_CACHE_PARENT/shimmy-images.XXXXXX") || fail "unable to create image verification workspace"
  SHIMMY_IMAGES_CACHE_DIR=$(cd -- "$SHIMMY_IMAGES_CACHE_DIR" && pwd -P)
  SHIMMY_IMAGES_CACHE_INDEX=$SHIMMY_IMAGES_CACHE_DIR/cache
  SHIMMY_IMAGES_CACHE_COUNT=0
  records_file=$SHIMMY_IMAGES_CACHE_DIR/records
  : > "$SHIMMY_IMAGES_CACHE_INDEX"
  : > "$records_file"
  trap cleanup EXIT HUP INT TERM

  for version_name in $selected_versions; do
    tool_name=$(shimmy_tool_version_tool "$version_name") || fail "unknown selected concrete version: $version_name"
    shimmy_images_config_records_print "$tool_name" "$version_name" >> "$records_file" || exit 1
  done

  verification_failed=0
  while IFS='|' read -r record_tool record_version version_name record_role upstream_ref default_ref registry_access; do
    [ -n "$record_tool" ] || continue
    verify_record "$record_tool" "$record_version" "$record_role" "$upstream_ref" "$default_ref" "$registry_access" || verification_failed=1
  done < "$records_file"
  [ "$verification_failed" -eq 0 ]
}

main "$@"
