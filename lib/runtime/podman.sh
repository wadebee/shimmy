#!/bin/sh
# Shared Podman runtime helpers.

shimmy_podman_bin_resolve() {
  if command -v podman >/dev/null 2>&1; then
    SHIMMY_PODMAN_BIN=$(command -v podman)
    return 0
  fi

  if [ -x /opt/podman/bin/podman ]; then
    SHIMMY_PODMAN_BIN=/opt/podman/bin/podman
    return 0
  fi

  SHIMMY_PODMAN_BIN=
  return 1
}

shimmy_podman_bin_require() {
  context_label=${1:-shimmy}

  if ! shimmy_podman_bin_resolve; then
    shimmy_podman_failure_print_missing "$context_label"
    return 1
  fi

  shimmy_podman_path_activate "$SHIMMY_PODMAN_BIN"
  export SHIMMY_PODMAN_BIN
}

shimmy_podman_failure_print_missing() {
  context_label=${1:-shimmy}

  printf 'ERROR: podman is required for %s.\n' "$context_label" >&2
  printf '%s\n' 'Install Podman and ensure the binary is available on PATH.' >&2
  printf '%s\n' 'Shimmy also checks /opt/podman/bin/podman for the macOS pkg installer.' >&2
}

shimmy_podman_failure_print_privileged_connection_missing() {
  context_label=${1:-shimmy}

  printf 'ERROR: SHIMMY_PODMAN_PRIVILEGED=1 requires a rootful Podman connection for %s.\n' "$context_label" >&2
  printf '%s\n' 'Set SHIMMY_PODMAN_PRIVILEGED_CONNECTION to a rootful connection from `podman system connection list`.' >&2
  printf '%s\n' 'On macOS, Podman commonly creates a rootful connection named <default-connection>-root.' >&2
  printf '%s\n' 'Shimmy will use that rootful connection automatically when it exists.' >&2
  printf '%s\n' 'Do not change the default Podman connection just to run a privileged shim command.' >&2
}

shimmy_podman_failure_print_privileged_connection_not_rootful() {
  context_label=${1:-shimmy}
  connection_name=${2:-unknown}

  printf 'ERROR: SHIMMY_PODMAN_PRIVILEGED_CONNECTION=%s is not a verified rootful Podman connection for %s.\n' "$connection_name" "$context_label" >&2
  printf '%s\n' 'Choose a rootful connection from `podman system connection list`, usually one with a root user and /run/podman/podman.sock URI.' >&2
  printf '%s\n' 'Do not change the default Podman connection just to run a privileged shim command.' >&2
}

shimmy_podman_failure_print_unreachable() {
  context_label=${1:-shimmy}
  podman_bin=${2:-podman}

  printf 'ERROR: podman was found at %s but could not talk to the engine for %s.\n' "$podman_bin" "$context_label" >&2
  printf '%s\n' 'Verify that `podman info` succeeds in your shell.' >&2
  printf '%s\n' 'On macOS, inspect the selected profile with: shimmy profile status' >&2
  printf '%s\n' 'If you use a non-default connection, review: podman system connection list' >&2
  if [ -n "${CONTAINER_HOST:-}" ]; then
    printf '%s\n' 'CONTAINER_HOST is set; its value is hidden. Unset it to use profile activation.' >&2
  else
    printf '%s\n' 'If you use CONTAINER_HOST, confirm it points at a reachable Podman service.' >&2
  fi
  printf '%s\n' 'AI Agent note: if `podman info` succeeds but this shim still fails, request approval for the dry-run smoke command prefix, for example ["rg","--version"] or ["./commands/run-tool.sh","rg","--version"].' >&2
  printf '%s\n' 'Approving `podman info` alone does not approve Podman access through a Shimmy wrapper.' >&2
}

