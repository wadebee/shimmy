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

On macOS, create the deterministic default machine in a normal user shell:

```sh
podman machine init shimmy-default
```

Bootstrap starts a stopped `shimmy-default` machine. If the machine is already
running and idle, bootstrap restarts it so the initial registry policy can be
projected and validated. Running containers block that restart; stop them
explicitly, then rerun bootstrap. Bootstrap never accepts `--stop-running`.

Create `shimmy-<profile>` separately before activating any later profile.

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

The dry run lists the exact profile root, engine transition, image preparation,
active-record change, and skill collisions without mutation. On macOS, create
`shimmy-team-one` before the non-dry-run command. Never use a direct Podman
machine lifecycle command as an agent fallback.

## Remove Shimmy

Use the installed launcher:

```sh
shimmy admin uninstall
```

This removes validated Shimmy-owned installation state while preserving the
source checkout, Podman machines, unrelated registry policy, unrelated user
skills, and the user skill root. Run once without `--stop-running`; add that
acknowledgement only after reviewing any listed macOS workloads.

Earlier installation schemas are unsupported. Remove them with the Shimmy
version that created them, then run this bootstrap. There is no forwarding or
in-place migration path.
