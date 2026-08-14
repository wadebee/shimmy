#!/bin/sh
# Atomic registration, rebind, and immutable default-catalog publication.

SHIMMY_CATALOG_LIFECYCLE_LOCK=
SHIMMY_CATALOG_LIFECYCLE_STAGE=
SHIMMY_CATALOG_REBIND_NEW=
SHIMMY_CATALOG_REBIND_PRIOR=

shimmy_catalog_checkout_publication_validate() {
  catalog_publication_checkout=$1

  command -v git >/dev/null 2>&1 || {
    shimmy_catalog_error_set 'Git is required for catalog publication'
    return 1
  }
  catalog_publication_git_root=$(git -C "$catalog_publication_checkout" rev-parse --show-toplevel 2>/dev/null || true)
  [ "$catalog_publication_git_root" = "$catalog_publication_checkout" ] || {
    shimmy_catalog_error_set "catalog publication source must be the root of a Git worktree: $catalog_publication_checkout"
    return 1
  }
  catalog_publication_head=$(shimmy_catalog_git_head_read "$catalog_publication_checkout" || true)
  shimmy_catalog_git_commit_validate "$catalog_publication_head" || {
    shimmy_catalog_error_set "catalog publication source has no readable HEAD: $catalog_publication_checkout"
    return 1
  }
  catalog_publication_dirty=$(git -C "$catalog_publication_checkout" status --porcelain --untracked-files=all 2>/dev/null || printf '%s\n' status-failed)
  [ -z "$catalog_publication_dirty" ] || {
    shimmy_catalog_error_set "refusing to publish catalog from dirty checkout $catalog_publication_checkout; commit all index, worktree, and untracked changes first"
    return 1
  }
  shimmy_catalog_payload_validate "$catalog_publication_checkout" upstream || return 1

  SHIMMY_CATALOG_PUBLICATION_CHECKOUT=$catalog_publication_checkout
  SHIMMY_CATALOG_PUBLICATION_HEAD=$catalog_publication_head
}

shimmy_catalog_checkout_recheck() {
  catalog_publication_head_current=$(shimmy_catalog_git_head_read "$SHIMMY_CATALOG_PUBLICATION_CHECKOUT" || true)
  [ "$catalog_publication_head_current" = "$SHIMMY_CATALOG_PUBLICATION_HEAD" ] || {
    shimmy_catalog_error_set "catalog publication source HEAD changed during publication: $SHIMMY_CATALOG_PUBLICATION_CHECKOUT"
    return 1
  }
  catalog_publication_dirty=$(git -C "$SHIMMY_CATALOG_PUBLICATION_CHECKOUT" status --porcelain --untracked-files=all 2>/dev/null || printf '%s\n' status-failed)
  [ -z "$catalog_publication_dirty" ] || {
    shimmy_catalog_error_set "catalog publication source changed during publication: $SHIMMY_CATALOG_PUBLICATION_CHECKOUT"
    return 1
  }
}

