#!/usr/bin/env bash

shimmy::_is_log_level_enabled() {
  local message_level="${1:?message level is required}"
  local configured_level

  configured_level="$(shimmy::_log_level_normalize "${LOG_LEVEL:-info}")"
  [[ "$(shimmy::_log_level_value "$message_level")" -ge "$(shimmy::_log_level_value "$configured_level")" ]]
}

shimmy::_log_level_normalize() {
  case "${1:-info}" in
    debug) printf 'debug\n' ;;
    info) printf 'info\n' ;;
    warn|warning) printf 'warn\n' ;;
    error) printf 'error\n' ;;
    silent|quiet|none) printf 'silent\n' ;;
    *) printf 'info\n' ;;
  esac
}

shimmy::_log_level_value() {
  case "${1:-info}" in
    debug) printf '10\n' ;;
    info) printf '20\n' ;;
    warn|warning) printf '30\n' ;;
    error) printf '40\n' ;;
    silent|quiet|none) printf '50\n' ;;
    *) printf '20\n' ;;
  esac
}

shimmy::log() {
  local level="${1:?log level is required}"
  shift

  shimmy::_is_log_level_enabled "$level" || return 0

  printf '%s: %s\n' "$(tr '[:lower:]' '[:upper:]' <<< "$level")" "$*" >&2
}

shimmy::log_debug() {
  shimmy::log debug "$@"
}

shimmy::log_error() {
  shimmy::log error "$@"
}

shimmy::log_info() {
  shimmy::log info "$@"
}

shimmy::log_init() {
  LOG_LEVEL="$(shimmy::_log_level_normalize "${LOG_LEVEL:-info}")"
  export LOG_LEVEL
}

shimmy::log_warn() {
  shimmy::log warn "$@"
}
