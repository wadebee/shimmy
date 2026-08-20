#!/bin/sh
# Private target pristine-profile baseline selection. Target bootstrap and
# create candidates consume this exact catalog-default tuple set in later
# lifecycle chunks; current public bootstrap remains unchanged.

shimmy_target_profile_baseline_render() {
  shimmy_target_profile_baseline_catalog_root=$1
  shimmy_target_catalog_payload_validate "$shimmy_target_profile_baseline_catalog_root" || return 1

  for shimmy_target_profile_baseline_tool in jq rg skopeo; do
    shimmy_target_profile_baseline_tool_file=$shimmy_target_profile_baseline_catalog_root/tools/$shimmy_target_profile_baseline_tool/tool.conf
    [ -f "$shimmy_target_profile_baseline_tool_file" ] && [ ! -L "$shimmy_target_profile_baseline_tool_file" ] || return 1
    shimmy_target_profile_baseline_version=$(shimmy__catalog_config_value_read \
      "$shimmy_target_profile_baseline_tool_file" tool_default_version)
    shimmy_version_token_validate "$shimmy_target_profile_baseline_version" || return 1
    [ -d "$shimmy_target_profile_baseline_catalog_root/tools/$shimmy_target_profile_baseline_tool/versions/$shimmy_target_profile_baseline_version" ] || return 1
    printf '%s|%s\n' "$shimmy_target_profile_baseline_tool" "$shimmy_target_profile_baseline_version"
  done
}
