# Bootstrap Shimmy from a Checkout

Use the existing source checkout and the root `install.sh` checkout bootstrap
for first-time installation. Shimmy does not provide a downloader or a
repository-local `shimmy` launcher.

## Prerequisites

- A complete Shimmy source checkout with `install.sh`, `commands/`, `lib/`, and
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
. ./install.sh
```

The initial default bootstrap requires a clean committed Git checkout. It
creates an immutable `default` catalog generation through the same staged
schema validation used by later publication, records `catalog=default`, and
does not create or change an upstream profile.

An unqualified default bootstrap installs a managed startup block in `.zshrc`,
`.bashrc`, and the active Bash login file (`.bash_profile`, `.bash_login`, or
`.profile`; `.bash_profile` is created when none exists). This covers zsh plus
login and non-login interactive Bash sessions. Use `--shell`, repeatable
`--startup-file`, or `--no-startup` to request narrower behavior.

Execute the same file when automation needs the installation but does not
need its parent shell initialized:

```sh
./install.sh --no-startup
```

Only the checkout bootstrap selects a profile. Maintainers can bootstrap the
`upstream` profile, which records `catalog=upstream` and binds that catalog to
the live source checkout without creating or changing `default`:

```sh
SHIMMY_UPSTREAM_CHECKOUT_DIR=/absolute/path/to/shimmy
export SHIMMY_UPSTREAM_CHECKOUT_DIR
. ./install.sh --profile upstream
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
install.sh                       public checkout bootstrap
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
