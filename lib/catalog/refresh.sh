#!/bin/sh
# Maintainer-only source catalog image digest refresh transaction.

SHIMMY_CATALOG_REFRESH_ERROR=
SHIMMY_CATALOG_REFRESH_WORKSPACE=
SHIMMY_CATALOG_REFRESH_LOCK_ACTIVE=0
SHIMMY_CATALOG_REFRESH_LOCK_PATH=
SHIMMY_CATALOG_REFRESH_LOCK_OWNER=
SHIMMY_CATALOG_REFRESH_LOCK_TOKEN=

shimmy_catalog_refresh_error_set() {
  SHIMMY_CATALOG_REFRESH_ERROR=$*
  return 1
}

shimmy_catalog_refresh_workspace_cleanup() {
  [ -n "$SHIMMY_CATALOG_REFRESH_WORKSPACE" ] || return 0
  [ -d "$SHIMMY_CATALOG_REFRESH_WORKSPACE" ] || return 0
  case "$SHIMMY_CATALOG_REFRESH_WORKSPACE" in
    "$SHIMMY_CATALOG_REFRESH_WORKSPACE_PARENT"/shimmy-catalog-refresh.*)
      rm -rf "$SHIMMY_CATALOG_REFRESH_WORKSPACE"
      ;;
    *) return 1 ;;
  esac
  SHIMMY_CATALOG_REFRESH_WORKSPACE=
}

