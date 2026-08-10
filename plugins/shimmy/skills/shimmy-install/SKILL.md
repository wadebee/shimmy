---
name: shimmy-install
description: Install, update, validate, initialize shells for, or remove Shimmy profiles. Use for Shimmy lifecycle work, bootstrap-time profile selection, disposable XDG installation validation, external startup or skills integration, and manifest-based state inspection.
---

# Shimmy Installation Lifecycle

## Source of truth

- For first-time checkout installation, read `BOOTSTRAP.md`, use the public
  `./install.sh` checkout bootstrap, and use `./tests/test.sh` for repository
  validation. There is no repository `shimmy` launcher.
- In an installed environment, use the desired profile's absolute
  `bin/shimmy` launcher or its `shimmy` command after sourcing `shell-init.sh`.
- Inspect the invoking profile with `shimmy status --format manifest`.
- Profile manifests are authoritative for installed tool kinds and concrete
  versions. Do not edit manifests directly when a Shimmy command supports the
  action.

## Profiles

Shimmy provides independent `default` and `upstream` profiles below
`${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`. Require
`XDG_CONFIG_HOME` to be absolute when it is non-empty.

- `default` is the normal external-user profile.
- `upstream` is intended for maintainers; only its generated tool
  implementations execute the recorded source checkout.
- Only `./install.sh` accepts `--profile default|upstream`. An installed
  launcher manages only its enclosing profile and rejects profile selection.
- Use `SHIMMY_UPSTREAM_CHECKOUT_DIR` only to select the absolute checkout
  recorded while bootstrapping `upstream`; it never relocates installed state.

## Lifecycle commands

```sh
. ./install.sh
SHIMMY_UPSTREAM_CHECKOUT_DIR=/absolute/checkout
export SHIMMY_UPSTREAM_CHECKOUT_DIR
. ./install.sh --profile upstream
shimmy install --shim task
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/bin/shimmy" status --format manifest
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/bin/shimmy" update --shim jq
"${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/bin/shimmy" uninstall
```

For disposable validation, set an absolute temporary `XDG_CONFIG_HOME` and use
`--no-startup`. Do not add an installation-directory override.

Every repository bootstrap includes jq and rg. Add any other kind afterward
through the installed `shimmy install --shim <kind>` command; it installs the
kind dispatcher and its default concrete version. Use `--shim
<kind>@<major.minor>` for a non-default version.

## Shell initialization and startup

Sourcing the repository bootstrap installs the profile and sources its
generated `shell-init.sh` in the caller. Executing it performs the same install
for automation, but initialization ends with that process.

```sh
. "${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/shell-init.sh"
```

Switch profiles by sourcing the desired profile's absolute `shell-init.sh`.
Only `default` may manage a persistent startup block. Use explicit `--shell`
and `--startup-file` only when the user authorizes default-profile startup
changes; `upstream` never changes shell startup files.

## Shared skills

The canonical five-skill management plugin and co-located tool skills are
included unconditionally in every profile payload. Install or update agent
skill adapters in a repository or home agent profile only when the user
explicitly selects that target through standalone `shimmy skills` commands.
The target's `.shimmy-skills-manifest.txt` owns those entries; no profile manifest owns the
target. Profile install, update, and uninstall never implicitly refresh or
remove it. Remove target-owned shared skills only with:

```sh
shimmy skills uninstall --target <repo|profile>
```

## Podman and validation

Podman is an explicit dependency. Do not provision it. Run `podman info` only
when appropriate; if a Shimmy wrapper is sandbox-blocked despite direct Podman
access, use the exact-wrapper approval workflow before any fallback.

Validate with status, an XDG-isolated disposable profile install, and
non-mutating tool smokes. Earlier layouts must be removed with the Shimmy
version that created them and reinstalled; do not migrate their manifests.
