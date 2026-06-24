#!/bin/sh
# Refresh Shimmy management and runtime assets.
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(
  cd -- "$SCRIPT_DIR/.." && pwd
)
SHIMMY_TOOLS_DIR=$ROOT_DIR/tools
COMMON_HELPER_FILE=$ROOT_DIR/core/common/common.sh
CATALOG_HELPER_FILE=$ROOT_DIR/core/catalog/catalog.sh
PROFILE_HELPER_FILE=$ROOT_DIR/core/profile/profile.sh
STARTUP_HELPER_FILE=$ROOT_DIR/core/startup/startup.sh
SHIMMY_CUSTOM_IMAGE_HELPER_FILE=$ROOT_DIR/core/runtime/image.sh
SHIMMY_PODMAN_HELPER_FILE=$ROOT_DIR/core/runtime/podman.sh
SHIMMY_RUNTIME_DIR=$ROOT_DIR/core/runtime
DEFAULT_INSTALL_DIR=${SHIMMY_INSTALL_DIR:-${SHIMMY_CONTROL_INSTALL_DIR:-$HOME/.config/shimmy}}
PREVIOUS_SOURCE_REF=
UPDATE_SOURCE_CHECKOUT=

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

if [ ! -f "$CATALOG_HELPER_FILE" ]; then
  fail "missing catalog helper: $CATALOG_HELPER_FILE"
fi

if [ ! -f "$COMMON_HELPER_FILE" ]; then
  fail "missing common helper: $COMMON_HELPER_FILE"
fi

if [ ! -f "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE" ]; then
  fail "missing custom image helper: $SHIMMY_CUSTOM_IMAGE_HELPER_FILE"
fi

if [ ! -f "$STARTUP_HELPER_FILE" ]; then
  fail "missing startup helper: $STARTUP_HELPER_FILE"
fi

if [ ! -f "$SHIMMY_PODMAN_HELPER_FILE" ]; then
  fail "missing Podman helper: $SHIMMY_PODMAN_HELPER_FILE"
fi

if [ ! -f "$PROFILE_HELPER_FILE" ]; then
  fail "missing profile helper: $PROFILE_HELPER_FILE"
fi

# shellcheck source=core/common/common.sh
. "$COMMON_HELPER_FILE"
# shellcheck source=core/catalog/catalog.sh
. "$CATALOG_HELPER_FILE"
# shellcheck source=core/profile/profile.sh
. "$PROFILE_HELPER_FILE"
# shellcheck source=core/startup/startup.sh
. "$STARTUP_HELPER_FILE"
# shellcheck source=core/runtime/image.sh
. "$SHIMMY_CUSTOM_IMAGE_HELPER_FILE"
# shellcheck source=core/runtime/podman.sh
. "$SHIMMY_PODMAN_HELPER_FILE"
# shellcheck source=core/update/request.sh
. "$ROOT_DIR/core/update/request.sh"
# shellcheck source=core/update/selection.sh
. "$ROOT_DIR/core/update/selection.sh"
# shellcheck source=core/update/management.sh
. "$ROOT_DIR/core/update/management.sh"
# shellcheck source=core/update/profile.sh
. "$ROOT_DIR/core/update/profile.sh"

local_build_repo_for_shim() {
  case "$1" in
    gdrive_0_2) printf 'localhost/shimmy-gdrive-0_2\n' ;;
    gh_2_94) printf 'localhost/shimmy-gh-2_94\n' ;;
    netcat_7_92) printf 'localhost/shimmy-netcat-7_92\n' ;;
    task_3_45) printf 'localhost/shimmy-task-3_45\n' ;;
    textual_8_2) printf 'localhost/shimmy-textual-8_2\n' ;;
    opnsense-mcp-admin_1_0) printf 'localhost/shimmy-opnsense-mcp-admin-1_0\n' ;;
    opnsense-mcp-read-only_0_4) printf 'localhost/shimmy-opnsense-mcp-read-only-0_4\n' ;;
    oc_4_18) printf 'localhost/shimmy-oc-4_18\n' ;;
    oc_4_20) printf 'localhost/shimmy-oc-4_20\n' ;;
    oc_4_22) printf 'localhost/shimmy-oc-4_22\n' ;;
    tessl_0_1) printf 'localhost/shimmy-tessl-0_1\n' ;;
    *) return 1 ;;
  esac
}

