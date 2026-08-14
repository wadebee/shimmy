#!/bin/sh
# Install, update, export, or remove Shimmy agent skills.
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
SHIMMY_CONTROL_ROOT=$ROOT_DIR
COMMON_HELPER_FILE=$ROOT_DIR/lib/common/common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/lib/catalog/catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/lib/profile/profile.sh

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
SKILLS_BACKED_UP_NAMES=
SKILLS_BACKUP_ROOT=
SKILLS_CATALOG_FINGERPRINT=
SKILLS_CATALOG_GENERATION=
SKILLS_CATALOG_NAME=
SKILLS_CATALOG_SCHEMA=
SKILLS_CATALOG_SOURCE_PATH=
SKILLS_CATALOG_SOURCE_TYPE=
SKILLS_COMMITTED_NAMES=
SKILLS_EXPORT_TMP_DIR=
SKILLS_MANIFEST_BACKED_UP=0
SKILLS_MANIFEST_COMMITTED=0
SKILLS_STAGE_ROOT=
SKILLS_TARGET_ROOT=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

for helper_file in "$COMMON_HELPER_FILE" "$CATALOG_HELPER_FILE" "$PROFILE_HELPER_FILE"; do
  [ -f "$helper_file" ] || fail "missing shared helper: $helper_file"
done

# shellcheck source=lib/common/common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=lib/catalog/catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=lib/profile/profile.sh
. "$PROFILE_HELPER_FILE"

catalog_context_resolve() {
  if shimmy_profile_context_resolve "$ROOT_DIR" 2>/dev/null; then
    shimmy_profile_manifest_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_PROFILE_NAME" || exit 1
    shimmy_catalog_profile_resolve "$SHIMMY_PROFILE_MANIFEST_PATH" "$SHIMMY_CONFIG_ROOT" || fail "$SHIMMY_CATALOG_ERROR"
  else
    shimmy_catalog_checkout_resolve "$ROOT_DIR" upstream || fail "$SHIMMY_CATALOG_ERROR"
  fi
}

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

shimmy__skills_install_usage_print() {
  cat <<'EOF'
Install Shimmy agent skills into a target or portable export.

Usage:
  shimmy skills install [options] [skill...]

Options:
  --target repo       Write skills to .agents/skills in the current directory.
  --target profile    Write skills to ~/.agents/skills.
  --export <path>     Export a portable skills folder, or a .zip archive.
  --manifest <path>   Read installed tools from this profile manifest if present.
  -h, --help          Show this help.

With no explicit skill names, install selects the core Shimmy management
skills plus tool skills for tools recorded in the install manifest.

Examples:
  shimmy skills install --target repo
  shimmy skills install --target profile shimmy-install shimmy-tool-rg
  shimmy skills install --export ./shimmy-skills.zip
EOF
}

shimmy__skills_uninstall_usage_print() {
  cat <<'EOF'
Remove manifest-tracked Shimmy agent skills from a target.

Usage:
  shimmy skills uninstall [--target repo|profile]

Options:
  --target repo       Remove tracked skills from .agents/skills.
  --target profile    Remove tracked skills from ~/.agents/skills.
  -h, --help          Show this help.

Uninstall removes only entries recorded in the target's
.shimmy-skills-manifest.txt. It does not require the source catalog.

Examples:
  shimmy skills uninstall --target repo
  shimmy skills uninstall --target profile
EOF
}

shimmy__skills_update_usage_print() {
  cat <<'EOF'
Refresh Shimmy agent skills in a target or portable export.

Usage:
  shimmy skills update [options] [skill...]

Options:
  --target repo       Update skills in .agents/skills in the current directory.
  --target profile    Update skills in ~/.agents/skills.
  --export <path>     Export refreshed skills as a folder or .zip archive.
  --manifest <path>   Read installed tools from this profile manifest if present.
  -h, --help          Show this help.

Update prefers skills already tracked by the target manifest. If no target
manifest exists, it selects the core management and installed-tool skills.

Examples:
  shimmy skills update --target repo
  shimmy skills update --target profile shimmy-tool-rg
EOF
}

