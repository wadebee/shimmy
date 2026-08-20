#!/bin/sh
# Private target default-catalog creation and immutable publication lifecycle.

SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE=

shimmy_target_catalog_lifecycle_cleanup() {
  [ -n "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" ] || return 0
  case "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" in
    */catalogs/.default-candidate.*|*/catalogs/default/.publish-candidate.*)
      [ ! -e "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" ] && [ ! -L "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" ] ||
        rm -rf "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE"
      ;;
    *) return 1 ;;
  esac
  SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE=
}

shimmy_target_catalog_checkout_validate() {
  shimmy_target_catalog_checkout=$1
  command -v git >/dev/null 2>&1 || {
    shimmy_target_catalog_error_set 'Git is required for target catalog publication'
    return 1
  }
  shimmy_target_catalog_checkout_resolved=$(shimmy_resolve_path_absolute "$shimmy_target_catalog_checkout") || return 1
  [ "$shimmy_target_catalog_checkout_resolved" = "$shimmy_target_catalog_checkout" ] || {
    shimmy_target_catalog_error_set "target catalog publication requires a normalized repository root: $shimmy_target_catalog_checkout"
    return 1
  }
  shimmy_target_catalog_git_root=$(git -C "$shimmy_target_catalog_checkout" rev-parse --show-toplevel 2>/dev/null || true)
  [ "$shimmy_target_catalog_git_root" = "$shimmy_target_catalog_checkout" ] || {
    shimmy_target_catalog_error_set "target catalog publication source must be a Git worktree root: $shimmy_target_catalog_checkout"
    return 1
  }
  shimmy_target_catalog_branch=$(git -C "$shimmy_target_catalog_checkout" symbolic-ref --quiet HEAD 2>/dev/null || true)
  [ "$shimmy_target_catalog_branch" = refs/heads/main ] || {
    shimmy_target_catalog_error_set 'target catalog publication requires attached local branch main'
    return 1
  }
  shimmy_target_catalog_head=$(git -C "$shimmy_target_catalog_checkout" rev-parse --verify HEAD 2>/dev/null || true)
  shimmy_git_commit_validate "$shimmy_target_catalog_head" || {
    shimmy_target_catalog_error_set 'target catalog publication source has no valid HEAD'
    return 1
  }
  [ "$(git -C "$shimmy_target_catalog_checkout" rev-parse --verify refs/heads/main 2>/dev/null || true)" = "$shimmy_target_catalog_head" ] || {
    shimmy_target_catalog_error_set 'target catalog publication HEAD does not equal refs/heads/main'
    return 1
  }
  shimmy_target_catalog_dirty=$(git -C "$shimmy_target_catalog_checkout" status --porcelain --untracked-files=all 2>/dev/null || printf '%s\n' status-failed)
  [ -z "$shimmy_target_catalog_dirty" ] || {
    shimmy_target_catalog_error_set 'target catalog publication requires a clean index, worktree, and untracked state'
    return 1
  }
  SHIMMY_TARGET_CATALOG_PUBLICATION_CHECKOUT=$shimmy_target_catalog_checkout
  SHIMMY_TARGET_CATALOG_PUBLICATION_HEAD=$shimmy_target_catalog_head
}

shimmy_target_catalog_checkout_revalidate() {
  [ "$(git -C "$SHIMMY_TARGET_CATALOG_PUBLICATION_CHECKOUT" symbolic-ref --quiet HEAD 2>/dev/null || true)" = refs/heads/main ] &&
    [ "$(git -C "$SHIMMY_TARGET_CATALOG_PUBLICATION_CHECKOUT" rev-parse --verify HEAD 2>/dev/null || true)" = "$SHIMMY_TARGET_CATALOG_PUBLICATION_HEAD" ] &&
    [ "$(git -C "$SHIMMY_TARGET_CATALOG_PUBLICATION_CHECKOUT" rev-parse --verify refs/heads/main 2>/dev/null || true)" = "$SHIMMY_TARGET_CATALOG_PUBLICATION_HEAD" ] || {
      shimmy_target_catalog_error_set 'target catalog publication authority moved during staging'
      return 1
    }
  shimmy_target_catalog_recheck_dirty=$(git -C "$SHIMMY_TARGET_CATALOG_PUBLICATION_CHECKOUT" status --porcelain --untracked-files=all 2>/dev/null || printf '%s\n' status-failed)
  [ -z "$shimmy_target_catalog_recheck_dirty" ] || {
    shimmy_target_catalog_error_set 'target catalog publication source changed during staging'
    return 1
  }
}

