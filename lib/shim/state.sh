#!/bin/sh
# Pure target shim-record validation for profile manifest schema 2.

shimmy_target_shim_record_validate() {
  shimmy_target_shim_record=$1
  case "$shimmy_target_shim_record" in *'|'*'|'*) ;; *) return 1 ;; esac
  shimmy_target_shim_record_tool=${shimmy_target_shim_record%%|*}
  shimmy_target_shim_record_remainder=${shimmy_target_shim_record#*|}
  shimmy_target_shim_record_default=${shimmy_target_shim_record_remainder%%|*}
  shimmy_target_shim_record_mode=${shimmy_target_shim_record_remainder#*|}
  case "$shimmy_target_shim_record_mode" in *'|'*) return 1 ;; esac
  shimmy_name_component_validate "$shimmy_target_shim_record_tool" || return 1
  shimmy_version_token_validate "$shimmy_target_shim_record_default" || return 1
  case "$shimmy_target_shim_record_mode" in tracking|pinned) ;; *) return 1 ;; esac
}

shimmy_target_shim_version_record_validate() {
  shimmy_target_shim_version_record=$1
  case "$shimmy_target_shim_version_record" in *'|'*'|'*) ;; *) return 1 ;; esac
  shimmy_target_shim_version_tool=${shimmy_target_shim_version_record%%|*}
  shimmy_target_shim_version_remainder=${shimmy_target_shim_version_record#*|}
  shimmy_target_shim_version_name=${shimmy_target_shim_version_remainder%%|*}
  shimmy_target_shim_version_kind=${shimmy_target_shim_version_remainder#*|}
  case "$shimmy_target_shim_version_kind" in *'|'*) return 1 ;; esac
  shimmy_name_component_validate "$shimmy_target_shim_version_tool" || return 1
  shimmy_version_token_validate "$shimmy_target_shim_version_name" || return 1
  case "$shimmy_target_shim_version_kind" in default|exact) ;; *) return 1 ;; esac
}

shimmy_target_shim_records_validate() {
  shimmy_target_shim_records=${1:-}
  shimmy_target_shim_version_records=${2:-}
  shimmy_line_list_lexical_unique_validate "$shimmy_target_shim_records" || return 1
  shimmy_line_list_lexical_unique_validate "$shimmy_target_shim_version_records" || return 1
  shimmy_target_shim_tools=

  while IFS= read -r shimmy_target_shim_entry; do
    [ -n "$shimmy_target_shim_entry" ] || continue
    shimmy_target_shim_record_validate "$shimmy_target_shim_entry" || return 1
    shimmy_contains_line_list "$shimmy_target_shim_tools" "$shimmy_target_shim_record_tool" && return 1
    shimmy_target_shim_tools=$(shimmy_append_line_list "$shimmy_target_shim_tools" "$shimmy_target_shim_record_tool")
  done <<EOF
$shimmy_target_shim_records
EOF

  while IFS= read -r shimmy_target_shim_entry; do
    [ -n "$shimmy_target_shim_entry" ] || continue
    shimmy_target_shim_record_validate "$shimmy_target_shim_entry" || return 1
    shimmy_target_shim_default_count=0
    shimmy_target_shim_launcher_found=0
    shimmy_target_shim_version_count=0
    shimmy_target_shim_version_names=
    while IFS= read -r shimmy_target_shim_version_entry; do
      [ -n "$shimmy_target_shim_version_entry" ] || continue
      shimmy_target_shim_version_record_validate "$shimmy_target_shim_version_entry" || return 1
      [ "$shimmy_target_shim_version_tool" = "$shimmy_target_shim_record_tool" ] || continue
      shimmy_target_shim_version_count=$((shimmy_target_shim_version_count + 1))
      shimmy_contains_line_list "$shimmy_target_shim_version_names" "$shimmy_target_shim_version_name" && return 1
      shimmy_target_shim_version_names=$(shimmy_append_line_list "$shimmy_target_shim_version_names" "$shimmy_target_shim_version_name")
      [ "$shimmy_target_shim_version_name" != "$shimmy_target_shim_record_default" ] || shimmy_target_shim_launcher_found=1
      [ "$shimmy_target_shim_version_kind" != default ] || shimmy_target_shim_default_count=$((shimmy_target_shim_default_count + 1))
    done <<EOF
$shimmy_target_shim_version_records
EOF
    [ "$shimmy_target_shim_version_count" -gt 0 ] || return 1
    [ "$shimmy_target_shim_launcher_found" -eq 1 ] || return 1
    [ "$shimmy_target_shim_default_count" -le 1 ] || return 1
    if [ "$shimmy_target_shim_record_mode" = tracking ]; then
      [ "$shimmy_target_shim_default_count" -eq 1 ] || return 1
      shimmy_contains_line_list "$shimmy_target_shim_version_records" "$shimmy_target_shim_record_tool|$shimmy_target_shim_record_default|default" || return 1
    fi
  done <<EOF
$shimmy_target_shim_records
EOF

  while IFS= read -r shimmy_target_shim_version_entry; do
    [ -n "$shimmy_target_shim_version_entry" ] || continue
    shimmy_target_shim_version_record_validate "$shimmy_target_shim_version_entry" || return 1
    shimmy_contains_line_list "$shimmy_target_shim_tools" "$shimmy_target_shim_version_tool" || return 1
  done <<EOF
$shimmy_target_shim_version_records
EOF
}