shimmy__skills_usage_print() {
  cat <<'EOF'
Install, update, uninstall, or export Shimmy agent skills.

Usage:
  shimmy skills <command> [options]
  shimmy skills <command> --help

Commands:
  install    Install selected or profile-derived skills into a target or export.
  update     Refresh manifest-tracked skills in a target or export.
  uninstall  Remove only the skills tracked by a target manifest.

Examples:
  shimmy skills install --target repo
  shimmy skills update --target profile
  shimmy skills uninstall --target repo

Run 'shimmy skills <command> --help' for command-specific options.
EOF
}

shimmy__skills_action_usage_print() {
  case "$1" in
    install) shimmy__skills_install_usage_print ;;
    uninstall) shimmy__skills_uninstall_usage_print ;;
    update) shimmy__skills_update_usage_print ;;
  esac
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
    source_file=$SHIMMY_CATALOG_AUTHORITY_ROOT/plugins/shimmy/skills/$skill_name/SKILL.md
    [ -f "$source_file" ] || fail "missing canonical source skill: $skill_name"
    printf '%s\n' "$source_file"
    return 0
  fi

  case "$skill_name" in
    shimmy-tool-*)
      tool_name=${skill_name#shimmy-tool-}
      if shimmy_tool_exists "$tool_name" && [ -f "$SHIMMY_CATALOG_TOOLS_DIR/$tool_name/SKILL.md" ]; then
        printf '%s/%s/SKILL.md\n' "$SHIMMY_CATALOG_TOOLS_DIR" "$tool_name"
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

skills_catalog_snapshot_record() {
  SKILLS_CATALOG_NAME=$SHIMMY_CATALOG_NAME
  SKILLS_CATALOG_SOURCE_TYPE=$SHIMMY_CATALOG_SOURCE_TYPE
  SKILLS_CATALOG_SOURCE_PATH=$SHIMMY_CATALOG_SOURCE_PATH
  SKILLS_CATALOG_GENERATION=$SHIMMY_CATALOG_GENERATION
  SKILLS_CATALOG_SCHEMA=$SHIMMY_CATALOG_SCHEMA
  SKILLS_CATALOG_FINGERPRINT=$SHIMMY_CATALOG_CONTENT_FINGERPRINT
}

skills_catalog_snapshot_validate() {
  staged_root=$1
  skill_names=$2

  catalog_context_resolve
  [ "$SHIMMY_CATALOG_NAME" = "$SKILLS_CATALOG_NAME" ] &&
    [ "$SHIMMY_CATALOG_SOURCE_TYPE" = "$SKILLS_CATALOG_SOURCE_TYPE" ] &&
    [ "$SHIMMY_CATALOG_SOURCE_PATH" = "$SKILLS_CATALOG_SOURCE_PATH" ] &&
    [ "$SHIMMY_CATALOG_GENERATION" = "$SKILLS_CATALOG_GENERATION" ] &&
    [ "$SHIMMY_CATALOG_SCHEMA" = "$SKILLS_CATALOG_SCHEMA" ] &&
    [ "$SHIMMY_CATALOG_CONTENT_FINGERPRINT" = "$SKILLS_CATALOG_FINGERPRINT" ] ||
    fail "catalog $SKILLS_CATALOG_NAME changed while skills were staged; target was not changed"

  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    source_skill_file=$(skill_source_file_resolve "$skill_name")
    cmp -s "$source_skill_file" "$staged_root/$skill_name/SKILL.md" ||
      fail "catalog skill changed while skills were staged: $skill_name"
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

skills_output_stage() {
  target_name=$1
  staged_root=$2
  skill_names=$3

  [ ! -e "$staged_root" ] && [ ! -L "$staged_root" ] || fail "skills staging path already exists: $staged_root"
  mkdir "$staged_root"
  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    source_skill_file=$(skill_source_file_resolve "$skill_name")
    mkdir "$staged_root/$skill_name"
    cp "$source_skill_file" "$staged_root/$skill_name/SKILL.md"
    chmod 644 "$staged_root/$skill_name/SKILL.md"
  done <<EOF
$skill_names
EOF
  skills_manifest_write "$target_name" "$staged_root" "$skill_names"
  skills_output_validate "$target_name" "$staged_root" "$skill_names"
}

skills_output_validate() {
  target_name=$1
  staged_root=$2
  skill_names=$3
  expected_entry_count=1
  actual_entry_count=0

  [ -d "$staged_root" ] && [ ! -L "$staged_root" ] || fail "invalid staged skills root: $staged_root"
  assert_manifest=$staged_root/$SKILLS_MANIFEST_NAME
  [ -f "$assert_manifest" ] && [ ! -L "$assert_manifest" ] || fail "staged skills manifest is missing or unsafe"
  [ "$(sed -n 's/^shimmy_skills_manifest_version=//p' "$assert_manifest")" = 1 ] || fail "staged skills manifest has invalid version"
  [ "$(sed -n 's/^shimmy_skills_target=//p' "$assert_manifest")" = "$target_name" ] || fail "staged skills manifest has invalid target"

  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    skill_name_validate "$skill_name"
    staged_skill_dir=$staged_root/$skill_name
    [ -d "$staged_skill_dir" ] && [ ! -L "$staged_skill_dir" ] || fail "invalid staged skill directory: $skill_name"
    [ -f "$staged_skill_dir/SKILL.md" ] && [ ! -L "$staged_skill_dir/SKILL.md" ] || fail "invalid staged skill file: $skill_name"
    staged_skill_entry_count=0
    for staged_skill_entry in "$staged_skill_dir"/* "$staged_skill_dir"/.[!.]* "$staged_skill_dir"/..?*; do
      [ -e "$staged_skill_entry" ] || [ -L "$staged_skill_entry" ] || continue
      staged_skill_entry_count=$((staged_skill_entry_count + 1))
    done
    [ "$staged_skill_entry_count" -eq 1 ] || fail "staged skill must contain only SKILL.md: $skill_name"
    expected_entry_count=$((expected_entry_count + 1))
  done <<EOF
$skill_names
EOF

  for staged_entry in "$staged_root"/* "$staged_root"/.[!.]* "$staged_root"/..?*; do
    [ -e "$staged_entry" ] || [ -L "$staged_entry" ] || continue
    actual_entry_count=$((actual_entry_count + 1))
  done
  [ "$actual_entry_count" -eq "$expected_entry_count" ] || fail "staged skills output contains unexpected entries"
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

skills_commit_restore() {
  target_root=$1

  if [ "$SKILLS_MANIFEST_COMMITTED" -eq 1 ]; then
    rm -f "$target_root/$SKILLS_MANIFEST_NAME"
  fi
  if [ "$SKILLS_MANIFEST_BACKED_UP" -eq 1 ]; then
    mv "$SKILLS_BACKUP_ROOT/$SKILLS_MANIFEST_NAME" "$target_root/$SKILLS_MANIFEST_NAME"
  fi
  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    target_skill_dir=$target_root/$skill_name
    if [ -e "$target_skill_dir" ] || [ -L "$target_skill_dir" ]; then
      if [ -L "$target_skill_dir" ]; then rm -f "$target_skill_dir"; else rm -rf "$target_skill_dir"; fi
    fi
  done <<EOF
$SKILLS_COMMITTED_NAMES
EOF
  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    backup_skill_dir=$SKILLS_BACKUP_ROOT/$skill_name
    [ ! -e "$backup_skill_dir" ] && [ ! -L "$backup_skill_dir" ] || mv "$backup_skill_dir" "$target_root/$skill_name"
  done <<EOF
$SKILLS_BACKED_UP_NAMES
EOF
  SKILLS_BACKED_UP_NAMES=
  SKILLS_COMMITTED_NAMES=
  SKILLS_MANIFEST_BACKED_UP=0
  SKILLS_MANIFEST_COMMITTED=0
}

skills_output_commit() {
  target_root=$1
  skill_names=$2
  SKILLS_TARGET_ROOT=$target_root

  if [ -e "$target_root" ] || [ -L "$target_root" ]; then
    [ -d "$target_root" ] && [ ! -L "$target_root" ] || fail "skills target must be a regular directory: $target_root"
  else
    mkdir "$target_root"
  fi
  mkdir "$SKILLS_BACKUP_ROOT"

  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    target_skill_dir=$target_root/$skill_name
    backup_skill_dir=$SKILLS_BACKUP_ROOT/$skill_name
    if [ -e "$target_skill_dir" ] || [ -L "$target_skill_dir" ]; then
      mv "$target_skill_dir" "$backup_skill_dir" || {
        skills_commit_restore "$target_root"
        fail "unable to back up target skill: $skill_name"
      }
      SKILLS_BACKED_UP_NAMES=$(shimmy_append_line_list "$SKILLS_BACKED_UP_NAMES" "$skill_name")
    fi
    mv "$SKILLS_STAGE_ROOT/$skill_name" "$target_skill_dir" || {
      skills_commit_restore "$target_root"
      fail "unable to commit target skill: $skill_name"
    }
    SKILLS_COMMITTED_NAMES=$(shimmy_append_line_list "$SKILLS_COMMITTED_NAMES" "$skill_name")
  done <<EOF
$skill_names
EOF

  target_manifest=$target_root/$SKILLS_MANIFEST_NAME
  backup_manifest=$SKILLS_BACKUP_ROOT/$SKILLS_MANIFEST_NAME
  if [ -e "$target_manifest" ] || [ -L "$target_manifest" ]; then
    mv "$target_manifest" "$backup_manifest" || {
      skills_commit_restore "$target_root"
      fail "unable to back up target skills manifest"
    }
    SKILLS_MANIFEST_BACKED_UP=1
  fi
  mv "$SKILLS_STAGE_ROOT/$SKILLS_MANIFEST_NAME" "$target_manifest" || {
    skills_commit_restore "$target_root"
    fail "unable to commit target skills manifest"
  }
  SKILLS_MANIFEST_COMMITTED=1

  rm -rf "$SKILLS_BACKUP_ROOT"
  rmdir "$SKILLS_STAGE_ROOT" 2>/dev/null || true
  SKILLS_BACKED_UP_NAMES=
  SKILLS_BACKUP_ROOT=
  SKILLS_COMMITTED_NAMES=
  SKILLS_MANIFEST_BACKED_UP=0
  SKILLS_MANIFEST_COMMITTED=0
  SKILLS_STAGE_ROOT=
  SKILLS_TARGET_ROOT=
}

skills_stage_paths_prepare() {
  target_root=$1
  target_parent=$(dirname -- "$target_root")
  target_base=$(basename -- "$target_root")

  mkdir -p "$target_parent"
  target_parent=$(cd -- "$target_parent" && pwd)
  SKILLS_STAGE_ROOT=$target_parent/.$target_base.shimmy-stage.$$
  SKILLS_BACKUP_ROOT=$target_parent/.$target_base.shimmy-backup.$$
  [ ! -e "$SKILLS_STAGE_ROOT" ] && [ ! -L "$SKILLS_STAGE_ROOT" ] || fail "skills staging path already exists: $SKILLS_STAGE_ROOT"
  [ ! -e "$SKILLS_BACKUP_ROOT" ] && [ ! -L "$SKILLS_BACKUP_ROOT" ] || fail "skills backup path already exists: $SKILLS_BACKUP_ROOT"
}

skills_temporary_cleanup() {
  if [ -n "$SKILLS_BACKUP_ROOT" ] && [ -d "$SKILLS_BACKUP_ROOT" ]; then
    case "$SKILLS_BACKUP_ROOT" in
      */.*.shimmy-backup.$$)
        [ -n "$SKILLS_TARGET_ROOT" ] && [ -d "$SKILLS_TARGET_ROOT" ] && skills_commit_restore "$SKILLS_TARGET_ROOT"
        rm -rf "$SKILLS_BACKUP_ROOT"
        ;;
    esac
  fi
  if [ -n "$SKILLS_STAGE_ROOT" ]; then
    case "$SKILLS_STAGE_ROOT" in */.*.shimmy-stage.$$) rm -rf "$SKILLS_STAGE_ROOT" ;; esac
  fi
  if [ -n "$SKILLS_EXPORT_TMP_DIR" ]; then
    case "$SKILLS_EXPORT_TMP_DIR" in */shimmy-skills-export.*) rm -rf "$SKILLS_EXPORT_TMP_DIR" ;; esac
  fi
}

