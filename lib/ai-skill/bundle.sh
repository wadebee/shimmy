#!/bin/sh
# Private target AI-skill bundle schema and content validation.

SHIMMY_TARGET_AI_SKILL_MANAGED_HEADER='> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.'

shimmy_target_ai_skill_control_names_render() {
  cat <<'EOF'
shimmy-catalog
shimmy-create-tool
shimmy-escalation
shimmy-init
shimmy-install
shimmy-tool-local-build
EOF
}

shimmy_target_ai_skill_source_ref_validate() {
  shimmy_target_ai_skill_source_kind=$1
  shimmy_target_ai_skill_source_ref=$2
  case "$shimmy_target_ai_skill_source_kind" in
    control) shimmy_git_commit_validate "$shimmy_target_ai_skill_source_ref" ;;
    shims)
      case "$shimmy_target_ai_skill_source_ref" in */*) ;; *) return 1 ;; esac
      shimmy_target_ai_skill_source_generation=${shimmy_target_ai_skill_source_ref%%/*}
      shimmy_target_ai_skill_source_fingerprint=${shimmy_target_ai_skill_source_ref#*/}
      case "$shimmy_target_ai_skill_source_fingerprint" in */*) return 1 ;; esac
      shimmy_target_catalog_generation_validate "$shimmy_target_ai_skill_source_generation" || return 1
      shimmy_sha256_fingerprint_validate "$shimmy_target_ai_skill_source_fingerprint" || return 1
      [ "$(shimmy_target_catalog_generation_render "$shimmy_target_ai_skill_source_fingerprint")" = "$shimmy_target_ai_skill_source_generation" ]
      ;;
    *) return 1 ;;
  esac
}

shimmy_target_ai_skill_record_validate() {
  shimmy_target_ai_skill_kind=$1
  shimmy_target_ai_skill_source_ref=$2
  shimmy_target_ai_skill_record=$3
  case "$shimmy_target_ai_skill_record" in *'|'*'|'*) ;; *) return 1 ;; esac
  shimmy_target_ai_skill_name=${shimmy_target_ai_skill_record%%|*}
  shimmy_target_ai_skill_remainder=${shimmy_target_ai_skill_record#*|}
  shimmy_target_ai_skill_fingerprint=${shimmy_target_ai_skill_remainder%%|*}
  shimmy_target_ai_skill_identity=${shimmy_target_ai_skill_remainder#*|}
  shimmy_name_component_validate "$shimmy_target_ai_skill_name" || return 1
  shimmy_sha256_fingerprint_validate "$shimmy_target_ai_skill_fingerprint" || return 1

  case "$shimmy_target_ai_skill_kind" in
    control)
      case "$shimmy_target_ai_skill_identity" in control'|'*'|'*) ;; *) return 1 ;; esac
      shimmy_target_ai_skill_identity_remainder=${shimmy_target_ai_skill_identity#control|}
      shimmy_target_ai_skill_identity_name=${shimmy_target_ai_skill_identity_remainder%%|*}
      shimmy_target_ai_skill_identity_ref=${shimmy_target_ai_skill_identity_remainder#*|}
      case "$shimmy_target_ai_skill_identity_ref" in *'|'*) return 1 ;; esac
      [ "$shimmy_target_ai_skill_identity_name" = "$shimmy_target_ai_skill_name" ] || return 1
      [ "$shimmy_target_ai_skill_identity_ref" = "$shimmy_target_ai_skill_source_ref" ] || return 1
      ;;
    shims)
      case "$shimmy_target_ai_skill_identity" in default'|'*'|'*) ;; *) return 1 ;; esac
      shimmy_target_ai_skill_identity_remainder=${shimmy_target_ai_skill_identity#default|}
      shimmy_target_ai_skill_identity_tool=${shimmy_target_ai_skill_identity_remainder%%|*}
      shimmy_target_ai_skill_identity_generation=${shimmy_target_ai_skill_identity_remainder#*|}
      case "$shimmy_target_ai_skill_identity_generation" in *'|'*) return 1 ;; esac
      shimmy_name_component_validate "$shimmy_target_ai_skill_identity_tool" || return 1
      [ "$shimmy_target_ai_skill_name" = "shimmy-tool-$shimmy_target_ai_skill_identity_tool" ] || return 1
      [ "$shimmy_target_ai_skill_identity_generation" = "${shimmy_target_ai_skill_source_ref%%/*}" ] || return 1
      ;;
    *) return 1 ;;
  esac
}

shimmy_target_ai_skill_frontmatter_validate() {
  shimmy_target_ai_skill_file=$1
  shimmy_target_ai_skill_expected_name=$2
  awk -v expected_name="$shimmy_target_ai_skill_expected_name" '
    NR == 1 { if ($0 != "---") exit 1; frontmatter = 1; next }
    frontmatter && $0 == "---" { frontmatter = 0; closed++; next }
    frontmatter && /^name: / { names++; if (substr($0, 7) != expected_name) exit 1; next }
    frontmatter && /^description: / { descriptions++; if (length(substr($0, 14)) == 0) exit 1; next }
    END { if (closed != 1 || names != 1 || descriptions != 1) exit 1 }
  ' "$shimmy_target_ai_skill_file"
}

shimmy_target_ai_skill_managed_header_validate() {
  shimmy_target_ai_skill_managed_file=$1
  [ "$(sed -n '6p' "$shimmy_target_ai_skill_managed_file")" = "$SHIMMY_TARGET_AI_SKILL_MANAGED_HEADER" ]
}

shimmy_target_ai_skill_bundle_render() {
  shimmy_target_ai_skill_bundle_kind=$1
  shimmy_target_ai_skill_bundle_profile=$2
  shimmy_target_ai_skill_bundle_source_ref=$3
  shimmy_target_ai_skill_bundle_records=${4:-}
  case "$shimmy_target_ai_skill_bundle_kind" in control|shims) ;; *) return 1 ;; esac
  shimmy_name_component_validate "$shimmy_target_ai_skill_bundle_profile" || return 1
  shimmy_target_ai_skill_source_ref_validate "$shimmy_target_ai_skill_bundle_kind" "$shimmy_target_ai_skill_bundle_source_ref" || return 1
  shimmy_line_list_lexical_unique_validate "$shimmy_target_ai_skill_bundle_records" || return 1
  while IFS= read -r shimmy_target_ai_skill_bundle_record; do
    [ -n "$shimmy_target_ai_skill_bundle_record" ] || continue
    shimmy_target_ai_skill_record_validate "$shimmy_target_ai_skill_bundle_kind" "$shimmy_target_ai_skill_bundle_source_ref" "$shimmy_target_ai_skill_bundle_record" || return 1
  done <<EOF
$shimmy_target_ai_skill_bundle_records
EOF
  printf 'shimmy_ai_skill_bundle_schema=1\n'
  printf 'shimmy_ai_skill_bundle_kind=%s\n' "$shimmy_target_ai_skill_bundle_kind"
  printf 'shimmy_profile_name=%s\n' "$shimmy_target_ai_skill_bundle_profile"
  printf 'shimmy_ai_skill_source_ref=%s\n' "$shimmy_target_ai_skill_bundle_source_ref"
  while IFS= read -r shimmy_target_ai_skill_bundle_record; do
    [ -n "$shimmy_target_ai_skill_bundle_record" ] || continue
    printf 'skill=%s\n' "$shimmy_target_ai_skill_bundle_record"
  done <<EOF
$shimmy_target_ai_skill_bundle_records
EOF
}

shimmy_target_ai_skill_bundle_read() {
  shimmy_target_ai_skill_bundle_root=$1
  shimmy_target_ai_skill_expected_kind=${2:-}
  shimmy_target_ai_skill_expected_profile=${3:-}
  shimmy_target_ai_skill_bundle_file=$shimmy_target_ai_skill_bundle_root/bundle.conf
  shimmy_target_ai_skill_skills_root=$shimmy_target_ai_skill_bundle_root/skills
  [ -d "$shimmy_target_ai_skill_bundle_root" ] && [ ! -L "$shimmy_target_ai_skill_bundle_root" ] || return 1
  shimmy_text_file_validate "$shimmy_target_ai_skill_bundle_file" || return 1
  [ -d "$shimmy_target_ai_skill_skills_root" ] && [ ! -L "$shimmy_target_ai_skill_skills_root" ] || return 1
  if find "$shimmy_target_ai_skill_bundle_root" -type l -o ! -type d ! -type f | grep . >/dev/null 2>&1; then return 1; fi

  [ "$(sed -n '1p' "$shimmy_target_ai_skill_bundle_file")" = shimmy_ai_skill_bundle_schema=1 ] || return 1
  SHIMMY_TARGET_AI_SKILL_BUNDLE_KIND=$(sed -n '2s/^shimmy_ai_skill_bundle_kind=//p' "$shimmy_target_ai_skill_bundle_file")
  SHIMMY_TARGET_AI_SKILL_PROFILE_NAME=$(sed -n '3s/^shimmy_profile_name=//p' "$shimmy_target_ai_skill_bundle_file")
  SHIMMY_TARGET_AI_SKILL_SOURCE_REF=$(sed -n '4s/^shimmy_ai_skill_source_ref=//p' "$shimmy_target_ai_skill_bundle_file")
  SHIMMY_TARGET_AI_SKILL_RECORDS=$(sed -n '5,$s/^skill=//p' "$shimmy_target_ai_skill_bundle_file")
  [ -z "$shimmy_target_ai_skill_expected_kind" ] || [ "$SHIMMY_TARGET_AI_SKILL_BUNDLE_KIND" = "$shimmy_target_ai_skill_expected_kind" ] || return 1
  [ -z "$shimmy_target_ai_skill_expected_profile" ] || [ "$SHIMMY_TARGET_AI_SKILL_PROFILE_NAME" = "$shimmy_target_ai_skill_expected_profile" ] || return 1
  [ "$(shimmy_target_ai_skill_bundle_render "$SHIMMY_TARGET_AI_SKILL_BUNDLE_KIND" "$SHIMMY_TARGET_AI_SKILL_PROFILE_NAME" "$SHIMMY_TARGET_AI_SKILL_SOURCE_REF" "$SHIMMY_TARGET_AI_SKILL_RECORDS")" = "$(cat "$shimmy_target_ai_skill_bundle_file")" ] || return 1

  shimmy_target_ai_skill_expected_names=
  while IFS= read -r shimmy_target_ai_skill_record; do
    [ -n "$shimmy_target_ai_skill_record" ] || continue
    shimmy_target_ai_skill_record_validate "$SHIMMY_TARGET_AI_SKILL_BUNDLE_KIND" "$SHIMMY_TARGET_AI_SKILL_SOURCE_REF" "$shimmy_target_ai_skill_record" || return 1
    shimmy_target_ai_skill_dir=$shimmy_target_ai_skill_skills_root/$shimmy_target_ai_skill_name
    shimmy_target_ai_skill_file=$shimmy_target_ai_skill_dir/SKILL.md
    [ -d "$shimmy_target_ai_skill_dir" ] && [ ! -L "$shimmy_target_ai_skill_dir" ] || return 1
    shimmy_text_file_validate "$shimmy_target_ai_skill_file" || return 1
    shimmy_target_ai_skill_frontmatter_validate "$shimmy_target_ai_skill_file" "$shimmy_target_ai_skill_name" || return 1
    shimmy_target_ai_skill_managed_header_validate "$shimmy_target_ai_skill_file" || return 1
    [ "$(shimmy_sha256_fingerprint_file_render "$shimmy_target_ai_skill_file")" = "$shimmy_target_ai_skill_fingerprint" ] || return 1
    shimmy_target_ai_skill_expected_names=$(shimmy_append_line_list "$shimmy_target_ai_skill_expected_names" "$shimmy_target_ai_skill_name")
    shimmy_target_ai_skill_entry_count=0
    for shimmy_target_ai_skill_entry in "$shimmy_target_ai_skill_dir"/* "$shimmy_target_ai_skill_dir"/.[!.]* "$shimmy_target_ai_skill_dir"/..?*; do
      [ -e "$shimmy_target_ai_skill_entry" ] || [ -L "$shimmy_target_ai_skill_entry" ] || continue
      [ "$shimmy_target_ai_skill_entry" = "$shimmy_target_ai_skill_file" ] || return 1
      shimmy_target_ai_skill_entry_count=$((shimmy_target_ai_skill_entry_count + 1))
    done
    [ "$shimmy_target_ai_skill_entry_count" -eq 1 ] || return 1
  done <<EOF
$SHIMMY_TARGET_AI_SKILL_RECORDS
EOF

  shimmy_target_ai_skill_actual_names=
  for shimmy_target_ai_skill_dir in "$shimmy_target_ai_skill_skills_root"/* "$shimmy_target_ai_skill_skills_root"/.[!.]* "$shimmy_target_ai_skill_skills_root"/..?*; do
    [ -e "$shimmy_target_ai_skill_dir" ] || [ -L "$shimmy_target_ai_skill_dir" ] || continue
    [ -d "$shimmy_target_ai_skill_dir" ] && [ ! -L "$shimmy_target_ai_skill_dir" ] || return 1
    shimmy_target_ai_skill_actual_names=$(shimmy_append_line_list "$shimmy_target_ai_skill_actual_names" "$(basename -- "$shimmy_target_ai_skill_dir")")
  done
  if [ -n "$shimmy_target_ai_skill_actual_names" ]; then
    shimmy_target_ai_skill_actual_names=$(printf '%s\n' "$shimmy_target_ai_skill_actual_names" | LC_ALL=C sort) || return 1
  fi
  [ "$shimmy_target_ai_skill_actual_names" = "$shimmy_target_ai_skill_expected_names" ] || return 1

  shimmy_target_ai_skill_root_entry_count=0
  for shimmy_target_ai_skill_root_entry in "$shimmy_target_ai_skill_bundle_root"/* "$shimmy_target_ai_skill_bundle_root"/.[!.]* "$shimmy_target_ai_skill_bundle_root"/..?*; do
    [ -e "$shimmy_target_ai_skill_root_entry" ] || [ -L "$shimmy_target_ai_skill_root_entry" ] || continue
    case "$shimmy_target_ai_skill_root_entry" in "$shimmy_target_ai_skill_bundle_file"|"$shimmy_target_ai_skill_skills_root") ;; *) return 1 ;; esac
    shimmy_target_ai_skill_root_entry_count=$((shimmy_target_ai_skill_root_entry_count + 1))
  done
  [ "$shimmy_target_ai_skill_root_entry_count" -eq 2 ]
}