shimmy_catalog_refresh_lock_owned() {
  [ "$SHIMMY_CATALOG_REFRESH_LOCK_ACTIVE" -eq 1 ] &&
    [ -d "$SHIMMY_CATALOG_REFRESH_LOCK_PATH" ] &&
    [ ! -L "$SHIMMY_CATALOG_REFRESH_LOCK_PATH" ] &&
    [ -f "$SHIMMY_CATALOG_REFRESH_LOCK_OWNER" ] &&
    [ ! -L "$SHIMMY_CATALOG_REFRESH_LOCK_OWNER" ] &&
    [ "$(cat "$SHIMMY_CATALOG_REFRESH_LOCK_OWNER")" = "shimmy_catalog_refresh_lock_schema=1
shimmy_catalog_refresh_lock_pid=$$
shimmy_catalog_refresh_lock_token=$SHIMMY_CATALOG_REFRESH_LOCK_TOKEN" ]
}

shimmy_catalog_refresh_lock_release() {
  [ "$SHIMMY_CATALOG_REFRESH_LOCK_ACTIVE" -eq 1 ] || return 0
  shimmy_catalog_refresh_lock_owned || return 1
  shimmy_catalog_refresh_lock_candidate=$SHIMMY_CATALOG_REFRESH_LOCK_PATH/candidate
  shimmy_catalog_refresh_lock_rollback=$SHIMMY_CATALOG_REFRESH_LOCK_PATH/rollback
  [ ! -e "$shimmy_catalog_refresh_lock_candidate" ] && [ ! -L "$shimmy_catalog_refresh_lock_candidate" ] ||
    rm -f "$shimmy_catalog_refresh_lock_candidate" || return 1
  if [ -e "$shimmy_catalog_refresh_lock_rollback" ] || [ -L "$shimmy_catalog_refresh_lock_rollback" ]; then
    [ -f "$shimmy_catalog_refresh_lock_rollback" ] && [ ! -L "$shimmy_catalog_refresh_lock_rollback" ] &&
      [ "$(shimmy_sha256_fingerprint_file_render "$shimmy_catalog_refresh_lock_rollback")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_FINGERPRINT" ] &&
      [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_FINGERPRINT" ] || return 1
    rm -f "$shimmy_catalog_refresh_lock_rollback" || return 1
  fi
  rm -f "$SHIMMY_CATALOG_REFRESH_LOCK_OWNER" || return 1
  rmdir "$SHIMMY_CATALOG_REFRESH_LOCK_PATH" || return 1
  SHIMMY_CATALOG_REFRESH_LOCK_ACTIVE=0
  SHIMMY_CATALOG_REFRESH_LOCK_PATH=
  SHIMMY_CATALOG_REFRESH_LOCK_OWNER=
  SHIMMY_CATALOG_REFRESH_LOCK_TOKEN=
}

shimmy_catalog_refresh_cleanup() {
  shimmy_catalog_refresh_workspace_cleanup 2>/dev/null || true
  shimmy_catalog_refresh_lock_release 2>/dev/null || true
}

shimmy_catalog_refresh_checkout_validate() {
  shimmy_catalog_refresh_checkout=$1
  command -v git >/dev/null 2>&1 || {
    shimmy_catalog_refresh_error_set 'Git is required for catalog refresh'
    return 1
  }
  shimmy_catalog_refresh_resolved=$(shimmy_resolve_path_absolute "$shimmy_catalog_refresh_checkout") || return 1
  [ "$shimmy_catalog_refresh_resolved" = "$shimmy_catalog_refresh_checkout" ] || {
    shimmy_catalog_refresh_error_set "catalog refresh requires a normalized repository root: $shimmy_catalog_refresh_checkout"
    return 1
  }
  shimmy_catalog_refresh_git_root=$(git -C "$shimmy_catalog_refresh_checkout" rev-parse --show-toplevel 2>/dev/null || true)
  [ "$shimmy_catalog_refresh_git_root" = "$shimmy_catalog_refresh_checkout" ] || {
    shimmy_catalog_refresh_error_set "catalog refresh source must be a Git worktree root: $shimmy_catalog_refresh_checkout"
    return 1
  }
  [ "$(git -C "$shimmy_catalog_refresh_checkout" symbolic-ref --quiet HEAD 2>/dev/null || true)" = refs/heads/main ] || {
    shimmy_catalog_refresh_error_set 'catalog refresh requires attached local branch main'
    return 1
  }
  shimmy_catalog_refresh_head=$(git -C "$shimmy_catalog_refresh_checkout" rev-parse --verify HEAD 2>/dev/null || true)
  shimmy_git_commit_validate "$shimmy_catalog_refresh_head" || {
    shimmy_catalog_refresh_error_set 'catalog refresh source has no valid HEAD'
    return 1
  }
  [ "$(git -C "$shimmy_catalog_refresh_checkout" rev-parse --verify refs/heads/main 2>/dev/null || true)" = "$shimmy_catalog_refresh_head" ] || {
    shimmy_catalog_refresh_error_set 'catalog refresh HEAD does not equal refs/heads/main'
    return 1
  }
  shimmy_catalog_refresh_git_dir=$(git -C "$shimmy_catalog_refresh_checkout" rev-parse --absolute-git-dir 2>/dev/null || true)
  shimmy_path_absolute_normalized_validate "$shimmy_catalog_refresh_git_dir" &&
    [ -d "$shimmy_catalog_refresh_git_dir" ] && [ ! -L "$shimmy_catalog_refresh_git_dir" ] &&
    shimmy_path_parent_chain_validate "$shimmy_catalog_refresh_git_dir" || {
      shimmy_catalog_refresh_error_set 'catalog refresh could not validate its Git-owned lock root'
      return 1
    }
  SHIMMY_CATALOG_REFRESH_CHECKOUT=$shimmy_catalog_refresh_checkout
  SHIMMY_CATALOG_REFRESH_HEAD=$shimmy_catalog_refresh_head
  SHIMMY_CATALOG_REFRESH_GIT_DIR=$shimmy_catalog_refresh_git_dir
}

shimmy_catalog_refresh_source_revalidate() {
  [ "$(git -C "$SHIMMY_CATALOG_REFRESH_CHECKOUT" rev-parse --show-toplevel 2>/dev/null || true)" = "$SHIMMY_CATALOG_REFRESH_CHECKOUT" ] &&
    [ "$(git -C "$SHIMMY_CATALOG_REFRESH_CHECKOUT" symbolic-ref --quiet HEAD 2>/dev/null || true)" = refs/heads/main ] &&
    [ "$(git -C "$SHIMMY_CATALOG_REFRESH_CHECKOUT" rev-parse --verify HEAD 2>/dev/null || true)" = "$SHIMMY_CATALOG_REFRESH_HEAD" ] &&
    [ "$(git -C "$SHIMMY_CATALOG_REFRESH_CHECKOUT" rev-parse --verify refs/heads/main 2>/dev/null || true)" = "$SHIMMY_CATALOG_REFRESH_HEAD" ] || {
      shimmy_catalog_refresh_error_set 'catalog refresh source authority moved during discovery'
      return 1
    }
  [ -f "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" ] && [ ! -L "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" ] &&
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_FINGERPRINT" ] &&
    [ "$(shimmy_file_mode_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE" ] || {
      shimmy_catalog_refresh_error_set 'selected image configuration changed during refresh'
      return 1
    }
}

shimmy_catalog_refresh_lock_acquire() {
  SHIMMY_CATALOG_REFRESH_LOCK_PATH=$SHIMMY_CATALOG_REFRESH_GIT_DIR/shimmy-catalog-refresh.lock
  SHIMMY_CATALOG_REFRESH_LOCK_OWNER=$SHIMMY_CATALOG_REFRESH_LOCK_PATH/owner
  SHIMMY_CATALOG_REFRESH_LOCK_TOKEN=$$-$(date +%s 2>/dev/null || printf 0)
  if ! mkdir "$SHIMMY_CATALOG_REFRESH_LOCK_PATH" 2>/dev/null; then
    shimmy_catalog_refresh_error_set "catalog refresh lock exists; verify no refresh is running, then remove it manually: $SHIMMY_CATALOG_REFRESH_LOCK_PATH"
    return 1
  fi
  SHIMMY_CATALOG_REFRESH_LOCK_ACTIVE=1
  if ! printf 'shimmy_catalog_refresh_lock_schema=1\nshimmy_catalog_refresh_lock_pid=%s\nshimmy_catalog_refresh_lock_token=%s\n' \
      "$$" "$SHIMMY_CATALOG_REFRESH_LOCK_TOKEN" > "$SHIMMY_CATALOG_REFRESH_LOCK_OWNER" ||
    ! chmod 0600 "$SHIMMY_CATALOG_REFRESH_LOCK_OWNER" ||
    ! shimmy_catalog_refresh_lock_owned; then
    shimmy_catalog_refresh_error_set 'unable to establish catalog refresh lock ownership'
    return 1
  fi
}

shimmy_catalog_refresh_workspace_prepare() {
  shimmy_catalog_refresh_tmp_parent=${TMPDIR:-/tmp}
  case "$shimmy_catalog_refresh_tmp_parent" in ''|/) shimmy_catalog_refresh_tmp_parent=/tmp ;; */) shimmy_catalog_refresh_tmp_parent=${shimmy_catalog_refresh_tmp_parent%/} ;; esac
  SHIMMY_CATALOG_REFRESH_WORKSPACE_PARENT=$(cd -- "$shimmy_catalog_refresh_tmp_parent" && pwd -P) || {
    shimmy_catalog_refresh_error_set 'invalid catalog refresh temporary directory'
    return 1
  }
  SHIMMY_CATALOG_REFRESH_WORKSPACE=$(mktemp -d "$SHIMMY_CATALOG_REFRESH_WORKSPACE_PARENT/shimmy-catalog-refresh.XXXXXX") || {
    shimmy_catalog_refresh_error_set 'unable to create catalog refresh workspace'
    return 1
  }
  SHIMMY_CATALOG_REFRESH_WORKSPACE=$(cd -- "$SHIMMY_CATALOG_REFRESH_WORKSPACE" && pwd -P)
}