shimmy_target_catalog_generation_stage() {
  shimmy_target_catalog_stage_payload=$1
  shimmy_target_catalog_stage_parent=$(dirname -- "$shimmy_target_catalog_stage_payload")
  shimmy_target_catalog_stage_archive=$shimmy_target_catalog_stage_parent/catalog.tar
  mkdir "$shimmy_target_catalog_stage_payload" || return 1
  git -C "$SHIMMY_TARGET_CATALOG_PUBLICATION_CHECKOUT" archive --format=tar \
    --output="$shimmy_target_catalog_stage_archive" "$SHIMMY_TARGET_CATALOG_PUBLICATION_HEAD" \
    catalog.conf tools plugins/shimmy/skills 2>/dev/null || {
      shimmy_target_catalog_error_set 'unable to stage tracked target catalog content from main'
      return 1
    }
  tar -xf "$shimmy_target_catalog_stage_archive" -C "$shimmy_target_catalog_stage_payload" || {
    shimmy_target_catalog_error_set 'unable to extract staged target catalog content'
    return 1
  }
  rm -f "$shimmy_target_catalog_stage_archive"
  shimmy_target_catalog_payload_validate "$shimmy_target_catalog_stage_payload" || return 1
  SHIMMY_TARGET_CATALOG_STAGED_FINGERPRINT=$(shimmy_target_catalog_content_fingerprint_render "$shimmy_target_catalog_stage_payload") || return 1
  SHIMMY_TARGET_CATALOG_STAGED_GENERATION=$(shimmy_target_catalog_generation_render "$SHIMMY_TARGET_CATALOG_STAGED_FINGERPRINT") || return 1
  shimmy_target_catalog_generation_metadata_render "$SHIMMY_TARGET_CATALOG_PUBLICATION_HEAD" \
    "$SHIMMY_TARGET_CATALOG_STAGED_FINGERPRINT" > "$shimmy_target_catalog_stage_payload/generation.conf" || return 1
  chmod 0644 "$shimmy_target_catalog_stage_payload/generation.conf" || return 1
  shimmy_target_catalog_generation_record_validate "$shimmy_target_catalog_stage_payload" "$SHIMMY_TARGET_CATALOG_STAGED_GENERATION"
}

