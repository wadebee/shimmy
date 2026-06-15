## OC multi-version shim (dispatcher + versioned shims)

### Goals

- Provide a single user-facing command: `oc <command> [args...]`.
- Support multiple OpenShift CLI minor tracks (initially 4.18, 4.20, 4.22).
- For each track, use a floating minor tag (for example, `:4.20`) so that Podman pulls
  the latest patch of that minor during `shimmy install` and `shimmy update`.
- Select the active minor version **at runtime** based on an environment variable
  derived from `SLOT_CONTEXT_PATH` or similar slot metadata.
- Keep the design future-proof so that a 5.x series can be added without changing
  env var names.

### High-level approach

Implement:

- A dispatcher shim named `oc`.
- Version-specific shims named `oc_4_18`, `oc_4_20`, `oc_4_22` (and potentially
  future `oc_5_1`, etc.).
- Per-version image configuration via env vars, following existing patterns (for
  example, `SHIMMY_AWS_IMAGE`, `SHIMMY_AWS_IMAGE_PULL`).

Shell startup logic outside Shimmy is responsible for deriving the desired OpenShift
CLI version from context (for example, `SLOT_CONTEXT_PATH`) and exporting a single
version selector env var. 

Your external slot logic (e.g., using SLOT_CONTEXT_PATH) just needs to set SHIMMY_OC_VERSION to the desired major.minor before running oc.

Shimmy then uses that selector to dispatch `oc` to the
appropriate minor-specific shim.

### Version selector environment variable

- Use a **version-agnostic** env var so it continues to work for 5.x and beyond:

  - `SHIMMY_OC_VERSION` — value is a `major.minor` identifier as a string.

- Examples of valid values:

  - `SHIMMY_OC_VERSION=4.18`
  - `SHIMMY_OC_VERSION=4.20`
  - `SHIMMY_OC_VERSION=4.22`
  - Future: `SHIMMY_OC_VERSION=5.1`

- Shell init / slot logic (outside Shimmy) is responsible for:

  - Parsing `SLOT_CONTEXT_PATH` or equivalent runtime context.
  - Choosing the appropriate OpenShift CLI track.
  - Exporting `SHIMMY_OC_VERSION` before any `oc` invocation.

### Dispatcher shim: `shims/oc`

Create `shims/oc` as a small POSIX shell script following existing shim patterns
(`#!/bin/sh`, `set -eu`). This shim acts purely as a dispatcher and does not invoke
Podman directly.

Responsibilities:

- Read environment state:

  - `SHIMMY_OC_VERSION` — required selector.

- Resolve a **shim name** from the version selector:

  - For known 4.x tracks:
    - `4.18` → `oc_4_18`
    - `4.20` → `oc_4_20`
    - `4.22` → `oc_4_22`
  - Future pattern for 5.x:
    - `5.1` → `oc_5_1`

- Behavior when `SHIMMY_OC_VERSION` is missing or unsupported:

  - If unset or empty, print a clear error to stderr explaining that
    `SHIMMY_OC_VERSION` must be set (for example, `4.20`) and exit non-zero.
  - If set to an unsupported value (for example, `4.17`), print a clear error
    listing known values and exit non-zero.

- Dispatch logic:

  - Compute `SCRIPT_DIR` as in existing shims.
  - Use a `case` or similar to map `SHIMMY_OC_VERSION` to a local shim path.
  - `exec "$SCRIPT_DIR/oc_4_20" "$@"` (or matching minor) so that process
    replacement occurs and the underlying shim handles container execution.

The dispatcher does **not** directly call Podman or know about specific images; that
detail lives in the minor-version shims.

### Version-specific shims: `shims/oc_4_18`, `shims/oc_4_20`, `shims/oc_4_22`

For each supported minor track, create a dedicated shim using the same shape as
`shims/aws` and `shims/terraform`:

- File names:
  - `shims/oc_4_18`
  - `shims/oc_4_20`
  - `shims/oc_4_22`

- Default images (floating minor tags):

  - `SHIMMY_OC_4_18_IMAGE=${SHIMMY_OC_4_18_IMAGE:-docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.18}`
  - `SHIMMY_OC_4_20_IMAGE=${SHIMMY_OC_4_20_IMAGE:-docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.20}`
  - `SHIMMY_OC_4_22_IMAGE=${SHIMMY_OC_4_22_IMAGE:-docker-redhat-proxy.northgrum.com/openshift4/ose-cli:4.22}`

  These tags are expected to float to the latest patch in each minor line.

