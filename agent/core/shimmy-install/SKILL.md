---
name: shimmy-install
description: Install, update, validate, activate, or remove Shimmy profiles. Use for Shimmy lifecycle work outside the source checkout, profile selection, disposable-install validation, or manifest-based state inspection.
---

# Shimmy Installation Lifecycle

## Source of truth

- In this repository, use `./shimmy` for lifecycle operations.
- In an installed environment, use the activated `shimmy` command.
- Inspect selected state with `shimmy status --format manifest`.
- Profile manifests are authoritative for installed tool kinds and concrete
  versions. Do not edit manifests directly when a Shimmy command supports the
  action.

## Profiles

Shimmy provides `default` and `upstream` profiles. Selection precedence is an
explicit `--profile`, then `SHIMMY_PROFILE_ACTIVE`, then `default`.

- `default` is the normal external-user profile.
- `upstream` dispatches through the recorded source checkout and is intended
  for maintainers.
- `SHIMMY_UPSTREAM_DIR` is profile state; use
  `SHIMMY_UPSTREAM_CHECKOUT_DIR` only to select a source checkout while
  installing the upstream profile.

## Lifecycle commands

```sh
./shimmy install --profile default --shim jq
./shimmy install --profile upstream --shim jq
./shimmy status --format manifest
./shimmy update --profile default --shim jq
./shimmy uninstall --profile default
```

Use `--install-dir <disposable-path>` and `--no-startup --no-skills` for
repository validation. An uninstall must name the profile explicitly.

`shimmy install --shim <kind>` installs the kind dispatcher and its default
concrete version. Use `--shim <kind>@<major.minor>` for a non-default version.

## Activation and startup

Activation prints shell code; it cannot modify the caller's shell itself.

```sh
eval "$(./shimmy activate --profile upstream)"
```

Use explicit `--shell` and `--startup-file` only when the user authorizes
startup-file changes. Managed blocks must remain idempotent.

## Podman and validation

Podman is an explicit dependency. Do not provision it. Run `podman info` only
when appropriate; if a Shimmy wrapper is sandbox-blocked despite direct Podman
access, use the exact-wrapper approval workflow before any fallback.

Validate with status, a disposable profile install, and non-mutating tool
smokes. Legacy layout-version-1 installs must be uninstalled and reinstalled;
do not migrate their manifests.
