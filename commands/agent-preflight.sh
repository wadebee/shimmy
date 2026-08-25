#!/bin/sh
# Inspect required Shimmy wrapper approvals for AI agents.
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
SHIMMY_ROOT_DIR=$ROOT_DIR
COMMON_HELPER_FILE=$ROOT_DIR/lib/common/common.sh
SHIMMY_PODMAN_HELPER_FILE=$ROOT_DIR/lib/runtime/podman.sh
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh
CATALOG_HELPER_FILE=$ROOT_DIR/lib/catalog/catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/lib/profile/profile.sh
PROFILE_STATE_HELPER_FILE=$ROOT_DIR/lib/profile/state.sh
CATALOG_STATE_HELPER_FILE=$ROOT_DIR/lib/catalog/state.sh
SHIM_STATE_HELPER_FILE=$ROOT_DIR/lib/shim/state.sh
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

if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing image helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

if [ ! -f "$COMMON_HELPER_FILE" ] || [ ! -f "$CATALOG_HELPER_FILE" ] ||
  [ ! -f "$PROFILE_HELPER_FILE" ] || [ ! -f "$PROFILE_STATE_HELPER_FILE" ] ||
  [ ! -f "$CATALOG_STATE_HELPER_FILE" ] || [ ! -f "$SHIM_STATE_HELPER_FILE" ]; then
  printf 'ERROR: missing catalog helper: %s\n' "$CATALOG_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/podman.sh
. "$SHIMMY_PODMAN_HELPER_FILE"
# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"
# shellcheck source=lib/common/common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=lib/catalog/catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=lib/profile/profile.sh
. "$PROFILE_HELPER_FILE"
# shellcheck source=lib/catalog/state.sh
. "$CATALOG_STATE_HELPER_FILE"
# shellcheck source=lib/shim/state.sh
. "$SHIM_STATE_HELPER_FILE"
# shellcheck source=lib/profile/state.sh
. "$PROFILE_STATE_HELPER_FILE"

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
  version_dir=$1
  smoke_file=$version_dir/smoke.conf
  image_config_file=$version_dir/image.conf

  shimmy_image_config_validate "$image_config_file" || return 1
  if [ "$(shimmy_image_config_scalar_read "$image_config_file" image_source)" = local-build ]; then
    printf '%s\n' '--preview-shim'
  fi

  if [ ! -f "$smoke_file" ]; then
    printf '%s\n' '--version'
    return 0
  fi

  sed -n 's/^smoke_arg=//p' "$smoke_file"
}

shimmy_agent_smoke_run() {
  shim_kind=$1
  shim_name=$2
  command_prefix=$3
  version_dir=$4
  smoke_args=$(shimmy_agent_smoke_args_render "$version_dir")
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
  version_dir=$5
  smoke_args=$(shimmy_agent_smoke_args_render "$version_dir")
  smoke_args_display=$(printf '%s\n' "$smoke_args" | tr '\n' ' ' | sed 's/ $//')

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
  printf 'smoke_command=%s %s\n' "$command_prefix" "$smoke_args_display"

  if [ "$RUN_SMOKE" = yes ]; then
    shimmy_agent_smoke_run "$shim_kind" "$shim_name" "$command_prefix" "$version_dir"
  fi
}

shimmy_agent_active_shim_consider() {
  shim_name=$1
  expected_path=$2
  version_dir=$3

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
  shimmy_agent_shim_print active "$shim_name" "$shim_name" "$resolved_path" "$version_dir"
}

shimmy_agent_manifest_shims_discover() {
  profile_root=$1
  manifest_file=$2
  bin_dir=$profile_root/bin

  shimmy_profile_manifest_read "$manifest_file" || return 1
  while IFS= read -r shim_record; do
    [ -n "$shim_record" ] || continue
    shimmy_shim_record_validate "$shim_record" || return 1
    shim_name=$shimmy_shim_record_tool
    version_label=
    while IFS= read -r version_record; do
      [ -n "$version_record" ] || continue
      shimmy_shim_version_record_validate "$version_record" || return 1
      [ "$shimmy_shim_version_tool" = "$shim_name" ] || continue
      [ "$shimmy_shim_version_kind" = default ] || continue
      version_label=$shimmy_shim_version_name
      break
    done <<EOF
$SHIMMY_PROFILE_SHIM_VERSION_RECORDS
EOF
    [ -n "$version_label" ] || return 1
    shimmy_agent_active_shim_consider "$shim_name" "$bin_dir/$shim_name" \
      "$profile_root/tools/$shim_name/versions/$version_label"
  done <<EOF
$SHIMMY_PROFILE_SHIM_RECORDS
EOF
}

shimmy_agent_installed_shims_discover() {
  config_root=$1
  shimmy_installation_paths_resolve "$config_root" || return 1
  [ -f "$SHIMMY_ACTIVE_PROFILE_PATH" ] || return 0
  shimmy_active_profile_read "$SHIMMY_ACTIVE_PROFILE_PATH" || return 1
  active_profile=$SHIMMY_ACTIVE_PROFILE_NAME
  shimmy_profile_state_paths_resolve "$config_root" "$active_profile" || return 1
  shimmy_agent_manifest_shims_discover "$SHIMMY_PROFILE_ROOT" \
    "$SHIMMY_PROFILE_MANIFEST_PATH"
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
    version_label=$(shimmy__catalog_config_value_read "$tool_dir/tool.conf" tool_default_version)
    shimmy_version_token_validate "$version_label" || continue
    version_dir=$tool_dir/versions/$version_label
    smoke_args=$(shimmy_agent_smoke_args_render "$version_dir")
    smoke_args_display=$(printf '%s\n' "$smoke_args" | tr '\n' ' ' | sed 's/ $//')
    printf 'repo_shim=%s\n' "$shim_name"
    printf 'path=%s\n' "$tool_dir"
    printf 'agent_prefix_rule='
    # shellcheck disable=SC2086
    shimmy_agent_prefix_rule_print "./commands/run-tool.sh" "$shim_name" $smoke_args
    printf 'smoke_command=./commands/run-tool.sh %s %s\n' "$shim_name" "$smoke_args_display"
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

if ! shimmy_catalog_payload_validate "$ROOT_DIR" default; then
  printf 'ERROR: %s\n' "$SHIMMY_CATALOG_ERROR" >&2
  exit 1
fi

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

if [ -n "${XDG_CONFIG_HOME:-}" ]; then
  case "$XDG_CONFIG_HOME" in /*) shimmy_agent_installed_shims_discover "$XDG_CONFIG_HOME/shimmy" ;; esac
elif [ -n "${HOME:-}" ]; then
  shimmy_agent_installed_shims_discover "$HOME/.config/shimmy"
fi

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
