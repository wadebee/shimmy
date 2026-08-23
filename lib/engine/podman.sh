#!/bin/sh
# Exact Podman machine, connection, guest-marker, and rootless-service primitives.

shimmy_engine_podman_bin_require() {
  if [ -n "${SHIMMY_TEST_ENGINE_PODMAN_BIN:-}" ]; then
    SHIMMY_ENGINE_PODMAN_BIN=$SHIMMY_TEST_ENGINE_PODMAN_BIN
    [ -x "$SHIMMY_ENGINE_PODMAN_BIN" ]
    return
  fi
  if [ -n "${SHIMMY_TEST_PROFILE_PODMAN_BIN:-}" ]; then
    SHIMMY_ENGINE_PODMAN_BIN=$SHIMMY_TEST_PROFILE_PODMAN_BIN
    [ -x "$SHIMMY_ENGINE_PODMAN_BIN" ]
    return
  fi
  if [ -n "${SHIMMY_PROFILE_PODMAN_BIN:-}" ] && [ -x "$SHIMMY_PROFILE_PODMAN_BIN" ]; then
    SHIMMY_ENGINE_PODMAN_BIN=$SHIMMY_PROFILE_PODMAN_BIN
    return 0
  fi
  if command -v podman >/dev/null 2>&1; then
    SHIMMY_ENGINE_PODMAN_BIN=$(command -v podman)
    return 0
  fi
  if [ -x /opt/podman/bin/podman ]; then
    SHIMMY_ENGINE_PODMAN_BIN=/opt/podman/bin/podman
    return 0
  fi
  SHIMMY_ENGINE_PODMAN_BIN=
  return 1
}

shimmy_engine_podman_run() {
  "$SHIMMY_ENGINE_PODMAN_BIN" "$@"
}

shimmy_engine_podman_connection_run() {
  shimmy_engine_podman_connection=$1
  shift
  shimmy_name_component_validate "$shimmy_engine_podman_connection" || return 1
  shimmy_engine_podman_run --connection "$shimmy_engine_podman_connection" "$@"
}

shimmy_engine_podman_machine_state_read() {
  shimmy_engine_podman_machine_requested=$1
  shimmy_name_component_validate "$shimmy_engine_podman_machine_requested" || return 1
  SHIMMY_ENGINE_MACHINE_STATE=absent
  SHIMMY_ENGINE_MACHINE_PROVIDER=none
  shimmy_engine_podman_machine_matches=0
  shimmy_engine_podman_machine_names=
  shimmy_engine_podman_machine_output=$(shimmy_engine_podman_run machine list \
    --format '{{.Name}}|{{.VMType}}|{{.Running}}') || return 1
  while IFS='|' read -r shimmy_engine_podman_machine_name \
    shimmy_engine_podman_machine_provider shimmy_engine_podman_machine_running \
    shimmy_engine_podman_machine_extra; do
    [ -n "$shimmy_engine_podman_machine_name" ] || continue
    case "$shimmy_engine_podman_machine_name" in *\*) shimmy_engine_podman_machine_name=${shimmy_engine_podman_machine_name%\*} ;; esac
    shimmy_name_component_validate "$shimmy_engine_podman_machine_name" || return 1
    shimmy_version_token_validate "$shimmy_engine_podman_machine_provider" || return 1
    [ -z "$shimmy_engine_podman_machine_extra" ] || return 1
    case "$shimmy_engine_podman_machine_running" in true|false) ;; *) return 1 ;; esac
    shimmy_contains_line_list "$shimmy_engine_podman_machine_names" \
      "$shimmy_engine_podman_machine_name" && return 1
    shimmy_engine_podman_machine_names=$(shimmy_append_line_list \
      "$shimmy_engine_podman_machine_names" "$shimmy_engine_podman_machine_name")
    [ "$shimmy_engine_podman_machine_name" = "$shimmy_engine_podman_machine_requested" ] || continue
    shimmy_engine_podman_machine_matches=$((shimmy_engine_podman_machine_matches + 1))
    SHIMMY_ENGINE_MACHINE_PROVIDER=$shimmy_engine_podman_machine_provider
    if [ "$shimmy_engine_podman_machine_running" = true ]; then
      SHIMMY_ENGINE_MACHINE_STATE=running
    else
      SHIMMY_ENGINE_MACHINE_STATE=stopped
    fi
  done <<EOF
$shimmy_engine_podman_machine_output
EOF
  [ "$shimmy_engine_podman_machine_matches" -le 1 ]
}