shimmy_catalog_refresh_repository_read() {
  shimmy_catalog_refresh_repository_ref=$1
  case "$shimmy_catalog_refresh_repository_ref" in
    *@sha256:*) printf '%s\n' "${shimmy_catalog_refresh_repository_ref%@sha256:*}" ;;
    *) printf '%s\n' "${shimmy_catalog_refresh_repository_ref%:*}" ;;
  esac
}

shimmy_catalog_refresh_role_key_read() {
  case "$1" in
    runtime) printf '%s\n' image_default_ref ;;
    base-*) printf 'image_base_%s_default_ref\n' "${1#base-}" ;;
    *) return 1 ;;
  esac
}

shimmy_catalog_refresh_digest_cache_read() {
  shimmy_catalog_refresh_digest_mode=$1
  shimmy_catalog_refresh_digest_ref=$2
  shimmy_images_cache_inspect "$shimmy_catalog_refresh_digest_mode" "$shimmy_catalog_refresh_digest_ref"
  [ "$SHIMMY_IMAGES_CACHE_STATUS" = ok ] || return 1
  [ "$(wc -l < "$SHIMMY_IMAGES_CACHE_FILE" | tr -d ' ')" -eq 1 ] || return 1
  SHIMMY_CATALOG_REFRESH_RESOLVED_DIGEST=$(sed -n '1p' "$SHIMMY_IMAGES_CACHE_FILE")
  shimmy_images_digest_validate "$SHIMMY_CATALOG_REFRESH_RESOLVED_DIGEST"
}

shimmy_catalog_refresh_index_read() {
  shimmy_catalog_refresh_index_ref=$1
  SHIMMY_CATALOG_REFRESH_PARSE_CATEGORY=candidate-reference-unreachable
  SHIMMY_CATALOG_REFRESH_MEDIA=not-inspected
  shimmy_images_cache_inspect raw "$shimmy_catalog_refresh_index_ref"
  [ "$SHIMMY_IMAGES_CACHE_STATUS" = ok ] || return 1
  if shimmy_catalog_refresh_parsed=$(shimmy_images_index_parse < "$SHIMMY_IMAGES_CACHE_FILE" 2>/dev/null); then
    SHIMMY_CATALOG_REFRESH_PARSE_CATEGORY=$(printf '%s\n' "$shimmy_catalog_refresh_parsed" | awk -F '\t' '{print $1}')
    SHIMMY_CATALOG_REFRESH_MEDIA=$(printf '%s\n' "$shimmy_catalog_refresh_parsed" | awk -F '\t' '{print $2}')
  else
    SHIMMY_CATALOG_REFRESH_PARSE_CATEGORY=malformed-json
    SHIMMY_CATALOG_REFRESH_MEDIA=unknown
  fi
  [ "$SHIMMY_CATALOG_REFRESH_PARSE_CATEGORY" = verified ]
}

