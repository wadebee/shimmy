#!/bin/sh

SHIMMY_STARTUP_BLOCK_END='# <<< shimmy onboarding <<<'
SHIMMY_STARTUP_BLOCK_START='# >>> shimmy onboarding >>>'

shimmy_activate_block_read() {
  activate_script=${1:?activate script path is required}
  install_dir=${2:-}

  set -- "$activate_script"
  if [ -n "$install_dir" ]; then
    set -- "$@" --install-dir "$install_dir"
  fi

  "$@"
}

shimmy_shell_name_normalize() {
  shell_name=${1:-}

  if [ -z "$shell_name" ]; then
    shell_name=$(basename -- "${SHELL:-sh}")
  fi

  case "$shell_name" in
    bash) printf 'bash\n' ;;
    zsh) printf 'zsh\n' ;;
    ksh|mksh) printf '%s\n' "$shell_name" ;;
    sh|dash|'') printf 'sh\n' ;;
    *)
      printf 'ERROR: unsupported shell for startup setup: %s\n' "$shell_name" >&2
      return 1
      ;;
  esac
}

shimmy_startup_file_label_render() {
  shell_name=${1:?shell name is required}
  requested_startup_file=${2:-}

  if [ -n "$requested_startup_file" ]; then
    printf '%s\n' "$requested_startup_file"
    return 0
  fi

  case "$shell_name" in
    bash) printf '~/.bashrc\n' ;;
    zsh) printf '~/.zshrc\n' ;;
    sh|ksh|mksh) printf '~/.profile\n' ;;
    *)
      printf 'ERROR: unsupported shell for startup file label: %s\n' "$shell_name" >&2
      return 1
      ;;
  esac
}

shimmy_startup_file_path_resolve() {
  shell_name=${1:?shell name is required}
  requested_startup_file=${2:-}
  home_dir=${3:-$HOME}

  if [ -n "$requested_startup_file" ]; then
    printf '%s\n' "$requested_startup_file"
    return 0
  fi

  case "$shell_name" in
    bash) printf '%s\n' "$home_dir/.bashrc" ;;
    zsh) printf '%s\n' "$home_dir/.zshrc" ;;
    sh|ksh|mksh) printf '%s\n' "$home_dir/.profile" ;;
    *)
      printf 'ERROR: unsupported shell for startup file path: %s\n' "$shell_name" >&2
      return 1
      ;;
  esac
}

shimmy_startup_block_remove() {
  startup_file=${1:?startup file path is required}

  [ -f "$startup_file" ] || return 0

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/shimmy-startup.XXXXXX")
  awk '
    BEGIN { skip=0 }
    $0 == start_marker { skip=1; next }
    $0 == end_marker { skip=0; next }
    skip { next }
    { print }
  ' start_marker="$SHIMMY_STARTUP_BLOCK_START" end_marker="$SHIMMY_STARTUP_BLOCK_END" "$startup_file" > "$tmp_file"
  mv "$tmp_file" "$startup_file"
}

shimmy_startup_block_render() {
  activate_block=${1:?activate block is required}

  printf '%s\n' "$SHIMMY_STARTUP_BLOCK_START"
  printf '%s\n' "$activate_block"
  printf '%s\n' "$SHIMMY_STARTUP_BLOCK_END"
}

shimmy_startup_file_update() {
  startup_file=${1:?startup file path is required}
  activate_block=${2:?activate block is required}

  startup_dir=$(dirname -- "$startup_file")
  mkdir -p "$startup_dir"
  if [ ! -f "$startup_file" ]; then
    : > "$startup_file"
  fi

  shimmy_startup_block_remove "$startup_file"
  if [ -s "$startup_file" ] && ! tail -n 1 "$startup_file" | grep '^$' >/dev/null 2>&1; then
    printf '\n' >> "$startup_file"
  fi

  shimmy_startup_block_render "$activate_block" >> "$startup_file"
}