shimmy_podman_profile_affinity_fail() {
  affinity_profile=$1
  affinity_profile_root=$2
  affinity_reason=$3

  printf 'ERROR: installed Shimmy profile %s cannot run against the current Darwin Podman engine: %s.\n' "$affinity_profile" "$affinity_reason" >&2
  case "${SHIMMY_PROFILE_RECOMMENDED_ACTION:-investigate}" in
    podman_machine_init)
      printf 'Create the required engine with: %s\n' "$SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND" >&2
      ;;
    profile_activate)
      printf 'Activate it with: %s\n' "$SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND" >&2
      ;;
    profile_activate_restart)
      printf 'Restart it with: %s\n' "$SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND" >&2
      ;;
    unset_override)
      if [ -n "${SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND:-}" ]; then
        printf 'Unset the masking environment with: %s\n' "$SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND" >&2
      else
        printf "Inspect it with: '%s/bin/shimmy' profile status\n" "$affinity_profile_root" >&2
      fi
      ;;
    *)
      printf "Inspect it with: '%s/bin/shimmy' profile status\n" "$affinity_profile_root" >&2
      ;;
  esac
  printf "Then select its PATH in this shell with: . '%s/shell-init.sh'\n" "$affinity_profile_root" >&2
  return 1
}

shimmy_podman_profile_affinity_reason_resolve() {
  case "$SHIMMY_PROFILE_ACTIVATION_STATE" in
    alternate_running)
      SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="alternate Podman machine is running: $SHIMMY_PROFILE_ALTERNATE_RUNNING_MACHINE"
      ;;
    invalid_metadata)
      SHIMMY_PODMAN_PROFILE_AFFINITY_REASON='expected same-name rootless connection or machine metadata is invalid'
      ;;
    invalid_registry)
      SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="registry projection is ${SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE:-invalid}"
      ;;
    mismatched_default)
      SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="global default connection is not $SHIMMY_PROFILE_EXPECTED_CONNECTION"
      ;;
    overridden)
      if [ "${SHIMMY_PROFILE_CONNECTION_OVERRIDE:-none}" != none ]; then
        SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="$SHIMMY_PROFILE_CONNECTION_OVERRIDE masks the global default (value hidden)"
      else
        SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="$SHIMMY_REGISTRIES_OVERRIDE masks the active registry projection (value hidden)"
      fi
      ;;
    registry_restart_required)
      SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="registry projection is ${SHIMMY_REGISTRIES_MACHINE_PROJECTION_STATE:-restart-required}"
      ;;
    stopped)
      SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="Podman machine is stopped: $SHIMMY_PROFILE_EXPECTED_MACHINE"
      ;;
    unavailable)
      if [ "${SHIMMY_PROFILE_EXPECTED_MACHINE_STATE:-unknown}" = missing ]; then
        SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="required Podman machine is missing: $SHIMMY_PROFILE_EXPECTED_MACHINE"
      else
        SHIMMY_PODMAN_PROFILE_AFFINITY_REASON='Podman is unavailable'
      fi
      ;;
    unreachable)
      if [ "${SHIMMY_PROFILE_CONNECTION_METADATA:-unknown}" = unavailable ]; then
        SHIMMY_PODMAN_PROFILE_AFFINITY_REASON='connection metadata is unreachable'
      else
        SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="connection $SHIMMY_PROFILE_EXPECTED_CONNECTION is unreachable"
      fi
      ;;
    *)
      SHIMMY_PODMAN_PROFILE_AFFINITY_REASON="profile activation state is $SHIMMY_PROFILE_ACTIVATION_STATE"
      ;;
  esac
}