shimmy_catalog_default_initialize() {
  catalog_config_root=$1
  catalog_initial_checkout=$2
  catalog_default_dir=$catalog_config_root/catalogs/default

  [ ! -e "$catalog_default_dir" ] && [ ! -L "$catalog_default_dir" ] || {
    shimmy_catalog_error_set "default catalog is already initialized: $catalog_default_dir"
    return 1
  }
  shimmy_catalog_checkout_publication_validate "$catalog_initial_checkout" || return 1
  shimmy_catalog_lock_acquire "$catalog_config_root" || return 1
  if [ -e "$catalog_default_dir" ] || [ -L "$catalog_default_dir" ]; then
    shimmy_catalog_lock_release
    shimmy_catalog_error_set "default catalog was initialized concurrently: $catalog_default_dir"
    return 1
  fi

  SHIMMY_CATALOG_LIFECYCLE_STAGE=$catalog_config_root/catalogs/.default.stage.$$
  [ ! -e "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] && [ ! -L "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set "catalog staging path already exists: $SHIMMY_CATALOG_LIFECYCLE_STAGE"
    return 1
  }
  mkdir -p "$SHIMMY_CATALOG_LIFECYCLE_STAGE/generations" || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to create default catalog staging directory'
    return 1
  }
  if ! shimmy_catalog_generation_stage "$SHIMMY_CATALOG_LIFECYCLE_STAGE/payload"; then
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    return 1
  fi
  catalog_generation_name=$SHIMMY_CATALOG_STAGED_GENERATION
  mv "$SHIMMY_CATALOG_LIFECYCLE_STAGE/payload" "$SHIMMY_CATALOG_LIFECYCLE_STAGE/generations/$catalog_generation_name" || {
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to stage initial default catalog generation'
    return 1
  }
  shimmy_catalog_registry_generation_render default "$catalog_generation_name" '' "$SHIMMY_CATALOG_PUBLICATION_HEAD" "$SHIMMY_CATALOG_STAGED_FINGERPRINT" > "$SHIMMY_CATALOG_LIFECYCLE_STAGE/registry.conf"
  shimmy__catalog_registry_file_validate "$SHIMMY_CATALOG_LIFECYCLE_STAGE/registry.conf" default || {
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    return 1
  }
  shimmy_catalog_checkout_recheck || {
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    return 1
  }
  mv "$SHIMMY_CATALOG_LIFECYCLE_STAGE" "$catalog_default_dir" || {
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to commit initial default catalog generation'
    return 1
  }
  SHIMMY_CATALOG_LIFECYCLE_STAGE=
  shimmy_catalog_lock_release
  shimmy_catalog_registry_resolve "$catalog_config_root" default
}

shimmy_catalog_default_publish() {
  catalog_config_root=$1
  catalog_default_dir=$catalog_config_root/catalogs/default

  shimmy_catalog_registry_resolve "$catalog_config_root" upstream || return 1
  catalog_publish_checkout=$SHIMMY_CATALOG_SOURCE_PATH
  shimmy_catalog_checkout_publication_validate "$catalog_publish_checkout" || return 1
  shimmy_catalog_registry_resolve "$catalog_config_root" default || return 1

  shimmy_catalog_lock_acquire "$catalog_config_root" || return 1
  shimmy_catalog_registry_resolve "$catalog_config_root" upstream || {
    shimmy_catalog_lock_release
    return 1
  }
  [ "$SHIMMY_CATALOG_SOURCE_PATH" = "$catalog_publish_checkout" ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'upstream catalog binding changed during publication'
    return 1
  }
  shimmy_catalog_registry_resolve "$catalog_config_root" default || {
    shimmy_catalog_lock_release
    return 1
  }
  catalog_previous_current=$SHIMMY_CATALOG_GENERATION
  catalog_previous_rollback=$SHIMMY_CATALOG_GENERATION_PREVIOUS

  SHIMMY_CATALOG_LIFECYCLE_STAGE=$catalog_default_dir/.publish-stage.$$
  [ ! -e "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] && [ ! -L "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set "catalog staging path already exists: $SHIMMY_CATALOG_LIFECYCLE_STAGE"
    return 1
  }
  mkdir "$SHIMMY_CATALOG_LIFECYCLE_STAGE" || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to create default catalog publication staging directory'
    return 1
  }
  if ! shimmy_catalog_generation_stage "$SHIMMY_CATALOG_LIFECYCLE_STAGE/payload"; then
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    return 1
  fi
  catalog_generation_name=$SHIMMY_CATALOG_STAGED_GENERATION
  catalog_generation_target=$catalog_default_dir/generations/$catalog_generation_name
  if [ -e "$catalog_generation_target" ] || [ -L "$catalog_generation_target" ]; then
    [ -d "$catalog_generation_target" ] && [ ! -L "$catalog_generation_target" ] || {
      shimmy_catalog_lifecycle_cleanup
      shimmy_catalog_lock_release
      shimmy_catalog_error_set "catalog generation collision: $catalog_generation_target"
      return 1
    }
    shimmy_catalog_payload_validate "$catalog_generation_target" default || {
      shimmy_catalog_lifecycle_cleanup
      shimmy_catalog_lock_release
      return 1
    }
    catalog_existing_fingerprint=$(shimmy_catalog_fingerprint_render "$catalog_generation_target") || {
      shimmy_catalog_lifecycle_cleanup
      shimmy_catalog_lock_release
      return 1
    }
    [ "$catalog_existing_fingerprint" = "$SHIMMY_CATALOG_STAGED_FINGERPRINT" ] || {
      shimmy_catalog_lifecycle_cleanup
      shimmy_catalog_lock_release
      shimmy_catalog_error_set "catalog generation identity collision: $catalog_generation_name"
      return 1
    }
    rm -rf "$SHIMMY_CATALOG_LIFECYCLE_STAGE/payload"
  fi

  if [ "$catalog_generation_name" = "$catalog_previous_current" ]; then
    catalog_generation_previous=$catalog_previous_rollback
  else
    catalog_generation_previous=$catalog_previous_current
  fi
  catalog_registry_tmp=$catalog_default_dir/.registry.conf.tmp.$$
  [ ! -e "$catalog_registry_tmp" ] && [ ! -L "$catalog_registry_tmp" ] || {
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    shimmy_catalog_error_set "catalog registry temporary path collision: $catalog_registry_tmp"
    return 1
  }
  shimmy_catalog_registry_generation_render default "$catalog_generation_name" "$catalog_generation_previous" "$SHIMMY_CATALOG_PUBLICATION_HEAD" "$SHIMMY_CATALOG_STAGED_FINGERPRINT" > "$catalog_registry_tmp"
  shimmy__catalog_registry_file_validate "$catalog_registry_tmp" default || {
    rm -f "$catalog_registry_tmp"
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    return 1
  }
  shimmy_catalog_checkout_recheck || {
    rm -f "$catalog_registry_tmp"
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    return 1
  }

  if [ -d "$SHIMMY_CATALOG_LIFECYCLE_STAGE/payload" ]; then
    mv "$SHIMMY_CATALOG_LIFECYCLE_STAGE/payload" "$catalog_generation_target" || {
      rm -f "$catalog_registry_tmp"
      shimmy_catalog_lifecycle_cleanup
      shimmy_catalog_lock_release
      shimmy_catalog_error_set 'unable to commit immutable default catalog generation'
      return 1
    }
  fi
  mv "$catalog_registry_tmp" "$catalog_default_dir/registry.conf" || {
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to advance the default catalog current generation'
    return 1
  }
  shimmy_catalog_lifecycle_cleanup
  shimmy_catalog_lock_release
  shimmy_catalog_registry_resolve "$catalog_config_root" default
}

