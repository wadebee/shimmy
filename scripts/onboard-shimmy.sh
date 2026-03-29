#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ACTIVATE_SCRIPT=$SCRIPT_DIR/activate-shimmy.sh
REQUESTED_INSTALL_DIR=
REQUESTED_SHELL=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

shell_name_normalize() {
  shell_name=${1:-}

  if [ -z "$shell_name" ]; then
    shell_name=$(basename -- "${SHELL:-sh}")
  fi

  case "$shell_name" in
    bash) printf 'bash\n' ;;
    zsh) printf 'zsh\n' ;;
    ksh|mksh) printf '%s\n' "$shell_name" ;;
    sh|dash|'') printf 'sh\n' ;;
    *) fail "unsupported shell for onboarding guidance: $shell_name" ;;
  esac
}

shell_rc_file_recommend() {
  case "$1" in
    bash) printf '~/.bashrc\n' ;;
    zsh) printf '~/.zshrc\n' ;;
    sh|ksh|mksh) printf '~/.profile\n' ;;
    *) fail "unsupported shell for rc-file recommendation: $1" ;;
  esac
}

usage() {
  cat <<'EOF'
Print shell-specific manual onboarding guidance for an installed Shimmy root.

Usage:
  scripts/onboard-shimmy.sh [--install-dir <dir>] [--shell <name>]

Options:
  --install-dir <dir>  Base install directory. Default: ~/.config/shimmy
  --shell <name>       One of: bash, zsh, sh, ksh, mksh
  -h, --help           Show help

Examples:
  ./shimmy onboard
  ./shimmy onboard --shell bash
  ./shimmy onboard --install-dir "$HOME/.config/shimmy" --shell zsh
EOF
}

main() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
        shift 2
        ;;
      --shell)
        [ "$#" -ge 2 ] || fail "missing value for --shell"
        REQUESTED_SHELL=$2
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done

  [ -x "$ACTIVATE_SCRIPT" ] || fail "missing activate helper: $ACTIVATE_SCRIPT"

  shell_name=$(shell_name_normalize "$REQUESTED_SHELL")
  rc_file=$(shell_rc_file_recommend "$shell_name")

  set -- "$ACTIVATE_SCRIPT"
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    set -- "$@" --install-dir "$REQUESTED_INSTALL_DIR"
  fi
  activate_block=$("$@")

  printf 'Shell: %s\n' "$shell_name"
  printf 'Recommended shell startup file: %s\n' "$rc_file"
  printf '\n'
  printf 'Add the following block to %s:\n' "$rc_file"
  printf '\n'
  printf '%s\n' "$activate_block"
}

main "$@"