shimmy_podman_profile_affinity_require() {
  [ -n "${SHIMMY_RUNTIME_DIR:-}" ] || return 0
  SHIMMY_PROFILE_RECOMMENDED_ACTION=investigate
  SHIMMY_PROFILE_RECOMMENDED_ACTION_COMMAND=
  runtime_profile_root=$(cd -- "$SHIMMY_RUNTIME_DIR/../.." 2>/dev/null && pwd -P) || return 0
  runtime_profile=$(basename -- "$runtime_profile_root")
  case "$runtime_profile" in ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return 0 ;; esac

  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    case "$XDG_CONFIG_HOME" in /*) affinity_config_home=$XDG_CONFIG_HOME ;; *) return 0 ;; esac
  else
    case "${HOME:-}" in /*) affinity_config_home=$HOME/.config ;; *) return 0 ;; esac
  fi
  while [ "$affinity_config_home" != / ]; do
    case "$affinity_config_home" in */) affinity_config_home=${affinity_config_home%/} ;; *) break ;; esac
  done
  if [ "$affinity_config_home" = / ]; then
    affinity_expected_root=/shimmy/profiles/$runtime_profile
  else
    affinity_expected_root=$affinity_config_home/shimmy/profiles/$runtime_profile
  fi
  [ "$runtime_profile_root" = "$affinity_expected_root" ] || return 0

  affinity_manifest=$runtime_profile_root/install-manifest.txt
  if [ ! -f "$affinity_manifest" ] || [ -L "$affinity_manifest" ] ||
    [ "$(sed -n '/^shimmy_install_layout=/p' "$affinity_manifest")" != shimmy_install_layout=profile-materialized-root ] ||
    [ "$(sed -n '/^shimmy_profile_name=/p' "$affinity_manifest")" != "shimmy_profile_name=$runtime_profile" ]; then
    shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" 'profile manifest is missing or invalid'
    return 1
  fi
  [ "$(sed -n 's/^shimmy_install_manifest_version=//p' "$affinity_manifest")" = 2 ] &&
    [ "$(sed -n 's/^shimmy_profile_manifest_version=//p' "$affinity_manifest")" = 2 ] || {
      shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" 'profile manifest version or identity is invalid'
      return 1
    }

  if [ "${SHIMMY_TEST_OS+x}" = x ]; then affinity_host_os=$SHIMMY_TEST_OS; else affinity_host_os=$(uname -s 2>/dev/null || true); fi
  [ "$affinity_host_os" = Darwin ] || return 0
  for affinity_helper in \
    "$runtime_profile_root/lib/common/common.sh" \
    "$runtime_profile_root/lib/profile/profile.sh" \
    "$runtime_profile_root/lib/profile/activation.sh" \
    "$runtime_profile_root/lib/registries/registries.sh"
  do
    [ -f "$affinity_helper" ] && [ ! -L "$affinity_helper" ] || {
      shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" 'profile engine helpers are missing or invalid'
      return 1
    }
  done
  if [ ! -f "$runtime_profile_root/lib/profile/state.sh" ] || [ -L "$runtime_profile_root/lib/profile/state.sh" ]; then
    shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" 'active profile state helper is missing or invalid'
    return 1
  fi
  . "$runtime_profile_root/lib/common/common.sh"
  . "$runtime_profile_root/lib/profile/profile.sh"
  . "$runtime_profile_root/lib/profile/state.sh"
  . "$runtime_profile_root/lib/profile/activation.sh"
  . "$runtime_profile_root/lib/registries/registries.sh"
  if [ -e "$runtime_profile_root/engine-binding.conf" ] ||
    [ -L "$runtime_profile_root/engine-binding.conf" ]; then
    for affinity_engine_helper in state podman ownership projection registry; do
      affinity_engine_path=$runtime_profile_root/lib/engine/$affinity_engine_helper.sh
      [ -f "$affinity_engine_path" ] && [ ! -L "$affinity_engine_path" ] || {
        shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" \
          'published engine binding is missing its engine helpers'
        return 1
      }
      . "$affinity_engine_path"
    done
  fi
  shimmy_profile_paths_resolve_name "$runtime_profile" || {
    shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" 'profile engine paths are invalid'
    return 1
  }
  if [ "${SHIMMY_PROFILE_ENGINE_TRANSITION_ACTIVE:-0}" -eq 1 ]; then
    :
  else
    shimmy_active_profile_read "$SHIMMY_CONFIG_ROOT/active-profile.conf" &&
      [ "$SHIMMY_ACTIVE_PROFILE_NAME" = "$runtime_profile" ] || {
        shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" 'installation active record belongs to another profile or is invalid'
        return 1
      }
  fi
  shimmy_registries_config_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" "$runtime_profile" || {
    shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" 'registry configuration is invalid'
    return 1
  }
  if [ "${SHIMMY_TEST_OS+x}" = x ]; then
    SHIMMY_TEST_PROFILE_OS=$SHIMMY_TEST_OS
  fi
  shimmy_profile_state_read
  shimmy_profile_activation_recommendation_resolve
  if [ "$SHIMMY_PROFILE_ACTIVATION_STATE" = active ]; then
    SHIMMY_PODMAN_PROFILE_REGISTRY_AFFINITY=$runtime_profile:current
    return 0
  fi
  shimmy_podman_profile_affinity_reason_resolve
  shimmy_podman_profile_affinity_fail "$runtime_profile" "$runtime_profile_root" "$SHIMMY_PODMAN_PROFILE_AFFINITY_REASON"
}

