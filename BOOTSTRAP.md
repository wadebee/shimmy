# Bootstrap Shimmy from a Checkout

Use the existing source checkout and the root `install.sh` checkout bootstrap
for first-time installation. Shimmy does not provide a downloader or a
repository-local `shimmy` launcher.

## Prerequisites

- A complete Shimmy source checkout with `install.sh`, `commands/`, `lib/`, and
  `tools/`.
- A POSIX-compatible `/bin/sh`.
- The Podman CLI and a reachable Podman engine. Shimmy treats Podman as an
  explicit dependency and does not install or start it.

On macOS, the official package may install Podman at
`/opt/podman/bin/podman`. Start the Podman machine and confirm `podman info`
from the invoking shell before bootstrapping.

## Public entrypoints

From the checkout root, source the bootstrap to install the default profile
and initialize it in the current shell:

```sh
. ./install.sh
```

Execute the same file when automation needs the installation but does not
need its parent shell initialized:

```sh
./install.sh --no-startup
```

Only the checkout bootstrap selects a profile. Maintainers can bootstrap the
`upstream` profile, which records the source checkout used by generated tool
implementations:

```sh
SHIMMY_UPSTREAM_CHECKOUT_DIR=/absolute/path/to/shimmy
export SHIMMY_UPSTREAM_CHECKOUT_DIR
. ./install.sh --profile upstream
```

Every bootstrap installs jq and rg. After initialization, add other tools with
the installed profile-local launcher:

```sh
shimmy install --shim <kind>
```

For an existing profile, select it by sourcing its generated `shell-init.sh`:

```sh
. "${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/shell-init.sh"
```

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
jq --version
rg --version
```

Each profile already contains the five-skill management plugin and the
canonical skill beside every tool. Repository and home `.agents/skills/`
adapters are separate, manifest-owned targets and are written only by an
explicit request:

```sh
shimmy skills install --target repo
shimmy skills install --target profile
```
