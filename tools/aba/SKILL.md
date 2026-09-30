---
name: shimmy-tool-aba
description: Use and maintain the high-impact ABA Shimmy tool, including its explicit privileged rootful Podman boundary and exact sensitive mounts.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# ABA Shim

Use this skill for ABA usage, documentation, runtime, image, or test changes in this repository.

## Approval boundary

ABA can install or remove registries, mirror substantial image data, alter host firewall or system state through sudo, use SSH, and create, upgrade, or delete OpenShift clusters and VMs. Persistent approval is suitable only for `aba --help` or `aba -h`.

Require explicit approval for the exact operational ABA command, all external targets, `SHIMMY_ABA_PRIVILEGED=1`, `SHIMMY_ABA_NETWORK=host`, `SHIMMY_PODMAN_PRIVILEGED=1`, the selected rootful connection, and every optional sensitive mount. Do not infer this approval from a safe wrapper approval and do not persist an operational `aba` prefix.

If an installed wrapper's exact safe outer prefix is already approved, use it with escalation on the first attempt. Sandbox-only reachability failures mean unverified from the sandbox, not an inactive profile. Follow `shimmy-escalation` before `shimmy-init` or any non-Shimmy fallback.

## Source and installed use

For source preview, run:

```sh
./commands/run-tool.sh aba --preview-shim --help
```

For an installed selected profile, invoke `aba` normally. To inspect or activate another profile, use its absolute `bin/shimmy` launcher, dry-run activation first, request approval for the exact activation, then source that profile's `shell-init.sh`. Do not use removed repository shim paths or direct Podman machine lifecycle commands.

## Runtime contract

- ABA 1.3 builds locally from upstream v1.3.4 commit `364c4c0faa743d57d04674d71eabd434b5ec17d5` using the version-owned Fedora base pin in `image.conf`; Fedora supplies ABA's `dialog` and `coreos-installer` dependencies, which public UBI9 repositories lack.
- `aba --help` and `aba -h` are the only unprivileged paths. They mount `$PWD` at `/work`, use `HOME=/work`, and add no network, privilege, rootful connection, credential, or mirror-data access.
- Every other invocation requires all three exact values: `SHIMMY_ABA_PRIVILEGED=1`, `SHIMMY_ABA_NETWORK=host`, and `SHIMMY_PODMAN_PRIVILEGED=1`. A live invocation additionally verifies a rootful connection through `SHIMMY_PODMAN_PRIVILEGED_CONNECTION` or Shimmy's resolver.
- `SHIMMY_ABA_SSH_KEY` and `SHIMMY_ABA_PULL_SECRET` each name one absolute readable regular file mounted read-only at `/tmp/shimmy-aba-ssh-key` and `/work/.pull-secret.json`. `SHIMMY_ABA_MIRROR_DATA_DIR` names one absolute existing writable directory mounted at `/work/mirror/data`.
- `SHIMMY_HOST_CA_BUNDLE` optionally names one absolute, readable, nonempty bundle. ABA supplies a present bundle only as the temporary `shimmy-host-ca-bundle` local-build secret before Fedora network work, then mounts it at `/tmp/shimmy-host-ca-bundle.pem` with `SSL_CERT_FILE` at runtime. It does not affect cache identity or image layers; use `SHIMMY_ABA_IMAGE_BUILD=always` for refreshed build-time trust. The host path and contents must not be logged.
- Do not mount `$HOME`, `$HOME/.aba`, `$HOME/.ssh`, pull-secret directories, known-host files, or Podman sockets. Never forward Shimmy control variables or secret values into the container.
- Operational support is Linux RHEL/CentOS Stream/Fedora bastions only. macOS validates local image build/help but not host operations. Upstream's UBI-container workflow is work in progress and has a known `nmstate` limitation.

## Change and validation rules

Keep tool behavior in `tools/aba/versions/1.3/`; do not modify shared dispatchers or runtime helpers for ABA. Preserve the three-control gate before ordinary Podman preflight and the fixed mount destinations. Test safe and configured previews, pre-Podman validation failures, and shared rootful-connection rejection. Validate metadata, shell syntax, executable modes, focused tests, and the full bounded-parallel suite. Live `--help` requires exact outer-wrapper approval and native Linux amd64 plus native Apple Silicon macOS arm64 acceptance; cross-emulation is not acceptance.
