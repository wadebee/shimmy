#!/bin/sh
# Sourceable checkout bootstrap for the default Shimmy profile.

shimmy__bootstrap_run() {
  shimmy__bootstrap_script_parent=$(dirname -- "$0") || return 1
  shimmy__bootstrap_script_root=$(cd -- "$shimmy__bootstrap_script_parent" 2>/dev/null && pwd -P) ||
    shimmy__bootstrap_script_root=
  shimmy__bootstrap_pwd_root=$(pwd -P) || shimmy__bootstrap_pwd_root=
  shimmy__bootstrap_root=
  for shimmy__bootstrap_candidate in "$shimmy__bootstrap_script_root" \
    "$shimmy__bootstrap_pwd_root"; do
    [ -n "$shimmy__bootstrap_candidate" ] || continue
    [ -x "$shimmy__bootstrap_candidate/commands/bootstrap.sh" ] || continue
    [ -f "$shimmy__bootstrap_candidate/lib/install/lifecycle.sh" ] || continue
    shimmy__bootstrap_root=$shimmy__bootstrap_candidate
    break
  done
  [ -x "$shimmy__bootstrap_root/commands/bootstrap.sh" ] || {
    printf '%s\n' 'ERROR: Shimmy bootstrap command is unavailable' >&2
    return 1
  }
  "$shimmy__bootstrap_root/commands/bootstrap.sh" "$@" || return $?
  case "${1:-}" in -h|--help) return 0 ;; esac
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    shimmy__bootstrap_config=$XDG_CONFIG_HOME/shimmy
  else
    shimmy__bootstrap_config=${HOME:?}/.config/shimmy
  fi
  shimmy__bootstrap_shell_init=$shimmy__bootstrap_config/profiles/default/shell-init.sh
  [ -f "$shimmy__bootstrap_shell_init" ] && [ ! -L "$shimmy__bootstrap_shell_init" ] || {
    printf 'ERROR: installed shell initialization is unavailable: %s\n' \
      "$shimmy__bootstrap_shell_init" >&2
    return 1
  }
  . "$shimmy__bootstrap_shell_init"
}

if shimmy__bootstrap_run "$@"; then
  shimmy__bootstrap_status=0
else
  shimmy__bootstrap_status=$?
fi
unset -f shimmy__bootstrap_run
unset shimmy__bootstrap_candidate shimmy__bootstrap_config
unset shimmy__bootstrap_pwd_root shimmy__bootstrap_root
unset shimmy__bootstrap_script_parent shimmy__bootstrap_script_root
unset shimmy__bootstrap_shell_init
if [ "$shimmy__bootstrap_status" -eq 0 ]; then
  unset shimmy__bootstrap_status
  true
else
  unset shimmy__bootstrap_status
  ! true
fi
