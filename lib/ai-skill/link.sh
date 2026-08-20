#!/bin/sh
# Private target exact-name AI-skill link planning and mutation.

SHIMMY_TARGET_AI_SKILL_LINK_SEQUENCE=0

shimmy_target_ai_skill_link_bundle_skill_resolve() {
  shimmy_target_ai_skill_link_profiles_root=$1
  shimmy_target_ai_skill_link_bundle_root=$2
  shimmy_target_ai_skill_link_name=$3
  shimmy_path_absolute_normalized_validate "$shimmy_target_ai_skill_link_profiles_root" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_target_ai_skill_link_bundle_root" || return 1
  shimmy_name_component_validate "$shimmy_target_ai_skill_link_name" || return 1
  [ -d "$shimmy_target_ai_skill_link_profiles_root" ] && [ ! -L "$shimmy_target_ai_skill_link_profiles_root" ] &&
    shimmy_path_parent_chain_validate "$shimmy_target_ai_skill_link_profiles_root" || return 1
  shimmy_path_parent_chain_validate "$shimmy_target_ai_skill_link_bundle_root" || return 1
  shimmy_target_ai_skill_bundle_read "$shimmy_target_ai_skill_link_bundle_root" || return 1
  shimmy_target_ai_skill_link_profile=$SHIMMY_TARGET_AI_SKILL_PROFILE_NAME
  shimmy_target_ai_skill_link_kind=$SHIMMY_TARGET_AI_SKILL_BUNDLE_KIND
  shimmy_target_ai_skill_link_expected_bundle=$shimmy_target_ai_skill_link_profiles_root/$shimmy_target_ai_skill_link_profile/ai-skills/$shimmy_target_ai_skill_link_kind
  [ "$shimmy_target_ai_skill_link_bundle_root" = "$shimmy_target_ai_skill_link_expected_bundle" ] || return 1

  shimmy_target_ai_skill_link_declared=0
  while IFS= read -r shimmy_target_ai_skill_link_record; do
    [ -n "$shimmy_target_ai_skill_link_record" ] || continue
    [ "${shimmy_target_ai_skill_link_record%%|*}" = "$shimmy_target_ai_skill_link_name" ] || continue
    shimmy_target_ai_skill_link_declared=1
    break
  done <<EOF
$SHIMMY_TARGET_AI_SKILL_RECORDS
EOF
  [ "$shimmy_target_ai_skill_link_declared" -eq 1 ] || return 1
  SHIMMY_TARGET_AI_SKILL_LINK_SOURCE=$shimmy_target_ai_skill_link_bundle_root/skills/$shimmy_target_ai_skill_link_name
  [ -d "$SHIMMY_TARGET_AI_SKILL_LINK_SOURCE" ] && [ ! -L "$SHIMMY_TARGET_AI_SKILL_LINK_SOURCE" ] || return 1
}