shimmy_catalog_default_rollback() {
  catalog_config_root=$1
  catalog_default_dir=$catalog_config_root/catalogs/default
  catalog_default_registry_file=$catalog_default_dir/registry.conf

  shimmy_catalog_lock_acquire "$catalog_config_root" || return 1
  shimmy__catalog_registry_file_validate "$catalog_default_registry_file" default || {
    shimmy_catalog_lock_release
    return 1
  }
  [ "$SHIMMY_CATALOG_SOURCE_TYPE" = generation ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'default catalog registry must use generation source type'
    return 1
  }

  catalog_current_generation=$(shimmy__catalog_config_value_read "$catalog_default_registry_file" catalog_generation_current)
  catalog_rollback_generation=$(shimmy__catalog_config_value_read "$catalog_default_registry_file" catalog_generation_previous)
  [ -n "$catalog_rollback_generation" ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'default catalog has no retained previous generation to roll back to'
    return 1
  }
  shimmy_catalog_generation_record_validate "$catalog_default_dir/generations/$catalog_rollback_generation" "$catalog_rollback_generation" || {
    shimmy_catalog_lock_release
    return 1
  }
  catalog_rollback_commit=$SHIMMY_CATALOG_VALIDATED_GENERATION_COMMIT
  catalog_rollback_fingerprint=$SHIMMY_CATALOG_VALIDATED_GENERATION_FINGERPRINT

  catalog_new_previous=
  if shimmy_catalog_generation_record_validate "$catalog_default_dir/generations/$catalog_current_generation" "$catalog_current_generation"; then
    catalog_new_previous=$catalog_current_generation
  fi

  catalog_registry_tmp=$catalog_default_dir/.registry.conf.tmp.$$
  [ ! -e "$catalog_registry_tmp" ] && [ ! -L "$catalog_registry_tmp" ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set "catalog registry temporary path collision: $catalog_registry_tmp"
    return 1
  }
  shimmy_catalog_registry_generation_render default "$catalog_rollback_generation" "$catalog_new_previous" "$catalog_rollback_commit" "$catalog_rollback_fingerprint" > "$catalog_registry_tmp"
  shimmy__catalog_registry_file_validate "$catalog_registry_tmp" default || {
    rm -f "$catalog_registry_tmp"
    shimmy_catalog_lock_release
    return 1
  }
  mv "$catalog_registry_tmp" "$catalog_default_registry_file" || {
    rm -f "$catalog_registry_tmp"
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to atomically roll back the default catalog generation'
    return 1
  }
  shimmy_catalog_lock_release
  shimmy_catalog_registry_resolve "$catalog_config_root" default
}

