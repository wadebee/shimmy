#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SHIM_SOURCE_DIR="$ROOT_DIR/shims"
DEFAULT_INSTALL_DIR="$HOME/.local/bin/shims"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
LEGACY_BIN_DIR="$HOME/.local/bin"
BASHRC_FILE="$HOME/.bashrc"
INSTALL_MODE="symlink"
UPDATE_BASHRC=1

usage() {
  cat <<'EOF'
Install shimmy CLI shims into a user profile directory.

Usage:
  scripts/install-shims.sh [options]

Options:
  --install-dir <dir>    Destination directory for installed shims.
                         Default: ~/.local/bin/shims
  --symlink              Install shims as symlinks to this repo (default).
  --copy                 Install shims by copying files.
  --update-bashrc        Add managed PATH block to ~/.bashrc (default).
  --no-update-bashrc     Do not edit ~/.bashrc.
  --bashrc-file <file>   Bash rc file to update (default: ~/.bashrc).
  -h, --help             Show help.
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

mkdir -p "$INSTALL_DIR"

for shim in aws jq terraform rg; do
  src="$SHIM_SOURCE_DIR/$shim"
  dest="$INSTALL_DIR/$shim"
  [[ -f "$src" ]] || fail "missing shim: $src"

  if [[ "$INSTALL_MODE" == "copy" ]]; then
    install -m 0755 "$src" "$dest"
  else
    ln -sfn "$src" "$dest"
  fi
done

remove_managed_bashrc_block() {
  local tmp
  tmp="$(mktemp)"
  awk '
    BEGIN { skip=0 }
    $0 == "# >>> shimmy shims >>>" { skip=1; next }
    $0 == "# <<< shimmy shims <<<" { skip=0; next }
    skip { next }
    { print }
  ' "$BASHRC_FILE" > "$tmp"
  mv "$tmp" "$BASHRC_FILE"
}

remove_legacy_repo_path_block() {
  local tmp
  tmp="$(mktemp)"
  awk '
    BEGIN { skip=0 }
    $0 == "# infrastructure-slots tools" || $0 == "# infrastructure_slots tools" { skip=1; next }
    skip && $0 == "fi" { skip=0; next }
    skip { next }
    { print }
  ' "$BASHRC_FILE" > "$tmp"
  mv "$tmp" "$BASHRC_FILE"
}

append_managed_bashrc_block() {
  {
    printf '\n'
    printf '%s\n' '# >>> shimmy shims >>>'
    printf '%s\n' "if [ -d \"$INSTALL_DIR\" ]; then"
    printf '%s\n' '  case ":$PATH:" in'
    printf '%s\n' "    *\":$INSTALL_DIR:\"*) ;;"
    printf '%s\n' "    *) export PATH=\"\$PATH:$INSTALL_DIR\" ;;"
    printf '%s\n' '  esac'
    printf '%s\n' 'fi'
    printf '%s\n' '# <<< shimmy shims <<<'
  } >> "$BASHRC_FILE"
}

remove_legacy_local_bin_symlinks() {
  local shim legacy target
  for shim in aws jq terraform rg; do
    legacy="$LEGACY_BIN_DIR/$shim"
    if [[ -L "$legacy" ]]; then
      target="$(readlink "$legacy" || true)"
      if [[ "$target" == "$SHIM_SOURCE_DIR/$shim" ]]; then
        rm -f "$legacy"
      fi
    fi
  done
}

if [[ "$UPDATE_BASHRC" -eq 1 ]]; then
  touch "$BASHRC_FILE"
  remove_managed_bashrc_block
  remove_legacy_repo_path_block
  append_managed_bashrc_block
fi

if [[ "$INSTALL_DIR" != "$LEGACY_BIN_DIR" ]]; then
  remove_legacy_local_bin_symlinks
fi

echo "Installed shims into $INSTALL_DIR ($INSTALL_MODE)."
if [[ "$UPDATE_BASHRC" -eq 1 ]]; then
  echo "Updated PATH block in $BASHRC_FILE."
  echo "Run: source \"$BASHRC_FILE\""
else
  echo "Add this path manually if needed: $INSTALL_DIR"
fi
