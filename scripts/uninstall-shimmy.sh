#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin/shimmy"
BASHRC_FILE="$HOME/.bashrc"
BASH_PROFILE_FILE="$HOME/.bash_profile"
BASH_SHIMMY_FILE="$HOME/.bashrc_shimmy"
SHIMMY_PROFILE_DIR="${HOME}/.config/shimmy"
INSTALL_MANIFEST_FILE="$SHIMMY_PROFILE_DIR/install-manifest.txt"
MANIFEST_FILE_EXPLICIT=0
SHELL_INIT_BLOCK_START="# >>> shimmy shell init >>>"
SHELL_INIT_BLOCK_END="# <<< shimmy shell init <<<"
PATH_BLOCK_START="# >>> shimmy shims >>>"
PATH_BLOCK_END="# <<< shimmy shims <<<"

usage() {
  cat <<'EOF'
Remove shimmy CLI shims and profile artifacts created by the installer.

Usage:
  scripts/uninstall-shimmy.sh [options]

Options:
  --install-dir <dir>        Installed shim directory to remove.
                             Default: ~/.local/bin/shimmy
  --bashrc-file <file>       Bash rc file to clean (default: ~/.bashrc).
  --bash-profile-file <file> Bash profile file to clean (default: ~/.bash_profile).
  --bash-shimmy-file <file>  Managed shim PATH file to clean (default: ~/.bashrc_shimmy).
  --profile-dir <dir>        Shimmy profile directory (default: ~/.config/shimmy).
  --manifest-file <file>     Install manifest file to read/remove.
                             Default: ~/.config/shimmy/install-manifest.txt
  -h, --help                 Show help.
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      [[ $# -ge 2 ]] || fail "missing value for --install-dir"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --bashrc-file)
      [[ $# -ge 2 ]] || fail "missing value for --bashrc-file"
      BASHRC_FILE="$2"
      shift 2
      ;;
    --bash-profile-file)
      [[ $# -ge 2 ]] || fail "missing value for --bash-profile-file"
      BASH_PROFILE_FILE="$2"
      shift 2
      ;;
    --bash-shimmy-file)
      [[ $# -ge 2 ]] || fail "missing value for --bash-shimmy-file"
      BASH_SHIMMY_FILE="$2"
      shift 2
      ;;
    --profile-dir)
      [[ $# -ge 2 ]] || fail "missing value for --profile-dir"
      SHIMMY_PROFILE_DIR="$2"
      if [[ "$MANIFEST_FILE_EXPLICIT" -eq 0 ]]; then
        INSTALL_MANIFEST_FILE="$SHIMMY_PROFILE_DIR/install-manifest.txt"
      fi
      shift 2
      ;;
    --manifest-file)
      [[ $# -ge 2 ]] || fail "missing value for --manifest-file"
      INSTALL_MANIFEST_FILE="$2"
      MANIFEST_FILE_EXPLICIT=1
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

remove_managed_block() {
  local file="$1"
  local start_marker="$2"
  local end_marker="$3"
  local tmp

  [[ -f "$file" ]] || return 0

  tmp="$(mktemp)"
  awk '
    BEGIN { skip=0 }
    $0 == start_marker { skip=1; next }
    $0 == end_marker { skip=0; next }
    skip { next }
    { print }
  ' start_marker="$start_marker" end_marker="$end_marker" "$file" > "$tmp"
  mv "$tmp" "$file"
}

remove_file_if_empty() {
  local file="$1"

  [[ -f "$file" ]] || return 0
  if ! grep -q '[^[:space:]]' "$file"; then
    rm -f "$file"
  fi
}

manifest_lists_path() {
  local key="$1"
  local path="$2"

  [[ -f "$INSTALL_MANIFEST_FILE" ]] || return 1
  grep -Fx -- "$key=$path" "$INSTALL_MANIFEST_FILE" >/dev/null
}

remove_empty_parent_dirs() {
  local dir="$1"
  local stop_dir="$2"

  while [[ -n "$dir" && "$dir" != "/" ]]; do
    rmdir "$dir" 2>/dev/null || break
    [[ "$dir" == "$stop_dir" ]] && break
    dir="$(dirname "$dir")"
  done
}

remove_manifest_profile_files() {
  local line path

  [[ -f "$INSTALL_MANIFEST_FILE" ]] || return 0

  while IFS= read -r line; do
    case "$line" in
      created_profile_file=*)
        path="${line#created_profile_file=}"
        rm -f "$path"
        remove_empty_parent_dirs "$(dirname "$path")" "$SHIMMY_PROFILE_DIR"
        ;;
    esac
  done < "$INSTALL_MANIFEST_FILE"
}

remove_install_dir() {
  [[ -e "$INSTALL_DIR" ]] || return 0
  rm -rf "$INSTALL_DIR"
  remove_empty_parent_dirs "$(dirname "$INSTALL_DIR")" "$HOME"
}

remove_shell_artifacts() {
  remove_managed_block "$BASHRC_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
  remove_managed_block "$BASH_PROFILE_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
  remove_managed_block "$BASH_SHIMMY_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"

  if manifest_lists_path "created_shell_file" "$BASHRC_FILE"; then
    remove_file_if_empty "$BASHRC_FILE"
  fi
  if manifest_lists_path "created_shell_file" "$BASH_PROFILE_FILE"; then
    remove_file_if_empty "$BASH_PROFILE_FILE"
  fi
  if manifest_lists_path "created_shell_file" "$BASH_SHIMMY_FILE"; then
    remove_file_if_empty "$BASH_SHIMMY_FILE"
  fi
}

remove_profile_dir_if_empty() {
  [[ -d "$SHIMMY_PROFILE_DIR" ]] || return 0
  rmdir "$SHIMMY_PROFILE_DIR" 2>/dev/null || true
  remove_empty_parent_dirs "$(dirname "$SHIMMY_PROFILE_DIR")" "$HOME"
}

remove_manifest_profile_files
remove_shell_artifacts
rm -f "$INSTALL_MANIFEST_FILE"
remove_install_dir
remove_profile_dir_if_empty

echo "Removed shimmy artifacts from $INSTALL_DIR."
echo "Cleaned Bash startup files: $BASHRC_FILE, $BASH_PROFILE_FILE, $BASH_SHIMMY_FILE."