shimmy_catalog_generation_stage() {
  catalog_generation_stage=$1
  catalog_generation_archive=$SHIMMY_CATALOG_LIFECYCLE_STAGE/catalog.tar

  mkdir "$catalog_generation_stage" || {
    shimmy_catalog_error_set 'unable to create catalog generation payload staging directory'
    return 1
  }
  git -C "$SHIMMY_CATALOG_PUBLICATION_CHECKOUT" archive --format=tar --output="$catalog_generation_archive" "$SHIMMY_CATALOG_PUBLICATION_HEAD" catalog.conf tools plugins/shimmy/skills 2>/dev/null || {
    shimmy_catalog_error_set 'unable to materialize tracked catalog payload from the recorded HEAD'
    return 1
  }
  tar -xf "$catalog_generation_archive" -C "$catalog_generation_stage" || {
    shimmy_catalog_error_set 'unable to extract tracked catalog payload into staging'
    return 1
  }
  rm -f "$catalog_generation_archive"
  shimmy_catalog_payload_validate "$catalog_generation_stage" default || return 1
  SHIMMY_CATALOG_STAGED_FINGERPRINT=$(shimmy_catalog_fingerprint_render "$catalog_generation_stage") || return 1
  SHIMMY_CATALOG_STAGED_GENERATION=$(shimmy_catalog_generation_name_render "$SHIMMY_CATALOG_STAGED_FINGERPRINT") || return 1
  {
    printf 'catalog_source_commit=%s\n' "$SHIMMY_CATALOG_PUBLICATION_HEAD"
    printf 'catalog_content_fingerprint=%s\n' "$SHIMMY_CATALOG_STAGED_FINGERPRINT"
  } > "$catalog_generation_stage/generation.conf"
  chmod 644 "$catalog_generation_stage/generation.conf"
  shimmy__catalog_generation_metadata_validate "$catalog_generation_stage"
}

shimmy_catalog_generation_record_validate() {
  catalog_generation_root=$1
  catalog_generation_name=$2

  shimmy_catalog_generation_name_validate "$catalog_generation_name" || {
    shimmy_catalog_error_set "invalid catalog generation name: $catalog_generation_name"
    return 1
  }
  shimmy_catalog_payload_validate "$catalog_generation_root" default || return 1
  shimmy__catalog_generation_metadata_validate "$catalog_generation_root" || return 1
  catalog_generation_commit=$(shimmy__catalog_config_value_read "$catalog_generation_root/generation.conf" catalog_source_commit)
  catalog_generation_fingerprint=$(shimmy__catalog_config_value_read "$catalog_generation_root/generation.conf" catalog_content_fingerprint)
  [ "$(shimmy_catalog_generation_name_render "$catalog_generation_fingerprint")" = "$catalog_generation_name" ] || {
    shimmy_catalog_error_set "catalog generation metadata does not match its name: $catalog_generation_name"
    return 1
  }
  catalog_generation_resolved_fingerprint=$(shimmy_catalog_fingerprint_render "$catalog_generation_root") || return 1
  [ "$catalog_generation_resolved_fingerprint" = "$catalog_generation_fingerprint" ] || {
    shimmy_catalog_error_set "catalog generation content fingerprint mismatch: $catalog_generation_name"
    return 1
  }
  SHIMMY_CATALOG_VALIDATED_GENERATION_COMMIT=$catalog_generation_commit
  SHIMMY_CATALOG_VALIDATED_GENERATION_FINGERPRINT=$catalog_generation_fingerprint
}