shimmy_catalog_refresh_candidate_records_create() {
  SHIMMY_CATALOG_REFRESH_CANDIDATES=$SHIMMY_CATALOG_REFRESH_WORKSPACE/candidates
  SHIMMY_CATALOG_REFRESH_SKIPPED=$SHIMMY_CATALOG_REFRESH_WORKSPACE/skipped
  : > "$SHIMMY_CATALOG_REFRESH_CANDIDATES"
  : > "$SHIMMY_CATALOG_REFRESH_SKIPPED"
  shimmy_catalog_refresh_record_failed=0
  shimmy_catalog_refresh_refreshable=0

  while IFS='|' read -r shimmy_catalog_refresh_record_tool shimmy_catalog_refresh_record_version \
    shimmy_catalog_refresh_record_identity shimmy_catalog_refresh_record_role \
    shimmy_catalog_refresh_record_upstream shimmy_catalog_refresh_record_default \
    shimmy_catalog_refresh_record_access; do
    [ -n "$shimmy_catalog_refresh_record_tool" ] || continue
    case "$shimmy_catalog_refresh_record_upstream" in
      *@sha256:*)
        printf '%s|%s\n' "$shimmy_catalog_refresh_record_role" "$shimmy_catalog_refresh_record_upstream" >> "$SHIMMY_CATALOG_REFRESH_SKIPPED"
        continue
        ;;
    esac
    shimmy_catalog_refresh_refreshable=$((shimmy_catalog_refresh_refreshable + 1))

    if [ "$shimmy_catalog_refresh_record_access" = authenticated ] &&
      [ -z "${SHIMMY_SKOPEO_AUTH_SECRET:-}" ]; then
      printf 'FAIL %s %s error=authentication-required\n' "$SHIMMY_CATALOG_REFRESH_SELECTOR" "$shimmy_catalog_refresh_record_role" >&2
      shimmy_catalog_refresh_record_failed=1
      continue
    fi
    shimmy_catalog_refresh_upstream_repository=$(shimmy_catalog_refresh_repository_read "$shimmy_catalog_refresh_record_upstream")
    shimmy_catalog_refresh_default_repository=$(shimmy_catalog_refresh_repository_read "$shimmy_catalog_refresh_record_default")
    if [ "$shimmy_catalog_refresh_upstream_repository" != "$shimmy_catalog_refresh_default_repository" ]; then
      printf 'FAIL %s %s error=repository-mismatch\n' "$SHIMMY_CATALOG_REFRESH_SELECTOR" "$shimmy_catalog_refresh_record_role" >&2
      shimmy_catalog_refresh_record_failed=1
      continue
    fi
    if ! shimmy_catalog_refresh_digest_cache_read digest "$shimmy_catalog_refresh_record_upstream"; then
      printf 'FAIL %s %s error=upstream-digest-invalid-or-unreachable\n' "$SHIMMY_CATALOG_REFRESH_SELECTOR" "$shimmy_catalog_refresh_record_role" >&2
      shimmy_catalog_refresh_record_failed=1
      continue
    fi
    shimmy_catalog_refresh_candidate_digest=$SHIMMY_CATALOG_REFRESH_RESOLVED_DIGEST
    shimmy_catalog_refresh_candidate_ref=$shimmy_catalog_refresh_upstream_repository@$shimmy_catalog_refresh_candidate_digest
    if ! shimmy_catalog_refresh_index_read "$shimmy_catalog_refresh_candidate_ref"; then
      printf 'FAIL %s %s error=%s\n' "$SHIMMY_CATALOG_REFRESH_SELECTOR" \
        "$shimmy_catalog_refresh_record_role" "$SHIMMY_CATALOG_REFRESH_PARSE_CATEGORY" >&2
      shimmy_catalog_refresh_record_failed=1
      continue
    fi
    shimmy_catalog_refresh_record_key=$(shimmy_catalog_refresh_role_key_read "$shimmy_catalog_refresh_record_role") || return 1
    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
      "$shimmy_catalog_refresh_record_role" "$shimmy_catalog_refresh_record_key" \
      "$shimmy_catalog_refresh_record_upstream" "$shimmy_catalog_refresh_record_default" \
      "$shimmy_catalog_refresh_candidate_ref" "$shimmy_catalog_refresh_candidate_digest" \
      "$SHIMMY_CATALOG_REFRESH_MEDIA" "$shimmy_catalog_refresh_record_access" \
      >> "$SHIMMY_CATALOG_REFRESH_CANDIDATES"
  done < "$SHIMMY_CATALOG_REFRESH_RECORDS"

  [ "$shimmy_catalog_refresh_refreshable" -gt 0 ] || {
    shimmy_catalog_refresh_error_set "$SHIMMY_CATALOG_REFRESH_SELECTOR is not-refreshable: every upstream reference is already immutable; choose a tag-backed concrete version"
    return 1
  }
  [ "$shimmy_catalog_refresh_record_failed" -eq 0 ] || {
    shimmy_catalog_refresh_error_set 'catalog refresh rejected one or more image records; no source changes were made'
    return 1
  }
}

