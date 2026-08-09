#!/bin/sh
# Template copied to <profile-root>/bin/shimmy with mode 0755.
set -eu

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

launcher_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
profile_root=$(cd -- "$launcher_dir/.." && pwd -P)
profile_name=$(basename -- "$profile_root")

case "$profile_name" in
  default|upstream) ;;
  *) fail "damaged Shimmy profile: unsupported profile directory $profile_name" ;;
esac

if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  case "$XDG_CONFIG_HOME" in
    /*)
      config_home=$XDG_CONFIG_HOME
      while [ "$config_home" != / ]; do case "$config_home" in */) config_home=${config_home%/} ;; *) break ;; esac; done
      ;;
    *) fail "XDG_CONFIG_HOME must be an absolute path" ;;
  esac
else
  case "${HOME:-}" in
    /*)
      home_root=$HOME
      while [ "$home_root" != / ]; do case "$home_root" in */) home_root=${home_root%/} ;; *) break ;; esac; done
      if [ "$home_root" = / ]; then config_home=/.config; else config_home=$home_root/.config; fi
      ;;
    *) fail "HOME must be an absolute path when XDG_CONFIG_HOME is unset" ;;
  esac
fi
if [ "$config_home" = / ]; then expected_root=/shimmy/profiles/$profile_name; else expected_root=$config_home/shimmy/profiles/$profile_name; fi
[ "$profile_root" = "$expected_root" ] || fail "damaged Shimmy profile: launcher is outside its canonical profile root $expected_root"

manifest_file=$profile_root/install-manifest.txt
manifest_fail() {
  printf 'ERROR: invalid or unsupported Shimmy profile manifest at %s (expected shimmy_install_manifest_version=4, shimmy_install_layout=profile-flat-root, shimmy_profile_manifest_version=4, and shimmy_profile_name=%s); inspect or uninstall it with the Shimmy version that created it, then reinstall that profile\n' "$manifest_file" "$profile_name" >&2
  exit 1
}
manifest_value_count() {
  awk -F= -v key="$1" '$1 == key { count++ } END { print count + 0 }' "$manifest_file"
}
manifest_value_read() {
  sed -n "s/^$1=//p" "$manifest_file" | sed -n '1p'
}

[ -f "$manifest_file" ] && [ ! -L "$manifest_file" ] || manifest_fail
for identity_key in shimmy_install_manifest_version shimmy_install_layout shimmy_profile_manifest_version shimmy_profile_name; do
  [ "$(manifest_value_count "$identity_key")" -eq 1 ] || manifest_fail
done
[ "$(manifest_value_read shimmy_install_manifest_version)" = 4 ] || manifest_fail
[ "$(manifest_value_read shimmy_install_layout)" = profile-flat-root ] || manifest_fail
[ "$(manifest_value_read shimmy_profile_manifest_version)" = 4 ] || manifest_fail
[ "$(manifest_value_read shimmy_profile_name)" = "$profile_name" ] || manifest_fail

for launcher_arg in "$@"; do
  [ "$launcher_arg" != --profile ] || fail "unknown argument: --profile"
done

usage() {
  cat <<'EOF'
Manage this installed Shimmy profile.

Usage:
  shimmy <command> [options]
  shimmy <command> --help

Commands:
  install    Add tool shims and optional agent skills to this profile.
  uninstall  Remove this profile and its managed startup integration.
  netinfo    Show host, VM, and container network perspectives.
  skills     Install, update, uninstall, or export Shimmy agent skills.
  status     Show installed shims, versions, and profile details.
  test       Validate this profile with non-mutating shim smoke commands.
  update     Refresh this profile and optionally pull or build tool images.

Examples:
  shimmy status
  shimmy install --shim jq

Run 'shimmy <command> --help' for command-specific options.
EOF
}

command_name=${1:-help}
case "$command_name" in
  help|-h|--help) usage ;;
  install) shift; exec "$profile_root/commands/install.sh" "$@" ;;
  uninstall) shift; exec "$profile_root/commands/install.sh" --uninstall "$@" ;;
  netinfo) shift; exec "$profile_root/commands/netinfo.sh" "$@" ;;
  skills) shift; exec "$profile_root/commands/skills.sh" "$@" ;;
  status) shift; exec "$profile_root/commands/status.sh" "$@" ;;
  test) shift; exec "$profile_root/tests/test.sh" "$@" ;;
  update) shift; exec "$profile_root/commands/update.sh" "$@" ;;
  *) fail "unknown command: $command_name" ;;
esac
