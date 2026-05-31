#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
PROFILE_HELPER_FILE=$ROOT_DIR/lib/repo/shimmy-profile.sh
DEFAULT_INSTALL_DIR=${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}
REQUESTED_INSTALL_DIR=
SHIMMY_PROFILE_REQUESTED=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [ ! -f "$PROFILE_HELPER_FILE" ]; then
  fail "missing profile helper: $PROFILE_HELPER_FILE"
fi

# shellcheck source=lib/repo/shimmy-profile.sh
. "$PROFILE_HELPER_FILE"

shell_quote() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

resolve_install_dir() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(shimmy_path_trim_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(shimmy_path_trim_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

render_activate() {
  control_bin_dir=$1
  dispatcher_dir=$2
  podman_dir=$3
  mode_export_value=$4

  quoted_control_bin_dir=$(shell_quote "$control_bin_dir")
  quoted_dispatcher_dir=$(shell_quote "$dispatcher_dir")
  quoted_podman_dir=$(shell_quote "$podman_dir")

  if [ -n "$mode_export_value" ]; then
    quoted_mode_export_value=$(shell_quote "$mode_export_value")
    printf 'SHIMMY_PROFILE_ACTIVE=%s\n' "$quoted_mode_export_value"
    printf 'export SHIMMY_PROFILE_ACTIVE\n'
  fi

  printf 'shimmy_activate_dispatcher_dir=%s\n' "$quoted_dispatcher_dir"
  printf 'if [ -d "$shimmy_activate_dispatcher_dir" ]; then\n'
  printf '  case ":${PATH:-}:" in\n'
  printf '    *:"$shimmy_activate_dispatcher_dir":*) ;;\n'
  printf '    *) PATH=$shimmy_activate_dispatcher_dir${PATH:+":$PATH"} ;;\n'
  printf '  esac\n'
  printf 'fi\n'
  printf 'unset shimmy_activate_dispatcher_dir\n'
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
  scripts/activate-shimmy.sh [--install-dir <dir>] [--profile default|upstream]

Examples:
  ./shimmy activate
  ./shimmy activate --profile upstream
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
      --profile)
        [ "$#" -ge 2 ] || fail "missing value for --profile"
        SHIMMY_PROFILE_REQUESTED=$2
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

  if ! shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$(resolve_install_dir)" "$ROOT_DIR"; then
    fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
  fi

  install_dir=$SHIMMY_PROFILE_INSTALL_DIR
  profile_manifest_file=$SHIMMY_PROFILE_MANIFEST_PATH
  root_manifest_file=$install_dir/install-manifest.txt
  manifest_file=$profile_manifest_file
  control_bin_dir=$SHIMMY_PROFILE_CONTROL_BIN_DIR
  dispatcher_dir=$SHIMMY_PROFILE_DISPATCHER_DIR

  if [ -f "$root_manifest_file" ]; then
    manifest_install_dir=$(shimmy_manifest_value "$root_manifest_file" install_dir || true)
    if [ -n "$manifest_install_dir" ]; then
      install_dir=$(shimmy_path_trim_trailing_slash "$manifest_install_dir")
      shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$install_dir" "$ROOT_DIR" || fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
      control_bin_dir=$install_dir/bin
      dispatcher_dir=$install_dir/shims
      root_manifest_file=$install_dir/install-manifest.txt
      profile_manifest_file=$SHIMMY_PROFILE_MANIFEST_PATH
      manifest_file=$profile_manifest_file
    fi
    manifest_control_bin=$(shimmy_manifest_value "$root_manifest_file" control_bin || true)
    if [ -n "$manifest_control_bin" ]; then
      control_bin_dir=$(dirname "$manifest_control_bin")
    fi
    manifest_dispatcher_dir=$(shimmy_manifest_value "$root_manifest_file" dispatcher_dir || true)
    if [ -n "$manifest_dispatcher_dir" ]; then
      dispatcher_dir=$manifest_dispatcher_dir
    fi
  fi

  if ! shimmy_profile_structure_validate "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"; then
    install_hint=$(shimmy_profile_install_hint "$SHIMMY_PROFILE_NAME")
    fail "incomplete Shimmy profile for profile $SHIMMY_PROFILE_NAME: expected manifest at $manifest_file and implementation directory at $SHIMMY_PROFILE_IMPLEMENTATION_DIR; repair with $install_hint"
  fi

  if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
    source_checkout=$(shimmy_manifest_value "$manifest_file" source_checkout || true)
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $source_checkout; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
  fi

  render_activate "$control_bin_dir" "$dispatcher_dir" /opt/podman/bin "$SHIMMY_PROFILE_NAME"
}

main "$@"
