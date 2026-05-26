#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)

DEFAULT_INSTALL_DIR=${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}
REQUESTED_INSTALL_DIR=
REQUESTED_MANIFEST_FILE=
REQUESTED_SKILLS=
REQUESTED_TARGET=repo
EXPORT_PATH=
ACTION=${1:-help}

CORE_SKILLS='shimmy-install
shimmy-init
shimmy-create
shimmy-escalation'

SKILLS_MANIFEST_NAME=.shimmy-skills-manifest.txt

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
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

line_list_append() {
  list_value=${1:-}
  line_value=$2

  if [ -n "$list_value" ]; then
    printf '%s\n%s\n' "$list_value" "$line_value"
  else
    printf '%s\n' "$line_value"
  fi
}

line_list_contains() {
  list_value=${1:-}
  line_value=$2

  while IFS= read -r existing_line; do
    [ -n "$existing_line" ] || continue
    if [ "$existing_line" = "$line_value" ]; then
      return 0
    fi
  done <<EOF
$list_value
EOF

  return 1
}

trim_trailing_slash() {
  path_value=${1:-}

  case "$path_value" in
    ''|/)
      printf '%s\n' "$path_value"
      ;;
    */)
      printf '%s\n' "${path_value%/}"
      ;;
    *)
      printf '%s\n' "$path_value"
      ;;
  esac
}

usage() {
  cat <<'EOF'
Install, update, or export Shimmy agent skills.

Usage:
  scripts/skills-shimmy.sh install [options] [skill...]
  scripts/skills-shimmy.sh update [options] [skill...]

Options:
  --target repo       Write skills to .agents/skills in the current directory
  --target profile    Write skills to ~/.agents/skills
  --target plugin     Write skills to the packaged Shimmy plugin skill bundle
  --export <path>     Export a portable skills folder, or a .zip archive
  --install-dir <dir> Record audit entries in <dir>/install-manifest.txt if present
  --manifest <path>   Record audit entries in the given manifest if present
  -h, --help          Show help

With no explicit skill names, install writes the core Shimmy management skills.
Update refreshes manifest-tracked skills for the target, falling back to the
core management skills when no target manifest exists yet.
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
    repo|profile|plugin)
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
    plugin)
      if [ -n "${SHIMMY_SKILLS_PLUGIN_DIR:-}" ]; then
        case "$SHIMMY_SKILLS_PLUGIN_DIR" in
          */skills)
            printf '%s\n' "$(trim_trailing_slash "$SHIMMY_SKILLS_PLUGIN_DIR")"
            ;;
          *)
            printf '%s/skills\n' "$(trim_trailing_slash "$SHIMMY_SKILLS_PLUGIN_DIR")"
            ;;
        esac
        return 0
      fi
      printf '%s/plugins/shimmy/skills\n' "$ROOT_DIR"
      ;;
  esac
}

