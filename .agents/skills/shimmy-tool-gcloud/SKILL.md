---
name: shimmy-tool-gcloud
description: Guidance for using, changing, testing, and troubleshooting the Google Cloud CLI shim in this repository, including configuration mounts, kubeconfig mounting, and CLOUDSDK_* environment variable forwarding.
---

# Google Cloud CLI Shim

Use this skill when working with the gcloud tool, its tests, its docs, or gcloud usage through Shimmy.

## AI Agent Evidence Order

1. If the installed wrapper's safe outer-command prefix is already approved,
   run the actual requested operation with escalation on the first attempt. Do
   not first run a sandboxed Podman call or a version smoke.
2. Treat a sandbox-only unreachable, unknown, socket-denied, or
   `operation not permitted` result as `unverified from the sandbox`, not as an
   inactive profile. Retry the same wrapper operation through
   `shimmy-escalation` before profile inspection or fallback.
3. Use `shimmy-init` only if the escalated wrapper still proves a
   profile-affinity, engine, connection, or registry-projection failure. Never
   activate a profile automatically from sandbox-only evidence.
4. Approval scope: require the exact informational or explicitly requested
   gcloud command. Do not persist a broad `gcloud` prefix because the wrapper
   mounts writable authentication state and can mutate cloud resources.

## Files

- Tool metadata: `tools/gcloud/tool.conf`
- Concrete runtime: `tools/gcloud/versions/573.0/run.sh`
- User guide: `tools/gcloud/guide.md`
- Tests: `tools/gcloud/tests/gcloud.sh`
- Repository suite: `tests/test.sh`
- README: `README.md`
- Contributor guidance: `CONTRIBUTING.md`
- Shared prompt: `docs/prompt-shimmy-project.md`

## Installed Workflow

When the installed profile is selected on `PATH`, invoke `gcloud` normally
and inspect the invoking profile with `shimmy status --format manifest`.

Before using another existing profile, resolve its absolute `profile_root` and
run `"$profile_root/bin/shimmy" profile status`, then
`"$profile_root/bin/shimmy" profile activate --dry-run`, then request approval
for the exact absolute
`"$profile_root/bin/shimmy" profile activate` command. Running containers
require separate explicit confirmation before adding `--stop-running`. A missing
machine must be provisioned by the user in a normal shell with the exact
`podman machine init shimmy-<profile>` guidance; agents never run direct Podman
machine lifecycle commands.

After activation, source `"$profile_root/shell-init.sh"` to select PATH.
Installed commands do not accept a profile selector. AI Agent calls do not
retain earlier sourcing, so invoke the absolute profile dispatcher or source
`shell-init.sh` in the same command as the tool. To test `upstream`, use the
absolute root `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream`.

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
