#!/bin/sh
# Immutable default-catalog state formats.

SHIMMY_TARGET_CATALOG_REGISTRY_SCHEMA=1

shimmy_target_catalog_generation_validate() {
  shimmy_target_catalog_generation_value=${1:-}
  case "$shimmy_target_catalog_generation_value" in sha256-*) ;;
    *) return 1 ;;
  esac
  shimmy_target_catalog_generation_hex=${shimmy_target_catalog_generation_value#sha256-}
  [ "${#shimmy_target_catalog_generation_hex}" -eq 64 ] || return 1
  case "$shimmy_target_catalog_generation_hex" in *[!0123456789abcdef]*) return 1 ;; esac
}

shimmy_target_catalog_generation_render() {
  shimmy_target_catalog_generation_fingerprint=$1
  shimmy_sha256_fingerprint_validate "$shimmy_target_catalog_generation_fingerprint" || return 1
  printf 'sha256-%s\n' "${shimmy_target_catalog_generation_fingerprint#sha256:}"
}

shimmy_target_catalog_content_fingerprint_render() {
  shimmy_catalog_fingerprint_render "$1"
}

shimmy_target_catalog_pin_validate() {
  shimmy_target_catalog_pin_value=$1
  case "$shimmy_target_catalog_pin_value" in *'|'*'|'*'|'*) ;; *) return 1 ;; esac
  shimmy_target_catalog_pin_name=${shimmy_target_catalog_pin_value%%|*}
  shimmy_target_catalog_pin_remainder=${shimmy_target_catalog_pin_value#*|}
  shimmy_target_catalog_pin_generation=${shimmy_target_catalog_pin_remainder%%|*}
  shimmy_target_catalog_pin_remainder=${shimmy_target_catalog_pin_remainder#*|}
  shimmy_target_catalog_pin_commit=${shimmy_target_catalog_pin_remainder%%|*}
  shimmy_target_catalog_pin_fingerprint=${shimmy_target_catalog_pin_remainder#*|}
  case "$shimmy_target_catalog_pin_fingerprint" in *'|'*) return 1 ;; esac

  [ "$shimmy_target_catalog_pin_name" = default ] || return 1
  shimmy_target_catalog_generation_validate "$shimmy_target_catalog_pin_generation" || return 1
  shimmy_git_commit_validate "$shimmy_target_catalog_pin_commit" || return 1
  shimmy_sha256_fingerprint_validate "$shimmy_target_catalog_pin_fingerprint" || return 1
  [ "$(shimmy_target_catalog_generation_render "$shimmy_target_catalog_pin_fingerprint")" = "$shimmy_target_catalog_pin_generation" ]
}

shimmy_target_catalog_registry_render() {
  shimmy_target_catalog_registry_current=$1
  shimmy_target_catalog_registry_previous=${2-}
  shimmy_target_catalog_registry_commit=$3
  shimmy_target_catalog_registry_fingerprint=$4

  shimmy_target_catalog_generation_validate "$shimmy_target_catalog_registry_current" || return 1
  if [ -n "$shimmy_target_catalog_registry_previous" ]; then
    shimmy_target_catalog_generation_validate "$shimmy_target_catalog_registry_previous" || return 1
    [ "$shimmy_target_catalog_registry_previous" != "$shimmy_target_catalog_registry_current" ] || return 1
  fi
  shimmy_git_commit_validate "$shimmy_target_catalog_registry_commit" || return 1
  shimmy_sha256_fingerprint_validate "$shimmy_target_catalog_registry_fingerprint" || return 1
  [ "$(shimmy_target_catalog_generation_render "$shimmy_target_catalog_registry_fingerprint")" = "$shimmy_target_catalog_registry_current" ] || return 1

  printf 'catalog_registry_schema=1\n'
  printf 'catalog_name=default\n'
  printf 'catalog_generation_current=%s\n' "$shimmy_target_catalog_registry_current"
  printf 'catalog_generation_previous=%s\n' "$shimmy_target_catalog_registry_previous"
  printf 'catalog_source_commit=%s\n' "$shimmy_target_catalog_registry_commit"
  printf 'catalog_content_fingerprint=%s\n' "$shimmy_target_catalog_registry_fingerprint"
}

shimmy_target_catalog_registry_read() {
  shimmy_target_catalog_registry_file=$1
  shimmy_text_file_validate "$shimmy_target_catalog_registry_file" || return 1
  shimmy_target_catalog_registry_expected=$(sed -n '1,6p' "$shimmy_target_catalog_registry_file")
  [ "$(wc -l < "$shimmy_target_catalog_registry_file" | tr -d ' ')" -eq 6 ] || return 1

  SHIMMY_TARGET_CATALOG_GENERATION_CURRENT=$(printf '%s\n' "$shimmy_target_catalog_registry_expected" | sed -n '3s/^catalog_generation_current=//p')
  SHIMMY_TARGET_CATALOG_GENERATION_PREVIOUS=$(printf '%s\n' "$shimmy_target_catalog_registry_expected" | sed -n '4s/^catalog_generation_previous=//p')
  SHIMMY_TARGET_CATALOG_SOURCE_COMMIT=$(printf '%s\n' "$shimmy_target_catalog_registry_expected" | sed -n '5s/^catalog_source_commit=//p')
  SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT=$(printf '%s\n' "$shimmy_target_catalog_registry_expected" | sed -n '6s/^catalog_content_fingerprint=//p')

  [ "$(printf '%s\n' "$shimmy_target_catalog_registry_expected" | sed -n '1p')" = catalog_registry_schema=1 ] || return 1
  [ "$(printf '%s\n' "$shimmy_target_catalog_registry_expected" | sed -n '2p')" = catalog_name=default ] || return 1
  [ "$(shimmy_target_catalog_registry_render "$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT" "$SHIMMY_TARGET_CATALOG_GENERATION_PREVIOUS" "$SHIMMY_TARGET_CATALOG_SOURCE_COMMIT" "$SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT")" = "$shimmy_target_catalog_registry_expected" ]
}

shimmy_target_catalog_generation_metadata_render() {
  shimmy_target_catalog_generation_metadata_commit=$1
  shimmy_target_catalog_generation_metadata_fingerprint=$2
  shimmy_git_commit_validate "$shimmy_target_catalog_generation_metadata_commit" || return 1
  shimmy_sha256_fingerprint_validate "$shimmy_target_catalog_generation_metadata_fingerprint" || return 1
  printf 'catalog_source_commit=%s\n' "$shimmy_target_catalog_generation_metadata_commit"
  printf 'catalog_content_fingerprint=%s\n' "$shimmy_target_catalog_generation_metadata_fingerprint"
}

shimmy_target_catalog_generation_metadata_read() {
  shimmy_target_catalog_generation_metadata_file=$1
  shimmy_text_file_validate "$shimmy_target_catalog_generation_metadata_file" || return 1
  [ "$(wc -l < "$shimmy_target_catalog_generation_metadata_file" | tr -d ' ')" -eq 2 ] || return 1
  SHIMMY_TARGET_CATALOG_GENERATION_SOURCE_COMMIT=$(sed -n '1s/^catalog_source_commit=//p' "$shimmy_target_catalog_generation_metadata_file")
  SHIMMY_TARGET_CATALOG_GENERATION_CONTENT_FINGERPRINT=$(sed -n '2s/^catalog_content_fingerprint=//p' "$shimmy_target_catalog_generation_metadata_file")
  [ "$(shimmy_target_catalog_generation_metadata_render "$SHIMMY_TARGET_CATALOG_GENERATION_SOURCE_COMMIT" "$SHIMMY_TARGET_CATALOG_GENERATION_CONTENT_FINGERPRINT")" = "$(cat "$shimmy_target_catalog_generation_metadata_file")" ]
}