shimmy_engine_podman_connections_read() {
  SHIMMY_ENGINE_CONNECTION_LINES=$(shimmy_engine_podman_run system connection list \
    --format '{{.Name}}|{{.URI}}|{{.Identity}}|{{.Default}}') || return 1
  shimmy_engine_podman_connection_default_count=0
  SHIMMY_ENGINE_DEFAULT_CONNECTION=none
  shimmy_engine_podman_connection_names=
  while IFS='|' read -r shimmy_engine_podman_connection_name \
    shimmy_engine_podman_connection_uri shimmy_engine_podman_connection_identity \
    shimmy_engine_podman_connection_default shimmy_engine_podman_connection_extra; do
    [ -n "$shimmy_engine_podman_connection_name" ] || continue
    shimmy_name_component_validate "$shimmy_engine_podman_connection_name" || return 1
    shimmy_scalar_value_validate "$shimmy_engine_podman_connection_uri" || return 1
    shimmy_scalar_value_validate "$shimmy_engine_podman_connection_identity" || return 1
    [ -z "$shimmy_engine_podman_connection_extra" ] || return 1
    case "$shimmy_engine_podman_connection_default" in true|false) ;; *) return 1 ;; esac
    shimmy_contains_line_list "$shimmy_engine_podman_connection_names" \
      "$shimmy_engine_podman_connection_name" && return 1
    shimmy_engine_podman_connection_names=$(shimmy_append_line_list \
      "$shimmy_engine_podman_connection_names" "$shimmy_engine_podman_connection_name")
    if [ "$shimmy_engine_podman_connection_default" = true ]; then
      shimmy_engine_podman_connection_default_count=$((shimmy_engine_podman_connection_default_count + 1))
      SHIMMY_ENGINE_DEFAULT_CONNECTION=$shimmy_engine_podman_connection_name
    fi
  done <<EOF
$SHIMMY_ENGINE_CONNECTION_LINES
EOF
  [ "$shimmy_engine_podman_connection_default_count" -le 1 ]
}

shimmy_engine_podman_connection_state_read() {
  shimmy_engine_podman_connection_requested=$1
  shimmy_name_component_validate "$shimmy_engine_podman_connection_requested" || return 1
  shimmy_engine_podman_connections_read || return 1
  SHIMMY_ENGINE_CONNECTION_STATE=absent
  SHIMMY_ENGINE_CONNECTION_URI=
  SHIMMY_ENGINE_CONNECTION_IDENTITY_PATH=
  shimmy_engine_podman_connection_matches=0
  while IFS='|' read -r shimmy_engine_podman_connection_name \
    shimmy_engine_podman_connection_uri shimmy_engine_podman_connection_identity \
    shimmy_engine_podman_connection_default shimmy_engine_podman_connection_extra; do
    [ -n "$shimmy_engine_podman_connection_name" ] || continue
    [ "$shimmy_engine_podman_connection_name" = "$shimmy_engine_podman_connection_requested" ] || continue
    shimmy_engine_podman_connection_matches=$((shimmy_engine_podman_connection_matches + 1))
    SHIMMY_ENGINE_CONNECTION_URI=$shimmy_engine_podman_connection_uri
    SHIMMY_ENGINE_CONNECTION_IDENTITY_PATH=$shimmy_engine_podman_connection_identity
    case "$shimmy_engine_podman_connection_uri" in
      ssh://root@*) SHIMMY_ENGINE_CONNECTION_STATE=rootful ;;
      ssh://*/*/run/user/*/podman/podman.sock|ssh://*/run/user/*/podman/podman.sock)
        SHIMMY_ENGINE_CONNECTION_STATE=rootless
        ;;
      *) SHIMMY_ENGINE_CONNECTION_STATE=invalid ;;
    esac
    if [ "$SHIMMY_ENGINE_CONNECTION_STATE" = rootless ]; then
      shimmy_path_absolute_normalized_validate "$SHIMMY_ENGINE_CONNECTION_IDENTITY_PATH" ||
        SHIMMY_ENGINE_CONNECTION_STATE=invalid
    fi
  done <<EOF
$SHIMMY_ENGINE_CONNECTION_LINES
EOF
  [ "$shimmy_engine_podman_connection_matches" -le 1 ]
}