skill_source_dir_resolve() {
  skill_name=$1

  if [ -f "$ROOT_DIR/.agents/skills/$skill_name/SKILL.md" ]; then
    printf '%s/.agents/skills/%s\n' "$ROOT_DIR" "$skill_name"
    return 0
  fi

  if [ -f "$ROOT_DIR/plugins/shimmy/skills/$skill_name/SKILL.md" ]; then
    printf '%s/plugins/shimmy/skills/%s\n' "$ROOT_DIR" "$skill_name"
    return 0
  fi

  fail "missing source skill: $skill_name"
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
        if ! line_list_contains "$skill_names" "$skill_name"; then
          skill_names=$(line_list_append "$skill_names" "$skill_name")
        fi
        ;;
    esac
  done < "$skills_manifest_file"

  if [ -n "$skill_names" ]; then
    printf '%s\n' "$skill_names"
  fi
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
    selected_skills=$CORE_SKILLS
  else
    selected_skills=$CORE_SKILLS
  fi

  if [ -z "$existing_skills" ]; then
    printf '%s\n' "$selected_skills"
    return 0
  fi

  combined_skills=$existing_skills
  while IFS= read -r selected_skill; do
    [ -n "$selected_skill" ] || continue
    if ! line_list_contains "$combined_skills" "$selected_skill"; then
      combined_skills=$(line_list_append "$combined_skills" "$selected_skill")
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
    skill_source_dir_resolve "$skill_name" >/dev/null
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

skill_dir_install() {
  source_dir=$1
  target_dir=$2
  skill_name=$3

  source_dir_real=$(cd -- "$source_dir" && pwd)
  target_dir_real=
  if [ -d "$target_dir" ]; then
    target_dir_real=$(cd -- "$target_dir" && pwd)
  fi

  if [ "$source_dir_real" = "$target_dir_real" ]; then
    log_info "Skill already current: $skill_name"
    return 0
  fi

  if [ -d "$target_dir" ] && diff -qr "$source_dir" "$target_dir" >/dev/null 2>&1; then
    log_info "Skill already current: $skill_name"
    return 0
  fi

  rm -rf "$target_dir"
  mkdir -p "$(dirname "$target_dir")"
  cp -R "$source_dir" "$target_dir"
  log_info "Installed skill: $skill_name"
}

skills_manifest_write() {
  target_name=$1
  target_root=$2
  skill_names=$3
  manifest_file=$target_root/$SKILLS_MANIFEST_NAME
  manifest_tmp=$manifest_file.tmp.$$

  mkdir -p "$target_root"

  {
    printf 'shimmy_skills_manifest_version=1\n'
    printf 'shimmy_skills_target=%s\n' "$target_name"
    printf 'shimmy_skills_root=%s\n' "$target_root"
    while IFS= read -r skill_name; do
      [ -n "$skill_name" ] || continue
      skill_dir=$target_root/$skill_name
      fingerprint=$(skill_fingerprint_render "$skill_dir")
      printf 'shimmy_skill=%s|%s|%s|%s\n' "$target_name" "$skill_name" "$skill_dir" "$fingerprint"
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

  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s/install-manifest.txt\n' "$(trim_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  if [ -n "${SHIMMY_CONTROL_INSTALL_DIR:-}" ]; then
    printf '%s/install-manifest.txt\n' "$(trim_trailing_slash "$DEFAULT_INSTALL_DIR")"
    return 0
  fi

  return 1
}

install_manifest_skills_update() {
  target_name=$1
  target_root=$2
  skill_names=$3
  manifest_file=$(install_manifest_file_resolve || true)
  [ -n "$manifest_file" ] || return 0

  if [ ! -f "$manifest_file" ]; then
    return 0
  fi

  manifest_tmp=$manifest_file.tmp.$$

  {
    while IFS= read -r manifest_line || [ -n "$manifest_line" ]; do
      case "$manifest_line" in
        shimmy_skill=*)
          skill_entry=${manifest_line#shimmy_skill=}
          skill_target=${skill_entry%%|*}
          if [ "$skill_target" = "$target_name" ]; then
            continue
          fi
          printf '%s\n' "$manifest_line"
          ;;
        *)
          printf '%s\n' "$manifest_line"
          ;;
      esac
    done < "$manifest_file"

    while IFS= read -r skill_name; do
      [ -n "$skill_name" ] || continue
      skill_dir=$target_root/$skill_name
      fingerprint=$(skill_fingerprint_render "$skill_dir")
      printf 'shimmy_skill=%s|%s|%s|%s\n' "$target_name" "$skill_name" "$skill_dir" "$fingerprint"
    done <<EOF
$skill_names
EOF
  } > "$manifest_tmp"

  mv "$manifest_tmp" "$manifest_file"
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
    source_dir=$(skill_source_dir_resolve "$skill_name")
    skill_dir_install "$source_dir" "$target_root/$skill_name" "$skill_name"
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
      export_root=$(trim_trailing_slash "$export_path")
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
    install|update)
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
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
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
    skills_export
    exit 0
  fi

  skills_target_sync
}

main "$@"