shimmy_catalog_refresh_image_rewrite() {
  SHIMMY_CATALOG_REFRESH_CANDIDATE_IMAGE=$SHIMMY_CATALOG_REFRESH_WORKSPACE/image.conf
  cp "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" "$SHIMMY_CATALOG_REFRESH_CANDIDATE_IMAGE" || return 1
  chmod "$SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE" "$SHIMMY_CATALOG_REFRESH_CANDIDATE_IMAGE" || return 1
  shimmy_catalog_refresh_rewrite_sequence=0
  while IFS='|' read -r shimmy_catalog_refresh_rewrite_role shimmy_catalog_refresh_rewrite_key \
    shimmy_catalog_refresh_rewrite_upstream shimmy_catalog_refresh_rewrite_old \
    shimmy_catalog_refresh_rewrite_new shimmy_catalog_refresh_rewrite_digest \
    shimmy_catalog_refresh_rewrite_media shimmy_catalog_refresh_rewrite_access; do
    [ -n "$shimmy_catalog_refresh_rewrite_role" ] || continue
    [ "$shimmy_catalog_refresh_rewrite_old" != "$shimmy_catalog_refresh_rewrite_new" ] || continue
    shimmy_catalog_refresh_rewrite_sequence=$((shimmy_catalog_refresh_rewrite_sequence + 1))
    shimmy_catalog_refresh_rewrite_next=$SHIMMY_CATALOG_REFRESH_WORKSPACE/image.conf.$shimmy_catalog_refresh_rewrite_sequence
    awk -v expected="$shimmy_catalog_refresh_rewrite_key=$shimmy_catalog_refresh_rewrite_old" \
      -v replacement="$shimmy_catalog_refresh_rewrite_key=$shimmy_catalog_refresh_rewrite_new" '
      $0 == expected { count++; print replacement; next }
      { print }
      END { if (count != 1) exit 7 }
    ' "$SHIMMY_CATALOG_REFRESH_CANDIDATE_IMAGE" > "$shimmy_catalog_refresh_rewrite_next" || {
      shimmy_catalog_refresh_error_set "unable to rewrite unique scalar $shimmy_catalog_refresh_rewrite_key"
      return 1
    }
    chmod "$SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE" "$shimmy_catalog_refresh_rewrite_next" || return 1
    mv "$shimmy_catalog_refresh_rewrite_next" "$SHIMMY_CATALOG_REFRESH_CANDIDATE_IMAGE" || return 1
  done < "$SHIMMY_CATALOG_REFRESH_CANDIDATES"
  shimmy_image_config_validate "$SHIMMY_CATALOG_REFRESH_CANDIDATE_IMAGE" || {
    shimmy_catalog_refresh_error_set 'rewritten image configuration failed canonical validation'
    return 1
  }
  SHIMMY_CATALOG_REFRESH_CANDIDATE_FINGERPRINT=$(shimmy_sha256_fingerprint_file_render "$SHIMMY_CATALOG_REFRESH_CANDIDATE_IMAGE") || return 1
}

shimmy_catalog_refresh_tags_revalidate() {
  shimmy_catalog_refresh_tag_failed=0
  while IFS='|' read -r shimmy_catalog_refresh_tag_role shimmy_catalog_refresh_tag_key \
    shimmy_catalog_refresh_tag_upstream shimmy_catalog_refresh_tag_old \
    shimmy_catalog_refresh_tag_new shimmy_catalog_refresh_tag_digest \
    shimmy_catalog_refresh_tag_media shimmy_catalog_refresh_tag_access; do
    [ -n "$shimmy_catalog_refresh_tag_role" ] || continue
    if ! shimmy_catalog_refresh_digest_cache_read refresh-digest "$shimmy_catalog_refresh_tag_upstream" ||
      [ "$SHIMMY_CATALOG_REFRESH_RESOLVED_DIGEST" != "$shimmy_catalog_refresh_tag_digest" ]; then
      printf 'FAIL %s %s error=upstream-moved-during-refresh\n' \
        "$SHIMMY_CATALOG_REFRESH_SELECTOR" "$shimmy_catalog_refresh_tag_role" >&2
      shimmy_catalog_refresh_tag_failed=1
    fi
  done < "$SHIMMY_CATALOG_REFRESH_CANDIDATES"
  [ "$shimmy_catalog_refresh_tag_failed" -eq 0 ] || {
    shimmy_catalog_refresh_error_set 'upstream-moved-during-refresh; no source changes were made'
    return 1
  }
}

shimmy_catalog_refresh_device_read() {
  if stat -f '%d' "$1" >/dev/null 2>&1; then stat -f '%d' "$1"; else stat -c '%d' "$1"; fi
}