shimmy_engine_podman_machine_absence_validate() {
  shimmy_engine_podman_absence_name=$1
  shimmy_engine_podman_absence_connection=$2
  shimmy_engine_podman_machine_state_read "$shimmy_engine_podman_absence_name" || return 1
  [ "$SHIMMY_ENGINE_MACHINE_STATE" = absent ] || return 1
  shimmy_engine_podman_connection_state_read "$shimmy_engine_podman_absence_connection" || return 1
  [ "$SHIMMY_ENGINE_CONNECTION_STATE" = absent ] || return 1
  shimmy_engine_podman_connection_state_read "$shimmy_engine_podman_absence_connection-root" || return 1
  [ "$SHIMMY_ENGINE_CONNECTION_STATE" = absent ]
}

shimmy_engine_podman_machine_identity_render() {
  shimmy_engine_podman_identity_name=$1
  shimmy_engine_podman_identity_connection=$2
  shimmy_name_component_validate "$shimmy_engine_podman_identity_name" || return 1
  shimmy_name_component_validate "$shimmy_engine_podman_identity_connection" || return 1
  shimmy_engine_podman_machine_state_read "$shimmy_engine_podman_identity_name" || return 1
  case "$SHIMMY_ENGINE_MACHINE_STATE" in running|stopped) ;; *) return 1 ;; esac
  shimmy_engine_podman_identity_provider=$SHIMMY_ENGINE_MACHINE_PROVIDER
  shimmy_engine_podman_connection_state_read "$shimmy_engine_podman_identity_connection" || return 1
  [ "$SHIMMY_ENGINE_CONNECTION_STATE" = rootless ] || return 1
  shimmy_engine_podman_identity_uri=$SHIMMY_ENGINE_CONNECTION_URI
  shimmy_engine_podman_identity_connection_path=$SHIMMY_ENGINE_CONNECTION_IDENTITY_PATH
  shimmy_engine_podman_identity_output=$(shimmy_engine_podman_run machine inspect \
    --format '{{.Name}}|{{.Created}}|{{.ConfigDir.Path}}|{{.ConnectionInfo.PodmanSocket.Path}}|{{.SSHConfig.IdentityPath}}|{{.SSHConfig.RemoteUsername}}|{{.Rootful}}' \
    "$shimmy_engine_podman_identity_name") || return 1
  IFS='|' read -r shimmy_engine_podman_identity_observed_name \
    shimmy_engine_podman_identity_created shimmy_engine_podman_identity_config_dir \
    shimmy_engine_podman_identity_socket shimmy_engine_podman_identity_ssh_path \
    shimmy_engine_podman_identity_ssh_user shimmy_engine_podman_identity_rootful \
    shimmy_engine_podman_identity_extra <<EOF
$shimmy_engine_podman_identity_output
EOF
  [ -z "$shimmy_engine_podman_identity_extra" ] || return 1
  [ "$shimmy_engine_podman_identity_observed_name" = "$shimmy_engine_podman_identity_name" ] || return 1
  [ "$shimmy_engine_podman_identity_ssh_user" = core ] || return 1
  [ "$shimmy_engine_podman_identity_rootful" = false ] || return 1
  shimmy_scalar_value_validate "$shimmy_engine_podman_identity_created" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_engine_podman_identity_config_dir" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_engine_podman_identity_socket" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_engine_podman_identity_ssh_path" || return 1
  [ "$shimmy_engine_podman_identity_ssh_path" = "$shimmy_engine_podman_identity_connection_path" ] || return 1
  printf 'name=%s\n' "$shimmy_engine_podman_identity_name"
  printf 'provider=%s\n' "$shimmy_engine_podman_identity_provider"
  printf 'created=%s\n' "$shimmy_engine_podman_identity_created"
  printf 'config_dir=%s\n' "$shimmy_engine_podman_identity_config_dir"
  printf 'socket_path=%s\n' "$shimmy_engine_podman_identity_socket"
  printf 'connection_uri=%s\n' "$shimmy_engine_podman_identity_uri"
  printf 'identity_path=%s\n' "$shimmy_engine_podman_identity_ssh_path"
  printf 'remote_username=%s\n' "$shimmy_engine_podman_identity_ssh_user"
  printf 'rootful=%s\n' "$shimmy_engine_podman_identity_rootful"
}

shimmy_engine_podman_machine_identity_fingerprint_render() {
  shimmy_engine_podman_identity_tmp=$(mktemp "${TMPDIR:-/tmp}/shimmy-engine-identity.XXXXXX") || return 1
  shimmy_engine_podman_machine_identity_render "$1" "$2" > "$shimmy_engine_podman_identity_tmp" || {
    rm -f "$shimmy_engine_podman_identity_tmp"
    return 1
  }
  shimmy_engine_podman_identity_fingerprint=$(shimmy_sha256_fingerprint_file_render \
    "$shimmy_engine_podman_identity_tmp") || {
    rm -f "$shimmy_engine_podman_identity_tmp"
    return 1
  }
  rm -f "$shimmy_engine_podman_identity_tmp"
  printf '%s\n' "$shimmy_engine_podman_identity_fingerprint"
}

