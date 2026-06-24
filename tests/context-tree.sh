#!/bin/sh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

context_require() {
  context_file=$1
  [ -f "$context_file" ] || fail "missing context file: ${context_file#$ROOT_DIR/}"
}

context_link_require() {
  parent_file=$1
  child_file=$2
  parent_dir=$(dirname "$parent_file")
  child_rel=${child_file#$parent_dir/}

  grep -F "$child_rel" "$parent_file" >/dev/null 2>&1 || fail "missing child context link: ${parent_file#$ROOT_DIR/} -> $child_rel"
}

context_parent_file_resolve() {
  child_dir=$1
  parent_dir=$(dirname "$child_dir")

  while [ "$parent_dir" != "$ROOT_DIR" ]; do
    if [ -f "$parent_dir/CONTEXT.md" ]; then
      printf '%s\n' "$parent_dir/CONTEXT.md"
      return 0
    fi
    parent_dir=$(dirname "$parent_dir")
  done

  printf '%s\n' "$ROOT_DIR/CONTEXT.md"
}

context_source_directory_has_files() {
  source_dir=$1

  for source_file in "$source_dir"/*; do
    [ -f "$source_file" ] || continue
    case "${source_file##*/}" in
      *.conf|*.go|*.js|*.py|*.sh|*.ts|*.yaml|*.yml|Containerfile|Dockerfile|SKILL.md|tool.conf)
        return 0
        ;;
    esac
  done

  return 1
}

context_source_tree_validate() {
  source_dir=$1

  if context_source_directory_has_files "$source_dir"; then
    context_file=$source_dir/CONTEXT.md
    context_require "$context_file"
    parent_file=$(context_parent_file_resolve "$source_dir")
    context_link_require "$parent_file" "$context_file"
  fi

  for child_dir in "$source_dir"/*; do
    [ -d "$child_dir" ] || continue
    context_source_tree_validate "$child_dir"
  done
}

context_require "$ROOT_DIR/CONTEXT.md"
for child_dir in agent commands core tools tests; do
  child_file=$ROOT_DIR/$child_dir/CONTEXT.md
  context_require "$child_file"
  context_link_require "$ROOT_DIR/CONTEXT.md" "$child_file"
done

for child_dir in core commands; do
  child_file=$ROOT_DIR/tests/$child_dir/CONTEXT.md
  context_require "$child_file"
  context_link_require "$ROOT_DIR/tests/CONTEXT.md" "$child_file"
done

for child_dir in catalog common install netinfo profile runtime startup update; do
  child_file=$ROOT_DIR/core/$child_dir/CONTEXT.md
  context_require "$child_file"
  context_link_require "$ROOT_DIR/core/CONTEXT.md" "$child_file"
done

context_require "$ROOT_DIR/agent/core/CONTEXT.md"
context_link_require "$ROOT_DIR/agent/CONTEXT.md" "$ROOT_DIR/agent/core/CONTEXT.md"

for source_tree in agent commands core tools tests; do
  context_source_tree_validate "$ROOT_DIR/$source_tree"
done

for version_dir in "$ROOT_DIR"/tools/*/versions/*; do
  [ -d "$version_dir" ] || continue
  [ -x "$version_dir/run.sh" ] || fail "missing executable runtime: ${version_dir#$ROOT_DIR/}/run.sh"
  [ -x "$version_dir/refresh.sh" ] || fail "missing executable refresh hook: ${version_dir#$ROOT_DIR/}/refresh.sh"
  [ -f "$version_dir/smoke.conf" ] || fail "missing smoke config: ${version_dir#$ROOT_DIR/}/smoke.conf"
  [ -f "$version_dir/status.conf" ] || fail "missing status metadata: ${version_dir#$ROOT_DIR/}/status.conf"
done

printf 'PASS: CONTEXT tree is complete and linked\n'
