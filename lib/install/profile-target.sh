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

shimmy_target_profile_launcher_render() {
  shimmy_target_profile_launcher_config_root=$1
  shimmy_target_profile_launcher_name=$2
  shimmy_path_absolute_normalized_validate "$shimmy_target_profile_launcher_config_root" || return 1
  shimmy_name_component_validate "$shimmy_target_profile_launcher_name" || return 1
  cat <<'EOF'
#!/bin/sh
set -eu
shimmy_launcher_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
shimmy_launcher_profile_root=$(cd -- "$shimmy_launcher_dir/.." && pwd -P)
shimmy_launcher_profile_name=$(basename -- "$shimmy_launcher_profile_root")
case "$shimmy_launcher_profile_name" in ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) printf 'ERROR: invalid target profile launcher identity: %s\n' "$shimmy_launcher_profile_name" >&2; exit 1 ;; esac
shimmy_launcher_profiles_root=$(cd -- "$shimmy_launcher_profile_root/.." && pwd -P)
shimmy_launcher_config_root=$(cd -- "$shimmy_launcher_profiles_root/.." && pwd -P)
[ "$shimmy_launcher_profile_root" = "$shimmy_launcher_config_root/profiles/$shimmy_launcher_profile_name" ] || { printf '%s\n' 'ERROR: target launcher is outside its canonical profile root' >&2; exit 1; }
shimmy_launcher_manifest=$shimmy_launcher_profile_root/install-manifest.txt
[ -f "$shimmy_launcher_manifest" ] && [ ! -L "$shimmy_launcher_manifest" ] || { printf '%s\n' 'ERROR: target profile manifest is missing or unsafe' >&2; exit 1; }
[ "$(sed -n '1s/^shimmy_install_manifest_version=//p' "$shimmy_launcher_manifest")" = 2 ] &&
  [ "$(sed -n '3s/^shimmy_profile_manifest_version=//p' "$shimmy_launcher_manifest")" = 2 ] &&
  [ "$(sed -n '4s/^shimmy_profile_name=//p' "$shimmy_launcher_manifest")" = "$shimmy_launcher_profile_name" ] || { printf '%s\n' 'ERROR: target profile manifest identity is invalid' >&2; exit 1; }
SHIMMY_TARGET_CONFIG_ROOT=$shimmy_launcher_config_root
SHIMMY_TARGET_INVOKING_PROFILE=$shimmy_launcher_profile_name
export SHIMMY_TARGET_CONFIG_ROOT SHIMMY_TARGET_INVOKING_PROFILE
shimmy_launcher_command=${1:-help}
case "$shimmy_launcher_command" in
  help|-h|--help)
    printf '%s\n' 'Private target Shimmy candidate: profile, catalog, shim, and ai-skill.'
    ;;
  profile) shift; exec "$shimmy_launcher_profile_root/commands/profile-target.sh" "$@" ;;
  catalog) shift; exec "$shimmy_launcher_profile_root/commands/catalog-target.sh" "$@" ;;
  shim) shift; exec "$shimmy_launcher_profile_root/commands/shim-target.sh" "$@" ;;
  ai-skill) shift; exec "$shimmy_launcher_profile_root/commands/ai-skill-target.sh" "$@" ;;
  *) printf 'ERROR: unsupported private target command: %s\n' "$shimmy_launcher_command" >&2; exit 1 ;;
esac
EOF
}

shimmy_target_profile_launcher_validate() {
  shimmy_target_profile_launcher_file=$1
  shimmy_target_profile_launcher_config_root=$2
  shimmy_target_profile_launcher_name=$3
  [ -f "$shimmy_target_profile_launcher_file" ] && [ ! -L "$shimmy_target_profile_launcher_file" ] &&
    [ -x "$shimmy_target_profile_launcher_file" ] || return 1
  [ "$(shimmy_target_profile_launcher_render "$shimmy_target_profile_launcher_config_root" "$shimmy_target_profile_launcher_name")" = "$(cat "$shimmy_target_profile_launcher_file")" ]
}

