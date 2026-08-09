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
  printf '%s\n' 'On macOS, start the engine from a normal user shell with: podman machine start' >&2
  printf '%s\n' 'If you use a non-default connection, review: podman system connection list' >&2
  if [ -n "${CONTAINER_HOST:-}" ]; then
    printf 'Current CONTAINER_HOST=%s\n' "$CONTAINER_HOST" >&2
    printf '%s\n' 'Confirm that CONTAINER_HOST points at a reachable Podman service or unset it to use the default connection.' >&2
  else
    printf '%s\n' 'If you use CONTAINER_HOST, confirm it points at a reachable Podman service.' >&2
  fi
  printf '%s\n' 'AI Agent note: if `podman info` succeeds but this shim still fails, request approval for the dry-run smoke command prefix, for example ["rg","--version"] or ["./commands/run-tool.sh","rg","--version"].' >&2
  printf '%s\n' 'Approving `podman info` alone does not approve Podman access through a Shimmy wrapper.' >&2
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

shimmy_podman_platform_resolve() {
  os_name=${SHIMMY_TEST_OS:-$(uname -s 2>/dev/null || printf unknown)}

  case "$os_name" in
    Darwin)
      SHIMMY_PODMAN_PLATFORM=linux/arm64
      ;;
    Linux)
      SHIMMY_PODMAN_PLATFORM=linux/amd64
      ;;
    *)
      SHIMMY_PODMAN_PLATFORM=linux/amd64
      ;;
  esac
}

shimmy_podman_platform_tag_render() {
  platform_value=${1:?platform value is required}

  printf '%s\n' "$platform_value" | sed 's#[/:]#-#g'
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
