#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM_SOURCE_DIR="$ROOT_DIR/shims"
RUNTIME_SOURCE_DIR="$ROOT_DIR/runtime"
DOCS_SOURCE_DIR="$ROOT_DIR/docs"
SKILLS_SOURCE_DIR="$ROOT_DIR/.agents"
REPO_AGENTS_SOURCE="$ROOT_DIR/AGENTS.md"
DEFAULT_INSTALL_DIR="$HOME/.local/bin/shimmy"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
LEGACY_BIN_DIR="$HOME/.local/bin"
BASHRC_FILE="$HOME/.bashrc"
BASH_PROFILE_FILE="$HOME/.bash_profile"
BASH_SHIMMY_FILE="$HOME/.bashrc_shimmy"
SHIMMY_PROFILE_DIR="${HOME}/.config/shimmy"
INSTALL_MANIFEST_FILE="$SHIMMY_PROFILE_DIR/install-manifest.txt"
INSTALL_MODE="copy"
UPDATE_BASHRC=1
PROFILE_CREATED_MESSAGES=()
PROFILE_WARNING_MESSAGES=()
PROFILE_CREATED_PATHS=()
SHELL_FILES_CREATED_PATHS=()
SHELL_INIT_BLOCK_START="# >>> shimmy shell init >>>"
SHELL_INIT_BLOCK_END="# <<< shimmy shell init <<<"
PATH_BLOCK_START="# >>> shimmy shims >>>"
PATH_BLOCK_END="# <<< shimmy shims <<<"

