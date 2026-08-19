# Bootstrap Shimmy from a Checkout

Use the existing source checkout and the root `bootstrap.sh` checkout bootstrap
for first-time installation. Shimmy does not provide a downloader or a
repository-local `shimmy` launcher.

## Prerequisites

- A complete Shimmy source checkout with `bootstrap.sh`, `commands/`, `lib/`, and
  `tools/`.
- A POSIX-compatible `/bin/sh`.
- The Podman CLI and a local rootless Podman engine. Shimmy treats Podman as an
  explicit dependency and does not install or provision it.

On macOS, the official package may install Podman at
`/opt/podman/bin/podman`. Before tool use, create the deterministic machines
needed by installed profiles in a normal user shell:

```sh
podman machine init shimmy-default
podman machine init shimmy-upstream
```

Shimmy does not adopt, rename, migrate, or remove `podman-machine-default`.

## Public entrypoints

From the checkout root, source the bootstrap to install the default profile
and initialize it in the current shell:

```sh
. ./bootstrap.sh
```

The initial default bootstrap requires a clean committed Git checkout. It
creates an immutable `default` catalog generation through the same staged
schema validation used by later publication and records `catalog=default`.

A fresh default bootstrap normalizes `$SHELL` to one of `bash`, `zsh`, `sh`,
`ksh`, or `mksh` (`dash` becomes `sh`) and records that shell as immutable
profile policy. Use `--shell <name>` to override detection during creation.
Managed policy resolves and records the conventional targets once: `.zshrc`
for zsh, `.profile` for POSIX-like shells, or `.bashrc` plus the active Bash
login file (`.bash_profile`, `.bash_login`, or `.profile`; `.bash_profile` is
created when none exists).

When a sourced bootstrap identifies a running Bash or Zsh that differs from the
managed startup shell, installation pauses before mutation and requires
confirmation. The warning reports both shells and explains how to align them:
run the bootstrap from the configured shell, or use `--shell` while creating a
fresh default profile to select the running shell. An existing profile must be
uninstalled and recreated to change its recorded startup shell. Executed
automation cannot initialize its parent shell and remains non-interactive.
Manual `--no-startup` and `upstream` bootstraps do not manage startup files and
therefore do not require this confirmation.

Use `--no-startup` only while creating a fresh default profile to select manual
policy. The normalized shell is still recorded, but no startup files are owned
or changed. Later unqualified checkout bootstraps inherit the recorded policy
and repair only its exact managed paths. A later `--shell` or `--no-startup`
request is rejected, even if it matches the recorded value. To choose a
different policy, uninstall and recreate the default profile.

For a fresh manual-policy profile, execute the same file when automation needs
the installation but does not need its parent shell initialized:

```sh
./bootstrap.sh --no-startup
```

Advanced users with a nonstandard startup chain can use manual policy and add
this block to their chosen startup file themselves:

```sh
shimmy_shell_init_file=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/shell-init.sh
if [ -r "$shimmy_shell_init_file" ]; then
  . "$shimmy_shell_init_file"
fi
unset shimmy_shell_init_file
```

A non-empty `XDG_CONFIG_HOME` must be absolute. This block initializes PATH
only. Bash users should place it in their own interactive or login source chain
instead of setting `BASH_ENV` globally.

Shimmy Maintainers/Repo Developers can bootstrap the `upstream` profile, which records `catalog=upstream` and binds the catalog and control plane to a live repo source checkout without changing the `default` profile:

```sh
SHIMMY_UPSTREAM_CHECKOUT_DIR=/absolute/path/to/shimmy
export SHIMMY_UPSTREAM_CHECKOUT_DIR
. ./bootstrap.sh --profile upstream
```

A different checkout cannot silently replace an existing upstream binding.
From the installed upstream profile, use `shimmy catalog rebind --checkout
<absolute-path>` for an explicit validated replacement. Complete schema-valid
catalog edits in the bound checkout are visible to upstream operations on the
next command; publishing to immutable `default` requires those changes to be
committed and the checkout to be clean.

