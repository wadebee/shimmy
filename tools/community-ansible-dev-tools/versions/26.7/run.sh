#!/bin/sh
set -eu

SCRIPT_DIR=$(
  cd -- "$(dirname -- "$0")" && pwd
)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/../../../.." && pwd)
SHIMMY_RUNTIME_DIR=$ROOT_DIR/lib/runtime
SHIMMY_IMAGE_CONFIG_FILE=$SCRIPT_DIR/image.conf
SHIMMY_IMAGE_HELPER_FILE=$SHIMMY_RUNTIME_DIR/image.sh

SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG=${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG:-}
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG_PATH=
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE_PULL=${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE_PULL:-}
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IO_ARG=-i
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN=${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN:-}
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED=
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_PREVIEW=
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_PULL_ARG=
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT=${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT:-}
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK=
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH=$PWD
SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH_INPUT=

shimmy_community_ansible_dev_tools_boolean_validate() {
  variable_name=${1:?variable name is required}
  variable_value=${2:-}

  case "$variable_value" in
    ''|0|1)
      ;;
    *)
      printf 'ERROR: %s must be 1, 0, or unset\n' "$variable_name" >&2
      exit 1
      ;;
  esac
}

shimmy_community_ansible_dev_tools_workdir_preflight_validate() {
  workdir_host_path=$PWD
  workdir_input=
  workdir_preview=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --preview-shim)
        workdir_preview=1
        shift
        ;;
      --mount-workdir)
        [ "$#" -ge 2 ] || {
          printf '%s\n' 'ERROR: --mount-workdir requires a host path argument' >&2
          exit 1
        }
        workdir_input=$2
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  if [ -n "$workdir_input" ]; then
    case "$workdir_input" in
      /*) workdir_host_path=$workdir_input ;;
      *) printf 'ERROR: --mount-workdir requires an absolute host path: %s\n' "$workdir_input" >&2; exit 1 ;;
    esac
  fi
  if [ "$workdir_preview" -eq 0 ] && [ ! -d "$workdir_host_path" ]; then
    printf 'ERROR: workdir host path does not exist: %s\n' "$workdir_host_path" >&2
    exit 1
  fi
}


if [ ! -f "$SHIMMY_IMAGE_HELPER_FILE" ]; then
  printf 'ERROR: missing shim helper: %s\n' "$SHIMMY_IMAGE_HELPER_FILE" >&2
  exit 1
fi

# shellcheck source=lib/runtime/image.sh
. "$SHIMMY_IMAGE_HELPER_FILE"

SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE=${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE:-$(shimmy_image_external_default_read "$SHIMMY_IMAGE_CONFIG_FILE")}

shimmy_community_ansible_dev_tools_boolean_validate \
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG \
  "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG"
shimmy_community_ansible_dev_tools_boolean_validate \
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN \
  "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN"
shimmy_community_ansible_dev_tools_boolean_validate \
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT \
  "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT"
shimmy_community_ansible_dev_tools_workdir_preflight_validate "$@"

shimmy_podman_preflight_or_preview_require "the community-ansible-dev-tools shim" "$@"

if [ "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN" = 1 ]; then
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED=1
fi

if [ "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG" = 1 ]; then
  if [ -z "${HOME:-}" ]; then
    printf '%s\n' 'ERROR: HOME is required when SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG=1' >&2
    exit 1
  fi
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG_PATH=$HOME/.gitconfig
  if ! shimmy_podman_is_preview && [ ! -f "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG_PATH" ]; then
    printf 'ERROR: git config file does not exist: %s\n' "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG_PATH" >&2
    exit 1
  fi
fi

if [ "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT" = 1 ]; then
  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    printf '%s\n' 'ERROR: SSH_AUTH_SOCK is required when SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AGENT=1' >&2
    exit 1
  fi
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK=$SSH_AUTH_SOCK
  if ! shimmy_podman_is_preview && [ ! -S "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK" ]; then
    printf 'ERROR: SSH_AUTH_SOCK is not a socket: %s\n' "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK" >&2
    exit 1
  fi
fi

if [ "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE_PULL" = always ]; then
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_PULL_ARG=--pull=always
fi

if shimmy_podman_is_preview; then
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_PREVIEW=1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --preview-shim)
      shift
      ;;
    --mount-workdir)
      [ "$#" -ge 2 ] || {
        printf '%s\n' 'ERROR: --mount-workdir requires a host path argument' >&2
        exit 1
      }
      SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH_INPUT=$2
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

if [ -n "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH_INPUT" ]; then
  case "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH_INPUT" in
    /*)
      SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH=$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH_INPUT
      ;;
    *)
      printf 'ERROR: --mount-workdir requires an absolute host path: %s\n' "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH_INPUT" >&2
      exit 1
      ;;
  esac
fi

if ! shimmy_podman_is_preview && [ ! -d "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH" ]; then
  printf 'ERROR: workdir host path does not exist: %s\n' "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH" >&2
  exit 1
fi

if [ -t 0 ] && [ -t 1 ]; then
  SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IO_ARG=-it
fi

case "$#:${1:-}:${2:-}" in
  0::)
    if [ -n "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_PREVIEW" ]; then
      set -- --preview-shim
    fi
    ;;
  1:--version:)
    if [ -n "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_PREVIEW" ]; then
      set -- --preview-shim adt --version
    else
      set -- adt --version
    fi
    ;;
esac

shimmy_podman_run_or_preview "$SHIMMY_PODMAN_BIN" run --rm \
  --platform "$SHIMMY_PODMAN_PLATFORM" \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_PULL_ARG:+"$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_PULL_ARG"} \
  "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IO_ARG" \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--cap-add"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"SYS_ADMIN"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--cap-add"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"SYS_RESOURCE"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--device"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"/dev/fuse"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--hostname"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"ansible-dev-container"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--security-opt"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"apparmor=unconfined"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--security-opt"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"label=disable"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--security-opt"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"seccomp=unconfined"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--user"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"root"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"--userns"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_NESTED_PODMAN_ENABLED:+"host"} \
  -v "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_WORKDIR_HOST_PATH:/workdir:rw" \
  -w /workdir \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG_PATH:+"-v"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG_PATH:+"$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_GIT_CONFIG_PATH:/root/.gitconfig:ro"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK:+"-v"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK:+"$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK:$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK:rw"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK:+"-e"} \
  ${SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK:+"SSH_AUTH_SOCK=$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_SSH_AUTH_SOCK"} \
  "$SHIMMY_COMMUNITY_ANSIBLE_DEV_TOOLS_IMAGE" \
  "$@"