usage() {
  cat <<'EOF'
Install shimmy CLI shims into a user profile directory.

Usage:
  scripts/install-shimmy.sh [options]

Options:
  --install-dir <dir>    Destination directory for installed shims.
                         Default: ~/.local/bin/shimmy
  --symlink              Install shims as symlinks to this repo.
  --copy                 Install shims by copying files (default).
  --update-bashrc        Update ~/.bashrc, ~/.bash_profile, and ~/.bashrc_shimmy (default).
  --no-update-bashrc     Do not edit Bash startup files.
  --bashrc-file <file>   Bash rc file to update (default: ~/.bashrc).
  --bash-profile-file <file>
                         Bash profile file to update (default: ~/.bash_profile).
  --bash-shimmy-file <file>
                         Managed shim PATH file (default: ~/.bashrc_shimmy).
  -h, --help             Show help.
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

record_profile_created() {
  PROFILE_CREATED_MESSAGES+=("$1")
}

record_profile_created_path() {
  PROFILE_CREATED_PATHS+=("$1")
}

record_shell_file_created_path() {
  SHELL_FILES_CREATED_PATHS+=("$1")
}

record_profile_warning() {
  PROFILE_WARNING_MESSAGES+=("$1")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      [[ $# -ge 2 ]] || fail "missing value for --install-dir"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --symlink)
      INSTALL_MODE="symlink"
      shift
      ;;
    --copy)
      INSTALL_MODE="copy"
      shift
      ;;
    --update-bashrc)
      UPDATE_BASHRC=1
      shift
      ;;
    --no-update-bashrc)
      UPDATE_BASHRC=0
      shift
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

INSTALL_DIR="${INSTALL_DIR%/}"
[[ -d "$SHIM_SOURCE_DIR" ]] || fail "shim source directory not found: $SHIM_SOURCE_DIR"
[[ -d "$RUNTIME_SOURCE_DIR" ]] || fail "runtime source directory not found: $RUNTIME_SOURCE_DIR"

mkdir -p "$INSTALL_DIR"

install_runtime_support() {
  local runtime_dest="$INSTALL_DIR/.shimmy"

  rm -rf "$runtime_dest"

  if [[ "$INSTALL_MODE" == "copy" ]]; then
    mkdir -p "$runtime_dest"
    cp -a "$RUNTIME_SOURCE_DIR"/. "$runtime_dest"/
  else
    ln -s "$RUNTIME_SOURCE_DIR" "$runtime_dest"
  fi
}

for shim in aws jq terraform rg tessl; do
  src="$SHIM_SOURCE_DIR/$shim"
  dest="$INSTALL_DIR/$shim"
  [[ -f "$src" ]] || fail "missing shim: $src"

  if [[ "$INSTALL_MODE" == "copy" ]]; then
    install -m 0755 "$src" "$dest"
  else
    ln -sfn "$src" "$dest"
  fi
done

install_runtime_support

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

remove_legacy_repo_path_block() {
  local file="$1"
  local tmp

  [[ -f "$file" ]] || return 0

  tmp="$(mktemp)"
  awk '
    BEGIN { skip=0 }
    $0 == "# infrastructure-slots tools" || $0 == "# infrastructure_slots tools" { skip=1; next }
    skip && $0 == "fi" { skip=0; next }
    skip { next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

append_managed_path_block() {
  {
    printf '\n'
    printf '%s\n' "$PATH_BLOCK_START"
    printf '%s\n' "if [ -d \"$INSTALL_DIR\" ]; then"
    printf '%s\n' '  case ":$PATH:" in'
    printf '%s\n' "    *\":$INSTALL_DIR:\"*) ;;"
    printf '%s\n' "    *) export PATH=\"\$PATH:$INSTALL_DIR\" ;;"
    printf '%s\n' '  esac'
    printf '%s\n' 'fi'
    printf '%s\n' "$PATH_BLOCK_END"
  } >> "$BASH_SHIMMY_FILE"
}

append_shell_init_block() {
  local file="$1"

  {
    printf '\n'
    printf '%s\n' "$SHELL_INIT_BLOCK_START"
    printf '%s\n' 'if [ -f ~/.bashrc_shimmy ]; then . ~/.bashrc_shimmy; fi'
    printf '%s\n' "$SHELL_INIT_BLOCK_END"
  } >> "$file"
}

remove_legacy_local_bin_symlinks() {
  local shim legacy target
  for shim in aws jq terraform rg tessl; do
    legacy="$LEGACY_BIN_DIR/$shim"
    if [[ -L "$legacy" ]]; then
      target="$(readlink "$legacy" || true)"
      if [[ "$target" == "$SHIM_SOURCE_DIR/$shim" ]]; then
        rm -f "$legacy"
      fi
    fi
  done
}

copy_profile_file_if_missing() {
  local src="$1"
  local dest="$2"

  if [[ -e "$dest" ]]; then
    record_profile_warning "Warning: profile already exists at $dest; leaving unchanged."
    return
  fi

  mkdir -p "$(dirname "$dest")"
  install -m 0644 "$src" "$dest"
  record_profile_created_path "$dest"
  record_profile_created "Created profile file: $dest"
}

install_repo_profile_files() {
  local src rel dest

  if [[ -f "$REPO_AGENTS_SOURCE" ]]; then
    copy_profile_file_if_missing "$REPO_AGENTS_SOURCE" "$SHIMMY_PROFILE_DIR/AGENTS.md"
  fi

  if [[ -d "$DOCS_SOURCE_DIR" ]]; then
    while IFS= read -r src; do
      rel="${src#$ROOT_DIR/}"
      dest="$SHIMMY_PROFILE_DIR/$rel"
      copy_profile_file_if_missing "$src" "$dest"
    done < <(find "$DOCS_SOURCE_DIR" -type f | sort)
  fi

  if [[ -d "$SKILLS_SOURCE_DIR" ]]; then
    while IFS= read -r src; do
      rel="${src#$ROOT_DIR/}"
      dest="$SHIMMY_PROFILE_DIR/$rel"
      copy_profile_file_if_missing "$src" "$dest"
    done < <(find "$SKILLS_SOURCE_DIR" -type f | sort)
  fi
}

write_install_manifest() {
  mkdir -p "$SHIMMY_PROFILE_DIR"

  {
    printf 'install_dir=%s\n' "$INSTALL_DIR"
    printf 'bashrc_file=%s\n' "$BASHRC_FILE"
    printf 'bash_profile_file=%s\n' "$BASH_PROFILE_FILE"
    printf 'bash_shimmy_file=%s\n' "$BASH_SHIMMY_FILE"
    for path in "${SHELL_FILES_CREATED_PATHS[@]}"; do
      printf 'created_shell_file=%s\n' "$path"
    done
    for path in "${PROFILE_CREATED_PATHS[@]}"; do
      printf 'created_profile_file=%s\n' "$path"
    done
  } > "$INSTALL_MANIFEST_FILE"
}

if [[ "$UPDATE_BASHRC" -eq 1 ]]; then
  mkdir -p "$(dirname "$BASHRC_FILE")" "$(dirname "$BASH_PROFILE_FILE")" "$(dirname "$BASH_SHIMMY_FILE")"
  [[ -e "$BASHRC_FILE" ]] || record_shell_file_created_path "$BASHRC_FILE"
  [[ -e "$BASH_PROFILE_FILE" ]] || record_shell_file_created_path "$BASH_PROFILE_FILE"
  [[ -e "$BASH_SHIMMY_FILE" ]] || record_shell_file_created_path "$BASH_SHIMMY_FILE"
  touch "$BASHRC_FILE"
  touch "$BASH_PROFILE_FILE"
  touch "$BASH_SHIMMY_FILE"

  remove_managed_block "$BASHRC_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
  remove_managed_block "$BASH_PROFILE_FILE" "$SHELL_INIT_BLOCK_START" "$SHELL_INIT_BLOCK_END"
  remove_managed_block "$BASH_SHIMMY_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"
  remove_managed_block "$BASHRC_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"
  remove_managed_block "$BASH_PROFILE_FILE" "$PATH_BLOCK_START" "$PATH_BLOCK_END"

  remove_legacy_repo_path_block "$BASHRC_FILE"
  remove_legacy_repo_path_block "$BASH_PROFILE_FILE"

  append_shell_init_block "$BASHRC_FILE"
  append_shell_init_block "$BASH_PROFILE_FILE"
  append_managed_path_block
fi

if [[ "$INSTALL_DIR" != "$LEGACY_BIN_DIR" ]]; then
  remove_legacy_local_bin_symlinks
fi

install_repo_profile_files
write_install_manifest

echo "Installed shims into $INSTALL_DIR ($INSTALL_MODE)."
if [[ "$UPDATE_BASHRC" -eq 1 ]]; then
  echo "Updated Bash startup files: $BASHRC_FILE, $BASH_PROFILE_FILE, $BASH_SHIMMY_FILE."
  echo "Run: source \"$BASH_SHIMMY_FILE\""
else
  echo "Add this path manually if needed: $INSTALL_DIR"
fi

if [[ "${#PROFILE_CREATED_MESSAGES[@]}" -gt 0 ]]; then
  printf '%s\n' "${PROFILE_CREATED_MESSAGES[@]}"
fi

if [[ "${#PROFILE_WARNING_MESSAGES[@]}" -gt 0 ]]; then
  printf '%s\n' "${PROFILE_WARNING_MESSAGES[@]}"
fi
