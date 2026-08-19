#!/bin/sh
# Bootstrap one canonical Shimmy profile from this source checkout.

shimmy__bootstrap_run() {
  shimmy__bootstrap_tool_baseline='jq rg'
  shimmy__bootstrap_profile_name=default
  shimmy__bootstrap_running_shell=

  if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE:-$0}" != "$0" ]; then
    shimmy__bootstrap_running_shell=${BASH:-bash}
  elif [ -n "${ZSH_VERSION:-}" ]; then
    case ${ZSH_EVAL_CONTEXT:-} in
      *:file*)
        shimmy__bootstrap_running_shell=$(command -v zsh 2>/dev/null || printf '%s\n' zsh)
        ;;
    esac
  fi

  case "${1:-}" in
    --profile)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' 'ERROR: missing value for --profile' >&2
        return 1
      fi
      shimmy__bootstrap_profile_name=$2
      shift 2
      ;;
  esac

  case "$shimmy__bootstrap_profile_name" in
    default|upstream) ;;
    *)
      printf 'ERROR: unsupported Shimmy profile: %s\n' "$shimmy__bootstrap_profile_name" >&2
      return 1
      ;;
  esac

  shimmy__bootstrap_help_requested=0
  for shimmy__bootstrap_argument do
    case "$shimmy__bootstrap_argument" in
      -h|--help)
        shimmy__bootstrap_help_requested=1
        ;;
      --uninstall)
        printf 'ERROR: unsupported repository bootstrap option: %s\n' "$shimmy__bootstrap_argument" >&2
        return 1
        ;;
      --shim)
        printf '%s\n' "ERROR: repository bootstrap includes jq and rg; finish onboarding, then run 'shimmy install --shim <tool>'" >&2
        return 1
        ;;
    esac
  done

  if [ "$shimmy__bootstrap_help_requested" -eq 1 ]; then
      cat <<'EOF'
Bootstrap a canonical Shimmy profile and initialize PATH.

Usage:
  source ./bootstrap.sh [--profile default] [--shell <name>] [--no-startup] [--activate]
  source ./bootstrap.sh --profile upstream [--activate]
  ./bootstrap.sh [--profile default] [--shell <name>] [--no-startup] [--activate]
  ./bootstrap.sh --profile upstream [--activate]

Sourcing installs the selected profile and initializes it in the current shell.
Executing performs the same install for automation; shell initialization ends
with that process. Every bootstrap includes jq and rg. Profile selection is
bootstrap-only; install additional tools afterward with the installed command:
  shimmy install --shim <tool>

The default profile records one startup shell and managed or manual startup
policy when first created. Later bootstraps inherit that immutable policy.

Shell initialization selects PATH only. Use --activate to request a post-install
engine activation in the same bootstrap. On macOS this may switch an idle
alternate VM or restart the idle selected VM when registry policy is stale.
Running containers are listed and block that stop; bootstrap never implies
--stop-running. Activation failure leaves the installed profile recoverable and
returns nonzero. Sourcing selects PATH after successful activation; execution
cannot change its parent shell.

