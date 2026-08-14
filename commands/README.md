# Shimmy commands

The profile-local `shimmy` launcher manages the profile that contains it. It
does not accept a profile selector; switch profiles by sourcing the desired
profile's `shell-init.sh`.

Repository entrypoints in this directory implement the installed management
commands and orchestrate shared behavior from `../lib/`. The root `install.sh`
is the bootstrap entrypoint for creating a profile.

## Table of contents

- [`images`](#images) — verify remote image indexes and upstream drift
- [`catalog`](#catalog) — publish, roll back, or rebind shared catalogs
- [`install`](#install) — add tool shims to the current profile
- [`uninstall`](#uninstall) — remove one profile or all owned Shimmy state
- [`netinfo`](#netinfo) — show host, VM, and container network perspectives
- [`skills`](#skills) — manage or export Shimmy agent skills
- [`status`](#status) — inspect the current profile and its tool catalog
- [`test`](#test) — run non-mutating profile and shim smoke tests
- [`update`](#update) — refresh the current profile and its tool images

Run `shimmy <command> --help` for the command's authoritative usage text.

## `catalog`

Manage the fixed shared named catalogs from the installed upstream profile.

```text
shimmy catalog publish
shimmy catalog rollback
shimmy catalog rebind --checkout <absolute-path>
```

`publish` stages and validates tracked content from the clean committed
upstream `HEAD`, then atomically advances the immutable default generation.
`rollback` atomically restores the retained prior valid default generation,
including recovery when the current generation is invalid. `rebind` validates
and atomically replaces only the live upstream checkout path; it does not
modify either checkout. None of these operations changes an installed
profile's recorded tool versions.

## `images`

Verify that configured image defaults resolve to valid multi-platform remote
indexes and report whether their upstream tags have moved. Verification does
not pull target image layers.

```text
shimmy images verify [--all | --shim <tool[@version]> ...]
                     [--public-only] [--require-current-upstream]
                     [--format human|manifest]
```

Options:

- `--all` verifies every catalog version. It cannot be combined with `--shim`.
- `--shim <tool[@version]>` verifies a tool or concrete version. Repeat the
  option to select multiple entries.
- `--public-only` visibly skips entries that require registry authentication.
- `--require-current-upstream` treats upstream-tag drift as a failure instead
  of a warning.
- `--format human|manifest` selects human-readable output or one
  pipe-delimited record per configured runtime or base. The default is
  `human`.
- `-h`, `--help` shows command help.

Installed use defaults to concrete versions recorded in the current profile.
Direct source-checkout use requires `--all` or at least one `--shim`.
Authenticated verification uses the Skopeo runtime's configured
`SHIMMY_SKOPEO_AUTH_SECRET`.

Examples:

```sh
shimmy images verify
shimmy images verify --shim terraform --shim aws@2.31
shimmy images verify --all --public-only
shimmy images verify --require-current-upstream --format manifest
```

Manifest records have this form:

```text
image_verify=<tool>|<version>|<role>|<digest>|<media-type>|<platform-result>|<access-result>|<drift-result>|<result>|<error>
```

The result is `pass`, `warning`, `skip`, or `fail`. Upstream movement is a
warning unless strict drift checking is enabled; an authenticated entry
omitted by `--public-only` is `skip`, never `pass`.

## `install`

Add one or more tools to the current profile. Installing a tool also
installs its catalog-default concrete version; use `tool@version` to request a
different available version as well.

```text
shimmy install --shim <tool[@version]> [--shim <tool[@version]> ...]
               [--shell <name>] [--startup-file <path> ...] [--no-startup]
```

Options:

- `--shim <tool[@version]>` selects a tool to install and is required. Repeat
  it to install multiple tools.
- `--shell <name>` overrides shell detection when updating startup files.
- `--startup-file <path>` selects a startup file to update. Repeat it to
  select multiple files.
- `--no-startup` skips persistent startup-file updates.
- `-h`, `--help` shows command help.

The `upstream` profile never modifies persistent startup files. Source its
generated `shell-init.sh` to activate it in the current shell.

Examples:

```sh
shimmy install --shim task
shimmy install --shim aws --shim terraform
shimmy install --shim oc@4.20 --no-startup
```

## `uninstall`

Remove the current profile and its managed startup integration. Without
`--global`, this command operates only on the profile containing the invoked
launcher and preserves sibling profiles and shared catalogs.

```text
shimmy uninstall [--global] [--shell <name>] [--startup-file <path> ...]
```

Options:

- `--global` removes every valid manifest-owned profile and registry-owned
  shared catalog. It preserves source checkouts and external skill exports and
  refuses unrecognized shared state.
- `--shell <name>` overrides shell detection for startup cleanup.
- `--startup-file <path>` selects a startup file from which managed integration
  is removed. Repeat it to select multiple files.
- `-h`, `--help` shows lifecycle command help.

Examples:

```sh
shimmy uninstall
shimmy uninstall --startup-file "$HOME/.zshrc"
```

## `netinfo`

Report network information from the current shell's perspective, including
host, VM, container, interface, route, and LAN observations. Explicit host
inputs are useful when the shell runs inside a VM or container and cannot infer
the physical host network.

```text
shimmy netinfo [options]
```

Options:

- `--target <host-or-ip>` adds an IPv4 route-perspective target. Repeat it for
  multiple targets. The default is `1.1.1.1`.
- `--host-name <name>` resolves a host-side DHCP or DNS name with the system
  resolver.
- `--host-ip <ipv4>` supplies the host-side IPv4 address.
- `--host-prefix <bits>` combines with `--host-ip` or `--host-name` to derive
  the host LAN CIDR.
- `--host-lan <cidr>` supplies the host-side LAN CIDR directly.
- `--format human|manifest` selects the output format. The default is `human`.
- `-h`, `--help` shows command help.

Examples:

```sh
shimmy netinfo
shimmy netinfo --target 8.8.8.8 --target 192.168.1.1
shimmy netinfo --host-name workstation.home.arpa --host-prefix 24
shimmy netinfo --host-ip 192.168.1.20 --host-lan 192.168.1.0/24 --format manifest
```

## `skills`

Install, update, uninstall, or export Shimmy agent skills. With no explicit
skill names, installation selects the core management skills plus tool skills
for tools in the invoking profile manifest. Canonical sources resolve from
that profile's validated named catalog, not from the profile payload. Updates
prefer the skills already tracked by the target's skills manifest. Install,
update, and export stage and validate complete output before changing the
destination.

```text
shimmy skills install [options] [skill...]
shimmy skills update [options] [skill...]
shimmy skills uninstall [options]
```

Options:

- `--target repo` writes compatibility adapters to `.agents/skills` in the
  current directory.
- `--target profile` writes compatibility adapters to `~/.agents/skills`.
- `--export <path>` exports a portable skills directory, or a `.zip` archive
  when the destination ends in `.zip`. It is not supported with `uninstall`.
- `--manifest <path>` uses installed tools from the specified profile manifest
  when present.
- `-h`, `--help` shows command help.

Uninstall removes only skills recorded in the selected target's
`.shimmy-skills-manifest.txt`; it does not accept individual skill names and
does not require the source catalog to remain available.

Examples:

```sh
shimmy skills install --target repo
shimmy skills install --target profile shimmy-install shimmy-tool-rg
shimmy skills update --target repo
shimmy skills uninstall --target profile
shimmy skills install --export ./shimmy-skills.zip
```

## `status`

Show the current profile's identity and root, its installed tools, and the
catalog source type/path, generation provenance, schema, content fingerprint,
health, and configured image references. Optionally include tools that are
available in the catalog but not installed. Invalid or unavailable catalog
state is reported and returns failure without changing the profile.

```text
shimmy status [--available] [--format human|manifest]
```

Options:

- `--available` includes catalog tools that are not installed.
- `--format human|manifest` selects human-readable or machine-readable output.
  The default is `human`.
- `-h`, `--help` shows command help.

Examples:

```sh
shimmy status
shimmy status --available
shimmy status --format manifest
```

## `test`

Validate the current profile and run non-mutating smoke commands through its
installed wrappers. A tool selection tests its installed public command; a
`tool@version` selection tests a recorded concrete version.

```text
shimmy test [--shim <tool>[@<version>]] [--all]
```

Options:

- `--shim <tool>[@<version>]` tests one installed tool or concrete version.
- `--all` tests every installed public tool and every installed concrete
  version. It cannot be combined with `--shim`.
- `-h`, `--help` shows command help.

Examples:

```sh
shimmy test
shimmy test --shim jq
shimmy test --shim aws@2.31
shimmy test --all
```

## `update`

Refresh management assets and selected installed tools in the current profile.
It can also run version-owned refresh hooks to pull external images or build
local images.

```text
shimmy update [--shim <name> ... | --all] [--pull] [--build]
              [--repair-startup] [--shell <name>]
              [--startup-file <path> ...]
```

Options:

- `--shim <name>` selects an installed tool to update. Repeat it to select
  multiple tools.
- `--all` selects all installed tools in the current profile. It does not
  enumerate sibling profiles and cannot be combined with `--shim`.
- `--pull` pulls images for selected external-image versions.
- `--build` builds images for selected local-build versions.
- `--repair-startup` repairs the current profile's managed startup integration.
- `--shell <name>` overrides shell detection during startup repair.
- `--startup-file <path>` selects a startup file to repair. Repeat it to select
  multiple files.
- `-h`, `--help` shows command help.

With neither `--all` nor `--shim`, the command updates all tools already
installed in the current profile. A selected tool adopts the current catalog
default while retaining any other explicitly installed concrete versions.
Catalog publication alone never changes the profile. Startup repair options
are unavailable for the `upstream` profile.

Examples:

```sh
shimmy update
shimmy update --shim terraform --pull
shimmy update --all --pull --build
shimmy update --repair-startup --shell zsh
```