shimmy_podman_is_preview() {
  [ "${SHIMMY_PODMAN_PREVIEW:-0}" = 1 ]
}

shimmy_podman_path_activate() {
  podman_bin=${1:?podman binary path is required}
  podman_dir=$(dirname -- "$podman_bin")

  case ":${PATH:-}:" in
    *":$podman_dir:"*)
      ;;
    *)
      PATH=$podman_dir${PATH:+":$PATH"}
      export PATH
      ;;
  esac
}

shimmy_podman_architecture_normalize() {
  architecture_value=${1:-}

  case "$architecture_value" in
    amd64|x86_64)
      printf '%s\n' amd64
      ;;
    aarch64|arm64)
      printf '%s\n' arm64
      ;;
    '')
      printf '%s\n' 'ERROR: unable to detect host architecture for Podman platform selection.' >&2
      return 1
      ;;
    *)
      printf 'ERROR: unsupported host architecture for Podman platform selection: %s\n' "$architecture_value" >&2
      return 1
      ;;
  esac
}

shimmy_podman_platform_resolve() {
  SHIMMY_PODMAN_PLATFORM=

  if [ "${SHIMMY_TEST_OS+x}" = x ]; then
    os_name=$SHIMMY_TEST_OS
  else
    os_name=$(uname -s 2>/dev/null) || os_name=
  fi

  if [ "${SHIMMY_TEST_ARCH+x}" = x ]; then
    architecture_name=$SHIMMY_TEST_ARCH
  else
    architecture_name=$(uname -m 2>/dev/null) || architecture_name=
  fi

  case "$os_name" in
    Linux|Darwin)
      ;;
    '')
      printf '%s\n' 'ERROR: unable to detect host operating system for Podman platform selection.' >&2
      return 1
      ;;
    *)
      printf 'ERROR: unsupported host operating system for Podman platform selection: %s\n' "$os_name" >&2
      return 1
      ;;
  esac

  architecture_normalized=$(shimmy_podman_architecture_normalize "$architecture_name") || return 1
  SHIMMY_PODMAN_PLATFORM=linux/$architecture_normalized
}

shimmy_podman_required_platforms_print() {
  printf '%s\n' linux/amd64 linux/arm64
}

shimmy_podman_platform_tag_render() {
  platform_value=${1:?platform value is required}

  printf '%s\n' "$platform_value" | sed 's#[/:]#-#g'
}

