#!/bin/sh

SHIMMY_LEGACY_STARTUP_BLOCK_END='# <<< shimmy shell init <<<'
SHIMMY_LEGACY_STARTUP_BLOCK_START='# >>> shimmy shell init >>>'
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

shimmy_activate_source_block_render() {
  activate_file=${1:?activate file path is required}
  quoted_activate_file=$(shimmy_quote_shell_word "$activate_file")

  printf 'shimmy_activate_file=%s\n' "$quoted_activate_file"
  printf 'if [ -r "$shimmy_activate_file" ]; then\n'
  printf '  . "$shimmy_activate_file"\n'
  printf 'fi\n'
  printf 'unset shimmy_activate_file\n'
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

shimmy_startup_file_path_list_resolve() {
  shell_name=${1:?shell name is required}
  home_dir=${2:-$HOME}

  case "$shell_name" in
    bash)
      printf '%s\n' "$home_dir/.bashrc"
      if [ -f "$home_dir/.bash_profile" ]; then
        printf '%s\n' "$home_dir/.bash_profile"
      elif [ -f "$home_dir/.bash_login" ]; then
        printf '%s\n' "$home_dir/.bash_login"
      elif [ -f "$home_dir/.profile" ]; then
        printf '%s\n' "$home_dir/.profile"
      else
        printf '%s\n' "$home_dir/.bash_profile"
      fi
      ;;
    zsh)
      printf '%s\n' "$home_dir/.zshrc"
      ;;
    sh|ksh|mksh)
      printf '%s\n' "$home_dir/.profile"
      ;;
    *)
      printf 'ERROR: unsupported shell for startup file path: %s\n' "$shell_name" >&2
      return 1
      ;;
  esac
}

shimmy_startup_block_remove() {
  startup_file=${1:?startup file path is required}

  shimmy_startup_marked_block_remove "$startup_file" "$SHIMMY_STARTUP_BLOCK_START" "$SHIMMY_STARTUP_BLOCK_END"
  shimmy_startup_marked_block_remove "$startup_file" "$SHIMMY_LEGACY_STARTUP_BLOCK_START" "$SHIMMY_LEGACY_STARTUP_BLOCK_END"
}

shimmy_startup_marked_block_remove() {
  startup_file=${1:?startup file path is required}
  start_marker=${2:?start marker is required}
  end_marker=${3:?end marker is required}

  [ -f "$startup_file" ] || return 0

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/shimmy-startup.XXXXXX")
  awk '
    BEGIN { skip=0 }
    $0 == start_marker { skip=1; next }
    $0 == end_marker { skip=0; next }
    skip { next }
    { print }
  ' start_marker="$start_marker" end_marker="$end_marker" "$startup_file" > "$tmp_file"
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
