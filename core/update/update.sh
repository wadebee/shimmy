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
REQUESTED_INSTALL_DIR=
SHIMMY_PROFILE_REQUESTED=
REQUESTED_SHIMS=
REQUESTED_SHELL=
REQUESTED_STARTUP_FILES=
PULL_IMAGES=0
BUILD_IMAGES=0
REPAIR_STARTUP=0
UPDATE_ALL=0
PREVIOUS_SOURCE_REF=
SHIMMY_PROFILE_ACTIVATED=0
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

install_dir_resolve() {
  if [ -n "$REQUESTED_INSTALL_DIR" ]; then
    printf '%s\n' "$(shimmy_trim_path_trailing_slash "$REQUESTED_INSTALL_DIR")"
    return 0
  fi

  printf '%s\n' "$(shimmy_trim_path_trailing_slash "$DEFAULT_INSTALL_DIR")"
}

manifest_file_resolve() {
  printf '%s\n' "$SHIMMY_PROFILE_MANIFEST_PATH"
}

profile_paths_resolve() {
  install_dir=$1

  if ! shimmy_profile_paths_resolve "$SHIMMY_PROFILE_REQUESTED" "$install_dir" "$ROOT_DIR"; then
    fail "unsupported Shimmy profile: ${SHIMMY_PROFILE_REQUESTED:-${SHIMMY_PROFILE_ACTIVE:-}}"
  fi
}

requested_shim_append() {
  requested_shim=$1

  if [ -n "$REQUESTED_SHIMS" ]; then
    REQUESTED_SHIMS="$REQUESTED_SHIMS $requested_shim"
  else
    REQUESTED_SHIMS=$requested_shim
  fi
}

is_installed_management_update() {
  install_dir=$1

  [ -n "${SHIMMY_CONTROL_INSTALL_DIR:-}" ] || return 1

  control_source_dir=$install_dir/core
  [ -d "$control_source_dir/scripts" ] || return 1

  root_dir_real=$(cd -- "$ROOT_DIR" && pwd) || return 1
  control_source_dir_real=$(cd -- "$control_source_dir" && pwd) || return 1

  [ "$root_dir_real" = "$control_source_dir_real" ]
}

run_installed_management_update() {
  install_dir=$1
  manifest_file=$2

  source_url=$(shimmy_read_manifest_value "$manifest_file" shimmy_source_url || true)
  [ -n "$source_url" ] || fail "no shimmy_source_url found in $manifest_file; run update from a Shimmy source checkout"
  command -v git >/dev/null 2>&1 || fail "git is required for installed shimmy update"

  temp_parent=${TMPDIR:-/tmp}
  update_tmp_dir=$(mktemp -d "$temp_parent/shimmy-self-update.XXXXXX") || fail "unable to create temporary update directory"
  source_dir=$update_tmp_dir/source

  printf 'INFO: Fetching Shimmy management updates from %s\n' "$source_url" >&2
  if git clone "$source_url" "$source_dir" >/dev/null; then
    :
  else
    command_status=$?
    rm -rf "$update_tmp_dir"
    return "$command_status"
  fi

  if [ ! -x "$source_dir/shimmy" ]; then
    rm -rf "$update_tmp_dir"
    fail "fetched source does not contain an executable shimmy launcher"
  fi

  source_ref=$(git -C "$source_dir" rev-parse --short HEAD 2>/dev/null || printf unknown)
  printf 'INFO: Updating Shimmy management plane from %s\n' "$source_ref" >&2

  set -- "$source_dir/shimmy" update --install-dir "$install_dir"
  if [ "$SHIMMY_PROFILE_ACTIVATED" -eq 1 ]; then
    set -- "$@" --profile "$SHIMMY_PROFILE_NAME"
  fi
  if [ "$PULL_IMAGES" -eq 1 ]; then
    set -- "$@" --pull
  fi
  if [ "$BUILD_IMAGES" -eq 1 ]; then
    set -- "$@" --build
  fi
  if [ "$REPAIR_STARTUP" -eq 1 ]; then
    set -- "$@" --repair-startup
  fi
  if [ "$UPDATE_ALL" -eq 1 ]; then
    set -- "$@" --all
  fi
  if [ -n "$REQUESTED_SHIMS" ]; then
    for shim_name in $REQUESTED_SHIMS; do
      set -- "$@" --shim "$shim_name"
    done
  fi
  if [ -n "$REQUESTED_SHELL" ]; then
    set -- "$@" --shell "$REQUESTED_SHELL"
  fi
  if [ -n "$REQUESTED_STARTUP_FILES" ]; then
    while IFS= read -r startup_file; do
      [ -n "$startup_file" ] || continue
      set -- "$@" --startup-file "$startup_file"
    done <<EOF
$REQUESTED_STARTUP_FILES
EOF
  fi

  set +e
  if [ -n "$UPDATE_SOURCE_CHECKOUT" ]; then
    SHIMMY_UPSTREAM_CHECKOUT_DIR=$UPDATE_SOURCE_CHECKOUT "$@"
    command_status=$?
  else
    "$@"
    command_status=$?
  fi
  set -e

  if [ "$command_status" -eq 0 ]; then
    rm -rf "$update_tmp_dir"
    return 0
  fi

  rm -rf "$update_tmp_dir"
  return "$command_status"
}

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