shimmy_engine_podman_machine_init() {
  shimmy_engine_podman_init_name=$1
  shimmy_engine_podman_init_connection=$2
  shimmy_engine_podman_machine_absence_validate "$shimmy_engine_podman_init_name" \
    "$shimmy_engine_podman_init_connection" || return 1
  shimmy_engine_podman_connections_read || return 1
  SHIMMY_ENGINE_PRIOR_DEFAULT_CONNECTION=$SHIMMY_ENGINE_DEFAULT_CONNECTION
  shimmy_engine_podman_run machine init \
    "$shimmy_engine_podman_init_name" </dev/null || return 1
  shimmy_engine_podman_connections_read || return 1
  if [ "$SHIMMY_ENGINE_PRIOR_DEFAULT_CONNECTION" != none ] &&
    [ "$SHIMMY_ENGINE_DEFAULT_CONNECTION" != "$SHIMMY_ENGINE_PRIOR_DEFAULT_CONNECTION" ]; then
    shimmy_engine_podman_run system connection default \
      "$SHIMMY_ENGINE_PRIOR_DEFAULT_CONNECTION" || return 1
  fi
}

shimmy_engine_podman_workloads_read() {
  shimmy_engine_podman_workloads_connection=$1
  SHIMMY_ENGINE_RUNNING_WORKLOADS=$(shimmy_engine_podman_connection_run \
    "$shimmy_engine_podman_workloads_connection" ps --format '{{.ID}}|{{.Names}}') || return 1
  SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT=0
  while IFS='|' read -r shimmy_engine_podman_workload_id \
    shimmy_engine_podman_workload_name shimmy_engine_podman_workload_extra; do
    [ -n "$shimmy_engine_podman_workload_id" ] || continue
    [ -n "$shimmy_engine_podman_workload_name" ] || return 1
    [ -z "$shimmy_engine_podman_workload_extra" ] || return 1
    case "$shimmy_engine_podman_workload_id" in *[!0123456789abcdef]*) return 1 ;; esac
    shimmy_scalar_value_validate "$shimmy_engine_podman_workload_name" || return 1
    SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT=$((SHIMMY_ENGINE_RUNNING_WORKLOAD_COUNT + 1))
  done <<EOF
$SHIMMY_ENGINE_RUNNING_WORKLOADS
EOF
}

shimmy_engine_podman_machine_start() {
  shimmy_name_component_validate "$1" || return 1
  shimmy_engine_podman_run machine start "$1" </dev/null
}

shimmy_engine_podman_machine_stop() {
  shimmy_name_component_validate "$1" || return 1
  shimmy_engine_podman_run machine stop "$1" </dev/null
}

shimmy_engine_podman_machine_remove() {
  shimmy_name_component_validate "$1" || return 1
  shimmy_engine_podman_run machine rm --force "$1" </dev/null
}

shimmy_engine_podman_guest_marker_run() {
  shimmy_engine_podman_marker_action=$1
  shimmy_engine_podman_marker_name=$2
  shimmy_engine_podman_marker_id=$3
  shimmy_engine_podman_marker_token=$4
  shimmy_name_component_validate "$shimmy_engine_podman_marker_name" || return 1
  shimmy_engine_id_validate "$shimmy_engine_podman_marker_id" || return 1
  shimmy_engine_token_validate "$shimmy_engine_podman_marker_token" || return 1
  shimmy_engine_podman_run machine ssh "$shimmy_engine_podman_marker_name" /bin/sh -s -- \
    "$shimmy_engine_podman_marker_action" "$shimmy_engine_podman_marker_id" \
    "$shimmy_engine_podman_marker_name" "$shimmy_engine_podman_marker_token" <<'EOF'
set -eu
action=$1
engine=$2
name=$3
token=$4
case "$engine" in shared|profile-[abcdefghijklmnopqrstuvwxyz0123456789]*) ;; *) exit 20 ;; esac
case "$name" in ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) exit 20 ;; esac
case "$token" in *[!0123456789abcdef]*) exit 20 ;; esac
[ "${#token}" -eq 64 ]
state_root=$HOME/.local/state/shimmy
marker_root=$state_root/ownership
marker=$marker_root/$engine.conf
expected=$(printf 'shimmy_engine_ownership_version=1\nengine=%s\nname=%s\nownership_token=%s\n' "$engine" "$name" "$token")
case "$action" in
  write)
    umask 077
    [ ! -L "$HOME/.local" ] && [ ! -L "$HOME/.local/state" ] && [ ! -L "$state_root" ] && [ ! -L "$marker_root" ]
    mkdir -p "$marker_root"
    [ -d "$marker_root" ] && [ ! -L "$marker_root" ]
    stage=$marker.tmp.$$
    [ ! -e "$stage" ] && [ ! -L "$stage" ]
    printf '%s\n' "$expected" > "$stage"
    chmod 0600 "$stage"
    mv "$stage" "$marker"
    printf '%s\n' written
    ;;
  verify)
    [ -f "$marker" ] && [ ! -L "$marker" ]
    [ "$(cat "$marker")" = "$expected" ]
    printf '%s\n' matched
    ;;
  remove)
    [ -f "$marker" ] && [ ! -L "$marker" ]
    [ "$(cat "$marker")" = "$expected" ]
    rm -f "$marker"
    printf '%s\n' removed
    ;;
  *) exit 21 ;;
