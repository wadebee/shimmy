#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
PODMAN_HELPER_FILE=$ROOT_DIR/lib/shims/shimmy-podman.sh
RUN_SMOKE=no
PREFLIGHT_STATUS=0
ACTIVE_SHIM_SEEN=
ACTIVE_SHIM_COUNT=0
REPO_SHIM_SEEN=
REPO_SHIM_COUNT=0

usage() {
  cat <<'EOF'
Usage: scripts/agent-shimmy-preflight.sh [--smoke]

Print the narrow AI Agent approval prefixes needed for Shimmy-backed tools.

Options:
  --smoke   Also run non-mutating version/help checks for discovered shims.
  --help    Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --smoke)
      RUN_SMOKE=yes
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ ! -f "$PODMAN_HELPER_FILE" ]; then
  printf 'ERROR: missing Podman helper: %s\n' "$PODMAN_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/shims/shimmy-podman.sh
. "$PODMAN_HELPER_FILE"

shimmy_agent_prefix_rule_print() {
  command_prefix=$1

  printf '["%s"]\n' "$command_prefix"
}

shimmy_agent_shim_name_validate() {
  shim_name=$1

  case "$shim_name" in
    ''|*/*|.*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

shimmy_agent_smoke_args_render() {
  shim_name=$1

  case "$shim_name" in
    aws)
      printf '%s\n' '--version'
      ;;
    go)
      printf '%s\n' 'version'
      ;;
    jq)
      printf '%s\n' '--version'
      ;;
    netcat)
      printf '%s\n' '--help'
      ;;
    rg)
      printf '%s\n' '--version'
      ;;
    task)
      printf '%s\n' '--version'
      ;;
    terraform)
      printf '%s\n' 'version'
      ;;
    textual)
      printf '%s\n' '--version'
      ;;
    *)
      printf '%s\n' '--version'
      ;;
  esac
}

shimmy_agent_smoke_run() {
  shim_kind=$1
  shim_name=$2
  command_prefix=$3
  smoke_args=$(shimmy_agent_smoke_args_render "$shim_name")
  smoke_output=

  if [ "$shim_kind" = repo ]; then
    if smoke_output=$(
      cd "$ROOT_DIR"
      # shellcheck disable=SC2086
      "$command_prefix" $smoke_args 2>&1
    ); then
      printf 'smoke_status=ok\n'
    else
      printf 'smoke_status=failed\n'
      printf 'smoke_output=%s\n' "$smoke_output"
      PREFLIGHT_STATUS=1
    fi
    return 0
  fi

  if smoke_output=$(
    # shellcheck disable=SC2086
    "$command_prefix" $smoke_args 2>&1
  ); then
    printf 'smoke_status=ok\n'
  else
    printf 'smoke_status=failed\n'
    printf 'smoke_output=%s\n' "$smoke_output"
    PREFLIGHT_STATUS=1
  fi
}

shimmy_agent_shim_print() {
  shim_kind=$1
  shim_name=$2
  command_prefix=$3
  shim_path=$4
  smoke_args=$(shimmy_agent_smoke_args_render "$shim_name")

  case "$shim_kind" in
    active)
      printf 'active_shim=%s\n' "$shim_name"
      ;;
    repo)
      printf 'repo_shim=%s\n' "$shim_name"
      ;;
    *)
      printf 'shim=%s\n' "$shim_name"
      ;;
  esac
  printf 'path=%s\n' "$shim_path"
  printf 'agent_prefix_rule='
  shimmy_agent_prefix_rule_print "$command_prefix"
  printf 'smoke_command=%s %s\n' "$command_prefix" "$smoke_args"

  if [ "$RUN_SMOKE" = yes ]; then
    shimmy_agent_smoke_run "$shim_kind" "$shim_name" "$command_prefix"
  fi
}

shimmy_agent_active_shim_consider() {
  shim_name=$1
  expected_path=$2

  shimmy_agent_shim_name_validate "$shim_name" || return 0
  resolved_path=$(command -v "$shim_name" 2>/dev/null || true)
  [ -n "$resolved_path" ] || return 0
  [ -x "$resolved_path" ] || return 0

  if [ -n "$expected_path" ] && [ "$resolved_path" != "$expected_path" ]; then
    return 0
  fi

  case "
$ACTIVE_SHIM_SEEN" in
    *"
$shim_name
"*)
      return 0
      ;;
  esac

  ACTIVE_SHIM_SEEN=$ACTIVE_SHIM_SEEN"
$shim_name
"
  ACTIVE_SHIM_COUNT=$((ACTIVE_SHIM_COUNT + 1))
  shimmy_agent_shim_print active "$shim_name" "$shim_name" "$resolved_path"
}

shimmy_agent_installed_shims_discover() {
  install_dir=$1
  manifest_file=$install_dir/install-manifest.txt
  shim_dir=$install_dir/shims

  if [ -f "$manifest_file" ]; then
    while IFS= read -r shim_name; do
      [ -n "$shim_name" ] || continue
      shimmy_agent_active_shim_consider "$shim_name" "$shim_dir/$shim_name"
    done <<EOF
$(sed -n 's/^shim=//p' "$manifest_file")
EOF
  fi

  [ -d "$shim_dir" ] || return 0

  for shim_path in "$shim_dir"/*; do
    [ -f "$shim_path" ] || continue
    [ -x "$shim_path" ] || continue
    shimmy_agent_active_shim_consider "$(basename "$shim_path")" "$shim_path"
  done
}

shimmy_agent_path_shims_discover() {
  old_ifs=$IFS
  IFS=:
  for path_dir in ${PATH:-}; do
    IFS=$old_ifs
    [ -n "$path_dir" ] || continue
    case "$path_dir" in
      */shimmy/shims)
        [ -d "$path_dir" ] || continue
        for shim_path in "$path_dir"/*; do
          [ -f "$shim_path" ] || continue
          [ -x "$shim_path" ] || continue
          shimmy_agent_active_shim_consider "$(basename "$shim_path")" "$shim_path"
        done
        ;;
    esac
    IFS=:
  done
  IFS=$old_ifs
}

shimmy_agent_repo_shims_discover() {
  shim_dir=$ROOT_DIR/shims

  [ -d "$shim_dir" ] || return 0

  for shim_path in "$shim_dir"/*; do
    [ -f "$shim_path" ] || continue
    [ -x "$shim_path" ] || continue
    shim_name=$(basename "$shim_path")
    shimmy_agent_shim_name_validate "$shim_name" || continue

    case "
$REPO_SHIM_SEEN" in
      *"
$shim_name
"*)
        continue
        ;;
    esac

    REPO_SHIM_SEEN=$REPO_SHIM_SEEN"
$shim_name
"
    REPO_SHIM_COUNT=$((REPO_SHIM_COUNT + 1))
    shimmy_agent_shim_print repo "$shim_name" "./shims/$shim_name" "$shim_path"
  done
}

printf 'Shimmy AI Agent preflight\n'
printf 'run_smoke=%s\n' "$RUN_SMOKE"

if shimmy_podman_bin_resolve; then
  shimmy_podman_path_activate "$SHIMMY_PODMAN_BIN"
  printf 'podman_bin=%s\n' "$SHIMMY_PODMAN_BIN"
  if "$SHIMMY_PODMAN_BIN" info >/dev/null 2>&1; then
    printf 'podman_info=ok\n'
  else
    printf 'podman_info=failed\n'
    printf '%s\n' 'agent_hint=If `podman info` succeeds outside this script but shims fail in an AI Agent, approve the outer shim prefix such as ["rg"] or ["./shims/rg"].'
    PREFLIGHT_STATUS=1
  fi
else
  printf 'podman_bin=missing\n'
  printf 'podman_info=skipped\n'
  PREFLIGHT_STATUS=1
fi

printf '\nActive Shimmy command approvals:\n'

if [ -n "${SHIMMY_INSTALL_DIR:-}" ]; then
  shimmy_agent_installed_shims_discover "$SHIMMY_INSTALL_DIR"
elif [ -n "${HOME:-}" ]; then
  shimmy_agent_installed_shims_discover "$HOME/.config/shimmy"
fi
shimmy_agent_path_shims_discover

if [ "$ACTIVE_SHIM_COUNT" -eq 0 ]; then
  printf 'active_shims=none\n'
fi

printf '\nRepository shim approvals:\n'
shimmy_agent_repo_shims_discover

if [ "$REPO_SHIM_COUNT" -eq 0 ]; then
  printf 'repo_shims=none\n'
fi

printf '\nAI Agent guidance:\n'
printf '%s\n' "Use the listed agent_prefix_rule values with your AI Agent's approval mechanism for harmless smoke commands."
printf '%s\n' 'Approve wrapper prefixes such as ["rg"] or ["./shims/rg"]; approving ["podman", "info"] alone does not approve a Shimmy wrapper.'

exit "$PREFLIGHT_STATUS"