cleanup_old_local_images() {
  shim_name=$1
  images_dir=$2
  image_repo=$(local_build_repo_for_shim "$shim_name" || true)

  [ -n "$image_repo" ] || return 0

  context_dir=$images_dir/$shim_name
  current_hash=$(shimmy_context_hash_render "$context_dir" 2>/dev/null || true)
  [ -n "$current_hash" ] || return 0

  shimmy_podman_platform_resolve
  platform_tag=$(shimmy_podman_platform_tag_render "$SHIMMY_PODMAN_PLATFORM")
  current_ref=${image_repo}:${current_hash}-${platform_tag}

  "$SHIMMY_PODMAN_BIN" images \
    --filter "label=io.wadebee.shimmy.image-repo=${image_repo}" \
    --format '{{.Repository}}:{{.Tag}}' | sort -u | while IFS= read -r image_ref; do
      [ -n "$image_ref" ] || continue
      case "$image_ref" in
        "<none>:<none>"|"<none>:"*|*":<none>")
          continue
          ;;
      esac
      if [ "$image_ref" = "$current_ref" ]; then
        continue
      fi

      if "$SHIMMY_PODMAN_BIN" image rm "$image_ref" >/dev/null 2>&1; then
        printf 'WARN: Removed stale shim image: %s\n' "$image_ref" >&2
      else
        printf 'WARN: Unable to remove stale shim image (possibly in use): %s\n' "$image_ref" >&2
      fi
    done
}

run_pull_refresh() {
  shim_dir=$1
  profile_name=$2
  shim_list=$3

  shimmy_podman_preflight_require "shimmy update --pull"

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    case "$shim_name" in
      aws_2_31)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_AWS_IMAGE_PULL=always "$shim_dir/aws_2_31" --version >/dev/null </dev/null
        ;;
      go_1_26)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_GO_IMAGE_PULL=always "$shim_dir/go_1_26" version >/dev/null </dev/null
        ;;
      gcloud_573_0)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_GCLOUD_IMAGE_PULL=always "$shim_dir/gcloud_573_0" --version >/dev/null </dev/null
        ;;
      jq_1_8)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_JQ_IMAGE_PULL=always "$shim_dir/jq_1_8" --version >/dev/null </dev/null
        ;;
      nmap_7_98)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_NMAP_IMAGE_PULL=always "$shim_dir/nmap_7_98" --version >/dev/null </dev/null
        ;;
      rg_15_1)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_RG_IMAGE_PULL=always "$shim_dir/rg_15_1" --version >/dev/null </dev/null
        ;;
      terraform_1_15)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_TF_IMAGE_PULL=always "$shim_dir/terraform_1_15" version >/dev/null </dev/null
        ;;
    esac
  done <<EOF
$shim_list
EOF
}