shimmy_catalog_refresh_rollback() {
  shimmy_catalog_refresh_rollback_file=$SHIMMY_CATALOG_REFRESH_LOCK_PATH/rollback
  [ -f "$shimmy_catalog_refresh_rollback_file" ] && [ ! -L "$shimmy_catalog_refresh_rollback_file" ] &&
    [ "$(shimmy_sha256_fingerprint_file_render "$shimmy_catalog_refresh_rollback_file")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_FINGERPRINT" ] &&
    [ "$(shimmy_file_mode_render "$shimmy_catalog_refresh_rollback_file")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE" ] &&
    mv "$shimmy_catalog_refresh_rollback_file" "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" &&
    [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_FINGERPRINT" ] &&
    [ "$(shimmy_file_mode_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE" ]
}

shimmy_catalog_refresh_source_commit() {
  shimmy_catalog_refresh_lock_owned || {
    shimmy_catalog_refresh_error_set 'catalog refresh lock ownership changed before source mutation'
    return 1
  }
  [ "$(shimmy_catalog_refresh_device_read "$SHIMMY_CATALOG_REFRESH_GIT_DIR")" = \
    "$(shimmy_catalog_refresh_device_read "$(dirname -- "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE")")" ] || {
      shimmy_catalog_refresh_error_set 'catalog refresh requires Git metadata and the selected source file on one filesystem'
      return 1
    }
  shimmy_catalog_refresh_commit_candidate=$SHIMMY_CATALOG_REFRESH_LOCK_PATH/candidate
  shimmy_catalog_refresh_commit_rollback=$SHIMMY_CATALOG_REFRESH_LOCK_PATH/rollback
  cp "$SHIMMY_CATALOG_REFRESH_CANDIDATE_IMAGE" "$shimmy_catalog_refresh_commit_candidate" || return 1
  chmod "$SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE" "$shimmy_catalog_refresh_commit_candidate" || return 1
  [ "$(shimmy_sha256_fingerprint_file_render "$shimmy_catalog_refresh_commit_candidate")" = "$SHIMMY_CATALOG_REFRESH_CANDIDATE_FINGERPRINT" ] &&
    shimmy_image_config_validate "$shimmy_catalog_refresh_commit_candidate" || {
      shimmy_catalog_refresh_error_set 'catalog refresh commit candidate changed before mutation'
      return 1
    }
  if [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] &&
    [ "${SHIMMY_TEST_CATALOG_REFRESH_FAILURE:-}" = after-candidate ]; then
    shimmy_catalog_refresh_error_set 'injected catalog refresh failure after commit candidate staging'
    return 1
  fi
  shimmy_catalog_refresh_source_revalidate || return 1
  shimmy_catalog_refresh_lock_owned || return 1
  cp -p "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" "$shimmy_catalog_refresh_commit_rollback" || return 1
  [ "$(shimmy_sha256_fingerprint_file_render "$shimmy_catalog_refresh_commit_rollback")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_FINGERPRINT" ] &&
    [ "$(shimmy_file_mode_render "$shimmy_catalog_refresh_commit_rollback")" = "$SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE" ] || return 1
  mv "$shimmy_catalog_refresh_commit_candidate" "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" || return 1

  shimmy_catalog_refresh_commit_failed=0
  if [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] &&
    [ "${SHIMMY_TEST_CATALOG_REFRESH_FAILURE:-}" = after-write ]; then
    shimmy_catalog_refresh_commit_failed=1
  elif [ "$(shimmy_sha256_fingerprint_file_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE")" != \
      "$SHIMMY_CATALOG_REFRESH_CANDIDATE_FINGERPRINT" ] ||
    [ "$(shimmy_file_mode_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE")" != \
      "$SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE" ] ||
    ! shimmy_image_config_validate "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE"; then
    shimmy_catalog_refresh_commit_failed=1
  fi
  if [ "$shimmy_catalog_refresh_commit_failed" -eq 1 ]; then
    if shimmy_catalog_refresh_rollback; then
      shimmy_catalog_refresh_error_set 'catalog refresh post-write validation failed; rollback complete'
    else
      shimmy_catalog_refresh_error_set 'catalog refresh post-write validation failed; rollback incomplete'
    fi
    return 1
  fi
  rm -f "$shimmy_catalog_refresh_commit_rollback" || return 1
}

shimmy_catalog_refresh_review_paths_read() {
  SHIMMY_CATALOG_REFRESH_REVIEW_PATHS=
  while IFS='|' read -r shimmy_catalog_refresh_review_role shimmy_catalog_refresh_review_key \
    shimmy_catalog_refresh_review_upstream shimmy_catalog_refresh_review_old \
    shimmy_catalog_refresh_review_new shimmy_catalog_refresh_review_digest \
    shimmy_catalog_refresh_review_media shimmy_catalog_refresh_review_access; do
    [ -n "$shimmy_catalog_refresh_review_role" ] || continue
    [ "$shimmy_catalog_refresh_review_old" != "$shimmy_catalog_refresh_review_new" ] || continue
    for shimmy_catalog_refresh_review_relative in \
      "tools/$SHIMMY_CATALOG_REFRESH_TOOL/guide.md" \
      "tools/$SHIMMY_CATALOG_REFRESH_TOOL/SKILL.md"; do
      shimmy_catalog_refresh_review_file=$SHIMMY_CATALOG_REFRESH_CHECKOUT/$shimmy_catalog_refresh_review_relative
      [ -f "$shimmy_catalog_refresh_review_file" ] && [ ! -L "$shimmy_catalog_refresh_review_file" ] || continue
      if grep -F "$shimmy_catalog_refresh_review_old" "$shimmy_catalog_refresh_review_file" >/dev/null 2>&1 &&
        ! shimmy_contains_line_list "$SHIMMY_CATALOG_REFRESH_REVIEW_PATHS" "$shimmy_catalog_refresh_review_relative"; then
        SHIMMY_CATALOG_REFRESH_REVIEW_PATHS=$(shimmy_append_line_list \
          "$SHIMMY_CATALOG_REFRESH_REVIEW_PATHS" "$shimmy_catalog_refresh_review_relative")
      fi
    done
  done < "$SHIMMY_CATALOG_REFRESH_CANDIDATES"
}

shimmy_catalog_refresh_output() {
  shimmy_catalog_refresh_output_changed=0
  while IFS='|' read -r shimmy_catalog_refresh_output_role shimmy_catalog_refresh_output_key \
    shimmy_catalog_refresh_output_upstream shimmy_catalog_refresh_output_old \
    shimmy_catalog_refresh_output_new shimmy_catalog_refresh_output_digest \
    shimmy_catalog_refresh_output_media shimmy_catalog_refresh_output_access; do
    [ -n "$shimmy_catalog_refresh_output_role" ] || continue
    if [ "$shimmy_catalog_refresh_output_old" = "$shimmy_catalog_refresh_output_new" ]; then
      printf 'CURRENT %s %s digest=%s media=%s platforms=linux/amd64,linux/arm64 access=%s\n' \
        "$SHIMMY_CATALOG_REFRESH_SELECTOR" "$shimmy_catalog_refresh_output_role" \
        "$shimmy_catalog_refresh_output_digest" "$shimmy_catalog_refresh_output_media" \
        "$shimmy_catalog_refresh_output_access"
      continue
    fi
    shimmy_catalog_refresh_output_changed=1
    printf 'REFRESH %s %s\n' "$SHIMMY_CATALOG_REFRESH_SELECTOR" "$shimmy_catalog_refresh_output_role"
    printf '  upstream:  %s\n' "$shimmy_catalog_refresh_output_upstream"
    printf '  previous:  %s\n' "$(shimmy_images_digest_read "$shimmy_catalog_refresh_output_old")"
    printf '  candidate: %s\n' "$shimmy_catalog_refresh_output_digest"
    printf '  media:     %s\n' "$shimmy_catalog_refresh_output_media"
    printf '  platforms: linux/amd64, linux/arm64\n'
    printf '  access:    %s\n' "$shimmy_catalog_refresh_output_access"
  done < "$SHIMMY_CATALOG_REFRESH_CANDIDATES"
  while IFS='|' read -r shimmy_catalog_refresh_output_skip_role shimmy_catalog_refresh_output_skip_ref; do
    [ -n "$shimmy_catalog_refresh_output_skip_role" ] || continue
    printf 'SKIP %s %s reason=immutable-only upstream=%s\n' \
      "$SHIMMY_CATALOG_REFRESH_SELECTOR" "$shimmy_catalog_refresh_output_skip_role" \
      "$shimmy_catalog_refresh_output_skip_ref"
  done < "$SHIMMY_CATALOG_REFRESH_SKIPPED"

  if [ "$shimmy_catalog_refresh_output_changed" -eq 1 ]; then
    if [ "$SHIMMY_CATALOG_REFRESH_DRY_RUN" -eq 1 ]; then
      printf 'WOULD UPDATE %s\n' "$SHIMMY_CATALOG_REFRESH_IMAGE_RELATIVE"
    else
      printf 'UPDATED %s\n' "$SHIMMY_CATALOG_REFRESH_IMAGE_RELATIVE"
    fi
    shimmy_catalog_refresh_review_paths_read
    while IFS= read -r shimmy_catalog_refresh_output_review; do
      [ -n "$shimmy_catalog_refresh_output_review" ] || continue
      printf 'REVIEW %s\n' "$shimmy_catalog_refresh_output_review"
    done <<EOF
$SHIMMY_CATALOG_REFRESH_REVIEW_PATHS
EOF
    printf 'NATIVE SMOKE linux/amd64: shimmy shim test %s\n' "$SHIMMY_CATALOG_REFRESH_SELECTOR"
    printf 'NATIVE SMOKE darwin/arm64: shimmy shim test %s\n' "$SHIMMY_CATALOG_REFRESH_SELECTOR"
    printf 'NEXT commit the reviewed source diff, then run: shimmy catalog publish\n'
  fi
  printf 'PUBLISHED no\n'
}

shimmy_catalog_refresh_run() {
  shimmy_catalog_refresh_config_root=$1
  shimmy_catalog_refresh_checkout=$2
  SHIMMY_CATALOG_REFRESH_SELECTOR=$3
  SHIMMY_CATALOG_REFRESH_DRY_RUN=${4:-0}
  SHIMMY_CATALOG_REFRESH_ERROR=

  shimmy_catalog_refresh_checkout_validate "$shimmy_catalog_refresh_checkout" || return 1
  SHIMMY_CATALOG_REFRESH_TOOL=${SHIMMY_CATALOG_REFRESH_SELECTOR%%@*}
  SHIMMY_CATALOG_REFRESH_VERSION=${SHIMMY_CATALOG_REFRESH_SELECTOR#*@}
  SHIMMY_CATALOG_REFRESH_IMAGE_RELATIVE=tools/$SHIMMY_CATALOG_REFRESH_TOOL/versions/$SHIMMY_CATALOG_REFRESH_VERSION/image.conf
  SHIMMY_CATALOG_REFRESH_IMAGE_FILE=$SHIMMY_CATALOG_REFRESH_CHECKOUT/$SHIMMY_CATALOG_REFRESH_IMAGE_RELATIVE
  [ -f "$SHIMMY_CATALOG_REFRESH_CHECKOUT/tools/$SHIMMY_CATALOG_REFRESH_TOOL/tool.conf" ] || {
    shimmy_catalog_refresh_error_set "unsupported shim tool: $SHIMMY_CATALOG_REFRESH_TOOL"
    return 1
  }
  [ -d "$SHIMMY_CATALOG_REFRESH_CHECKOUT/tools/$SHIMMY_CATALOG_REFRESH_TOOL/versions/$SHIMMY_CATALOG_REFRESH_VERSION" ] || {
    shimmy_catalog_refresh_error_set "unsupported $SHIMMY_CATALOG_REFRESH_TOOL version: $SHIMMY_CATALOG_REFRESH_VERSION"
    return 1
  }
  [ -f "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" ] && [ ! -L "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" ] || {
    shimmy_catalog_refresh_error_set "selected image configuration is not a regular file: $SHIMMY_CATALOG_REFRESH_IMAGE_RELATIVE"
    return 1
  }
  shimmy_image_config_validate "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE" || {
    shimmy_catalog_refresh_error_set "selected image configuration failed canonical validation: $SHIMMY_CATALOG_REFRESH_IMAGE_RELATIVE"
    return 1
  }
  SHIMMY_CATALOG_REFRESH_ORIGINAL_FINGERPRINT=$(shimmy_sha256_fingerprint_file_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE") || return 1
  SHIMMY_CATALOG_REFRESH_ORIGINAL_MODE=$(shimmy_file_mode_render "$SHIMMY_CATALOG_REFRESH_IMAGE_FILE") || return 1

  shimmy_images_active_runtimes_prepare "$shimmy_catalog_refresh_config_root" 'catalog refresh' || {
    shimmy_catalog_refresh_error_set "$SHIMMY_IMAGES_ERROR"
    return 1
  }
  shimmy_catalog_refresh_workspace_prepare || return 1
  SHIMMY_CATALOG_TOOLS_DIR=$SHIMMY_CATALOG_REFRESH_CHECKOUT/tools
  SHIMMY_CATALOG_REFRESH_RECORDS=$SHIMMY_CATALOG_REFRESH_WORKSPACE/records
  shimmy_images_config_records_print "$SHIMMY_CATALOG_REFRESH_TOOL" "$SHIMMY_CATALOG_REFRESH_VERSION" \
    > "$SHIMMY_CATALOG_REFRESH_RECORDS" || {
      shimmy_catalog_refresh_error_set 'unable to enumerate selected image records'
      return 1
    }
  shimmy_catalog_refresh_candidate_records_create || return 1
  shimmy_catalog_refresh_image_rewrite || return 1

  if [ "$SHIMMY_CATALOG_REFRESH_DRY_RUN" -eq 0 ]; then
    shimmy_catalog_refresh_lock_acquire || return 1
  fi
  shimmy_catalog_refresh_tags_revalidate || return 1
  if [ "${SHIMMY_TEST_MODE:-0}" -eq 1 ] &&
    [ -n "${SHIMMY_TEST_CATALOG_REFRESH_BEFORE_COMMIT_FUNCTION:-}" ]; then
    shimmy_shell_function_name_validate "$SHIMMY_TEST_CATALOG_REFRESH_BEFORE_COMMIT_FUNCTION" || return 1
    "$SHIMMY_TEST_CATALOG_REFRESH_BEFORE_COMMIT_FUNCTION" "$SHIMMY_CATALOG_REFRESH_CHECKOUT" || return 1
  fi
  shimmy_catalog_refresh_source_revalidate || return 1

  if [ "$SHIMMY_CATALOG_REFRESH_CANDIDATE_FINGERPRINT" != "$SHIMMY_CATALOG_REFRESH_ORIGINAL_FINGERPRINT" ] &&
    [ "$SHIMMY_CATALOG_REFRESH_DRY_RUN" -eq 0 ]; then
    shimmy_catalog_refresh_source_commit || return 1
  fi
  shimmy_catalog_refresh_output
  shimmy_catalog_refresh_lock_release || return 1
  shimmy_catalog_refresh_workspace_cleanup || return 1
}