esac
EOF
}

shimmy_engine_podman_guest_marker_write() {
  [ "$(shimmy_engine_podman_guest_marker_run write "$1" "$2" "$3")" = written ]
}

shimmy_engine_podman_guest_marker_verify() {
  [ "$(shimmy_engine_podman_guest_marker_run verify "$1" "$2" "$3" 2>/dev/null)" = matched ]
}

shimmy_engine_podman_guest_marker_remove() {
  [ "$(shimmy_engine_podman_guest_marker_run remove "$1" "$2" "$3")" = removed ]
}

shimmy_engine_podman_projection_dropin_run() {
  shimmy_engine_podman_dropin_action=$1
  shimmy_engine_podman_dropin_machine=$2
  shimmy_engine_podman_dropin_target=$3
  shimmy_name_component_validate "$shimmy_engine_podman_dropin_machine" || return 1
  shimmy_path_absolute_normalized_validate "$shimmy_engine_podman_dropin_target" || return 1
  shimmy_engine_podman_run machine ssh "$shimmy_engine_podman_dropin_machine" /bin/sh -s -- \
    "$shimmy_engine_podman_dropin_action" "$shimmy_engine_podman_dropin_target" <<'EOF'
set -eu
action=$1
target=$2
case "$target" in /*/shimmy/engines/shared/registries.conf|*/shimmy/engines/profile-*/registries.conf) ;; *) exit 20 ;; esac
root=$HOME/.config/containers/registries.conf.d
link=$root/shimmy-active-profile.conf
case "$action" in
  install)
    [ ! -L "$HOME/.config" ] && [ ! -L "$HOME/.config/containers" ] && [ ! -L "$root" ]
    mkdir -p "$root"
    [ -d "$root" ] && [ ! -L "$root" ]
    if [ -e "$link" ] || [ -L "$link" ]; then
      [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]
      printf '%s\n' current
      exit 0
    fi
    stage=$root/.shimmy-active-profile.tmp.$$
    [ ! -e "$stage" ] && [ ! -L "$stage" ]
    ln -s "$target" "$stage"
    mv "$stage" "$link"
    printf '%s\n' installed
    ;;
  verify)
    [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]
    printf '%s\n' current
    ;;
  remove)
    [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]
    rm -f "$link"
    printf '%s\n' removed
    ;;
  *) exit 21 ;;
esac
EOF
}

shimmy_engine_podman_projection_dropin_install() {
  shimmy_engine_podman_dropin_result=$(shimmy_engine_podman_projection_dropin_run \
    install "$1" "$2") || return 1
  case "$shimmy_engine_podman_dropin_result" in installed|current) ;; *) return 1 ;; esac
}

shimmy_engine_podman_projection_dropin_verify() {
  [ "$(shimmy_engine_podman_projection_dropin_run verify "$1" "$2" 2>/dev/null)" = current ]
}

shimmy_engine_podman_projection_dropin_remove() {
  [ "$(shimmy_engine_podman_projection_dropin_run remove "$1" "$2")" = removed ]
}

