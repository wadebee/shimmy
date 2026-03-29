#!/bin/sh

shimmy__is_log_level_enabled() {
  message_level=${1:?message level is required}
  configured_level=$(shimmy__log_level_normalize "${LOG_LEVEL:-info}")

  [ "$(shimmy__log_level_value "$message_level")" -ge "$(shimmy__log_level_value "$configured_level")" ]
}

shimmy__log_level_normalize() {
  case "${1:-info}" in
    debug) printf 'debug\n' ;;
    info) printf 'info\n' ;;
    warn|warning) printf 'warn\n' ;;
    error) printf 'error\n' ;;
    silent|quiet|none) printf 'silent\n' ;;
    *) printf 'info\n' ;;
  esac
}

shimmy__log_level_value() {
  case "${1:-info}" in
    debug) printf '10\n' ;;
    info) printf '20\n' ;;
    warn|warning) printf '30\n' ;;
    error) printf '40\n' ;;
    silent|quiet|none) printf '50\n' ;;
    *) printf '20\n' ;;
  esac
}

shimmy_log() {
  level=${1:?log level is required}
  shift

  shimmy__is_log_level_enabled "$level" || return 0

  upper_level=$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]')
  printf '%s: %s\n' "$upper_level" "$*" >&2
}

shimmy_log_debug() {
  shimmy_log debug "$@"
}

shimmy_log_error() {
  shimmy_log error "$@"
}

shimmy_log_info() {
  shimmy_log info "$@"
}

shimmy_log_init() {
  LOG_LEVEL=$(shimmy__log_level_normalize "${LOG_LEVEL:-info}")
  export LOG_LEVEL
}

shimmy_log_warn() {
  shimmy_log warn "$@"
}
