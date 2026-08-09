# OC multi-version shim implementation record

## Status

Implemented. The canonical current guidance is in
`tools/oc/guide.md`; this file retains the design history using the current
repository and installed-layout paths.

## Goals

- Provide one user-facing `oc <command> [args...]` kind.
- Support multiple OpenShift CLI minor tracks, initially 4.18, 4.20, and 4.22.
- Select the concrete track at runtime with a version-agnostic
  `SHIMMY_OC_VERSION` environment variable derived by external slot logic such
  as `SLOT_CONTEXT_PATH`.
- Keep version-specific image, build, smoke, and runtime behavior isolated so a
  future 5.x track does not require a new selector variable.

The early proposal used floating minor image tags. The accepted implementation
instead uses publisher-supplied multi-architecture manifest-list digests as
version-local base-image defaults, while retaining documented image and base
image overrides.

## Realized layout

```text
tools/oc/
  tool.conf
  guide.md
  agent/SKILL.md
  tests/
  versions/
    4.18/
      run.sh
      refresh.sh
      smoke.conf
      status.conf
      container/Containerfile
    4.20/
      run.sh
      refresh.sh
      smoke.conf
      status.conf
      container/Containerfile
    4.22/
      run.sh
      refresh.sh
      smoke.conf
      status.conf
      container/Containerfile
```

`tools/oc/tool.conf` records 4.20 as the default and
`SHIMMY_OC_VERSION` as the optional selector. Generic dispatch in
`commands/run-tool.sh` maps the selected label to the corresponding version
runtime. Tool-specific dispatch and image behavior do not live in management
commands or shared `lib/` modules.

## Selector behavior

Supported mappings are:

- `4.18` → `oc_4_18`
- `4.20` → `oc_4_20`
- `4.22` → `oc_4_22`

An unset or empty selector uses the metadata default, 4.20. An unsupported
selector fails with the supported values. External shell or slot logic remains
responsible for exporting `SHIMMY_OC_VERSION` before invoking `oc`.

## Concrete runtime behavior

Each version's `run.sh`:

- uses `lib/runtime/podman.sh` and `lib/runtime/image.sh`;
- builds or reuses its version-local `container/` context unless an explicit
  `SHIMMY_OC_<MAJOR>_<MINOR>_IMAGE` override is set;
- accepts the documented `SHIMMY_OC_<MAJOR>_<MINOR>_IMAGE_BUILD` and
  `SHIMMY_OC_<MAJOR>_<MINOR>_BASE_IMAGE` controls;
- mounts `$PWD` at `/work` and runs there;
- forwards `KUBECONFIG` when set without implicitly mounting `$HOME/.kube`;
- preserves shared platform selection and `--preview-shim` behavior.

Version-local `refresh.sh`, `smoke.conf`, and `status.conf` files own update,
non-mutating smoke, and status behavior. No command-level tool/version case
list is required.

## Installation, profiles, and validation

Bootstrap or extend `default` with:

```sh
./install.sh --shim oc
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/bin/shimmy" install --shim oc@4.18
./tests/test.sh --shim oc
./tests/test.sh --shim oc_4_18
```

Bootstrap and manually activate the maintainer profile with:

```sh
./install.sh --profile upstream --shim oc
eval "$("${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/bin/shimmy" activate)"
oc version
SHIMMY_OC_VERSION=4.18 oc version
```

The bootstrap is the only profile-selection surface. Each installed
profile-local `bin/shimmy` manages only its enclosing flat XDG profile. The
upstream profile is manual-activation-only; generated upstream tool
implementations use its manifest-recorded source checkout.

## Future extension

To add a track such as 5.1:

1. Add `tools/oc/versions/5.1/` with `run.sh`, `refresh.sh`, `smoke.conf`,
   `status.conf`, `CONTEXT.md`, and a local `container/` context if required.
2. Add the version to `tools/oc/tool.conf` metadata and keep
   `SHIMMY_OC_VERSION` as the selector.
3. Add focused tool tests, guide and agent-guidance updates, and context links.
4. Validate with `./tests/test.sh` and exact-approved non-mutating live smokes.