shimmy_catalog_lifecycle_cleanup() {
  [ -n "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] || return 0
  case "$SHIMMY_CATALOG_LIFECYCLE_STAGE" in
    */catalogs/.default.stage.*|*/catalogs/default/.publish-stage.*|*/catalogs/.upstream.stage.*)
      [ ! -e "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] && [ ! -L "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] || rm -rf "$SHIMMY_CATALOG_LIFECYCLE_STAGE"
      ;;
  esac
  SHIMMY_CATALOG_LIFECYCLE_STAGE=
}

shimmy_catalog_lock_acquire() {
  catalog_config_root=$1
  catalog_catalogs_root=$catalog_config_root/catalogs
  case "$catalog_catalogs_root" in /*/shimmy/catalogs) ;; *) shimmy_catalog_error_set "unsafe catalog registry root: $catalog_catalogs_root"; return 1 ;; esac
  shimmy_catalog_path_parent_chain_validate "$catalog_catalogs_root" || {
    shimmy_catalog_error_set "catalog registry root has a symbolic-link path component: $catalog_catalogs_root"
    return 1
  }
  mkdir -p "$catalog_catalogs_root" || {
    shimmy_catalog_error_set "unable to create catalog registry root: $catalog_catalogs_root"
    return 1
  }
  SHIMMY_CATALOG_LIFECYCLE_LOCK=$catalog_catalogs_root/.catalog-transaction-lock
  mkdir "$SHIMMY_CATALOG_LIFECYCLE_LOCK" 2>/dev/null || {
    shimmy_catalog_error_set "another catalog transaction is active: $SHIMMY_CATALOG_LIFECYCLE_LOCK"
    SHIMMY_CATALOG_LIFECYCLE_LOCK=
    return 1
  }
  printf '%s\n' "$$" > "$SHIMMY_CATALOG_LIFECYCLE_LOCK/pid"
}

shimmy_catalog_lock_release() {
  [ -n "$SHIMMY_CATALOG_LIFECYCLE_LOCK" ] || return 0
  case "$SHIMMY_CATALOG_LIFECYCLE_LOCK" in */shimmy/catalogs/.catalog-transaction-lock) ;; *) return 1 ;; esac
  rm -f "$SHIMMY_CATALOG_LIFECYCLE_LOCK/pid"
  rmdir "$SHIMMY_CATALOG_LIFECYCLE_LOCK" 2>/dev/null || true
  SHIMMY_CATALOG_LIFECYCLE_LOCK=
}

shimmy_catalog_owned_state_remove() {
  catalog_config_root=$1
  catalog_catalogs_root=$catalog_config_root/catalogs

  [ -e "$catalog_catalogs_root" ] || [ -L "$catalog_catalogs_root" ] || return 0
  shimmy_catalog_owned_state_validate "$catalog_config_root" 0 || return 1
  shimmy_catalog_lock_acquire "$catalog_config_root" || return 1
  shimmy_catalog_owned_state_validate "$catalog_config_root" 1 || {
    shimmy_catalog_lock_release
    return 1
  }
  for catalog_name in default upstream; do
    catalog_owned_dir=$catalog_catalogs_root/$catalog_name
    [ -e "$catalog_owned_dir" ] || [ -L "$catalog_owned_dir" ] || continue
    rm -rf "$catalog_owned_dir" || {
      shimmy_catalog_lock_release
      shimmy_catalog_error_set "unable to remove owned catalog state: $catalog_owned_dir"
      return 1
    }
  done
  shimmy_catalog_lock_release
  rmdir "$catalog_catalogs_root" 2>/dev/null || true
}

