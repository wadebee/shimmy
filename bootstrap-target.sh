#!/bin/sh
# Private sourceable target bootstrap candidate. Public bootstrap.sh is unchanged.

shimmy__target_bootstrap_run() {
  shimmy__target_bootstrap_script_parent=$(dirname -- "$0") || return 1
  shimmy__target_bootstrap_script_root=$(cd -- "$shimmy__target_bootstrap_script_parent" 2>/dev/null && pwd -P) ||
    shimmy__target_bootstrap_script_root=
  shimmy__target_bootstrap_pwd_root=$(pwd -P) || shimmy__target_bootstrap_pwd_root=
  shimmy__target_bootstrap_root=
  for shimmy__target_bootstrap_candidate in "$shimmy__target_bootstrap_script_root" \
    "$shimmy__target_bootstrap_pwd_root"; do
    [ -n "$shimmy__target_bootstrap_candidate" ] || continue
    [ -x "$shimmy__target_bootstrap_candidate/commands/bootstrap-target.sh" ] || continue
    [ -f "$shimmy__target_bootstrap_candidate/lib/install/lifecycle-target.sh" ] || continue
    shimmy__target_bootstrap_root=$shimmy__target_bootstrap_candidate
    break
  done
  [ -x "$shimmy__target_bootstrap_root/commands/bootstrap-target.sh" ] || {
    printf '%s\n' 'ERROR: private target bootstrap command is unavailable' >&2
    return 1
  }
  "$shimmy__target_bootstrap_root/commands/bootstrap-target.sh" "$@" || return $?
  if [ -n "${SHIMMY_TARGET_CONFIG_ROOT:-}" ]; then
    shimmy__target_bootstrap_config=$SHIMMY_TARGET_CONFIG_ROOT
  elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
    shimmy__target_bootstrap_config=$XDG_CONFIG_HOME/shimmy
  else
    shimmy__target_bootstrap_config=${HOME:?}/.config/shimmy
  fi
  shimmy__target_bootstrap_shell_init=$shimmy__target_bootstrap_config/profiles/default/shell-init.sh
  [ -f "$shimmy__target_bootstrap_shell_init" ] && [ ! -L "$shimmy__target_bootstrap_shell_init" ] || {
    printf 'ERROR: installed target shell initialization is unavailable: %s\n' \
      "$shimmy__target_bootstrap_shell_init" >&2
    return 1
  }
  . "$shimmy__target_bootstrap_shell_init"
}

if shimmy__target_bootstrap_run "$@"; then
  shimmy__target_bootstrap_status=0
else
  shimmy__target_bootstrap_status=$?
fi
unset -f shimmy__target_bootstrap_run
unset shimmy__target_bootstrap_candidate shimmy__target_bootstrap_config
unset shimmy__target_bootstrap_pwd_root shimmy__target_bootstrap_root
unset shimmy__target_bootstrap_script_parent shimmy__target_bootstrap_script_root
unset shimmy__target_bootstrap_shell_init
if [ "$shimmy__target_bootstrap_status" -eq 0 ]; then
  unset shimmy__target_bootstrap_status
  true
else
  unset shimmy__target_bootstrap_status
  ! true
fi
