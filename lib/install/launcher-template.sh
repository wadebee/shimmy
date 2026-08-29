#!/bin/sh
# Installed <profile-root>/bin/shimmy template.
set -eu

shimmy_launcher_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
shimmy_launcher_profile_root=$(cd -- "$shimmy_launcher_dir/.." && pwd -P)
shimmy_launcher_profile_name=$(basename -- "$shimmy_launcher_profile_root")
case "$shimmy_launcher_profile_name" in
  ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*)
    printf 'ERROR: invalid profile launcher identity: %s\n' "$shimmy_launcher_profile_name" >&2
    exit 1
    ;;
esac
shimmy_launcher_profiles_root=$(cd -- "$shimmy_launcher_profile_root/.." && pwd -P)
shimmy_launcher_config_root=$(cd -- "$shimmy_launcher_profiles_root/.." && pwd -P)
[ "$shimmy_launcher_profile_root" = "$shimmy_launcher_config_root/profiles/$shimmy_launcher_profile_name" ] || {
  printf '%s\n' 'ERROR: launcher is outside its canonical profile root' >&2
  exit 1
}
shimmy_launcher_help=$shimmy_launcher_profile_root/commands/help.sh
[ -f "$shimmy_launcher_help" ] && [ ! -L "$shimmy_launcher_help" ] && [ -x "$shimmy_launcher_help" ] || {
  printf '%s\n' 'ERROR: command help is missing or unsafe' >&2
  exit 1
}
shimmy_launcher_command=${1:-help}
case "$shimmy_launcher_command" in
  help|-h|--help) exec "$shimmy_launcher_help" root ;;
  admin|profile|catalog|shim|ai-skill) ;;
  *) printf 'ERROR: unsupported command: %s\n' "$shimmy_launcher_command" >&2; exit 1 ;;
esac
[ "$#" -gt 1 ] || exec "$shimmy_launcher_help" "$shimmy_launcher_command"
case "${2:-}" in help|-h|--help) exec "$shimmy_launcher_help" "$shimmy_launcher_command" ;; esac
if { [ "$shimmy_launcher_command" = profile ] && [ "${2:-}" = redirect ]; } ||
  { [ "$shimmy_launcher_command" = admin ] && [ "${2:-}" = engine ]; }; then
  [ "$#" -gt 2 ] || exec "$shimmy_launcher_help" "$shimmy_launcher_command" "${2:-}"
  case "${3:-}" in
    help|-h|--help) exec "$shimmy_launcher_help" "$shimmy_launcher_command" "${2:-}" ;;
  esac
fi
for shimmy_launcher_arg in "$@"; do
  case "$shimmy_launcher_arg" in
    -h|--help)
      if { [ "$shimmy_launcher_command" = profile ] && [ "${2:-}" = redirect ]; } ||
        { [ "$shimmy_launcher_command" = admin ] && [ "${2:-}" = engine ]; }; then
        exec "$shimmy_launcher_help" "$shimmy_launcher_command" "${2:-}" "${3:-}"
      fi
      exec "$shimmy_launcher_help" "$shimmy_launcher_command" "${2:-}"
      ;;
  esac
done
shimmy_launcher_manifest=$shimmy_launcher_profile_root/install-manifest.txt
[ -f "$shimmy_launcher_manifest" ] && [ ! -L "$shimmy_launcher_manifest" ] || {
  printf '%s\n' 'ERROR: profile manifest is missing or unsafe' >&2
  exit 1
}
[ "$(sed -n '1s/^shimmy_install_manifest_version=//p' "$shimmy_launcher_manifest")" = 2 ] &&
  [ "$(sed -n '3s/^shimmy_profile_manifest_version=//p' "$shimmy_launcher_manifest")" = 2 ] &&
  [ "$(sed -n '4s/^shimmy_profile_name=//p' "$shimmy_launcher_manifest")" = "$shimmy_launcher_profile_name" ] || {
    printf '%s\n' 'ERROR: profile manifest identity is invalid' >&2
    exit 1
  }
SHIMMY_CONFIG_ROOT=$shimmy_launcher_config_root
SHIMMY_INVOKING_PROFILE=$shimmy_launcher_profile_name
export SHIMMY_CONFIG_ROOT SHIMMY_INVOKING_PROFILE
case "$shimmy_launcher_command" in
  admin) shift; exec "$shimmy_launcher_profile_root/commands/admin.sh" "$@" ;;
  profile) shift; exec "$shimmy_launcher_profile_root/commands/profile.sh" "$@" ;;
  catalog) shift; exec "$shimmy_launcher_profile_root/commands/catalog.sh" "$@" ;;
  shim) shift; exec "$shimmy_launcher_profile_root/commands/shim.sh" "$@" ;;
  ai-skill) shift; exec "$shimmy_launcher_profile_root/commands/ai-skill.sh" "$@" ;;
esac