Every bootstrap installs jq and rg. After initialization, add other tools with
the installed profile-local launcher:

```sh
shimmy install --shim <tool>
```

Installed `shimmy install` accepts only repeatable `--shim` selections and
preserves the profile's startup policy without changing startup files. Use
`shimmy update --repair-startup` to restore only the exact managed paths
recorded by the default profile.

For an existing profile, activate its engine explicitly, then select its PATH:

```sh
profile_root=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default
"$profile_root/bin/shimmy" profile status
"$profile_root/bin/shimmy" profile activate --dry-run
"$profile_root/bin/shimmy" profile activate
. "$profile_root/shell-init.sh"
```

On macOS, activation uses only `shimmy-default` or `shimmy-upstream` and
Podman permits only one managed VM to run at a time. Activation may therefore
stop another VM and interrupt its workloads; it refuses to interrupt displayed
running containers without `--stop-running`. Activation also projects the
profile's registry policy through the fixed VM-side
`/etc/containers/registries.conf.d/shimmy-profile.conf` symlink and records its
fingerprint. The profile root must be visible at the same absolute path inside
the machine. After an active redirect edit, run the exact printed `profile
activate --restart` command. Detach with `profile redirect remove --all
--detach` before uninstalling a projected profile.
On Linux it validates the current user's local rootless engine without managing
a VM. Sourcing `shell-init.sh` is PATH-only and never activates an engine.
When Skopeo is installed, it mounts only the valid current invoking profile's
registry policy read-only; `shimmy images verify` inherits that policy.
Profiles with no activation omit the mount, while mismatched, damaged, stale,
unsafe, or registry-overridden installed state fails closed.

## Implementation routing

The supported installation chain is:

```text
bootstrap.sh                     public checkout bootstrap
  -> commands/install.sh         public management entrypoint
     -> lib/install/install.sh   sourceable orchestration implementation
        -> sibling lib/install modules
```

Invoke the root bootstrap for first-time checkout installation. Afterward,
invoke `shimmy install` or the selected profile's absolute `bin/shimmy`
launcher for lifecycle changes. Do not execute or source
`lib/install/install.sh` directly; it depends on argument setup and lifecycle
cleanup supplied by the public entrypoints.

## Verify and install agent adapters

Verify the selected profile without changing external state:

```sh
shimmy status --format manifest
shimmy profile status --format manifest
jq --version
rg --version
```

Canonical management and tool skills remain in the profile's named catalog;
they are not copied into the profile. Repository and home `.agents/skills/`
adapters are separate, manifest-owned targets and are written only by an
explicit request. A default selection exports the core management skills plus
skills for tools installed in the invoking profile:

```sh
shimmy skills install --target repo
shimmy skills install --target profile
shimmy skills update --target repo
shimmy skills update --target profile
```

Shimmy stages and validates the complete output before changing either target.
Profile or catalog removal does not remove an existing export; its target
manifest remains authoritative for standalone `shimmy skills uninstall`.
Use explicit `skills update` after accepting canonical changes in a newer
catalog; profile lifecycle commands never refresh generated adapters.

## Catalog recovery and removal

Inspect catalog identity, provenance, schema, fingerprint, and health with:

```sh
shimmy status --format manifest
```

From the upstream profile, `shimmy catalog publish` advances immutable
`default`, `shimmy catalog rollback` restores its retained prior valid
generation, and `shimmy catalog rebind --checkout <absolute-path>` recovers a
missing or moved live checkout. Invalid or unsupported catalog schema blocks
catalog-dependent mutation but does not stop already-materialized tools.

`shimmy uninstall` removes only its enclosing profile. Use `shimmy uninstall
--global` only when every owned profile and shared catalog should be removed.
Global uninstall preserves source checkouts and independently manifest-owned
repository or home skill exports.