shimmy_engine_podman_service_pid_read() {
  shimmy_engine_podman_service_machine=$1
  shimmy_name_component_validate "$shimmy_engine_podman_service_machine" || return 1
  shimmy_engine_podman_service_pid=$(shimmy_engine_podman_run machine ssh \
    "$shimmy_engine_podman_service_machine" systemctl --user show \
    --property MainPID --value podman.service) || return 1
  case "$shimmy_engine_podman_service_pid" in ''|*[!0123456789]*) return 1 ;; esac
  printf '%s\n' "$shimmy_engine_podman_service_pid"
}

shimmy_engine_podman_service_recycle() {
  shimmy_engine_podman_service_machine=$1
  shimmy_engine_podman_service_connection=$2
  shimmy_name_component_validate "$shimmy_engine_podman_service_machine" || return 1
  shimmy_name_component_validate "$shimmy_engine_podman_service_connection" || return 1
  shimmy_engine_podman_service_prior_pid=$(shimmy_engine_podman_service_pid_read \
    "$shimmy_engine_podman_service_machine") || return 1
  [ "$(shimmy_engine_podman_run machine ssh "$shimmy_engine_podman_service_machine" \
    systemctl --user is-active podman.socket)" = active ] || return 1
  shimmy_engine_podman_run machine ssh "$shimmy_engine_podman_service_machine" \
    systemctl --user stop podman.service || return 1
  [ "$(shimmy_engine_podman_run machine ssh "$shimmy_engine_podman_service_machine" \
    systemctl --user is-active podman.socket)" = active ] || return 1
  shimmy_engine_podman_service_info=$(shimmy_engine_podman_connection_run \
    "$shimmy_engine_podman_service_connection" info \
    --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}') || return 1
  [ "$shimmy_engine_podman_service_info" = 'true|true' ] || return 1
  [ "$(shimmy_engine_podman_run machine ssh "$shimmy_engine_podman_service_machine" \
    systemctl --user is-active podman.socket)" = active ] || return 1
  shimmy_engine_podman_service_new_pid=$(shimmy_engine_podman_service_pid_read \
    "$shimmy_engine_podman_service_machine") || return 1
  [ "$shimmy_engine_podman_service_new_pid" -gt 0 ] || return 1
  if [ "$shimmy_engine_podman_service_prior_pid" -gt 0 ]; then
    [ "$shimmy_engine_podman_service_new_pid" != "$shimmy_engine_podman_service_prior_pid" ] || return 1
  fi
  SHIMMY_ENGINE_SERVICE_PRIOR_PID=$shimmy_engine_podman_service_prior_pid
  SHIMMY_ENGINE_SERVICE_NEW_PID=$shimmy_engine_podman_service_new_pid
}

shimmy_engine_podman_registry_mapping_read() {
  shimmy_engine_podman_registry_connection=$1
  shimmy_engine_podman_registry_prefix=$2
  shimmy_registries_endpoint_validate "$shimmy_engine_podman_registry_prefix" || return 1
  shimmy_engine_podman_registry_template="{{ with index .Registries \"$shimmy_engine_podman_registry_prefix\" }}{{ .Prefix }}|{{ .Location }}{{ end }}"
  shimmy_engine_podman_connection_run "$shimmy_engine_podman_registry_connection" \
    info --format "$shimmy_engine_podman_registry_template"
}

shimmy_engine_podman_registry_entries_validate() {
  shimmy_engine_podman_registry_connection=$1
  shimmy_engine_podman_registry_expected=${2:-}
  shimmy_engine_podman_registry_prefixes=${3:-}
  shimmy_engine_podman_connection_run "$shimmy_engine_podman_registry_connection" \
    info --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}' | \
    { IFS= read -r shimmy_engine_podman_registry_info; [ "$shimmy_engine_podman_registry_info" = 'true|true' ]; } || return 1
  while IFS= read -r shimmy_engine_podman_registry_prefix; do
    [ -n "$shimmy_engine_podman_registry_prefix" ] || continue
    shimmy_engine_podman_registry_expected_line=$(printf '%s\n' \
      "$shimmy_engine_podman_registry_expected" | awk -F '|' \
      -v prefix="$shimmy_engine_podman_registry_prefix" '$1 == prefix { print; matches += 1 } END { if (matches > 1) exit 1 }') || return 1
    shimmy_engine_podman_registry_actual_line=$(shimmy_engine_podman_registry_mapping_read \
      "$shimmy_engine_podman_registry_connection" "$shimmy_engine_podman_registry_prefix") || return 1
    [ "$shimmy_engine_podman_registry_actual_line" = "$shimmy_engine_podman_registry_expected_line" ] || return 1
  done <<EOF
$shimmy_engine_podman_registry_prefixes
EOF
}