run_build_refresh() {
  shim_dir=$1
  images_dir=$2
  profile_name=$3
  shim_list=$4

  shimmy_podman_preflight_require "shimmy update --build"

  while IFS= read -r shim_name; do
    [ -n "$shim_name" ] || continue
    case "$shim_name" in
      netcat_7_92)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_NETCAT_IMAGE_BUILD=always "$shim_dir/netcat_7_92" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      opnsense-mcp-read-only_0_4)
        if [ -n "${SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF:-}" ]; then
          shimmy_local_image_ensure \
            "localhost/shimmy-opnsense-mcp-read-only-0_4" \
            "$images_dir/opnsense-mcp-read-only_0_4" \
            always \
            --build-arg "SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF=$SHIMMY_OPNSENSE_MCP_READ_ONLY_SOURCE_REF" >/dev/null
        else
          shimmy_local_image_ensure \
            "localhost/shimmy-opnsense-mcp-read-only-0_4" \
            "$images_dir/opnsense-mcp-read-only_0_4" \
            always >/dev/null
        fi
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      opnsense-mcp-admin_1_0)
        if [ -n "${SHIMMY_OPNSENSE_MCP_ADMIN_SOURCE_REF:-}" ]; then
          shimmy_local_image_ensure \
            "localhost/shimmy-opnsense-mcp-admin-1_0" \
            "$images_dir/opnsense-mcp-admin_1_0" \
            always \
            --build-arg "SHIMMY_OPNSENSE_MCP_ADMIN_SOURCE_REF=$SHIMMY_OPNSENSE_MCP_ADMIN_SOURCE_REF" >/dev/null
        else
          shimmy_local_image_ensure \
            "localhost/shimmy-opnsense-mcp-admin-1_0" \
            "$images_dir/opnsense-mcp-admin_1_0" \
            always >/dev/null
        fi
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      gdrive_0_2)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_GDRIVE_IMAGE_BUILD=always "$shim_dir/gdrive_0_2" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      gh_2_94)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_GH_IMAGE_BUILD=always "$shim_dir/gh_2_94" --version >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      task_3_45)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_TASK_IMAGE_BUILD=always "$shim_dir/task_3_45" --version >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      textual_8_2)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_TEXTUAL_IMAGE_BUILD=always "$shim_dir/textual_8_2" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      oc_4_18)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_OC_4_18_IMAGE_BUILD=always "$shim_dir/oc_4_18" version >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      tessl_0_1)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_TESSL_IMAGE_BUILD=always "$shim_dir/tessl_0_1" --help >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      oc_4_20)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_OC_4_20_IMAGE_BUILD=always "$shim_dir/oc_4_20" version >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
      oc_4_22)
        SHIMMY_PROFILE_ACTIVE=$profile_name SHIMMY_OC_4_22_IMAGE_BUILD=always "$shim_dir/oc_4_22" version >/dev/null </dev/null
        cleanup_old_local_images "$shim_name" "$images_dir"
        ;;
    esac
  done <<EOF
$shim_list
EOF
}

