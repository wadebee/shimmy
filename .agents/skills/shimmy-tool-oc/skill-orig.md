---
name: shimmy-tool-oc
description: Guidance for using, changing, testing, and troubleshooting the OpenShift CLI (oc) kind dispatcher and concrete version shims in this repository, including default 4.20 dispatch, SHIMMY_OC_VERSION selection, per-track local-build images, and KUBECONFIG forwarding.
---

# OpenShift CLI (oc) Kind Shim

Use this skill when working with `shims/oc`, the versioned `oc_4_xx` shims, their tests, docs, or oc usage through Shimmy.

## Files

- Dispatcher shim: `../../../shims/oc`
- Versioned shims: `../../../shims/oc_4_18`, `../../../shims/oc_4_20`, `../../../shims/oc_4_22`
- Shim configs: `../../../shims/oc.conf`, `../../../shims/oc_4_18.conf`, `../../../shims/oc_4_20.conf`, `../../../shims/oc_4_22.conf`
- Image build contexts: `../../../images/oc_4_18`, `../../../images/oc_4_20`, `../../../images/oc_4_22`
- User docs: `../../../docs/shims/oc.md`
- Tests: `../../../scripts/test-shimmy.sh`
- Installer: `../../../scripts/install-shimmy.sh`
- Status and update: `../../../scripts/status-shimmy.sh`, `../../../scripts/update-shimmy.sh`
- README: `../../../README.md`
- Contributor guidance: `../../../CONTRIBUTING.md`
- Shared prompt: `../../../docs/prompt-shimmy-project.md`

## Installed Workflow

When this skill is installed outside the Shimmy source checkout, do not rely on the repo-relative `Files` paths above. Prefer activated commands such as `oc version`, inspect selected profile state with `shimmy status --format manifest`, and use `SHIMMY_PROFILE_ACTIVE=upstream oc version` when validating the upstream profile. Use repo-local paths such as `./shims/oc_4_20` only when intentionally editing or testing source files in the Shimmy checkout.

## Current Behavior

- Dispatcher command: `oc`
  - Reads optional `SHIMMY_OC_VERSION` (`major.minor` such as `4.18`, `4.20`, `4.22`).
  - Uses default `4.20` and execs `oc_4_20` when `SHIMMY_OC_VERSION` is unset.
  - Maps `4.18` → `oc_4_18`, `4.20` → `oc_4_20`, `4.22` → `oc_4_22`.
  - Prints a clear error when `SHIMMY_OC_VERSION` is unsupported, including available values and the default.
  - Has `shims/oc.conf` with `smoke_env=SHIMMY_OC_VERSION=4.20` and preview smoke args.
- Versioned shims (per-track local-build images):
  - `oc_4_18`: builds a local image from `images/oc_4_18/Containerfile` using `shimmy_local_image_ensure`, with optional `SHIMMY_OC_4_18_IMAGE` override, `SHIMMY_OC_4_18_IMAGE_BUILD` (`auto`/`always`), and `SHIMMY_OC_4_18_BASE_IMAGE` build arg.
  - `oc_4_20`: builds from `images/oc_4_20/Containerfile`, optional `SHIMMY_OC_4_20_IMAGE` override, `SHIMMY_OC_4_20_IMAGE_BUILD`, and `SHIMMY_OC_4_20_BASE_IMAGE`.
  - `oc_4_22`: builds from `images/oc_4_22/Containerfile`, optional `SHIMMY_OC_4_22_IMAGE` override, `SHIMMY_OC_4_22_IMAGE_BUILD`, and `SHIMMY_OC_4_22_BASE_IMAGE`.
- Runtime mode:
  - Uses Shimmy's shared Podman helper for platform selection and `--preview-shim` support.
  - Mounts `$PWD` to `/work` and uses `-w /work`.
  - Adds `-it` only when stdin and stdout are terminals.
  - Forwards `KUBECONFIG` into the container when set.

## Change Rules

1. Preserve the `SHIMMY_OC_VERSION` selector contract; do not change the variable name when adding new tracks.
2. Keep per-track image env vars (`SHIMMY_OC_4_xx_IMAGE`, `SHIMMY_OC_4_xx_IMAGE_BUILD`, `SHIMMY_OC_4_xx_BASE_IMAGE`) and local-build behavior aligned between shims, docs, status, and update scripts.
3. Avoid adding implicit kubeconfig mounts beyond `KUBECONFIG` forwarding unless the task explicitly calls for them.
4. When extending to new tracks (for example, `5.1`), add a new `oc_5_1` shim, `.conf`, image build context, dispatcher mapping, catalog kind/version entry, status description, update `--build` behavior, docs, tests, and README coverage together.
5. If a Shimmy wrapper fails because of Podman reachability, sandboxing, or AI Agent approval symptoms, follow the `shimmy-escalation` workflow before using a non-shim fallback.
6. Update the runtime shims, docs, tests, installer behavior, status/update scripts, README, skill manifest, and executable bits together when behavior changes.

## Validation

- Direct smoke for versioned shims:
  - `./shims/oc_4_20 version`
  - `./shims/oc_4_18 version`
  - `./shims/oc_4_22 version`
- Dispatcher smoke (from an activated profile):
  - `oc version`
  - `SHIMMY_OC_VERSION=4.18 oc version`
- Preview mode (no Podman engine contact):
  - `./shims/oc --preview-shim version`
  - `SHIMMY_OC_VERSION=4.18 ./shims/oc --preview-shim version`
- Shimmy tests:
  - Install default: `./shimmy install --shim oc && ./shimmy test --shim oc`
  - Install selector: `./shimmy install --shim oc@4.18`
  - Source suite: `./scripts/test-shimmy.sh`

## Learning Guidance

- Capture oc-specific lessons here when they affect version dispatch, image selection, or KUBECONFIG usage.
- Promote reusable kind/version design lessons to `../shimmy-create-tool/SKILL.md` under `Learning Guidance`.
- Preserve the explicit local-build image strategy unless a task calls for a strategy change; do not silently replace it with a remote-image default.
- Dispatcher smoke belongs in `shims/oc.conf` with `smoke_env=SHIMMY_OC_VERSION=4.20` and preview args, while versioned shims keep direct `version` smoke commands.
