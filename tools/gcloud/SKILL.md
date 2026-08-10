---
name: shimmy-tool-gcloud
description: Guidance for using, changing, testing, and troubleshooting the Google Cloud CLI shim in this repository, including configuration mounts, kubeconfig mounting, and CLOUDSDK_* environment variable forwarding.
---

# Google Cloud CLI Shim

Use this skill when working with the gcloud tool, its tests, its docs, or gcloud usage through Shimmy.

## Files

- Kind metadata: `tools/gcloud/tool.conf`
- Concrete runtime: `tools/gcloud/versions/573.0/run.sh`
- User guide: `tools/gcloud/guide.md`
- Tests: `tools/gcloud/tests/gcloud.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `gcloud` normally
and inspect the invoking profile with `shimmy status --format manifest`. Select an
existing profile by sourcing its generated `shell-init.sh`; installed commands do
not accept a profile selector. To test `upstream`, source
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh`.

For source validation, use `./commands/run-tool.sh gcloud --preview-shim --version`
or the concrete `tools/gcloud/versions/573.0/run.sh` runtime. Do not use
removed repository `shims/` paths.

## Current Behavior

- Default image: `gcr.io/google.com/cloudsdktool/google-cloud-cli@sha256:f5fae73a6f1c60b58a1150ff76771a43620891d4dd74abc527c8eca0d544b385` from version-owned `image.conf`
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
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64` from host OS and CPU

## Change Rules

1. Preserve the provided writable gcloud config directory and optional read-only kubeconfig mount unless the task explicitly changes credential or cache behavior.
2. Do not create kubeconfig paths, credentials, or Google Cloud CLI config files automatically.
3. Keep `--shimmy-config-help` non-mutating; normal gcloud execution creates host `CLOUDSDK_CONFIG` when set, otherwise `~/.config/gcloud` when `HOME` is set.
4. Keep the container running as `cloudsdk` with `CLOUDSDK_CONFIG=/home/cloudsdk/.config/gcloud` unless a future image removes that user or changes its home.
5. Keep the upstream tag and immutable multi-platform default in `image.conf` aligned with Google's documented Google Cloud CLI image repository.
6. Treat `CLOUDSDK_*` forwarding as the current contract; update docs and tests deliberately if it changes. Host `CLOUDSDK_CONFIG` should select the host mount source, and Shimmy's explicit container `CLOUDSDK_CONFIG` value should point to that mounted directory.
7. Prefer `gcloud info`, `gcloud version`, and `gcloud auth list` for validation and information gathering.
8. Do not run `gcloud apply` or `gcloud destroy` style operations unless the user explicitly asks for that operation and understands the consequences.
9. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
10. Update the runtime shim, docs, tests, installer behavior, and README together when behavior changes.

## Validation

- Config help smoke: `./commands/run-tool.sh gcloud --shimmy-config-help`
- Direct smoke: `./commands/run-tool.sh gcloud --version`
- Auth smoke: `gcloud auth list` (when authenticated)
- Project smoke: `gcloud projects list` (when authenticated)

## Learning Guidance

- Capture gcloud-specific lessons here when they affect credential management, project configuration, or command behavior.
- Promote reusable Shimmy design lessons to the `shimmy-create-tool` skill under `Learning Guidance`.