shimmy_target_profile_shell_init_render() {
  shimmy_target_profile_shell_config_root=$1
  shimmy_target_profile_shell_name=$2
  shimmy_path_absolute_normalized_validate "$shimmy_target_profile_shell_config_root" || return 1
  shimmy_name_component_validate "$shimmy_target_profile_shell_name" || return 1
  shimmy_target_profile_shell_profiles_root=$shimmy_target_profile_shell_config_root/profiles
  shimmy_target_profile_shell_bin=$shimmy_target_profile_shell_profiles_root/$shimmy_target_profile_shell_name/bin
  shimmy_target_profile_shell_launcher=$shimmy_target_profile_shell_bin/shimmy
  shimmy_target_profile_shell_profiles_quoted=$(shimmy_quote_shell_word "$shimmy_target_profile_shell_profiles_root") || return 1
  shimmy_target_profile_shell_bin_quoted=$(shimmy_quote_shell_word "$shimmy_target_profile_shell_bin") || return 1
  shimmy_target_profile_shell_launcher_quoted=$(shimmy_quote_shell_word "$shimmy_target_profile_shell_launcher") || return 1

  printf '%s\n' '# shimmy_target_shell_init_schema=1'
  printf 'PATH=`\n'
  printf '  shimmy_target_shell_profiles_root=%s\n' "$shimmy_target_profile_shell_profiles_quoted"
  printf '  shimmy_target_shell_bin=%s\n' "$shimmy_target_profile_shell_bin_quoted"
  printf '  shimmy_target_shell_input=${PATH-}\n'
  printf '  shimmy_target_shell_output=\n'
  printf '  shimmy_target_shell_output_count=0\n'
  printf '  while :; do\n'
  printf '    case "$shimmy_target_shell_input" in\n'
  printf '      *:*) shimmy_target_shell_entry=${shimmy_target_shell_input%%%%:*}; shimmy_target_shell_input=${shimmy_target_shell_input#*:}; shimmy_target_shell_more=1 ;;\n'
  printf '      *) shimmy_target_shell_entry=$shimmy_target_shell_input; shimmy_target_shell_more=0 ;;\n'
  printf '    esac\n'
  printf '    shimmy_target_shell_remove=0\n'
  printf '    case "$shimmy_target_shell_entry" in\n'
  printf '      "$shimmy_target_shell_profiles_root"/*/bin)\n'
  printf '        shimmy_target_shell_remainder=${shimmy_target_shell_entry#"$shimmy_target_shell_profiles_root"/}\n'
  printf '        shimmy_target_shell_profile=${shimmy_target_shell_remainder%%/bin}\n'
  printf '        if [ "$shimmy_target_shell_remainder" = "$shimmy_target_shell_profile/bin" ]; then\n'
  printf '%s\n' '          case "$shimmy_target_shell_profile" in '\'''\''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) ;; *) shimmy_target_shell_remove=1 ;; esac'
  printf '        fi\n'
  printf '        ;;\n'
  printf '    esac\n'
  printf '    if [ "$shimmy_target_shell_remove" -eq 0 ]; then\n'
  printf '      if [ "$shimmy_target_shell_output_count" -eq 0 ]; then shimmy_target_shell_output=$shimmy_target_shell_entry; else shimmy_target_shell_output=$shimmy_target_shell_output:$shimmy_target_shell_entry; fi\n'
  printf '      shimmy_target_shell_output_count=$((shimmy_target_shell_output_count + 1))\n'
  printf '    fi\n'
  printf '    [ "$shimmy_target_shell_more" -eq 1 ] || break\n'
  printf '  done\n'
  printf '  if [ "$shimmy_target_shell_output_count" -eq 0 ]; then printf "%%s\\n" "$shimmy_target_shell_bin"; else printf "%%s:%%s\\n" "$shimmy_target_shell_bin" "$shimmy_target_shell_output"; fi\n'
  printf '`\n'
  printf '%s\n' 'if [ -x /opt/podman/bin/podman ] && ! command -v podman >/dev/null 2>&1; then PATH=${PATH:+$PATH:}/opt/podman/bin; fi'
  printf '%s\n' 'export PATH'
  printf '%s\n' 'hash -r 2>/dev/null || true'
  printf '%s\n' 'shimmy() {'
  printf '  case "${1-}|${2-}|${3-}" in\n'
  printf '    profile\\|activate\\|[abcdefghijklmnopqrstuvwxyz0123456789]*|profile\\|create\\|[abcdefghijklmnopqrstuvwxyz0123456789]*)\n'
  printf '      %s "$@" || return $?\n' "$shimmy_target_profile_shell_launcher_quoted"
  printf '%s\n' '      if ( shift 3; for shimmy_target_shell_arg do [ "$shimmy_target_shell_arg" != --dry-run ] || exit 0; done; exit 1 ); then return 0; fi'
  printf '      . %s/${3}/shell-init.sh\n' "$shimmy_target_profile_shell_profiles_quoted"
  printf '      ;;\n'
  printf '    *) %s "$@" ;;\n' "$shimmy_target_profile_shell_launcher_quoted"
  printf '  esac\n'
  printf '%s\n' '}'
}

shimmy_target_profile_shell_init_validate() {
  shimmy_target_profile_shell_file=$1
  shimmy_target_profile_shell_config_root=$2
  shimmy_target_profile_shell_name=$3
  shimmy_text_file_validate "$shimmy_target_profile_shell_file" || return 1
  if shimmy_target_profile_shell_mode=$(stat -c '%a' "$shimmy_target_profile_shell_file" 2>/dev/null); then
    :
  else
    shimmy_target_profile_shell_mode=$(stat -f '%Lp' "$shimmy_target_profile_shell_file" 2>/dev/null) || return 1
  fi
  [ "$shimmy_target_profile_shell_mode" = 644 ] || return 1
  [ "$(shimmy_target_profile_shell_init_render "$shimmy_target_profile_shell_config_root" "$shimmy_target_profile_shell_name")" = "$(cat "$shimmy_target_profile_shell_file")" ]
}