shimmy_update_orchestration_run() {
  if [ -n "${SHIMMY_PROFILE_ACTIVE:-}" ]; then
    SHIMMY_PROFILE_ACTIVATED=1
  fi

  if [ "$UPDATE_ALL" -eq 1 ] && [ -n "$REQUESTED_SHIMS" ]; then
    fail "--all cannot be combined with --shim"
  fi

  install_dir=$(shimmy_update_install_dir_resolve)
  if [ "$UPDATE_ALL" -eq 1 ]; then
    SHIMMY_PROFILE_REQUESTED=default
  fi
  shimmy_update_profile_paths_resolve "$install_dir"
  install_dir=$SHIMMY_PROFILE_INSTALL_DIR
  manifest_file=$(shimmy_update_manifest_file_resolve)
  root_manifest_file=$install_dir/install-manifest.txt

  shimmy_install_layout_validate "$root_manifest_file" || fail "legacy Shimmy install layout detected; uninstall and reinstall"

  manifest_install_dir=$(shimmy_read_manifest_value "$root_manifest_file" install_dir || true)
  if [ -n "$manifest_install_dir" ]; then
    install_dir=$(shimmy_trim_path_trailing_slash "$manifest_install_dir")
    shimmy_update_profile_paths_resolve "$install_dir"
    manifest_file=$(shimmy_update_manifest_file_resolve)
    root_manifest_file=$install_dir/install-manifest.txt
  fi

  if [ "$UPDATE_ALL" -eq 1 ] && [ ! -f "$manifest_file" ]; then
    [ -f "$root_manifest_file" ] || fail "no shimmy install manifest found at $root_manifest_file; run ./shimmy install first"
    first_profile_name=$(shimmy_update_installed_profile_list "$root_manifest_file" | sed -n '1p')
    [ -n "$first_profile_name" ] || fail "no shimmy profiles found under $install_dir; run ./shimmy install first"
    SHIMMY_PROFILE_REQUESTED=$first_profile_name
    shimmy_update_profile_paths_resolve "$install_dir"
    manifest_file=$(shimmy_update_manifest_file_resolve)
  fi

  if [ ! -f "$manifest_file" ]; then
    if [ "$SHIMMY_PROFILE_NAME" = upstream ] && [ -z "${SHIMMY_UPSTREAM_CHECKOUT_DIR:-}" ]; then
      fail "no shimmy profile manifest found for profile upstream at $manifest_file; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
    fail "no shimmy profile manifest found for profile $SHIMMY_PROFILE_NAME at $manifest_file; run ./shimmy install first"
  fi

  if shimmy_update_is_installed_management "$install_dir"; then
    shimmy_update_management_run "$install_dir" "$manifest_file"
    exit 0
  fi

  if [ "$UPDATE_ALL" -eq 1 ]; then
    while IFS= read -r profile_name; do
      [ -n "$profile_name" ] || continue
      SHIMMY_PROFILE_REQUESTED=$profile_name
      shimmy_update_profile_paths_resolve "$install_dir"
      profile_manifest_file=$(shimmy_update_manifest_file_resolve)
      [ -f "$profile_manifest_file" ] || fail "no shimmy profile manifest found for profile $profile_name at $profile_manifest_file"
      profile_requests=$(shimmy_read_manifest_kinds "$profile_manifest_file")
  for version_name in $(shimmy_update_installed_kind_version_names "$profile_manifest_file"); do
        profile_requests=$(shimmy_append_line_list "$profile_requests" "$version_name")
      done
      profile_versions=$(shimmy_update_installed_kind_version_names "$profile_manifest_file")
      shimmy_update_profile_refresh_run "$profile_name" "$profile_manifest_file" "$profile_requests" "$profile_versions"
    done <<EOF
$(shimmy_update_installed_profile_list "$root_manifest_file")
EOF
    exit 0
  fi

  if [ -n "$REQUESTED_SHIMS" ]; then
    refresh_requests=
    refresh_versions=
    for requested_shim in $REQUESTED_SHIMS; do
      resolved_requests=$(shimmy_update_refresh_requests_for_shim "$manifest_file" "$requested_shim")
      while IFS= read -r refresh_request; do
        [ -n "$refresh_request" ] || continue
        if ! shimmy_contains_line_list "$refresh_requests" "$refresh_request"; then
          refresh_requests=$(shimmy_append_line_list "$refresh_requests" "$refresh_request")
        fi
        if shimmy_is_version "$refresh_request" && ! shimmy_contains_line_list "$refresh_versions" "$refresh_request"; then
          refresh_versions=$(shimmy_append_line_list "$refresh_versions" "$refresh_request")
        fi
      done <<EOF
$resolved_requests
EOF
    done
    shims_to_refresh=$refresh_requests
    versions_to_refresh=$refresh_versions
  else
    shims_to_refresh=$(shimmy_update_default_installed_kind_request_list "$manifest_file")
    versions_to_refresh=
    for refresh_request in $shims_to_refresh; do
      if shimmy_is_version "$refresh_request" && ! shimmy_contains_line_list "$versions_to_refresh" "$refresh_request"; then
        versions_to_refresh=$(shimmy_append_line_list "$versions_to_refresh" "$refresh_request")
      fi
    done
    [ -n "$shims_to_refresh" ] || fail "no default shim kinds are installed in profile $SHIMMY_PROFILE_NAME; run ./shimmy install first"
  fi

  shimmy_update_profile_refresh_run "$SHIMMY_PROFILE_NAME" "$manifest_file" "$shims_to_refresh" "$versions_to_refresh"
}

shimmy_update_run() {
  shimmy_update_request_reset
  shimmy_update_request_parse "$@"
  shimmy_update_orchestration_run
}
