---
name: shimmy-tool-gcloud
description: Guidance for using, changing, testing, and troubleshooting the Google Cloud CLI shim in this repository, including configuration mounts, kubeconfig mounting, and CLOUDSDK_* environment variable forwarding.
---

# Google Cloud CLI Shim

Use this skill when working with `shims/gcloud`, its tests, its docs, or gcloud usage through Shimmy.

## Files

- Runtime shim: `../../../shims/gcloud`
- User docs: `../../../docs/shims/gcloud.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version` and inspect the invoking profile with `shimmy status --format manifest`. To validate `upstream`, first activate its absolute `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/bin/shimmy` launcher, then run the tool without a profile selector. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: `gcr.io/google.com/cloudsdktool/google-cloud-cli:stable`
- Image override: `SHIMMY_GCLOUD_IMAGE`
- Pull override: `SHIMMY_GCLOUD_IMAGE_PULL=always`
- Config dir override: host `CLOUDSDK_CONFIG`
- Runtime mode: TTY only when stdin and stdout are terminals
- Shimmy diagnostics: `--shimmy-config-help` prints host `HOME`, host `CLOUDSDK_CONFIG`, expected gcloud/kubeconfig paths, effective config path, path presence, and mount policy before Podman preflight
- Container user: `cloudsdk`
- Container env: `HOME=/home/cloudsdk`, `CLOUDSDK_CONFIG=/home/cloudsdk/.config/gcloud`
- Mounts:
  - `$PWD` to `/work`
  - host `CLOUDSDK_CONFIG`, otherwise `$HOME/.config/gcloud`, to `/home/cloudsdk/.config/gcloud:rw`; the host directory is created during normal gcloud execution
  - `$HOME/.kube/config` to `/home/cloudsdk/.kube/config:ro` when present
- Forwarded env: `CLOUDSDK_*`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Preserve the provided writable gcloud config directory and optional read-only kubeconfig mount unless the task explicitly changes credential or cache behavior.
2. Do not create kubeconfig paths, credentials, or Google Cloud CLI config files automatically.
3. Keep `--shimmy-config-help` non-mutating; normal gcloud execution creates host `CLOUDSDK_CONFIG` when set, otherwise `~/.config/gcloud` when `HOME` is set.
4. Keep the container running as `cloudsdk` with `CLOUDSDK_CONFIG=/home/cloudsdk/.config/gcloud` unless a future image removes that user or changes its home.
5. Keep the default image aligned with Google's documented Google Cloud CLI Docker image repository. The `:stable` tag is the preferred default because Google documents it as supporting both `linux/amd64` and `linux/arm64`.
6. Treat `CLOUDSDK_*` forwarding as the current contract; update docs and tests deliberately if it changes. Host `CLOUDSDK_CONFIG` should select the host mount source, and Shimmy's explicit container `CLOUDSDK_CONFIG` value should point to that mounted directory.
7. Prefer `gcloud info`, `gcloud version`, and `gcloud auth list` for validation and information gathering.
8. Do not run `gcloud apply` or `gcloud destroy` style operations unless the user explicitly asks for that operation and understands the consequences.
9. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
10. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Config help smoke: `./shims/gcloud --shimmy-config-help`
- Direct smoke: `./shims/gcloud --version`
- Auth smoke: `gcloud auth list` (when authenticated)
- Project smoke: `gcloud projects list` (when authenticated)

## Learning Guidance

- Capture gcloud-specific lessons here when they affect credential management, project configuration, or command behavior.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
