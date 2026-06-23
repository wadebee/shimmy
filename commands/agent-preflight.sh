#!/bin/sh
# Inspect required Shimmy wrapper approvals for AI agents.
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
SHIMMY_PODMAN_HELPER_FILE=$ROOT_DIR/core/runtime/podman.sh
RUN_SMOKE=no
PREFLIGHT_STATUS=0
ACTIVE_SHIM_SEEN=
ACTIVE_SHIM_COUNT=0
REPO_SHIM_SEEN=
REPO_SHIM_COUNT=0

usage() {
  cat <<'EOF'
Usage: commands/agent-preflight.sh [--smoke]

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

if [ ! -f "$SHIMMY_PODMAN_HELPER_FILE" ]; then
  printf 'ERROR: missing Podman helper: %s\n' "$SHIMMY_PODMAN_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=core/runtime/podman.sh
. "$SHIMMY_PODMAN_HELPER_FILE"

shimmy_agent_json_string_print() {
  json_value=$1
  escaped_value=$(printf '%s' "$json_value" | sed 's/\\/\\\\/g; s/"/\\"/g')

  printf '"%s"' "$escaped_value"
}

shimmy_agent_prefix_rule_print() {
  first_token=yes

  printf '['
  for command_token in "$@"; do
    if [ "$first_token" = yes ]; then
      first_token=no
    else
      printf ','
    fi
    shimmy_agent_json_string_print "$command_token"
  done
  printf ']\n'
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

shimmy_agent_manifest_value() {
  manifest_file=$1
  manifest_key=$2

  sed -n "s/^$manifest_key=//p" "$manifest_file" | sed -n '1p'
}

shimmy_agent_smoke_args_render() {
  shim_name=$1

  case "$shim_name" in
    aws|aws_2_31)
      printf '%s\n' '--version'
      ;;
    go|go_1_26)
      printf '%s\n' 'version'
      ;;
    gcloud|gcloud_573_0)
      printf '%s\n' '--version'
      ;;
    gdrive|gdrive_0_2)
      printf '%s\n' '--help'
      ;;
    jq|jq_1_8)
      printf '%s\n' '--version'
      ;;
    netcat|netcat_7_92)
      printf '%s\n' '--help'
      ;;
    nmap|nmap_7_98)
      printf '%s\n' '--version'
      ;;
    opnsense-mcp-admin|opnsense-mcp-admin_1_0)
      printf '%s\n' '--help'
      ;;
    opnsense-mcp-read-only|opnsense-mcp-read-only_0_4)
      printf '%s\n' '--help'
      ;;
    oc|oc_4_18|oc_4_20|oc_4_22)
      printf '%s\n' '--preview-shim version'
      ;;
    rg|rg_15_1)
      printf '%s\n' '--version'
      ;;
    task|task_3_45)
      printf '%s\n' '--version'
      ;;
    terraform|terraform_1_15)
      printf '%s\n' 'version'
      ;;
    tessl|tessl_0_1)
      printf '%s\n' '--help'
      ;;
    textual|textual_8_2)
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
      case "$shim_name:$smoke_output" in
        opnsense-mcp-read-only:*'ERROR: OPNSENSE_URL is required for the opnsense-mcp-read-only shim.'*)
          printf 'smoke_status=ok\n'
          return 0
          ;;
      esac
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
    case "$shim_name:$smoke_output" in
      opnsense-mcp-read-only:*'ERROR: OPNSENSE_URL is required for the opnsense-mcp-read-only shim.'*)
        printf 'smoke_status=ok\n'
        return 0
        ;;
    esac
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
  # shellcheck disable=SC2086
  shimmy_agent_prefix_rule_print "$command_prefix" $smoke_args
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

shimmy_agent_manifest_shims_discover() {
  install_dir=$1
  manifest_file=$2
  bin_dir=$install_dir/bin

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    shimmy_agent_active_shim_consider "$shim_name" "$bin_dir/$shim_name"
  done <<EOF
$(sed -n 's/^kind=//p' "$manifest_file")
EOF
}

shimmy_agent_installed_shims_discover() {
  install_dir=$1
  shim_dir=$install_dir/bin

  for manifest_file in "$install_dir"/profiles/default/install-manifest.txt "$install_dir"/profiles/upstream/install-manifest.txt "$install_dir"/install-manifest.txt; do
    [ -f "$manifest_file" ] || continue
    shimmy_agent_manifest_shims_discover "$install_dir" "$manifest_file"
  done

  [ -d "$shim_dir" ] || return 0

  for shim_path in "$shim_dir"/*; do
    [ -f "$shim_path" ] || continue
    [ -x "$shim_path" ] || continue
    [ "$(basename "$shim_path")" != shimmy ] || continue
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
      */shimmy/bin)
        [ -d "$path_dir" ] || continue
        for shim_path in "$path_dir"/*; do
          [ -f "$shim_path" ] || continue
          [ -x "$shim_path" ] || continue
          [ "$(basename "$shim_path")" != shimmy ] || continue
          shimmy_agent_active_shim_consider "$(basename "$shim_path")" "$shim_path"
        done
        ;;
    esac
    IFS=:
  done
  IFS=$old_ifs
}

shimmy_agent_repo_shims_discover() {
  tools_dir=$ROOT_DIR/tools

  [ -d "$tools_dir" ] || return 0

  for tool_dir in "$tools_dir"/*; do
    [ -f "$tool_dir/tool.conf" ] || continue
    shim_name=$(basename "$tool_dir")
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
    smoke_args=$(shimmy_agent_smoke_args_render "$shim_name")
    printf 'repo_shim=%s\n' "$shim_name"
    printf 'path=%s\n' "$tool_dir"
    printf 'agent_prefix_rule='
    # shellcheck disable=SC2086
    shimmy_agent_prefix_rule_print "./commands/run-tool.sh" "$shim_name" $smoke_args
    printf 'smoke_command=./commands/run-tool.sh %s %s\n' "$shim_name" "$smoke_args"
    if [ "$RUN_SMOKE" = yes ]; then
      if smoke_output=$(cd "$ROOT_DIR" && "$ROOT_DIR/commands/run-tool.sh" "$shim_name" $smoke_args 2>&1); then
        printf 'smoke_status=ok\n'
      else
        printf 'smoke_status=failed\n'
        printf 'smoke_output=%s\n' "$smoke_output"
        PREFLIGHT_STATUS=1
      fi
    fi
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
    printf '%s\n' 'agent_hint=If `podman info` succeeds outside this script but shims fail in an AI Agent, approve the dry-run smoke command prefix such as ["rg","--version"] or ["./commands/run-tool.sh","rg","--version"].'
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
printf '%s\n' 'Approve dry-run smoke command prefixes such as ["rg","--version"] or ["./commands/run-tool.sh","rg","--version"]; approving ["podman", "info"] alone does not approve a Shimmy wrapper.'

exit "$PREFLIGHT_STATUS"