shimmy_target_catalog_publication_state_read() {
  shimmy_target_catalog_root_paths_resolve "$1" || return 1
  [ -d "$SHIMMY_TARGET_CATALOGS_ROOT" ] && [ ! -L "$SHIMMY_TARGET_CATALOGS_ROOT" ] &&
    [ -d "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] && [ ! -L "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] &&
    [ -d "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT" ] && [ ! -L "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT" ] || {
      shimmy_target_catalog_error_set 'target default-catalog state is incomplete'
      return 1
    }
  for shimmy_target_catalog_publication_entry in "$SHIMMY_TARGET_CATALOGS_ROOT"/* "$SHIMMY_TARGET_CATALOGS_ROOT"/.[!.]* "$SHIMMY_TARGET_CATALOGS_ROOT"/..?*; do
    [ -e "$shimmy_target_catalog_publication_entry" ] || [ -L "$shimmy_target_catalog_publication_entry" ] || continue
    [ "$shimmy_target_catalog_publication_entry" = "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] || {
      shimmy_target_catalog_error_set "unsupported target catalog state: $shimmy_target_catalog_publication_entry"
      return 1
    }
  done
  for shimmy_target_catalog_publication_entry in "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT"/* "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT"/.[!.]* "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT"/..?*; do
    [ -e "$shimmy_target_catalog_publication_entry" ] || [ -L "$shimmy_target_catalog_publication_entry" ] || continue
    case "$shimmy_target_catalog_publication_entry" in
      "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH"|"$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT"|"$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE") ;;
      *) shimmy_target_catalog_error_set "unrecognized target default-catalog state: $shimmy_target_catalog_publication_entry"; return 1 ;;
    esac
  done
  shimmy_target_catalog_registry_read "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH" || {
    shimmy_target_catalog_error_set 'invalid target default-catalog registry'
    return 1
  }
  SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT=$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT
  SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS=$SHIMMY_TARGET_CATALOG_GENERATION_PREVIOUS
  SHIMMY_TARGET_CATALOG_PUBLICATION_REGISTRY_COMMIT=$SHIMMY_TARGET_CATALOG_SOURCE_COMMIT
  SHIMMY_TARGET_CATALOG_PUBLICATION_REGISTRY_FINGERPRINT=$SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT
  SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT_VALID=0
  if shimmy_target_catalog_generation_record_validate "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT" "$SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT"; then
    [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_COMMIT" = "$SHIMMY_TARGET_CATALOG_PUBLICATION_REGISTRY_COMMIT" ] &&
      [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$SHIMMY_TARGET_CATALOG_PUBLICATION_REGISTRY_FINGERPRINT" ] || {
        shimmy_target_catalog_error_set 'target catalog registry provenance does not match current generation'
        return 1
      }
    SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT_VALID=1
  fi
  if [ -n "$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS" ]; then
    shimmy_target_catalog_generation_record_validate "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS" "$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS" || return 1
  fi
  for shimmy_target_catalog_publication_generation_dir in "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT"/* "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT"/.[!.]* "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT"/..?*; do
    [ -e "$shimmy_target_catalog_publication_generation_dir" ] || [ -L "$shimmy_target_catalog_publication_generation_dir" ] || continue
    shimmy_target_catalog_publication_generation_name=$(basename -- "$shimmy_target_catalog_publication_generation_dir")
    [ -d "$shimmy_target_catalog_publication_generation_dir" ] && [ ! -L "$shimmy_target_catalog_publication_generation_dir" ] &&
      shimmy_target_catalog_generation_validate "$shimmy_target_catalog_publication_generation_name" || {
        shimmy_target_catalog_error_set "unsafe retained target catalog generation: $shimmy_target_catalog_publication_generation_dir"
        return 1
      }
  done
}

shimmy_target_catalog_registry_candidate_validate() {
  shimmy_target_catalog_registry_read "$1"
}

shimmy_target_catalog_registry_commit_authority_validate() {
  shimmy_target_catalog_authority_target=$1
  shimmy_target_catalog_authority_candidate=$2
  [ "$shimmy_target_catalog_authority_target" = "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH" ] || return 1
  shimmy_target_catalog_registry_read "$shimmy_target_catalog_authority_candidate" || return 1
  [ "$SHIMMY_TARGET_CATALOG_GENERATION_CURRENT" = "$SHIMMY_TARGET_CATALOG_COMMIT_GENERATION" ] &&
    [ "$SHIMMY_TARGET_CATALOG_SOURCE_COMMIT" = "$SHIMMY_TARGET_CATALOG_COMMIT_SOURCE" ] &&
    [ "$SHIMMY_TARGET_CATALOG_CONTENT_FINGERPRINT" = "$SHIMMY_TARGET_CATALOG_COMMIT_FINGERPRINT" ] || return 1
  shimmy_target_catalog_generation_record_validate "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$SHIMMY_TARGET_CATALOG_COMMIT_GENERATION" "$SHIMMY_TARGET_CATALOG_COMMIT_GENERATION" || return 1
  [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_COMMIT" = "$SHIMMY_TARGET_CATALOG_COMMIT_SOURCE" ] &&
    [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$SHIMMY_TARGET_CATALOG_COMMIT_FINGERPRINT" ] || return 1
  if [ "$SHIMMY_TARGET_CATALOG_COMMIT_RECHECK_GIT" -eq 1 ]; then
    shimmy_target_catalog_checkout_revalidate || return 1
  fi
}

shimmy_target_catalog_registry_commit() {
  SHIMMY_TARGET_CATALOG_COMMIT_GENERATION=$1
  SHIMMY_TARGET_CATALOG_COMMIT_PREVIOUS=$2
  SHIMMY_TARGET_CATALOG_COMMIT_SOURCE=$3
  SHIMMY_TARGET_CATALOG_COMMIT_FINGERPRINT=$4
  SHIMMY_TARGET_CATALOG_COMMIT_RECHECK_GIT=$5
  shimmy_target_filesystem_transaction_prepare "$SHIMMY_TARGET_CATALOG_REGISTRY_PATH" || return 1
  shimmy_target_catalog_registry_render "$SHIMMY_TARGET_CATALOG_COMMIT_GENERATION" "$SHIMMY_TARGET_CATALOG_COMMIT_PREVIOUS" \
    "$SHIMMY_TARGET_CATALOG_COMMIT_SOURCE" "$SHIMMY_TARGET_CATALOG_COMMIT_FINGERPRINT" > "$SHIMMY_TARGET_FILESYSTEM_CANDIDATE_PATH" || return 1
  chmod 0644 "$SHIMMY_TARGET_FILESYSTEM_CANDIDATE_PATH" || return 1
  shimmy_target_filesystem_transaction_candidate_validate shimmy_target_catalog_registry_candidate_validate || return 1
  shimmy_target_filesystem_transaction_commit shimmy_target_catalog_registry_commit_authority_validate catalog || return 1
  shimmy_target_filesystem_transaction_cleanup
}

shimmy_target_catalog_default_create() {
  shimmy_target_catalog_create_config_root=$1
  shimmy_target_catalog_create_checkout=$2
  shimmy_target_catalog_checkout_validate "$shimmy_target_catalog_create_checkout" || return 1
  shimmy_target_catalog_root_paths_resolve "$shimmy_target_catalog_create_config_root" || return 1
  [ ! -e "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] && [ ! -L "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] || {
    shimmy_target_catalog_error_set 'target default catalog is already initialized'
    return 1
  }
  mkdir -p "$SHIMMY_TARGET_CATALOGS_ROOT" || return 1
  for shimmy_target_catalog_create_entry in "$SHIMMY_TARGET_CATALOGS_ROOT"/* "$SHIMMY_TARGET_CATALOGS_ROOT"/.[!.]* "$SHIMMY_TARGET_CATALOGS_ROOT"/..?*; do
    [ -e "$shimmy_target_catalog_create_entry" ] || [ -L "$shimmy_target_catalog_create_entry" ] || continue
    shimmy_target_catalog_error_set "unsupported state blocks target default-catalog creation: $shimmy_target_catalog_create_entry"
    return 1
  done
  shimmy_target_lock_acquire catalog "$shimmy_target_catalog_create_config_root" || {
    shimmy_target_catalog_error_set "$SHIMMY_TARGET_LOCK_ERROR"
    return 1
  }
  SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE=$SHIMMY_TARGET_CATALOGS_ROOT/.default-candidate.$$
  if [ -e "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" ] || [ -L "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" ]; then
    shimmy_target_locks_release_all
    shimmy_target_catalog_error_set 'target default-catalog creation staging collision'
    return 1
  fi
  mkdir -p "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/generations" || return 1
  shimmy_target_catalog_generation_stage "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/payload" || return 1
  mv "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/payload" "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/generations/$SHIMMY_TARGET_CATALOG_STAGED_GENERATION" || return 1
  shimmy_target_catalog_registry_render "$SHIMMY_TARGET_CATALOG_STAGED_GENERATION" '' "$SHIMMY_TARGET_CATALOG_PUBLICATION_HEAD" \
    "$SHIMMY_TARGET_CATALOG_STAGED_FINGERPRINT" > "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/registry.conf" || return 1
  chmod 0644 "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/registry.conf" || return 1
  shimmy_target_catalog_checkout_revalidate || return 1
  [ ! -e "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] && [ ! -L "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" ] || return 1
  mv "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" "$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT" || return 1
  SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE=
  shimmy_target_locks_release_all || return 1
  shimmy_target_catalog_tree_validate "$shimmy_target_catalog_create_config_root"
}

shimmy_target_catalog_default_publish() {
  shimmy_target_catalog_publish_config_root=$1
  shimmy_target_catalog_publish_checkout=$2
  shimmy_target_catalog_checkout_validate "$shimmy_target_catalog_publish_checkout" || return 1
  shimmy_target_catalog_publication_state_read "$shimmy_target_catalog_publish_config_root" || return 1
  SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE=$SHIMMY_TARGET_CATALOG_DEFAULT_ROOT/.publish-candidate.$$
  [ ! -e "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" ] && [ ! -L "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" ] || return 1
  mkdir "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE" || return 1
  shimmy_target_catalog_generation_stage "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/payload" || return 1
  shimmy_target_lock_acquire catalog "$shimmy_target_catalog_publish_config_root" || return 1
  shimmy_target_catalog_publication_state_read "$shimmy_target_catalog_publish_config_root" || return 1
  shimmy_target_catalog_checkout_revalidate || return 1

  shimmy_target_catalog_publish_generation_root=$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$SHIMMY_TARGET_CATALOG_STAGED_GENERATION
  if [ -e "$shimmy_target_catalog_publish_generation_root" ] || [ -L "$shimmy_target_catalog_publish_generation_root" ]; then
    shimmy_target_catalog_generation_record_validate "$shimmy_target_catalog_publish_generation_root" "$SHIMMY_TARGET_CATALOG_STAGED_GENERATION" || {
      shimmy_target_catalog_error_set "target catalog generation fingerprint collision: $SHIMMY_TARGET_CATALOG_STAGED_GENERATION"
      return 1
    }
    [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_COMMIT" = "$SHIMMY_TARGET_CATALOG_PUBLICATION_HEAD" ] &&
      [ "$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_FINGERPRINT" = "$SHIMMY_TARGET_CATALOG_STAGED_FINGERPRINT" ] || {
        shimmy_target_catalog_error_set "target catalog generation identity collision: $SHIMMY_TARGET_CATALOG_STAGED_GENERATION"
        return 1
      }
    rm -rf "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/payload"
  else
    mv "$SHIMMY_TARGET_CATALOG_LIFECYCLE_STAGE/payload" "$shimmy_target_catalog_publish_generation_root" || return 1
  fi

  if [ "$SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT_VALID" -eq 1 ] &&
    [ "$SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT" = "$SHIMMY_TARGET_CATALOG_STAGED_GENERATION" ]; then
    shimmy_target_catalog_lifecycle_cleanup
    shimmy_target_locks_release_all
    shimmy_target_catalog_tree_validate "$shimmy_target_catalog_publish_config_root"
    return
  fi
  if [ "$SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT_VALID" -eq 1 ]; then
    shimmy_target_catalog_publish_previous=$SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT
  elif [ "$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS" != "$SHIMMY_TARGET_CATALOG_STAGED_GENERATION" ]; then
    shimmy_target_catalog_publish_previous=$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS
  else
    shimmy_target_catalog_publish_previous=
  fi
  if [ "${SHIMMY_TARGET_TEST_MODE:-0}" -eq 1 ] && [ -n "${SHIMMY_TARGET_TEST_CATALOG_BEFORE_COMMIT_FUNCTION:-}" ]; then
    shimmy_shell_function_name_validate "$SHIMMY_TARGET_TEST_CATALOG_BEFORE_COMMIT_FUNCTION" || return 1
    "$SHIMMY_TARGET_TEST_CATALOG_BEFORE_COMMIT_FUNCTION" "$SHIMMY_TARGET_CATALOG_PUBLICATION_CHECKOUT" || return 1
  fi
  shimmy_target_catalog_registry_commit "$SHIMMY_TARGET_CATALOG_STAGED_GENERATION" "$shimmy_target_catalog_publish_previous" \
    "$SHIMMY_TARGET_CATALOG_PUBLICATION_HEAD" "$SHIMMY_TARGET_CATALOG_STAGED_FINGERPRINT" 1 || return 1
  shimmy_target_catalog_lifecycle_cleanup
  shimmy_target_locks_release_all || return 1
  shimmy_target_catalog_tree_validate "$shimmy_target_catalog_publish_config_root"
}

shimmy_target_catalog_default_rollback() {
  shimmy_target_catalog_rollback_config_root=$1
  shimmy_target_catalog_publication_state_read "$shimmy_target_catalog_rollback_config_root" || return 1
  [ -n "$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS" ] || {
    shimmy_target_catalog_error_set 'target default catalog has no retained previous generation'
    return 1
  }
  shimmy_target_lock_acquire catalog "$shimmy_target_catalog_rollback_config_root" || return 1
  shimmy_target_catalog_publication_state_read "$shimmy_target_catalog_rollback_config_root" || return 1
  shimmy_target_catalog_generation_record_validate "$SHIMMY_TARGET_CATALOG_GENERATIONS_ROOT/$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS" "$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS" || return 1
  shimmy_target_catalog_rollback_commit=$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_COMMIT
  shimmy_target_catalog_rollback_fingerprint=$SHIMMY_TARGET_CATALOG_VALIDATED_GENERATION_FINGERPRINT
  if [ "$SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT_VALID" -eq 1 ]; then
    shimmy_target_catalog_rollback_previous=$SHIMMY_TARGET_CATALOG_PUBLICATION_CURRENT
  else
    shimmy_target_catalog_rollback_previous=
  fi
  shimmy_target_catalog_registry_commit "$SHIMMY_TARGET_CATALOG_PUBLICATION_PREVIOUS" "$shimmy_target_catalog_rollback_previous" \
    "$shimmy_target_catalog_rollback_commit" "$shimmy_target_catalog_rollback_fingerprint" 0 || return 1
  shimmy_target_locks_release_all || return 1
  shimmy_target_catalog_tree_validate "$shimmy_target_catalog_rollback_config_root"
}