On macOS, first create the deterministic machine in a normal user shell
(`podman machine init shimmy-default` or `podman machine init shimmy-upstream`).
Shimmy does not migrate or remove data in podman-machine-default.
EOF
    return 0
  fi

  shimmy__bootstrap_script_candidate=$(
    shimmy__bootstrap_script_parent=$(dirname -- "$0") || exit 1
    cd -- "$shimmy__bootstrap_script_parent" 2>/dev/null && pwd -P
  ) || shimmy__bootstrap_script_candidate=
  shimmy__bootstrap_pwd_candidate=$(pwd -P) || shimmy__bootstrap_pwd_candidate=
  shimmy__bootstrap_source_root=

  for shimmy__bootstrap_candidate in "$shimmy__bootstrap_script_candidate" "$shimmy__bootstrap_pwd_candidate"; do
    [ -n "$shimmy__bootstrap_candidate" ] || continue
    [ -x "$shimmy__bootstrap_candidate/bootstrap.sh" ] || continue
    [ -d "$shimmy__bootstrap_candidate/commands" ] || continue
    [ -d "$shimmy__bootstrap_candidate/lib" ] || continue
    [ -d "$shimmy__bootstrap_candidate/tools" ] || continue
    [ -f "$shimmy__bootstrap_candidate/lib/install/launcher-template.sh" ] || continue
    [ -x "$shimmy__bootstrap_candidate/commands/install.sh" ] || continue
    shimmy__bootstrap_source_root=$shimmy__bootstrap_candidate
    break
  done

  if [ -z "$shimmy__bootstrap_source_root" ]; then
    printf '%s\n' 'ERROR: unable to resolve a valid Shimmy source checkout; change to the checkout root and source ./bootstrap.sh' >&2
    return 1
  fi

  if ! (
    set -eu
    for shimmy__bootstrap_required_dir in commands lib tools; do
      [ -d "$shimmy__bootstrap_source_root/$shimmy__bootstrap_required_dir" ] || {
        printf 'ERROR: invalid Shimmy source checkout: missing %s\n' "$shimmy__bootstrap_required_dir" >&2
        exit 1
      }
    done
    [ -f "$shimmy__bootstrap_source_root/lib/install/launcher-template.sh" ] || {
      printf '%s\n' 'ERROR: invalid Shimmy source checkout: missing lib/install/launcher-template.sh' >&2
      exit 1
    }
    [ -x "$shimmy__bootstrap_source_root/bootstrap.sh" ] || {
      printf '%s\n' 'ERROR: invalid Shimmy source checkout: bootstrap.sh is not executable' >&2
      exit 1
    }
    [ -x "$shimmy__bootstrap_source_root/commands/install.sh" ] || {
      printf '%s\n' 'ERROR: invalid Shimmy source checkout: commands/install.sh is not executable' >&2
      exit 1
    }
    SHIMMY_BOOTSTRAP_PROFILE=$shimmy__bootstrap_profile_name
    SHIMMY_BOOTSTRAP_RUNNING_SHELL=$shimmy__bootstrap_running_shell
    export SHIMMY_BOOTSTRAP_PROFILE SHIMMY_BOOTSTRAP_RUNNING_SHELL
    for shimmy__bootstrap_tool in $shimmy__bootstrap_tool_baseline; do
      set -- "$@" --shim "$shimmy__bootstrap_tool"
    done
    "$shimmy__bootstrap_source_root/commands/install.sh" "$@"
  ); then
    return 1
  fi

  shimmy__bootstrap_profile_root=$(
    set -eu
    . "$shimmy__bootstrap_source_root/lib/common/common.sh"
    . "$shimmy__bootstrap_source_root/lib/profile/profile.sh"
    shimmy_profile_paths_resolve "$shimmy__bootstrap_profile_name"
    printf '%s\n' "$SHIMMY_PROFILE_ROOT"
  ) || {
    printf '%s\n' 'ERROR: unable to resolve the installed Shimmy profile' >&2
    return 1
  }
  shimmy__bootstrap_shell_init_file=$shimmy__bootstrap_profile_root/shell-init.sh
  if [ ! -f "$shimmy__bootstrap_shell_init_file" ] ||
    [ -L "$shimmy__bootstrap_shell_init_file" ] ||
    [ ! -r "$shimmy__bootstrap_shell_init_file" ]; then
    printf 'ERROR: installed shell init must be a readable regular non-symlink file: %s\n' "$shimmy__bootstrap_shell_init_file" >&2
    return 1
  fi

  . "$shimmy__bootstrap_shell_init_file"
}

if shimmy__bootstrap_run "$@"; then
  shimmy__bootstrap_status=0
else
  shimmy__bootstrap_status=$?
fi
unset -f shimmy__bootstrap_run
unset shimmy__bootstrap_argument shimmy__bootstrap_candidate
unset shimmy__bootstrap_help_requested
unset shimmy__bootstrap_tool shimmy__bootstrap_tool_baseline
unset shimmy__bootstrap_profile_name shimmy__bootstrap_profile_root
unset shimmy__bootstrap_running_shell
unset shimmy__bootstrap_pwd_candidate shimmy__bootstrap_script_candidate
unset shimmy__bootstrap_script_parent shimmy__bootstrap_shell_init_file
unset shimmy__bootstrap_source_root
if [ "$shimmy__bootstrap_status" -eq 0 ]; then
  unset shimmy__bootstrap_status
  true
else
  unset shimmy__bootstrap_status
  ! true
fi
