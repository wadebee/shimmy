#!/bin/sh
set -eu

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Print shell code that activates a Shimmy install in the current shell.

Usage:
  scripts/shellenv-shimmy.sh [--install-dir <dir>]

Examples:
  ./shimmy shellenv
  ./shimmy shellenv --install-dir "$HOME/.config/shimmy"
  eval "$(./shimmy shellenv)"
EOF
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
  requested_install_dir=$1

  if [ -n "$requested_install_dir" ]; then
    printf '%s\n' "$requested_install_dir"
    return 0
  fi

  if [ -n "${SHIMMY_INSTALL_DIR:-}" ]; then
    printf '%s\n' "$SHIMMY_INSTALL_DIR"
    return 0
  fi

  printf '%s/.config/shimmy\n' "$HOME"
}

render_shellenv() {
  install_dir=$1
  shim_dir=$2
  images_dir=$3
  shim_lib_dir=$4

  quoted_install_dir=$(shell_quote "$install_dir")
  quoted_shim_dir=$(shell_quote "$shim_dir")
  quoted_images_dir=$(shell_quote "$images_dir")
  quoted_shim_lib_dir=$(shell_quote "$shim_lib_dir")

  printf 'export SHIMMY_INSTALL_DIR=%s\n' "$quoted_install_dir"
  printf 'export SHIMMY_SHIM_DIR=%s\n' "$quoted_shim_dir"
  printf 'export SHIMMY_IMAGES_DIR=%s\n' "$quoted_images_dir"
  printf 'export SHIMMY_SHIM_LIB_DIR=%s\n' "$quoted_shim_lib_dir"
  printf 'if [ -d "$SHIMMY_SHIM_DIR" ]; then\n'
  printf '  case ":${PATH:-}:" in\n'
  printf '    *:"$SHIMMY_SHIM_DIR":*) ;;\n'
  printf '    *) export PATH="${PATH:+$PATH:}$SHIMMY_SHIM_DIR" ;;\n'
  printf '  esac\n'
  printf 'fi\n'
}

main() {
  requested_install_dir=

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        requested_install_dir=$2
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

  install_dir=$(resolve_install_dir "$requested_install_dir")
  manifest_file=$install_dir/install-manifest.txt

  shim_dir=${SHIMMY_SHIM_DIR:-}
  images_dir=${SHIMMY_IMAGES_DIR:-}
  shim_lib_dir=${SHIMMY_SHIM_LIB_DIR:-}

  if [ -f "$manifest_file" ]; then
    install_dir=$(manifest_value "$manifest_file" install_dir || printf '%s\n' "$install_dir")
    if [ -z "$shim_dir" ]; then
      shim_dir=$(manifest_value "$manifest_file" shim_dir || true)
    fi
    if [ -z "$images_dir" ]; then
      images_dir=$(manifest_value "$manifest_file" images_dir || true)
    fi
    if [ -z "$shim_lib_dir" ]; then
      shim_lib_dir=$(manifest_value "$manifest_file" shim_lib_dir || true)
    fi
  fi

  if [ -z "$shim_dir" ]; then
    shim_dir=$install_dir/shims
  fi
  if [ -z "$images_dir" ]; then
    images_dir=$install_dir/images
  fi
  if [ -z "$shim_lib_dir" ]; then
    shim_lib_dir=$install_dir/lib/shims
  fi

  if [ ! -f "$manifest_file" ] && [ ! -d "$shim_dir" ]; then
    fail "no shimmy install found for shellenv; expected manifest at $manifest_file or shim dir at $shim_dir"
  fi

  render_shellenv "$install_dir" "$shim_dir" "$images_dir" "$shim_lib_dir"
}

main "$@"