shimmy_target_ai_skill_link_target_classify() {
  shimmy_target_ai_skill_link_classify_target=$1
  shimmy_target_ai_skill_link_classify_profiles_root=$2
  shimmy_target_ai_skill_link_classify_name=$3
  shimmy_target_ai_skill_link_classify_expected=$4

  SHIMMY_TARGET_AI_SKILL_LINK_TARGET=
  if [ -L "$shimmy_target_ai_skill_link_classify_target" ]; then
    SHIMMY_TARGET_AI_SKILL_LINK_TARGET=$(readlink "$shimmy_target_ai_skill_link_classify_target") || return 1
    shimmy_target_ai_skill_link_target_exists=1
    [ -e "$shimmy_target_ai_skill_link_classify_target" ] || shimmy_target_ai_skill_link_target_exists=0
    if [ "$SHIMMY_TARGET_AI_SKILL_LINK_TARGET" = "$shimmy_target_ai_skill_link_classify_expected" ]; then
      if [ "$shimmy_target_ai_skill_link_target_exists" -eq 1 ]; then
        SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=shimmy-link-current
      else
        SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=shimmy-link-current-broken
      fi
      return 0
    fi
    case "$SHIMMY_TARGET_AI_SKILL_LINK_TARGET" in
      "$shimmy_target_ai_skill_link_classify_profiles_root"/*)
        shimmy_target_ai_skill_link_target_remainder=${SHIMMY_TARGET_AI_SKILL_LINK_TARGET#"$shimmy_target_ai_skill_link_classify_profiles_root"/}
        shimmy_target_ai_skill_link_target_profile=${shimmy_target_ai_skill_link_target_remainder%%/*}
        shimmy_target_ai_skill_link_target_suffix=${shimmy_target_ai_skill_link_target_remainder#*/}
        case "$shimmy_target_ai_skill_link_target_suffix" in
          ai-skills/control/skills/"$shimmy_target_ai_skill_link_classify_name"|ai-skills/shims/skills/"$shimmy_target_ai_skill_link_classify_name") ;;
          *) shimmy_target_ai_skill_link_target_suffix= ;;
        esac
        if [ -n "$shimmy_target_ai_skill_link_target_suffix" ] &&
          shimmy_name_component_validate "$shimmy_target_ai_skill_link_target_profile" &&
          shimmy_path_absolute_normalized_validate "$SHIMMY_TARGET_AI_SKILL_LINK_TARGET"; then
          if [ "$shimmy_target_ai_skill_link_target_exists" -eq 1 ]; then
            SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=shimmy-link-wrong-profile
          else
            SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=shimmy-link-wrong-profile-broken
          fi
          return 0
        fi
        ;;
    esac
    if [ "$shimmy_target_ai_skill_link_target_exists" -eq 1 ]; then
      SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=foreign-link
    else
      SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=foreign-link-broken
    fi
    return 0
  fi
  if [ -f "$shimmy_target_ai_skill_link_classify_target" ]; then
    SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=file
    return 0
  fi
  if [ -d "$shimmy_target_ai_skill_link_classify_target" ]; then
    SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=directory-empty
    for shimmy_target_ai_skill_link_directory_entry in \
      "$shimmy_target_ai_skill_link_classify_target"/* \
      "$shimmy_target_ai_skill_link_classify_target"/.[!.]* \
      "$shimmy_target_ai_skill_link_classify_target"/..?*; do
      [ -e "$shimmy_target_ai_skill_link_directory_entry" ] || [ -L "$shimmy_target_ai_skill_link_directory_entry" ] || continue
      SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=directory-nonempty
      break
    done
    return 0
  fi
  if [ -e "$shimmy_target_ai_skill_link_classify_target" ]; then
    SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=special
    return 0
  fi
  SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION=empty
}

shimmy_target_ai_skill_link_plan() {
  shimmy_target_ai_skill_link_user_root=$1
  shimmy_target_ai_skill_link_profiles_root=$2
  shimmy_target_ai_skill_link_bundle_root=$3
  shimmy_target_ai_skill_link_name=$4
  shimmy_path_absolute_normalized_validate "$shimmy_target_ai_skill_link_user_root" || return 1
  [ -d "$shimmy_target_ai_skill_link_user_root" ] && [ ! -L "$shimmy_target_ai_skill_link_user_root" ] &&
    shimmy_path_parent_chain_validate "$shimmy_target_ai_skill_link_user_root" || return 1
  shimmy_target_ai_skill_link_bundle_skill_resolve "$shimmy_target_ai_skill_link_profiles_root" "$shimmy_target_ai_skill_link_bundle_root" "$shimmy_target_ai_skill_link_name" || return 1
  SHIMMY_TARGET_AI_SKILL_LINK_DESTINATION=$shimmy_target_ai_skill_link_user_root/$shimmy_target_ai_skill_link_name
  [ "$SHIMMY_TARGET_AI_SKILL_LINK_DESTINATION" != "$shimmy_target_ai_skill_link_user_root" ] || return 1
  shimmy_target_ai_skill_link_target_classify \
    "$SHIMMY_TARGET_AI_SKILL_LINK_DESTINATION" \
    "$shimmy_target_ai_skill_link_profiles_root" \
    "$shimmy_target_ai_skill_link_name" \
    "$SHIMMY_TARGET_AI_SKILL_LINK_SOURCE"
}

shimmy_target_ai_skill_link_rollback() {
  shimmy_target_ai_skill_link_rollback_destination=$1
  shimmy_target_ai_skill_link_rollback_prior=$2
  shimmy_target_ai_skill_link_rollback_committed=$3
  shimmy_path_absolute_normalized_validate "$shimmy_target_ai_skill_link_rollback_destination" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_target_ai_skill_link_rollback_committed" || return 1
  case "$shimmy_target_ai_skill_link_rollback_prior" in
    absent) ;;
    *) shimmy_path_absolute_normalized_validate "$shimmy_target_ai_skill_link_rollback_prior" || return 1 ;;
  esac
  if [ -L "$shimmy_target_ai_skill_link_rollback_destination" ]; then
    [ "$(readlink "$shimmy_target_ai_skill_link_rollback_destination")" = "$shimmy_target_ai_skill_link_rollback_committed" ] || return 1
  elif [ -e "$shimmy_target_ai_skill_link_rollback_destination" ]; then
    return 1
  fi
  if [ "$shimmy_target_ai_skill_link_rollback_prior" = absent ]; then
    [ ! -L "$shimmy_target_ai_skill_link_rollback_destination" ] || rm -f "$shimmy_target_ai_skill_link_rollback_destination"
    return 0
  fi
  shimmy_target_ai_skill_link_rollback_stage=$(dirname -- "$shimmy_target_ai_skill_link_rollback_destination")/."$(basename -- "$shimmy_target_ai_skill_link_rollback_destination")".shimmy-rollback.$$
  [ ! -e "$shimmy_target_ai_skill_link_rollback_stage" ] && [ ! -L "$shimmy_target_ai_skill_link_rollback_stage" ] || return 1
  ln -s "$shimmy_target_ai_skill_link_rollback_prior" "$shimmy_target_ai_skill_link_rollback_stage" || return 1
  if [ -L "$shimmy_target_ai_skill_link_rollback_destination" ]; then
    rm -f "$shimmy_target_ai_skill_link_rollback_destination" || {
      rm -f "$shimmy_target_ai_skill_link_rollback_stage"
      return 1
    }
  fi
  mv "$shimmy_target_ai_skill_link_rollback_stage" "$shimmy_target_ai_skill_link_rollback_destination" || {
    rm -f "$shimmy_target_ai_skill_link_rollback_stage"
    return 1
  }
}

shimmy_target_ai_skill_link_replace() {
  shimmy_target_ai_skill_link_replace_user_root=$1
  shimmy_target_ai_skill_link_replace_profiles_root=$2
  shimmy_target_ai_skill_link_replace_bundle_root=$3
  shimmy_target_ai_skill_link_replace_name=$4
  [ "$SHIMMY_TARGET_EXTERNAL_TRANSACTION_ACTIVE" -eq 1 ] || return 1
  shimmy_target_ai_skill_link_plan \
    "$shimmy_target_ai_skill_link_replace_user_root" \
    "$shimmy_target_ai_skill_link_replace_profiles_root" \
    "$shimmy_target_ai_skill_link_replace_bundle_root" \
    "$shimmy_target_ai_skill_link_replace_name" || return 1
  shimmy_target_ai_skill_link_replace_destination=$SHIMMY_TARGET_AI_SKILL_LINK_DESTINATION
  shimmy_target_ai_skill_link_replace_source=$SHIMMY_TARGET_AI_SKILL_LINK_SOURCE
  shimmy_target_ai_skill_link_replace_classification=$SHIMMY_TARGET_AI_SKILL_LINK_CLASSIFICATION
  shimmy_target_ai_skill_link_replace_prior_target=$SHIMMY_TARGET_AI_SKILL_LINK_TARGET
  [ "$shimmy_target_ai_skill_link_replace_classification" != special ] || return 1
  [ "$shimmy_target_ai_skill_link_replace_classification" != shimmy-link-current ] || return 0
  [ "$shimmy_target_ai_skill_link_replace_destination" = "$shimmy_target_ai_skill_link_replace_user_root/$shimmy_target_ai_skill_link_replace_name" ] &&
    [ "$shimmy_target_ai_skill_link_replace_destination" != "$shimmy_target_ai_skill_link_replace_user_root" ] || return 1

  SHIMMY_TARGET_AI_SKILL_LINK_SEQUENCE=$((SHIMMY_TARGET_AI_SKILL_LINK_SEQUENCE + 1))
  shimmy_target_ai_skill_link_replace_stage=$shimmy_target_ai_skill_link_replace_user_root/."$shimmy_target_ai_skill_link_replace_name".shimmy-link.$$.$SHIMMY_TARGET_AI_SKILL_LINK_SEQUENCE
  [ ! -e "$shimmy_target_ai_skill_link_replace_stage" ] && [ ! -L "$shimmy_target_ai_skill_link_replace_stage" ] || return 1
  ln -s "$shimmy_target_ai_skill_link_replace_source" "$shimmy_target_ai_skill_link_replace_stage" || return 1
  shimmy_target_ai_skill_link_replace_journal_before=$SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS
  shimmy_target_ai_skill_link_replace_registration_status=0

  case "$shimmy_target_ai_skill_link_replace_classification" in
    empty)
      shimmy_target_external_rollback_register \
        "$shimmy_target_ai_skill_link_replace_destination" \
        shimmy_target_ai_skill_link_rollback absent \
        "$shimmy_target_ai_skill_link_replace_source" 'remove newly projected link' || shimmy_target_ai_skill_link_replace_registration_status=1
      ;;
    shimmy-link-current-broken|shimmy-link-wrong-profile|shimmy-link-wrong-profile-broken)
      shimmy_target_external_rollback_register \
        "$shimmy_target_ai_skill_link_replace_destination" \
        shimmy_target_ai_skill_link_rollback "$shimmy_target_ai_skill_link_replace_prior_target" \
        "$shimmy_target_ai_skill_link_replace_source" 'restore prior recognized Shimmy link' || shimmy_target_ai_skill_link_replace_registration_status=1
      ;;
    file|directory-empty|directory-nonempty|foreign-link|foreign-link-broken)
      shimmy_target_external_irrecoverable_register \
        "$shimmy_target_ai_skill_link_replace_destination" \
        "exact bundle destination previously contained $shimmy_target_ai_skill_link_replace_classification" || shimmy_target_ai_skill_link_replace_registration_status=1
      if [ "$shimmy_target_ai_skill_link_replace_registration_status" -eq 0 ]; then
        shimmy_target_external_rollback_register \
          "$shimmy_target_ai_skill_link_replace_destination" \
          shimmy_target_ai_skill_link_rollback absent \
          "$shimmy_target_ai_skill_link_replace_source" 'remove newly projected link; foreign content remains unrecoverable' || shimmy_target_ai_skill_link_replace_registration_status=1
      fi
      ;;
    *) shimmy_target_ai_skill_link_replace_registration_status=1 ;;
  esac
  if [ "$shimmy_target_ai_skill_link_replace_registration_status" -ne 0 ]; then
    SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS=$shimmy_target_ai_skill_link_replace_journal_before
    rm -f "$shimmy_target_ai_skill_link_replace_stage"
    return 1
  fi

  if [ -L "$shimmy_target_ai_skill_link_replace_destination" ] || [ -f "$shimmy_target_ai_skill_link_replace_destination" ]; then
    rm -f "$shimmy_target_ai_skill_link_replace_destination" || {
      SHIMMY_TARGET_EXTERNAL_ROLLBACK_RECORDS=$shimmy_target_ai_skill_link_replace_journal_before
      rm -f "$shimmy_target_ai_skill_link_replace_stage"
      return 1
    }
  elif [ -d "$shimmy_target_ai_skill_link_replace_destination" ]; then
    rm -rf "$shimmy_target_ai_skill_link_replace_destination" || {
      rm -f "$shimmy_target_ai_skill_link_replace_stage"
      return 1
    }
  elif [ -e "$shimmy_target_ai_skill_link_replace_destination" ]; then
    rm -f "$shimmy_target_ai_skill_link_replace_stage"
    return 1
  fi
  mv "$shimmy_target_ai_skill_link_replace_stage" "$shimmy_target_ai_skill_link_replace_destination" || {
    rm -f "$shimmy_target_ai_skill_link_replace_stage"
    return 1
  }
}
