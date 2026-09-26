# ABA Shim

## Upstream and image provenance

ABA 1.3 is built locally from [ABA v1.3.4](https://github.com/sjbylo/aba/releases/tag/v1.3.4), commit `364c4c0faa743d57d04674d71eabd434b5ec17d5`. The version-owned build uses `docker.io/library/fedora@sha256:43b29f65a41eb9c35e1cd5323e3bdf3b655c2357a9f4f1ff2f9c2798e5045d80`; `image.conf` records its mutable discovery reference and both supported native platforms. Fedora is required because its public repositories provide ABA's `dialog` and `coreos-installer` dependencies, which UBI9 public repositories do not.

ABA is a high-impact OpenShift disconnected-environment administration utility. It can install or remove registries, mirror large image archives, change firewall or system state through sudo, access SSH targets, and create, upgrade, or delete OpenShift clusters and VMs. Read the upstream documentation and review the exact target before running an operational command.

## Install and validate

Install `aba@1.3` into an active profile through Shimmy's normal shim lifecycle. Source contributors can render the unprivileged runtime without Podman:

```sh
./commands/run-tool.sh aba --preview-shim --help
```

A live help smoke builds the pinned local image and runs `aba --help`. It is non-mutating from the wrapper's perspective, but the image build needs Podman and registry access.

## Safe and operational modes

`aba --help` and `aba -h` are the only safe help invocations. They mount only the current project directory at `/work`, set `HOME=/work`, use the native platform, and do not select a rootful connection, enable host networking, grant privileged mode, or expose optional credentials or mirror data.

Every other invocation, including no arguments, is operational. It fails before ordinary Podman preflight unless all of these exact controls are set:

```sh
SHIMMY_ABA_PRIVILEGED=1 \
SHIMMY_ABA_NETWORK=host \
SHIMMY_PODMAN_PRIVILEGED=1 \
aba -d mirror install
```

For a live operational invocation, Shimmy selects and verifies a rootful Podman connection. Set `SHIMMY_PODMAN_PRIVILEGED_CONNECTION` to name the exact rootful connection when automatic selection is unsuitable. The operational container receives `--connection`, `--privileged`, and `--network host`; its normal rootless connection is unchanged.

Operational support is limited to Linux RHEL, CentOS Stream, or Fedora bastions. On macOS, Podman host networking is networking in the Linux VM, not the macOS host; use macOS only for build and help validation.

## Inputs, state, and image controls

The project directory is always mounted at `/work`, and ABA uses `HOME=/work`; its state therefore resides below project-local `.aba`. Shimmy never mounts `$HOME`, `$HOME/.aba`, `$HOME/.ssh`, a Podman socket, or arbitrary credential directories. `mirror/mirror.conf` in the project is the supported mirror configuration location.

Optional inputs are available only when the caller selects exact existing host resources:

- `SHIMMY_ABA_SSH_KEY=/absolute/file` mounts one readable regular private key at `/tmp/shimmy-aba-ssh-key:ro`. Pass that container path to the ABA option that accepts the registry SSH key. Do not mount `known_hosts`: upstream-generated SSH configuration disables strict host-key checking, so confirm the destination through an independent trusted channel.
- `SHIMMY_ABA_PULL_SECRET=/absolute/file` mounts one readable regular Red Hat pull secret at `/work/.pull-secret.json:ro`. Its value is never forwarded or printed.
- `SHIMMY_ABA_MIRROR_DATA_DIR=/absolute/directory` mounts one existing writable directory at `/work/mirror/data:rw`. This is the only mirror archive mount and may contain multi-gigabyte data.
- `SHIMMY_ABA_IMAGE` overrides the local image. `SHIMMY_ABA_IMAGE_PULL=always` pulls only that override before use.
- `SHIMMY_ABA_IMAGE_BUILD=always` rebuilds the default local image. `SHIMMY_ABA_BASE_IMAGE` overrides its compatible Fedora build base.
- `SHIMMY_HOST_CA_BUNDLE=/absolute/path/to/bundle.pem` adds one readable PEM bundle to the local image's system trust store before Fedora installs packages, and mounts the same file at `/tmp/shimmy-host-ca-bundle.pem:ro` with `SSL_CERT_FILE` for ABA runtime processes. The build receives the bundle only as a Podman build secret; its SHA-256 affects the local image cache identity, while the host path is neither forwarded nor stored in the image.

The upstream container workflow remains work in progress. In particular, upstream reports that `nmstate` does not work inside its UBI container, so a successful build or `--help` does not establish that host operations will work.
