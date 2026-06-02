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

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `<tool> --version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_PROFILE_ACTIVE=upstream <tool> --version` when validating the upstream profile. Use repo-local paths such as `./shims/<tool>` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Default image: `gcr.io/google.com/cloudsdktool/google-cloud-cli:stable`
- Image override: `SHIMMY_GCLOUD_IMAGE`
- Pull override: `SHIMMY_GCLOUD_IMAGE_PULL=always`
- Runtime mode: TTY only when stdin and stdout are terminals
- Mounts:
  - `$PWD` to `/work`
  - `$HOME/.config/gcloud` to `/root/.config/gcloud:ro` when present
  - `$HOME/.kube/config` to `/root/.kube/config:ro` when present
- Forwarded env: `CLOUDSDK_*`
- Platform: shared Podman helper resolves `linux/amd64` on Linux and `linux/arm64` on macOS

## Change Rules

1. Preserve the optional gcloud config and kubeconfig mounts unless the task explicitly changes credential or cache behavior.
2. Keep the default image aligned with Google's documented Google Cloud CLI Docker image repository. The `:stable` tag is the preferred default because Google documents it as supporting both `linux/amd64` and `linux/arm64`.
3. Treat `CLOUDSDK_*` forwarding as the current contract; update docs and tests deliberately if it changes.
4. Prefer `gcloud info`, `gcloud version`, and `gcloud auth list` for validation and information gathering.
5. Do not run `gcloud apply` or `gcloud destroy` style operations unless the user explicitly asks for that operation and understands the consequences.
6. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
7. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Direct smoke: `./shims/gcloud --version`
- Auth smoke: `gcloud auth list` (when authenticated)
- Project smoke: `gcloud projects list` (when authenticated)

## Learning Guidance

- Capture gcloud-specific lessons here when they affect credential management, project configuration, or command behavior.
- Promote reusable Shimmy design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