shimmy_podman_ca_bundle_prepare() {
  SHIMMY_PODMAN_CA_BUNDLE_SOURCE=
  SHIMMY_PODMAN_CA_BUNDLE_TARGET=
  SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT=

  if [ "$#" -ne 1 ]; then
    printf '%s\n' 'ERROR: exactly one native CA environment variable name is required.' >&2
    return 1
  fi

  ca_bundle_native_environment_name=$1
  case "$ca_bundle_native_environment_name" in
    ''|[!A-Za-z_]*|*[!A-Za-z0-9_]*)
      printf 'ERROR: invalid native CA environment variable name: %s\n' \
        "$ca_bundle_native_environment_name" >&2
      return 1
      ;;
  esac

  ca_bundle_source=${SHIMMY_HOST_CA_BUNDLE:-}
  [ -n "$ca_bundle_source" ] || return 0

  case "$ca_bundle_source" in
    /*)
      ;;
    *)
      printf 'ERROR: SHIMMY_HOST_CA_BUNDLE must name an absolute readable CA bundle file: %s\n' \
        "$ca_bundle_source" >&2
      return 1
      ;;
  esac

  if [ ! -f "$ca_bundle_source" ] || [ ! -r "$ca_bundle_source" ]; then
    printf 'ERROR: SHIMMY_HOST_CA_BUNDLE must name an absolute readable CA bundle file: %s\n' \
      "$ca_bundle_source" >&2
    return 1
  fi

  SHIMMY_PODMAN_CA_BUNDLE_SOURCE=$ca_bundle_source
  SHIMMY_PODMAN_CA_BUNDLE_TARGET=/tmp/shimmy-host-ca-bundle.pem
  SHIMMY_PODMAN_CA_BUNDLE_ENV_ASSIGNMENT=$ca_bundle_native_environment_name=$SHIMMY_PODMAN_CA_BUNDLE_TARGET
}

shimmy_podman_preview_args_include() {
  for arg do
    if [ "$arg" = "--preview-shim" ]; then
      return 0
    fi
  done

  return 1
}

shimmy_podman_preview_prepare() {
  if ! shimmy_podman_preview_args_include "$@"; then
    SHIMMY_PODMAN_PREVIEW=0
    return 0
  fi

  SHIMMY_PODMAN_PREVIEW=1
  if ! shimmy_podman_bin_resolve; then
    SHIMMY_PODMAN_BIN=podman
  fi
  shimmy_podman_platform_resolve
  export SHIMMY_PODMAN_BIN
}

shimmy_podman_preflight_require() {
  context_label=${1:-shimmy}

  shimmy_podman_bin_require "$context_label" || return 1
  shimmy_podman_platform_resolve
  shimmy_podman_profile_affinity_require || return 1

  if ! "$SHIMMY_PODMAN_BIN" info >/dev/null 2>&1; then
    shimmy_podman_failure_print_unreachable "$context_label" "$SHIMMY_PODMAN_BIN"
    return 1
  fi
}

shimmy_podman_preflight_or_preview_require() {
  context_label=${1:-shimmy}
  shift

  shimmy_podman_preview_prepare "$@"
  if shimmy_podman_is_preview; then
    return 0
  fi

  shimmy_podman_preflight_require "$context_label"
}

shimmy_podman_privileged_connection_require() {
  context_label=${1:-shimmy}

  if ! shimmy_podman_privileged_connection_resolve; then
    shimmy_podman_failure_print_privileged_connection_missing "$context_label"
    return 1
  fi

  rootless_value=$("$SHIMMY_PODMAN_BIN" --connection "$SHIMMY_PODMAN_PRIVILEGED_CONNECTION" info --format '{{.Host.Security.Rootless}}' 2>/dev/null || printf unknown)
  if [ "$rootless_value" != false ]; then
    shimmy_podman_failure_print_privileged_connection_not_rootful "$context_label" "$SHIMMY_PODMAN_PRIVILEGED_CONNECTION"
    return 1
  fi

  export SHIMMY_PODMAN_PRIVILEGED_CONNECTION
}

shimmy_podman_privileged_connection_resolve() {
  if [ -n "${SHIMMY_PODMAN_PRIVILEGED_CONNECTION:-}" ]; then
    return 0
  fi

  default_connection=$("$SHIMMY_PODMAN_BIN" system connection list --format '{{range .}}{{if .Default}}{{.Name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null | sed -n '1p' || printf '')
  connection_names=$("$SHIMMY_PODMAN_BIN" system connection list --format '{{range .}}{{.Name}}{{"\n"}}{{end}}' 2>/dev/null || printf '')

  if [ -n "$default_connection" ]; then
    root_connection=$default_connection-root
    while IFS= read -r connection_name; do
      if [ "$connection_name" = "$root_connection" ]; then
        SHIMMY_PODMAN_PRIVILEGED_CONNECTION=$root_connection
        return 0
      fi
    done <<EOF
$connection_names
EOF
  fi

  connection_entries=$("$SHIMMY_PODMAN_BIN" system connection list --format '{{range .}}{{.Name}} {{.URI}}{{"\n"}}{{end}}' 2>/dev/null || printf '')
  while IFS=' ' read -r connection_name connection_uri; do
    [ -n "$connection_name" ] || continue
    case "$connection_uri" in
      ssh://root@*|*/run/podman/podman.sock*)
        SHIMMY_PODMAN_PRIVILEGED_CONNECTION=$connection_name
        return 0
        ;;
    esac
  done <<EOF
$connection_entries
EOF

  SHIMMY_PODMAN_PRIVILEGED_CONNECTION=
  return 1
}

shimmy_podman_shell_word_print() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

shimmy_podman_command_preview_print() {
  separator=

  for arg do
    [ "$arg" = "--preview-shim" ] && continue
    printf '%s' "$separator"
    shimmy_podman_shell_word_print "$arg"
    separator=' '
  done

  printf '\n'
}

shimmy_podman_run_or_preview() {
  if shimmy_podman_is_preview; then
    shimmy_podman_command_preview_print "$@"
    return 0
  fi

  exec "$@"
}
