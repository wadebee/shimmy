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

context_require "$ROOT_DIR/CONTEXT.md"
for child_dir in agent commands core tools tests; do
  child_file=$ROOT_DIR/$child_dir/CONTEXT.md
  context_require "$child_file"
  context_link_require "$ROOT_DIR/CONTEXT.md" "$child_file"
done

for child_dir in catalog common profile runtime startup; do
  child_file=$ROOT_DIR/core/$child_dir/CONTEXT.md
  context_require "$child_file"
  context_link_require "$ROOT_DIR/core/CONTEXT.md" "$child_file"
done

context_require "$ROOT_DIR/agent/core/CONTEXT.md"
context_link_require "$ROOT_DIR/agent/CONTEXT.md" "$ROOT_DIR/agent/core/CONTEXT.md"

for tool_dir in "$ROOT_DIR"/tools/*; do
  [ -d "$tool_dir" ] || continue
  [ "$(basename "$tool_dir")" != CONTEXT.md ] || continue
  tool_context=$tool_dir/CONTEXT.md
  context_require "$tool_context"
  context_link_require "$ROOT_DIR/tools/CONTEXT.md" "$tool_context"

  for version_dir in "$tool_dir"/versions/*; do
    [ -d "$version_dir" ] || continue
    version_context=$version_dir/CONTEXT.md
    context_require "$version_context"
    context_link_require "$tool_context" "$version_context"
    [ -x "$version_dir/run.sh" ] || fail "missing executable runtime: ${version_dir#$ROOT_DIR/}/run.sh"
    [ -f "$version_dir/smoke.conf" ] || fail "missing smoke config: ${version_dir#$ROOT_DIR/}/smoke.conf"
  done
done

printf 'PASS: CONTEXT tree is complete and linked\n'