shimmy_catalog_owned_state_validate() {
  catalog_config_root=$1
  catalog_allow_lock=${2:-0}
  catalog_catalogs_root=$catalog_config_root/catalogs

  [ -e "$catalog_catalogs_root" ] || [ -L "$catalog_catalogs_root" ] || return 0
  [ -d "$catalog_catalogs_root" ] && [ ! -L "$catalog_catalogs_root" ] || {
    shimmy_catalog_error_set "shared catalog root must be a regular directory: $catalog_catalogs_root"
    return 1
  }
  shimmy_catalog_path_parent_chain_validate "$catalog_catalogs_root" || {
    shimmy_catalog_error_set "catalog registry root has a symbolic-link path component: $catalog_catalogs_root"
    return 1
  }

  for catalog_owned_entry in "$catalog_catalogs_root"/* "$catalog_catalogs_root"/.[!.]* "$catalog_catalogs_root"/..?*; do
    [ -e "$catalog_owned_entry" ] || [ -L "$catalog_owned_entry" ] || continue
    catalog_owned_name=$(basename -- "$catalog_owned_entry")
    case "$catalog_owned_name" in
      default|upstream) ;;
      .catalog-transaction-lock)
        [ "$catalog_allow_lock" -eq 1 ] || {
          shimmy_catalog_error_set "refusing global uninstall while a catalog transaction is active: $catalog_owned_entry"
          return 1
        }
        continue
        ;;
      *)
        shimmy_catalog_error_set "refusing to remove unrecognized shared catalog state: $catalog_owned_entry"
        return 1
        ;;
    esac
    [ -d "$catalog_owned_entry" ] && [ ! -L "$catalog_owned_entry" ] || {
      shimmy_catalog_error_set "catalog registry entry must be a regular directory: $catalog_owned_entry"
      return 1
    }
  done

  catalog_upstream_dir=$catalog_catalogs_root/upstream
  if [ -e "$catalog_upstream_dir" ] || [ -L "$catalog_upstream_dir" ]; then
    for catalog_owned_entry in "$catalog_upstream_dir"/* "$catalog_upstream_dir"/.[!.]* "$catalog_upstream_dir"/..?*; do
      [ -e "$catalog_owned_entry" ] || [ -L "$catalog_owned_entry" ] || continue
      [ "$catalog_owned_entry" = "$catalog_upstream_dir/registry.conf" ] || {
        shimmy_catalog_error_set "refusing to remove unrecognized upstream catalog state: $catalog_owned_entry"
        return 1
      }
    done
    shimmy__catalog_registry_file_validate "$catalog_upstream_dir/registry.conf" upstream || return 1
    [ "$SHIMMY_CATALOG_SOURCE_TYPE" = checkout ] || {
      shimmy_catalog_error_set 'upstream catalog registry must use checkout source type'
      return 1
    }
    catalog_owned_source=$(shimmy__catalog_config_value_read "$catalog_upstream_dir/registry.conf" catalog_source_path)
    case "$catalog_owned_source" in /*) ;; *) shimmy_catalog_error_set "upstream catalog records a relative checkout path: $catalog_owned_source"; return 1 ;; esac
  fi

  catalog_default_dir=$catalog_catalogs_root/default
  if [ -e "$catalog_default_dir" ] || [ -L "$catalog_default_dir" ]; then
    for catalog_owned_entry in "$catalog_default_dir"/* "$catalog_default_dir"/.[!.]* "$catalog_default_dir"/..?*; do
      [ -e "$catalog_owned_entry" ] || [ -L "$catalog_owned_entry" ] || continue
      case "$catalog_owned_entry" in
        "$catalog_default_dir/registry.conf"|"$catalog_default_dir/generations") ;;
        *) shimmy_catalog_error_set "refusing to remove unrecognized default catalog state: $catalog_owned_entry"; return 1 ;;
      esac
    done
    shimmy__catalog_registry_file_validate "$catalog_default_dir/registry.conf" default || return 1
    [ "$SHIMMY_CATALOG_SOURCE_TYPE" = generation ] || {
      shimmy_catalog_error_set 'default catalog registry must use generation source type'
      return 1
    }
    [ -d "$catalog_default_dir/generations" ] && [ ! -L "$catalog_default_dir/generations" ] || {
      shimmy_catalog_error_set "default catalog generations must be a regular directory: $catalog_default_dir/generations"
      return 1
    }
    for catalog_generation_dir in "$catalog_default_dir"/generations/*; do
      [ -e "$catalog_generation_dir" ] || [ -L "$catalog_generation_dir" ] || continue
      [ -d "$catalog_generation_dir" ] && [ ! -L "$catalog_generation_dir" ] || {
        shimmy_catalog_error_set "catalog generation must be a regular directory: $catalog_generation_dir"
        return 1
      }
      catalog_generation_name=$(basename -- "$catalog_generation_dir")
      shimmy_catalog_generation_name_validate "$catalog_generation_name" || {
        shimmy_catalog_error_set "unsafe catalog generation directory: $catalog_generation_name"
        return 1
      }
      shimmy__catalog_generation_metadata_validate "$catalog_generation_dir" || return 1
      catalog_generation_fingerprint=$(shimmy__catalog_config_value_read "$catalog_generation_dir/generation.conf" catalog_content_fingerprint)
      [ "$(shimmy_catalog_generation_name_render "$catalog_generation_fingerprint")" = "$catalog_generation_name" ] || {
        shimmy_catalog_error_set "catalog generation metadata does not match its directory: $catalog_generation_name"
        return 1
      }
    done
  fi
}

shimmy_catalog_registry_checkout_render() {
  catalog_registry_checkout_name=$1
  catalog_registry_checkout_path=$2

  printf 'catalog_name=%s\n' "$catalog_registry_checkout_name"
  printf 'catalog_source_type=checkout\n'
  printf 'catalog_source_path=%s\n' "$catalog_registry_checkout_path"
}

shimmy_catalog_registry_generation_render() {
  catalog_registry_generation_name=$1
  catalog_registry_generation_current=$2
  catalog_registry_generation_previous=$3
  catalog_registry_generation_commit=$4
  catalog_registry_generation_fingerprint=$5

  printf 'catalog_name=%s\n' "$catalog_registry_generation_name"
  printf 'catalog_source_type=generation\n'
  printf 'catalog_generation_current=%s\n' "$catalog_registry_generation_current"
  printf 'catalog_generation_previous=%s\n' "$catalog_registry_generation_previous"
  printf 'catalog_source_commit=%s\n' "$catalog_registry_generation_commit"
  printf 'catalog_content_fingerprint=%s\n' "$catalog_registry_generation_fingerprint"
}

shimmy_catalog_upstream_rebind() {
  catalog_config_root=$1
  catalog_rebind_checkout=$2
  catalog_upstream_dir=$catalog_config_root/catalogs/upstream
  catalog_upstream_registry=$catalog_upstream_dir/registry.conf

  catalog_rebind_checkout=$(shimmy_resolve_path_absolute "$catalog_rebind_checkout") || {
    shimmy_catalog_error_set "unable to resolve replacement upstream checkout: $2"
    return 1
  }
  shimmy_catalog_checkout_resolve "$catalog_rebind_checkout" upstream || return 1
  shimmy_catalog_git_commit_validate "$SHIMMY_CATALOG_SOURCE_COMMIT" || {
    shimmy_catalog_error_set "replacement upstream catalog must be a Git checkout with a readable HEAD: $catalog_rebind_checkout"
    return 1
  }
  shimmy_catalog_lock_acquire "$catalog_config_root" || return 1
  shimmy__catalog_registry_file_validate "$catalog_upstream_registry" upstream || {
    shimmy_catalog_lock_release
    return 1
  }
  [ "$SHIMMY_CATALOG_SOURCE_TYPE" = checkout ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'upstream catalog registry must use checkout source type'
    return 1
  }
  SHIMMY_CATALOG_REBIND_PRIOR=$(shimmy__catalog_config_value_read "$catalog_upstream_registry" catalog_source_path)
  SHIMMY_CATALOG_REBIND_NEW=$catalog_rebind_checkout
  catalog_registry_tmp=$catalog_upstream_dir/.registry.conf.tmp.$$
  [ ! -e "$catalog_registry_tmp" ] && [ ! -L "$catalog_registry_tmp" ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set "catalog registry temporary path collision: $catalog_registry_tmp"
    return 1
  }
  shimmy_catalog_registry_checkout_render upstream "$catalog_rebind_checkout" > "$catalog_registry_tmp"
  shimmy__catalog_registry_file_validate "$catalog_registry_tmp" upstream || {
    rm -f "$catalog_registry_tmp"
    shimmy_catalog_lock_release
    return 1
  }
  mv "$catalog_registry_tmp" "$catalog_upstream_registry" || {
    rm -f "$catalog_registry_tmp"
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to atomically replace the upstream catalog binding'
    return 1
  }
  shimmy_catalog_lock_release
  shimmy_catalog_registry_resolve "$catalog_config_root" upstream
}

shimmy_catalog_upstream_register() {
  catalog_config_root=$1
  catalog_register_checkout=$2
  catalog_upstream_dir=$catalog_config_root/catalogs/upstream

  catalog_register_checkout=$(shimmy_resolve_path_absolute "$catalog_register_checkout") || {
    shimmy_catalog_error_set "unable to resolve upstream checkout: $2"
    return 1
  }
  shimmy_catalog_checkout_resolve "$catalog_register_checkout" upstream || return 1
  shimmy_catalog_git_commit_validate "$SHIMMY_CATALOG_SOURCE_COMMIT" || {
    shimmy_catalog_error_set "upstream catalog must be a Git checkout with a readable HEAD: $catalog_register_checkout"
    return 1
  }
  if [ -f "$catalog_upstream_dir/registry.conf" ] && [ ! -L "$catalog_upstream_dir/registry.conf" ]; then
    shimmy__catalog_registry_file_validate "$catalog_upstream_dir/registry.conf" upstream || return 1
    catalog_registered_path=$(shimmy__catalog_config_value_read "$catalog_upstream_dir/registry.conf" catalog_source_path)
    [ "$catalog_registered_path" = "$catalog_register_checkout" ] || {
      shimmy_catalog_error_set "upstream catalog is already bound to $catalog_registered_path; use 'shimmy catalog rebind --checkout $catalog_register_checkout' for an explicit replacement"
      return 1
    }
    shimmy_catalog_registry_resolve "$catalog_config_root" upstream
    return
  fi
  [ ! -e "$catalog_upstream_dir" ] && [ ! -L "$catalog_upstream_dir" ] || {
    shimmy_catalog_error_set "refusing to register upstream catalog over unmanaged or incomplete state: $catalog_upstream_dir"
    return 1
  }

  shimmy_catalog_lock_acquire "$catalog_config_root" || return 1
  if [ -e "$catalog_upstream_dir" ] || [ -L "$catalog_upstream_dir" ]; then
    shimmy_catalog_lock_release
    shimmy_catalog_error_set "upstream catalog was registered concurrently: $catalog_upstream_dir"
    return 1
  fi
  SHIMMY_CATALOG_LIFECYCLE_STAGE=$catalog_config_root/catalogs/.upstream.stage.$$
  [ ! -e "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] && [ ! -L "$SHIMMY_CATALOG_LIFECYCLE_STAGE" ] || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set "catalog staging path already exists: $SHIMMY_CATALOG_LIFECYCLE_STAGE"
    return 1
  }
  mkdir "$SHIMMY_CATALOG_LIFECYCLE_STAGE" || {
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to create upstream catalog registration staging directory'
    return 1
  }
  shimmy_catalog_registry_checkout_render upstream "$catalog_register_checkout" > "$SHIMMY_CATALOG_LIFECYCLE_STAGE/registry.conf"
  shimmy__catalog_registry_file_validate "$SHIMMY_CATALOG_LIFECYCLE_STAGE/registry.conf" upstream || {
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    return 1
  }
  mv "$SHIMMY_CATALOG_LIFECYCLE_STAGE" "$catalog_upstream_dir" || {
    shimmy_catalog_lifecycle_cleanup
    shimmy_catalog_lock_release
    shimmy_catalog_error_set 'unable to atomically register upstream catalog'
    return 1
  }
  SHIMMY_CATALOG_LIFECYCLE_STAGE=
  shimmy_catalog_lock_release
  shimmy_catalog_registry_resolve "$catalog_config_root" upstream
}
