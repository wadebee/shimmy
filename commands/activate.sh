#!/bin/sh
# Activate an installed Shimmy profile.
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
COMMON_HELPER_FILE=$ROOT_DIR/core/common/common.sh
PROFILE_HELPER_FILE=$ROOT_DIR/core/profile/profile.sh
DEFAULT_INSTALL_DIR=${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}
REQUESTED_INSTALL_DIR=
SHIMMY_PROFILE_REQUESTED=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [ ! -f "$COMMON_HELPER_FILE" ]; then
  fail "missing common helper: $COMMON_HELPER_FILE"
fi

if [ ! -f "$PROFILE_HELPER_FILE" ]; then
  fail "missing profile helper: $PROFILE_HELPER_FILE"
fi

# shellcheck source=core/common/common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=core/profile/profile.sh
. "$PROFILE_HELPER_FILE"

resolve_install_dir() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(shimmy_trim_path_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(shimmy_trim_path_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

render_activate() {
  bin_dir=$1
  podman_dir=$2
  mode_export_value=$3

  quoted_bin_dir=$(shimmy_quote_shell_word "$bin_dir")
  quoted_podman_dir=$(shimmy_quote_shell_word "$podman_dir")

  if [ -n "$mode_export_value" ]; then
    quoted_mode_export_value=$(shimmy_quote_shell_word "$mode_export_value")
    printf 'SHIMMY_PROFILE_ACTIVE=%s\n' "$quoted_mode_export_value"
    printf 'export SHIMMY_PROFILE_ACTIVE\n'
  fi

  printf 'shimmy_activate_bin_dir=%s\n' "$quoted_bin_dir"
  printf 'if [ -d "$shimmy_activate_bin_dir" ]; then\n'
  printf '  case ":${PATH:-}:" in\n'
  printf '    *:"$shimmy_activate_bin_dir":*) ;;\n'
  printf '    *) PATH=$shimmy_activate_bin_dir${PATH:+":$PATH"} ;;\n'
  printf '  esac\n'
  printf 'fi\n'
  printf 'unset shimmy_activate_bin_dir\n'
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
  commands/activate.sh [--install-dir <dir>] [--profile default|upstream]

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
  bin_dir=$SHIMMY_INSTALL_BIN_DIR

  if [ -f "$root_manifest_file" ]; then
    manifest_install_dir=$(shimmy_read_manifest_value "$root_manifest_file" install_dir || true)
    if [ -n "$manifest_install_dir" ]; then
      install_dir=$(shimmy_trim_path_trailing_slash "$manifest_install_dir")
      shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$install_dir" "$ROOT_DIR" || fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
      bin_dir=$SHIMMY_INSTALL_BIN_DIR
      root_manifest_file=$install_dir/install-manifest.txt
      profile_manifest_file=$SHIMMY_PROFILE_MANIFEST_PATH
      manifest_file=$profile_manifest_file
    fi
    manifest_bin_dir=$(shimmy_read_manifest_value "$root_manifest_file" bin_dir || true)
    if [ -n "$manifest_bin_dir" ]; then
      bin_dir=$manifest_bin_dir
    fi
  fi

  if ! shimmy_profile_structure_validate "$manifest_file" "$SHIMMY_PROFILE_IMPLEMENTATION_DIR"; then
    install_hint=$(shimmy_profile_install_hint "$SHIMMY_PROFILE_NAME")
    fail "incomplete Shimmy profile for profile $SHIMMY_PROFILE_NAME: expected manifest at $manifest_file and implementation directory at $SHIMMY_PROFILE_IMPLEMENTATION_DIR; repair with $install_hint"
  fi

  if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
    source_checkout=$(shimmy_read_manifest_value "$manifest_file" source_checkout || true)
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $source_checkout; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
  fi

  render_activate "$bin_dir" /opt/podman/bin "$SHIMMY_PROFILE_NAME"
}

main "$@"
