#!/bin/sh
set -eu

DEFAULT_INSTALL_DIR=${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}
REQUESTED_INSTALL_DIR=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

trim_trailing_slash() {
  path_value=${1:-}

  case "$path_value" in
    ''|/)
      printf '%s\n' "$path_value"
      ;;
    */)
      printf '%s\n' "${path_value%/}"
      ;;
    *)
      printf '%s\n' "$path_value"
      ;;
  esac
}

shell_quote() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

manifest_value() {
  manifest_file=$1
  key=$2

  if [ ! -f "$manifest_file" ]; then
    return 1
  fi

  sed -n "s/^${key}=//p" "$manifest_file" | sed -n '1p'
}

resolve_install_dir() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(trim_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(trim_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

render_activate() {
  control_bin_dir=$1
  shim_dir=$2
  podman_dir=$3

  quoted_control_bin_dir=$(shell_quote "$control_bin_dir")
  quoted_shim_dir=$(shell_quote "$shim_dir")
  quoted_podman_dir=$(shell_quote "$podman_dir")

  printf 'shimmy_activate_shim_dir=%s\n' "$quoted_shim_dir"
  printf 'if [ -d "$shimmy_activate_shim_dir" ]; then\n'
  printf '  case ":${PATH:-}:" in\n'
  printf '    *:"$shimmy_activate_shim_dir":*) ;;\n'
  printf '    *) PATH=$shimmy_activate_shim_dir${PATH:+":$PATH"} ;;\n'
  printf '  esac\n'
  printf 'fi\n'
  printf 'unset shimmy_activate_shim_dir\n'
  printf 'shimmy_activate_control_bin_dir=%s\n' "$quoted_control_bin_dir"
  printf 'if [ -d "$shimmy_activate_control_bin_dir" ]; then\n'
  printf '  case ":${PATH:-}:" in\n'
  printf '    *:"$shimmy_activate_control_bin_dir":*) ;;\n'
  printf '    *) PATH=$shimmy_activate_control_bin_dir${PATH:+":$PATH"} ;;\n'
  printf '  esac\n'
  printf 'fi\n'
  printf 'unset shimmy_activate_control_bin_dir\n'
  printf 'shimmy_activate_podman_dir=%s\n' "$quoted_podman_dir"
  printf 'if [ -x "$shimmy_activate_podman_dir/podman" ]; then\n'
  printf '  case ":${PATH:-}:" in\n'
  printf '    *:"$shimmy_activate_podman_dir":*) ;;\n'
  printf '    *)\n'
  printf '      if ! command -v podman >/dev/null 2>&1; then\n'
  printf '        PATH=${PATH:+$PATH:}$shimmy_activate_podman_dir\n'
  printf '      fi\n'
  printf '      ;;\n'
  printf '  esac\n'
  printf 'fi\n'
  printf 'unset shimmy_activate_podman_dir\n'
  printf 'export PATH\n'
}

usage() {
  cat <<'EOF'
Print shell code that activates a Shimmy install in the current shell.

Usage:
  scripts/activate-shimmy.sh [--install-dir <dir>]

Examples:
  ./shimmy activate
  ./shimmy activate --install-dir "$HOME/.config/shimmy"
  eval "$(./shimmy activate)"
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
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done

  install_dir=$(resolve_install_dir)
  manifest_file=$install_dir/install-manifest.txt
  control_bin_dir=$install_dir/bin
  shim_dir=$install_dir/shims

  if [ -f "$manifest_file" ]; then
    manifest_install_dir=$(manifest_value "$manifest_file" install_dir || true)
    if [ -n "$manifest_install_dir" ]; then
      install_dir=$(trim_trailing_slash "$manifest_install_dir")
      control_bin_dir=$install_dir/bin
      shim_dir=$install_dir/shims
    fi
    manifest_control_bin=$(manifest_value "$manifest_file" control_bin || true)
    if [ -n "$manifest_control_bin" ]; then
      control_bin_dir=$(dirname "$manifest_control_bin")
    fi
  fi

  if [ ! -f "$manifest_file" ] && [ ! -d "$shim_dir" ]; then
    fail "no shimmy install found for activate; expected manifest at $manifest_file or shim dir at $shim_dir"
  fi

  render_activate "$control_bin_dir" "$shim_dir" /opt/podman/bin
}

main "$@"
