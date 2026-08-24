# Bootstrap Shimmy

Shimmy has one checkout bootstrap: `./bootstrap.sh`. The repository does not
contain an installed `shimmy` launcher and does not copy generated agent-skill
adapters into `.agents/skills`.

> **Overwrite warning:** initial activation unconditionally replaces every
> exact user-skill destination declared by the new profile's bundles. It creates
> no backup and provides no recovery for overwritten foreign content. It never
> recursively deletes `$HOME/.agents/skills` or unrelated skill names.

## First contact without a checkout

If Codex does not yet have this repository, ask it to use `$skill-installer` to
install the canonical lifecycle skill from:

```text
https://github.com/wadebee/shimmy/tree/main/plugins/shimmy/skills/shimmy-install
```

Restart Codex so the skill is discovered, then ask it to follow
`shimmy-install` for first-time setup. The skill directs the agent to create or
use a source checkout, read this file, and invoke the checkout bootstrap. It
does not make a repository-local adapter tree authoritative.

## Prerequisites

- a complete Shimmy checkout;
- POSIX-compatible `/bin/sh`;
- Git;
- Podman CLI and a reachable local rootless engine.

Shimmy treats Podman as an explicit dependency. It does not install Podman or
provision, adopt, rename, migrate, or remove machines. The macOS package may
place the CLI at `/opt/podman/bin/podman`.

On macOS, bootstrap requires the exact Podman machine and connection name
`shimmy` to be absent. It initializes that shared machine without provider
overrides, `--now`, or post-5.8 connection-update flags, preserves the prior
default connection, starts `shimmy`, records host and guest ownership evidence,
installs its stable user registry drop-in, and activates the default profile
policy. A same-name machine or connection is a pre-mutation collision; Shimmy
never adopts it. Do not create a machine manually before fresh bootstrap.

On Linux, bootstrap validates the current local rootless Podman service and
publishes it as a shared host-local engine. It performs no machine operation.

## Install the default profile

The checkout must be clean, committed, on attached local branch `main`, and
have `HEAD` equal to `refs/heads/main`.

Source the bootstrap to install, activate, and select the default profile in
the current shell:

```sh
. ./bootstrap.sh
```

For automation that does not need to change its parent shell:

```sh
./bootstrap.sh --no-startup
```

Supported options are:

- `--shell <bash|zsh|sh|ksh|mksh>` — record the managed startup shell;
- `--no-startup` — record manual startup policy and own no startup files;
- `-h`, `--help` — show help without validating or changing installation state.

The bootstrap creates `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy`. A non-empty
`XDG_CONFIG_HOME` must be normalized and absolute. The entire config root must
not already exist; bootstrap fails instead of merging, migrating, or adopting
partial state.

The initial profile contains jq, rg, and Skopeo. It also creates the immutable
first `default` catalog generation, materializes the control and tool skill
bundles, activates engine/registry authority, writes the active-profile record,
reconciles exact user-skill links, and applies the selected startup policy as
one compensated lifecycle. A failure removes new installation state and
restores every recoverable external change.

Machine initialization records durable intent before invoking Podman and gains
automatic deletion authority only after committing the exact created identity.
If identity remains ambiguous or exact machine removal fails, bootstrap reports
incomplete rollback and retains the configuration root and
`engines/shared/lifecycle.conf`. That retained root deliberately blocks another
fresh bootstrap. Do not remove or adopt a machine by name; inspect the reported
recovery state before any separate remediation.

## Startup policy

With managed startup policy, Shimmy records the conventional paths for the
selected shell once and owns only its exact marked blocks. With manual policy,
source the generated file from your preferred startup chain:

```sh
shimmy_shell_init_file=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/shell-init.sh
if [ -r "$shimmy_shell_init_file" ]; then
  . "$shimmy_shell_init_file"
fi
unset shimmy_shell_init_file
```

`shell-init.sh` selects PATH only. It never starts or stops Podman and never
sets a connection variable. AI-agent tool calls do not retain sourcing across
separate calls; use an absolute profile launcher or source and invoke within the
same shell command.

Repair recorded startup blocks with:

```sh
shimmy profile repair-startup
```

## Verify

```sh
shimmy admin status --format manifest
shimmy admin engine status --format manifest
shimmy profile status --format manifest
shimmy shim list --format manifest
jq --version
rg --version
```

For AI agents, a sandbox-only Podman error proves only that engine access is
unverified from the sandbox. Retry the actual safe wrapper command through the
approval boundary before diagnosing profile activation. Status, activation
dry-run, activation, and any later `--stop-running` acknowledgement remain
separate decisions.

## Create another profile

Creation is an explicit installed operation and automatically activates the
new profile:

```sh
shimmy profile create team-one --dry-run
shimmy profile create team-one
```

The dry run lists the exact profile root, shared-engine transition, registry
service action, image preparation, active-record change, and skill collisions
without mutation. Ordinary creation binds the new profile to the existing
shared engine and never calls `podman machine init`.

## Remove Shimmy

Use the installed launcher:

```sh
shimmy admin uninstall --dry-run
shimmy admin uninstall
```

This removes validated Shimmy-owned installation state and every macOS Podman
machine whose complete current ownership evidence matches. Removing an owned
machine permanently destroys its containers, images, volumes, build caches,
and all other VM-local data; none is preserved. The source checkout, Linux
host-local engine, legacy, external, and ambiguous machines, unrelated registry
policy, unrelated user skills, and the user skill root remain untouched.

Run `--dry-run` first. Add `--stop-running` only after reviewing and explicitly
accepting deletion of listed running containers. Machine removal is journaled
before the first stop. A partial failure retains the installation and prints
completed and pending engines plus the exact retry command; a replacement at a
previously removed name is treated as a collision.

For an existing schema-2 installation, first update its installed controls,
then inspect and explicitly migrate the engine registry:

```sh
shimmy admin engine status
shimmy admin engine migrate --dry-run
shimmy admin engine migrate
```

On macOS, migration preserves each existing `shimmy-<profile>` machine as an
external legacy-isolated engine and creates `shimmy` for future shared profiles.
It does not rename, claim, start, stop, or remove the legacy machines.