installed_kind_version_names() {
  manifest_file=$1
  kind_filter=${2:-}
  version_names=

  while IFS= read -r kind_version_entry; do
    [ -n "$kind_version_entry" ] || continue
    kind_name=${kind_version_entry%%|*}
    entry_remainder=${kind_version_entry#*|}
    version_label=${entry_remainder%%|*}
    version_name=${kind_version_entry##*|}
    [ "$version_label" != default ] || continue
    [ -z "$kind_filter" ] || [ "$kind_filter" = "$kind_name" ] || continue
    if ! shimmy_contains_line_list "$version_names" "$version_name"; then
      version_names=$(shimmy_append_line_list "$version_names" "$version_name")
    fi
  done <<EOF
$(shimmy_read_manifest_kind_versions "$manifest_file" || true)
EOF

  printf '%s\n' "$version_names"
}

default_installed_kind_request_list() {
  manifest_file=$1
  installed_kinds=$(shimmy_read_manifest_kinds "$manifest_file")
  default_installed_requests=

  for kind_name in $(shimmy_default_kind_list); do
    if shimmy_contains_line_list "$installed_kinds" "$kind_name"; then
      default_installed_requests=$(shimmy_append_line_list "$default_installed_requests" "$kind_name")
      for version_name in $(installed_kind_version_names "$manifest_file" "$kind_name"); do
        default_installed_requests=$(shimmy_append_line_list "$default_installed_requests" "$version_name")
      done
    fi
  done

  printf '%s\n' "$default_installed_requests"
}

request_version_label_validate() {
  manifest_file=$1
  kind_name=$2
  version_label=$3
  version_name=$(shimmy_kind_version_for_label "$kind_name" "$version_label" || true)
  [ -n "$version_name" ] || fail "unsupported $kind_name version: $version_label"

  expected_entry=$kind_name\|$version_label\|$version_name
  if ! shimmy_contains_line_list "$(shimmy_read_manifest_kind_versions "$manifest_file" || true)" "$expected_entry"; then
    fail "$kind_name@$version_label not installed; run shimmy install --shim $kind_name@$version_label"
  fi

  printf '%s\n' "$version_name"
}

refresh_requests_for_shim() {
  manifest_file=$1
  requested_shim=$2
  installed_kinds=$(shimmy_read_manifest_kinds "$manifest_file" || true)

  case "$requested_shim" in
    *@*)
      kind_name=${requested_shim%%@*}
      version_label=${requested_shim#*@}
      shimmy_is_kind "$kind_name" || fail "unsupported shim kind: $kind_name"
      shimmy_contains_line_list "$installed_kinds" "$kind_name" || fail "$kind_name not installed; run shimmy install --shim $kind_name"
      version_name=$(request_version_label_validate "$manifest_file" "$kind_name" "$version_label")
      printf '%s\n%s\n' "$kind_name" "$version_name"
      ;;
    *)
      if shimmy_is_kind "$requested_shim"; then
        kind_name=$requested_shim
        shimmy_contains_line_list "$installed_kinds" "$kind_name" || fail "$kind_name not installed; run shimmy install --shim $kind_name"
        printf '%s\n' "$kind_name"
        installed_kind_version_names "$manifest_file" "$kind_name"
      elif shimmy_is_version "$requested_shim"; then
        version_name=$requested_shim
        kind_name=$(shimmy_version_kind "$version_name")
        shimmy_contains_line_list "$installed_kinds" "$kind_name" || fail "$kind_name not installed; run shimmy install --shim $kind_name"
        request_version_label_validate "$manifest_file" "$kind_name" "$(shimmy_version_label "$version_name")" >/dev/null
        printf '%s\n%s\n' "$kind_name" "$version_name"
      else
        fail "unsupported shim kind: $requested_shim"
      fi
      ;;
  esac
}

installed_profile_list() {
  root_manifest_file=$1
  profile_names=

  if [ -f "$root_manifest_file" ]; then
    profile_names=$(shimmy_read_manifest_values "$root_manifest_file" profile || true)
  fi

  for profile_manifest_file in "$install_dir"/profiles/*/install-manifest.txt; do
    [ -f "$profile_manifest_file" ] || continue
    profile_name=$(basename "$(dirname "$profile_manifest_file")")
    if ! shimmy_contains_line_list "$profile_names" "$profile_name"; then
      profile_names=$(shimmy_append_line_list "$profile_names" "$profile_name")
    fi
  done

  printf '%s\n' "$profile_names"
}

profile_refresh_run() {
  profile_name=$1
  profile_manifest_file=$2
  request_list=$3
  version_list=$4

  [ -n "$request_list" ] || fail "no installed shim kinds selected for profile $profile_name"

  PREVIOUS_SOURCE_REF=$(shimmy_read_manifest_value "$profile_manifest_file" shimmy_source_ref || true)
  UPDATE_SOURCE_CHECKOUT=
  manifest_source_checkout=$(shimmy_read_manifest_value "$profile_manifest_file" source_checkout || true)
  if [ "$profile_name" = upstream ] && [ -n "$manifest_source_checkout" ]; then
    UPDATE_SOURCE_CHECKOUT=$manifest_source_checkout
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$UPDATE_SOURCE_CHECKOUT" || true)
    if [ -n "$upstream_invalid_reason" ]; then
      fail "invalid upstream Shimmy checkout ($upstream_invalid_reason): $UPDATE_SOURCE_CHECKOUT; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
  fi

  set -- "$SCRIPT_DIR/install.sh" --install-dir "$install_dir" --profile "$profile_name" --refresh-shims --no-skills
  if [ "$REPAIR_STARTUP" -eq 0 ]; then
    set -- "$@" --no-startup
  else
    startup_shell=$REQUESTED_SHELL
    startup_files=$REQUESTED_STARTUP_FILES

    if [ -z "$startup_shell" ]; then
      startup_shell=$(shimmy_read_manifest_value "$root_manifest_file" startup_shell || true)
    fi
    if [ -z "$startup_files" ]; then
      startup_files=$(shimmy_read_manifest_values "$root_manifest_file" startup_file || true)
    fi

    if [ -n "$startup_shell" ]; then
      set -- "$@" --shell "$startup_shell"
    fi
    if [ -n "$startup_files" ]; then
      while IFS= read -r startup_file; do
        [ -n "$startup_file" ] || continue
        set -- "$@" --startup-file "$startup_file"
      done <<EOF
$startup_files
EOF
    fi
  fi

  for requested_shim in $request_list; do
    set -- "$@" --shim "$requested_shim"
  done

  if [ -n "$PREVIOUS_SOURCE_REF" ]; then
    if [ -n "$UPDATE_SOURCE_CHECKOUT" ]; then
      SHIMMY_UPSTREAM_CHECKOUT_DIR=$UPDATE_SOURCE_CHECKOUT SHIMMY_PREVIOUS_SOURCE_REF=$PREVIOUS_SOURCE_REF "$@"
    else
      SHIMMY_PREVIOUS_SOURCE_REF=$PREVIOUS_SOURCE_REF "$@"
    fi
  else
    if [ -n "$UPDATE_SOURCE_CHECKOUT" ]; then
      SHIMMY_UPSTREAM_CHECKOUT_DIR=$UPDATE_SOURCE_CHECKOUT "$@"
    else
      "$@"
    fi
  fi

  profile_paths_resolve "$install_dir"
  if [ "$PULL_IMAGES" -eq 1 ]; then
    run_pull_refresh "$SHIMMY_PROFILE_IMPLEMENTATION_DIR" "$profile_name" "$version_list"
  fi

  if [ "$BUILD_IMAGES" -eq 1 ]; then
    run_build_refresh "$SHIMMY_PROFILE_IMPLEMENTATION_DIR" "$SHIMMY_PROFILE_DIR/images" "$profile_name" "$version_list"
  fi
}

usage() {
  cat <<'EOF'
Refresh an existing shimmy installation.

Usage:
  commands/update.sh [--install-dir <dir>] [--profile default|upstream] [--shim <name>] [--all] [--pull] [--build] [--repair-startup]

When run from a source checkout, update refreshes the install from that checkout.
When run through an installed shimmy command, update fetches the recorded
shimmy_source_url and refreshes the management plane from that source.

Options:
  --install-dir <dir>   Base install directory. Default: ~/.config/shimmy
  --profile <name>         Update profile: default or upstream
  --shim <name>         Refresh one installed shim in the selected profile. Repeatable.
  --all                 Refresh root assets and every installed profile shim.
  --pull                Pull newer remote images for installed remote-image shims.
  --build               Rebuild local images for installed local-build shims.
  --repair-startup      Rewrite the managed Shimmy startup block after reinstalling
  --shell <name>        Override shell detection for startup-file repair
  --startup-file <path> Override startup files used during repair. Repeatable.
  -h, --help
EOF
}

shimmy_update_run() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --install-dir)
        [ "$#" -ge 2 ] || fail "missing value for --install-dir"
        REQUESTED_INSTALL_DIR=$2
        shift 2
        ;;
      --profile)
        [ "$#" -ge 2 ] || fail "missing value for --profile"
        SHIMMY_PROFILE_REQUESTED=$2
        SHIMMY_PROFILE_ACTIVATED=1
        shift 2
        ;;
      --shim)
        [ "$#" -ge 2 ] || fail "missing value for --shim"
        requested_shim_append "$2"
        shift 2
        ;;
      --all)
        UPDATE_ALL=1
        shift
        ;;
      --pull)
        PULL_IMAGES=1
        shift
        ;;
      --build)
        BUILD_IMAGES=1
        shift
        ;;
      --repair-startup)
        REPAIR_STARTUP=1
        shift
        ;;
      --shell)
        [ "$#" -ge 2 ] || fail "missing value for --shell"
        REQUESTED_SHELL=$2
        shift 2
        ;;
      --startup-file)
        [ "$#" -ge 2 ] || fail "missing value for --startup-file"
        REQUESTED_STARTUP_FILES=$(shimmy_append_line_list "$REQUESTED_STARTUP_FILES" "$2")
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

  if [ -n "${SHIMMY_PROFILE_ACTIVE:-}" ]; then
    SHIMMY_PROFILE_ACTIVATED=1
  fi

  if [ "$UPDATE_ALL" -eq 1 ] && [ -n "$REQUESTED_SHIMS" ]; then
    fail "--all cannot be combined with --shim"
  fi

  install_dir=$(install_dir_resolve)
  if [ "$UPDATE_ALL" -eq 1 ]; then
    SHIMMY_PROFILE_REQUESTED=default
  fi
  profile_paths_resolve "$install_dir"
  install_dir=$SHIMMY_PROFILE_INSTALL_DIR
  manifest_file=$(manifest_file_resolve)
  root_manifest_file=$install_dir/install-manifest.txt

  manifest_install_dir=$(shimmy_read_manifest_value "$root_manifest_file" install_dir || true)
  if [ -n "$manifest_install_dir" ]; then
    install_dir=$(shimmy_trim_path_trailing_slash "$manifest_install_dir")
    profile_paths_resolve "$install_dir"
    manifest_file=$(manifest_file_resolve)
    root_manifest_file=$install_dir/install-manifest.txt
  fi

  if [ "$UPDATE_ALL" -eq 1 ] && [ ! -f "$manifest_file" ]; then
    [ -f "$root_manifest_file" ] || fail "no shimmy install manifest found at $root_manifest_file; run ./shimmy install first"
    first_profile_name=$(installed_profile_list "$root_manifest_file" | sed -n '1p')
    [ -n "$first_profile_name" ] || fail "no shimmy profiles found under $install_dir; run ./shimmy install first"
    SHIMMY_PROFILE_REQUESTED=$first_profile_name
    profile_paths_resolve "$install_dir"
    manifest_file=$(manifest_file_resolve)
  fi

  if [ ! -f "$manifest_file" ]; then
    if [ "$SHIMMY_PROFILE_NAME" = upstream ] && [ -z "${SHIMMY_UPSTREAM_CHECKOUT_DIR:-}" ]; then
      fail "no shimmy profile manifest found for profile upstream at $manifest_file; rerun ./shimmy install --profile upstream from the desired Shimmy checkout"
    fi
    fail "no shimmy profile manifest found for profile $SHIMMY_PROFILE_NAME at $manifest_file; run ./shimmy install first"
  fi

  if is_installed_management_update "$install_dir"; then
    run_installed_management_update "$install_dir" "$manifest_file"
    exit 0
  fi

  if [ "$UPDATE_ALL" -eq 1 ]; then
    while IFS= read -r profile_name; do
      [ -n "$profile_name" ] || continue
      SHIMMY_PROFILE_REQUESTED=$profile_name
      profile_paths_resolve "$install_dir"
      profile_manifest_file=$(manifest_file_resolve)
      [ -f "$profile_manifest_file" ] || fail "no shimmy profile manifest found for profile $profile_name at $profile_manifest_file"
      profile_requests=$(shimmy_read_manifest_kinds "$profile_manifest_file")
      for version_name in $(installed_kind_version_names "$profile_manifest_file"); do
        profile_requests=$(shimmy_append_line_list "$profile_requests" "$version_name")
      done
      profile_versions=$(installed_kind_version_names "$profile_manifest_file")
      profile_refresh_run "$profile_name" "$profile_manifest_file" "$profile_requests" "$profile_versions"
    done <<EOF
$(installed_profile_list "$root_manifest_file")
EOF
    exit 0
  fi

  if [ -n "$REQUESTED_SHIMS" ]; then
    refresh_requests=
    refresh_versions=
    for requested_shim in $REQUESTED_SHIMS; do
      resolved_requests=$(refresh_requests_for_shim "$manifest_file" "$requested_shim")
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
    shims_to_refresh=$(default_installed_kind_request_list "$manifest_file")
    versions_to_refresh=
    for refresh_request in $shims_to_refresh; do
      if shimmy_is_version "$refresh_request" && ! shimmy_contains_line_list "$versions_to_refresh" "$refresh_request"; then
        versions_to_refresh=$(shimmy_append_line_list "$versions_to_refresh" "$refresh_request")
      fi
    done
    [ -n "$shims_to_refresh" ] || fail "no default shim kinds are installed in profile $SHIMMY_PROFILE_NAME; run ./shimmy install first"
  fi

  profile_refresh_run "$SHIMMY_PROFILE_NAME" "$manifest_file" "$shims_to_refresh" "$versions_to_refresh"
}
