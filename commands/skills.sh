#!/bin/sh
# Install, update, export, or remove Shimmy agent skills.
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
COMMON_HELPER_FILE=$ROOT_DIR/lib/common/common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/lib/catalog/catalog.sh

REQUESTED_MANIFEST_FILE=
REQUESTED_SKILLS=
REQUESTED_TARGET=repo
EXPORT_PATH=
ACTION=${1:-help}

CORE_SKILLS='shimmy-install
shimmy-init
shimmy-create-tool
shimmy-escalation'

CONTROL_PLANE_SKILLS="$CORE_SKILLS
shimmy-tool-local-build"

SKILLS_MANIFEST_NAME=.shimmy-skills-manifest.txt

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

for helper_file in "$COMMON_HELPER_FILE" "$CATALOG_HELPER_FILE"; do
  [ -f "$helper_file" ] || fail "missing shared helper: $helper_file"
done

# shellcheck source=lib/common/common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=lib/catalog/catalog.sh
. "$CATALOG_HELPER_FILE"

ensure_safe_root() {
  root_path=$1

  case "$root_path" in
    ''|/)
      fail "refusing to write unsafe skills root: $root_path"
      ;;
  esac
}

log_info() {
  printf 'INFO: %s\n' "$*" >&2
}

usage() {
  cat <<'EOF'
Install, update, uninstall, or export Shimmy agent skills.

Usage:
  commands/skills.sh install [options] [skill...]
  commands/skills.sh update [options] [skill...]
  commands/skills.sh uninstall [options]

Options:
  --target repo       Write skills to .agents/skills in the current directory
  --target profile    Write skills to ~/.agents/skills
  --export <path>     Export a portable skills folder, or a .zip archive
  --manifest <path>   Read installed tools from the given profile manifest if present
  -h, --help          Show help

With no explicit skill names, install writes the core Shimmy management skills
plus tool skills for tools recorded in the install manifest.
Update refreshes manifest-tracked skills for the target, falling back to the
core management and installed-tool skills when no target manifest exists yet.
Uninstall removes skills recorded in the selected target manifest.
EOF
}

requested_skill_append() {
  skill_name=$1

  skill_name_validate "$skill_name"

  if [ -n "$REQUESTED_SKILLS" ]; then
    REQUESTED_SKILLS="$REQUESTED_SKILLS
$skill_name"
  else
    REQUESTED_SKILLS=$skill_name
  fi
}