skills_sync_to_root() {
  skills_sync_target_name=$1
  skills_sync_target_root=$2
  skills_sync_skill_names=$3

  ensure_safe_root "$skills_sync_target_root"
  skill_sources_validate "$skills_sync_skill_names"
  skills_catalog_snapshot_record
  skills_stage_paths_prepare "$skills_sync_target_root"
  skills_output_stage "$skills_sync_target_name" "$SKILLS_STAGE_ROOT" "$skills_sync_skill_names"
  skills_catalog_snapshot_validate "$SKILLS_STAGE_ROOT" "$skills_sync_skill_names"
  skills_output_commit "$skills_sync_target_root" "$skills_sync_skill_names"
  while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    log_info "Installed skill: $skill_name"
  done <<EOF
$skills_sync_skill_names
EOF
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
      export_destination_path=$export_dir_real/$export_base
      export_parent=${TMPDIR:-/tmp}
      SKILLS_EXPORT_TMP_DIR=$(mktemp -d "$export_parent/shimmy-skills-export.XXXXXX") || fail "unable to create export temp directory"
      export_root=$SKILLS_EXPORT_TMP_DIR/shimmy-skills
      target_manifest_file=$export_root/$SKILLS_MANIFEST_NAME
      skill_names=$(selected_skill_names_resolve "$target_manifest_file")
      skill_sources_validate "$skill_names"
      skills_catalog_snapshot_record
      skills_output_stage export "$export_root" "$skill_names"
      skills_catalog_snapshot_validate "$export_root" "$skill_names"
      staged_archive=$SKILLS_EXPORT_TMP_DIR/shimmy-skills.zip
      export_zip_create "$staged_archive" "$export_root"
      mv "$staged_archive" "$export_destination_path"
      rm -rf "$SKILLS_EXPORT_TMP_DIR"
      SKILLS_EXPORT_TMP_DIR=
      log_info "Exported skills archive: $export_destination_path"
      ;;
    *)
      export_root=$(shimmy_trim_path_trailing_slash "$export_path")
      target_manifest_file=$export_root/$SKILLS_MANIFEST_NAME
      skill_names=$(selected_skill_names_resolve "$target_manifest_file")
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
      shimmy__skills_usage_print
      exit 0
      ;;
    *)
      fail "unknown skills command: $ACTION. Run 'shimmy skills --help' for available commands"
      ;;
  esac

  case "${1:-}" in
    help|-h|--help)
      [ "$#" -eq 1 ] || fail "unknown argument after ${1}: $2"
      shimmy__skills_action_usage_print "$ACTION"
      exit 0
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
        shimmy__skills_action_usage_print "$ACTION"
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

  if [ "$ACTION" != uninstall ]; then
    catalog_context_resolve
    trap skills_temporary_cleanup EXIT HUP INT TERM
  fi

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