- Pull policy env vars (per minor):

  - `SHIMMY_OC_4_18_IMAGE_PULL` (empty or `always`)
  - `SHIMMY_OC_4_20_IMAGE_PULL`
  - `SHIMMY_OC_4_22_IMAGE_PULL`

  When set to `always`, pass the corresponding `--pull=always` flag to Podman in
  the minor shim. When empty, rely on Podman defaults.

- Podman invocation pattern:

  - Use `lib/shims/shimmy-podman.sh` (`shimmy_podman_preflight_or_preview_require`,
    `shimmy_podman_run_or_preview`) as in existing shims.
  - Mount `$PWD` to `/work` and set `-w /work`.
  - Optionally mount kube/OpenShift config directories if agreed (for example,
    `$HOME/.kube` → `/root/.kube:ro`) following the same pattern as the AWS shim
    uses for `$HOME/.aws`.
  - Run the container entrypoint/command such that invoking `oc_4_20` behaves like
    `oc` inside the container (for example, the image’s entrypoint is `oc`).

- CLI surface:

  - Each minor shim is a transparent pass-through to the containerized `oc`:
    - `oc_4_20 <command> [args...]` → `oc <command> [args...]` inside the `:4.20`
      image.
  - The dispatcher reuses this behavior for the user-facing `oc` command.

### Shim configuration files for tests

For each minor shim, create a `.conf` file modeled on `aws.conf` and
`terraform.conf` so that `shimmy test` can run non-mutating smoke commands:

- `shims/oc_4_18.conf`
  - `shim_config_version=1`
  - `shim_name=oc_4_18`
  - `smoke_arg=version` (or `version --client` if that is safer)

- `shims/oc_4_20.conf`
  - `shim_config_version=1`
  - `shim_name=oc_4_20`
  - `smoke_arg=version`

- `shims/oc_4_22.conf`
  - Same pattern as above.

This lets `shimmy test --shim oc_4_20` (or `--all`) verify that the container starts
and the CLI is responsive without mutating cluster state.

### Install and profile wiring

- Ensure the new shims are discoverable by the existing shim-install logic (for
  example, via manifest-based discovery or shim directory scanning, depending on
  current implementation).
- Expect usage patterns such as:

  - `shimmy install --shim oc_4_20`
  - `shimmy test --shim oc_4_20`

- Upstream profile:

  - When installed with `--profile upstream`, the dispatcher `oc` and the
    version-specific shims should behave like other upstream shims: invoking `oc`
    runs through the installed dispatcher, which then `exec`s the
    upstream-checked-out `oc_4_20`/`oc_4_18`/`oc_4_22` scripts.

### Future extension to 5.x and beyond

- To add a new major/minor track (for example, 5.1):

  - Add `shims/oc_5_1` using the same pattern with a default image, e.g.
    `SHIMMY_OC_5_1_IMAGE=${SHIMMY_OC_5_1_IMAGE:-docker-redhat-proxy.northgrum.com/openshift5/ose-cli:5.1}`
    (adjust registry path as needed).
  - Add `shims/oc_5_1.conf` with `shim_name=oc_5_1`.
  - Extend the `oc` dispatcher to map `SHIMMY_OC_VERSION=5.1` to `oc_5_1`.

- No changes to the version selector env var name are required; the dispatcher
  logic and the set of minor-version shims encode the supported tracks.

# Profile integration
- **Determine integration steps**: Identify how Shimmy integrates with your shell profile for runtime usage.
- **Assume** you want to see or set up Shimmy's shell profile integration for runtime use.

- **Profile Script**: [lib/repo/shimmy-profile.sh] exists—likely contains shell profile logic.
- **Profile Management**: According to [README.md] Shimmy supports two main profiles:
  - `default`: Normal user profile.
  - `upstream`: Maintainer/dev profile (runs from source checkout).
- **Profile Selection**:
  - Use `SHIMMY_PROFILE_ACTIVE=default|upstream` to set the active profile.
  - Or use `./shimmy install --profile default|upstream` to install a profile.
  - Shell integration is managed via startup files (`~/.bashrc`, `~/.zshrc`, etc.).
- **Activation**: Use `eval "$(./shimmy activate --profile upstream)"` to activate a profile in your shell.

You’re asking for a new Shimmy shim ose_cli_4_20 that wraps the upstream image docker-redhat-proxy.northgrum.com/openshift4/ose-cli, pinned to the latest 4.20.x tag, wired into the upstream profile.