skill_name_validate() {
  skill_name=$1

  case "$skill_name" in
    ''|.*|*/*|*..*|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-]*)
      fail "invalid skill name: $skill_name"
      ;;
  esac
}

target_name_validate() {
  case "$1" in
    repo|profile)
      ;;
    *)
      fail "unsupported skills target: $1"
      ;;
  esac
}

target_root_resolve() {
  target_name=$1

  case "$target_name" in
    repo)
      printf '%s/.agents/skills\n' "$(pwd)"
      ;;
    profile)
      printf '%s/.agents/skills\n' "$HOME"
      ;;
  esac
}

skill_source_file_resolve() {
  skill_name=$1

  if shimmy_contains_line_list "$CONTROL_PLANE_SKILLS" "$skill_name"; then
    source_file=$ROOT_DIR/plugins/shimmy/skills/$skill_name/SKILL.md
    [ -f "$source_file" ] || fail "missing canonical source skill: $skill_name"
    printf '%s\n' "$source_file"
    return 0
  fi

  case "$skill_name" in
    shimmy-tool-*)
      tool_name=${skill_name#shimmy-tool-}
      if shimmy_tool_exists "$tool_name" && [ -f "$ROOT_DIR/tools/$tool_name/SKILL.md" ]; then
        printf '%s/tools/%s/SKILL.md\n' "$ROOT_DIR" "$tool_name"
        return 0
      fi
      ;;
  esac

  fail "missing canonical source skill: $skill_name"
}

skill_source_exists() {
  skill_name=$1

  (skill_source_file_resolve "$skill_name" >/dev/null 2>&1)
}

skill_manifest_skill_names_read() {
  skills_manifest_file=$1
  skill_names=

  if [ ! -f "$skills_manifest_file" ]; then
    return 0
  fi

  while IFS= read -r manifest_line; do
    case "$manifest_line" in
      shimmy_skill=*)
        skill_entry=${manifest_line#shimmy_skill=}
        skill_entry=${skill_entry#*|}
        skill_name=${skill_entry%%|*}
        [ -n "$skill_name" ] || continue
        skill_source_exists "$skill_name" || continue
        if ! shimmy_contains_line_list "$skill_names" "$skill_name"; then
          skill_names=$(shimmy_append_line_list "$skill_names" "$skill_name")
        fi
        ;;
    esac
  done < "$skills_manifest_file"

  if [ -n "$skill_names" ]; then
    printf '%s\n' "$skill_names"
  fi
}

skill_manifest_skill_names_read_all() {
  skills_manifest_file=$1
  skill_names=

  if [ ! -f "$skills_manifest_file" ]; then
    return 0
  fi

  while IFS= read -r manifest_line; do
    case "$manifest_line" in
      shimmy_skill=*)
        skill_entry=${manifest_line#shimmy_skill=}
        skill_entry=${skill_entry#*|}
        skill_name=${skill_entry%%|*}
        [ -n "$skill_name" ] || continue
        skill_name_validate "$skill_name"
        if ! shimmy_contains_line_list "$skill_names" "$skill_name"; then
          skill_names=$(shimmy_append_line_list "$skill_names" "$skill_name")
        fi
        ;;
    esac
  done < "$skills_manifest_file"

  if [ -n "$skill_names" ]; then
    printf '%s\n' "$skill_names"
  fi
}

installed_tool_skill_name_render() {
  tool_name=$1

  case "$tool_name" in
    opnsense-mcp-admin)
      printf 'shimmy-tool-opnsense-mcp-admin\n'
      ;;
    opnsense-mcp-read-only)
      printf 'shimmy-tool-opnsense-mcp-read-only\n'
      ;;
    *)
      printf 'shimmy-tool-%s\n' "$tool_name"
      ;;
  esac
}

installed_tool_skill_names_read() {
  manifest_file=$(install_manifest_file_resolve || true)
  skill_names=

  [ -n "$manifest_file" ] || return 0
  [ -f "$manifest_file" ] || return 0

  while IFS= read -r manifest_line; do
    case "$manifest_line" in
      tool=*)
        tool_name=${manifest_line#tool=}
        [ -n "$tool_name" ] || continue
        skill_name=$(installed_tool_skill_name_render "$tool_name")
        [ -n "$skill_name" ] || continue
        if ! shimmy_contains_line_list "$skill_names" "$skill_name"; then
          skill_names=$(shimmy_append_line_list "$skill_names" "$skill_name")
        fi
        ;;
    esac
  done < "$manifest_file"

  if [ -n "$skill_names" ]; then
    printf '%s\n' "$skill_names"
  fi
}

default_skill_names_resolve() {
  default_skills=$CORE_SKILLS
  installed_skill_names=$(installed_tool_skill_names_read)

  while IFS= read -r installed_skill_name; do
    [ -n "$installed_skill_name" ] || continue
    if ! shimmy_contains_line_list "$default_skills" "$installed_skill_name"; then
      default_skills=$(shimmy_append_line_list "$default_skills" "$installed_skill_name")
    fi
  done <<EOF
$installed_skill_names
EOF

  printf '%s\n' "$default_skills"
}

selected_skill_names_resolve() {
  target_manifest_file=$1
  existing_skills=$(skill_manifest_skill_names_read "$target_manifest_file")

  if [ -n "$REQUESTED_SKILLS" ]; then
    selected_skills=$REQUESTED_SKILLS
  elif [ "$ACTION" = update ]; then
    if [ -n "$existing_skills" ]; then
      printf '%s\n' "$existing_skills"
      return 0
    fi
    selected_skills=$(default_skill_names_resolve)
  else
    selected_skills=$(default_skill_names_resolve)
  fi

  if [ -z "$existing_skills" ]; then
    printf '%s\n' "$selected_skills"
    return 0
  fi

  combined_skills=$existing_skills
  while IFS= read -r selected_skill; do
    [ -n "$selected_skill" ] || continue
    if ! shimmy_contains_line_list "$combined_skills" "$selected_skill"; then
      combined_skills=$(shimmy_append_line_list "$combined_skills" "$selected_skill")
    fi
  done <<EOF
$selected_skills
EOF

  printf '%s\n' "$combined_skills"
}

skill_sources_validate() {
  skill_names=$1

  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    skill_name_validate "$skill_name"
    skill_source_file_resolve "$skill_name" >/dev/null
  done <<EOF
$skill_names
EOF
}

skill_fingerprint_render() {
  skill_dir=$1

  fingerprint_output=$(
    (
      cd -- "$skill_dir"
      find . -type f -print | LC_ALL=C sort | while IFS= read -r skill_file; do
        cksum "$skill_file"
        printf ' %s\n' "$skill_file"
      done
    ) | cksum
  )
  set -- $fingerprint_output
  printf '%s-%s\n' "$1" "$2"
}

skill_file_install() {
  source_skill_file=$1
  target_dir=$2
  skill_name=$3
  target_skill_file=$target_dir/SKILL.md
  target_entry_count=0

  if [ -d "$target_dir" ]; then
    for target_entry in "$target_dir"/* "$target_dir"/.[!.]* "$target_dir"/..?*; do
      [ -e "$target_entry" ] || [ -L "$target_entry" ] || continue
      target_entry_count=$((target_entry_count + 1))
    done
  fi

  [ -f "$source_skill_file" ] || fail "missing canonical skill file: $source_skill_file"
  if [ -d "$target_dir" ] && [ "$target_entry_count" -eq 1 ] &&
    [ -f "$target_skill_file" ] && cmp -s "$source_skill_file" "$target_skill_file"; then
    log_info "Skill already current: $skill_name"
    return 0
  fi

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cp "$source_skill_file" "$target_skill_file"
  log_info "Installed skill: $skill_name"
}

skills_manifest_root_render() {
  target_name=$1
  target_root=$2

  case "$target_name" in
    repo)
      printf '%s\n' '.agents/skills'
      ;;
    export)
      printf '%s\n' '.'
      ;;
    profile)
      printf '%s\n' '$HOME/.agents/skills'
      ;;
    *)
      printf '%s\n' "$target_root"
      ;;
  esac
}

skills_manifest_skill_path_render() {
  manifest_root=$1
  skill_name=$2

  case "$manifest_root" in
    .)
      printf '%s\n' "$skill_name"
      ;;
    *)
      printf '%s/%s\n' "$manifest_root" "$skill_name"
      ;;
  esac
}

skills_manifest_write() {
  target_name=$1
  target_root=$2
  skill_names=$3
  manifest_file=$target_root/$SKILLS_MANIFEST_NAME
  manifest_tmp=$manifest_file.tmp.$$
  manifest_root=$(skills_manifest_root_render "$target_name" "$target_root")

  mkdir -p "$target_root"

  {
    printf 'shimmy_skills_manifest_version=1\n'
    printf 'shimmy_skills_target=%s\n' "$target_name"
    printf 'shimmy_skills_root=%s\n' "$manifest_root"
    while IFS= read -r skill_name; do
      [ -n "$skill_name" ] || continue
      skill_dir=$target_root/$skill_name
      manifest_skill_path=$(skills_manifest_skill_path_render "$manifest_root" "$skill_name")
      fingerprint=$(skill_fingerprint_render "$skill_dir")
      printf 'shimmy_skill=%s|%s|%s|%s\n' "$target_name" "$skill_name" "$manifest_skill_path" "$fingerprint"
    done <<EOF
$skill_names
EOF
  } > "$manifest_tmp"

  mv "$manifest_tmp" "$manifest_file"
}

install_manifest_file_resolve() {
  if [ -n "$REQUESTED_MANIFEST_FILE" ]; then
    printf '%s\n' "$REQUESTED_MANIFEST_FILE"
    return 0
  fi

  [ -f "$ROOT_DIR/install-manifest.txt" ] || return 1
  printf '%s/install-manifest.txt\n' "$ROOT_DIR"
}

install_manifest_skills_update() {
  return 0
}

skills_sync_to_root() {
  target_name=$1
  target_root=$2
  skill_names=$3

  ensure_safe_root "$target_root"
  skill_sources_validate "$skill_names"
  mkdir -p "$target_root"

  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    source_skill_file=$(skill_source_file_resolve "$skill_name")
    skill_file_install "$source_skill_file" "$target_root/$skill_name" "$skill_name"
  done <<EOF
$skill_names
EOF

  skills_manifest_write "$target_name" "$target_root" "$skill_names"
}

skills_target_sync() {
  target_name_validate "$REQUESTED_TARGET"
  target_root=$(target_root_resolve "$REQUESTED_TARGET")
  target_manifest_file=$target_root/$SKILLS_MANIFEST_NAME
  skill_names=$(selected_skill_names_resolve "$target_manifest_file")

  skills_sync_to_root "$REQUESTED_TARGET" "$target_root" "$skill_names"
  install_manifest_skills_update "$REQUESTED_TARGET" "$target_root" "$skill_names"
  log_info "Skills manifest: $target_root/$SKILLS_MANIFEST_NAME"
}

skills_target_uninstall() {
  target_name_validate "$REQUESTED_TARGET"
  if [ -n "$REQUESTED_SKILLS" ]; then
    fail "skills uninstall removes the manifest-tracked target; explicit skill names are not supported"
  fi

  target_root=$(target_root_resolve "$REQUESTED_TARGET")
  target_manifest_file=$target_root/$SKILLS_MANIFEST_NAME
  ensure_safe_root "$target_root"

  if [ ! -f "$target_manifest_file" ]; then
    log_info "No Shimmy skills manifest found: $target_manifest_file"
    return 0
  fi

  skill_names=$(skill_manifest_skill_names_read_all "$target_manifest_file")
  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    skill_name_validate "$skill_name"
    rm -rf "$target_root/$skill_name"
    log_info "Removed skill: $skill_name"
  done <<EOF
$skill_names
EOF

  rm -f "$target_manifest_file"
  if rmdir "$target_root" 2>/dev/null; then
    log_info "Removed empty skills root: $target_root"
  fi
  log_info "Removed skills manifest: $target_manifest_file"
}

export_zip_create() {
  export_path=$1
  export_source_dir=$2

  rm -f "$export_path"
  if command -v zip >/dev/null 2>&1; then
    (
      cd -- "$(dirname "$export_source_dir")"
      zip -qr "$export_path" "$(basename "$export_source_dir")"
    )
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    (
      cd -- "$(dirname "$export_source_dir")"
      python3 -m zipfile -c "$export_path" "$(basename "$export_source_dir")"
    )
    return 0
  fi

  fail "zip export requires zip or python3"
}

skills_export() {
  [ -n "$EXPORT_PATH" ] || fail "--export requires a destination path"

  export_path=$EXPORT_PATH
  case "$export_path" in
    *.zip)
      export_dir=$(dirname "$export_path")
      export_base=$(basename "$export_path")
      mkdir -p "$export_dir"
      export_dir_real=$(cd -- "$export_dir" && pwd)
      export_path=$export_dir_real/$export_base
      export_parent=${TMPDIR:-/tmp}
      export_tmp_dir=$(mktemp -d "$export_parent/shimmy-skills-export.XXXXXX") || fail "unable to create export temp directory"
      export_root=$export_tmp_dir/shimmy-skills
      target_manifest_file=$export_root/$SKILLS_MANIFEST_NAME
      skill_names=$(selected_skill_names_resolve "$target_manifest_file")
      skills_sync_to_root export "$export_root" "$skill_names"
      export_zip_create "$export_path" "$export_root"
      rm -rf "$export_tmp_dir"
      log_info "Exported skills archive: $export_path"
      ;;
    *)
      export_root=$(shimmy_trim_path_trailing_slash "$export_path")
      target_manifest_file=$export_root/$SKILLS_MANIFEST_NAME
      skill_names=$(selected_skill_names_resolve "$target_manifest_file")
      mkdir -p "$export_root"
      while IFS= read -r skill_name; do
        [ -n "$skill_name" ] || continue
        skill_name_validate "$skill_name"
        rm -rf "$export_root/$skill_name"
      done <<EOF
$skill_names
EOF
      rm -f "$target_manifest_file"
      skills_sync_to_root export "$export_root" "$skill_names"
      log_info "Exported skills folder: $export_root"
      ;;
  esac
}

main() {
  case "$ACTION" in
    install|update|uninstall)
      shift
      ;;
    help|-h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown skills command: $ACTION"
      ;;
  esac

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target)
        [ "$#" -ge 2 ] || fail "missing value for --target"
        REQUESTED_TARGET=$2
        target_name_validate "$REQUESTED_TARGET"
        shift 2
        ;;
      --export)
        [ "$#" -ge 2 ] || fail "missing value for --export"
        EXPORT_PATH=$2
        shift 2
        ;;
      --manifest)
        [ "$#" -ge 2 ] || fail "missing value for --manifest"
        REQUESTED_MANIFEST_FILE=$2
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        fail "unknown argument: $1"
        ;;
      *)
        requested_skill_append "$1"
        shift
        ;;
    esac
  done

  if [ -n "$EXPORT_PATH" ]; then
    [ "$ACTION" != uninstall ] || fail "--export is not supported with skills uninstall"
    skills_export
    exit 0
  fi

  if [ "$ACTION" = uninstall ]; then
    skills_target_uninstall
    exit 0
  fi

  skills_target_sync
}

main "$@"
