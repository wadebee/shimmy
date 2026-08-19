# Shimmy commands

The profile-local `shimmy` launcher manages the profile that contains it. It
does not accept a profile or machine selector. Engine activation and PATH
selection are separate; sourcing `shell-init.sh` changes PATH only.

Repository entrypoints in this directory implement the installed management
commands and orchestrate shared behavior from `../lib/`. The root `install.sh`
is the bootstrap entrypoint for creating a profile.

## Table of contents

- [`images`](#images) — verify remote image indexes and upstream drift
- [`catalog`](#catalog) — list or manage shared catalogs
- [`install`](#install) — add tool shims to the current profile
- [`uninstall`](#uninstall) — remove one profile or all owned Shimmy state
- [`netinfo`](#netinfo) — show host, VM, and container network perspectives
- [`profile`](#profile) — inspect or activate the engine and manage registry redirects
- [`skills`](#skills) — manage or export Shimmy agent skills
- [`status`](#status) — inspect the current profile and its tool catalog
- [`test`](#test) — run non-mutating profile and shim smoke tests
- [`update`](#update) — refresh the current profile and its tool images

Every second-level command supports `shimmy <command> --help` with authoritative
usage, options, and examples. `catalog`, `images`, `profile`, and `skills` also summarize
their third-level actions when invoked without one; use
`shimmy <group> <action> --help` for action-specific guidance.

## `profile`

Inspect or explicitly activate the invoking profile's deterministic Podman
engine and manage strict registry redirects:

```text
shimmy profile status [--format human|manifest]
shimmy profile activate [--restart] [--stop-running] [--dry-run]
shimmy profile redirect --prefix <logical-prefix> --location <physical-location> [--dry-run]
shimmy profile redirect list [--format human|manifest]
shimmy profile redirect remove (--prefix <logical-prefix> | --all) [--detach] [--dry-run]
```

On macOS, `default` maps only to the pre-existing `shimmy-default` machine and
same-name rootless connection; `upstream` maps only to `shimmy-upstream`.
Activation may stop one idle alternate VM, starts and validates the target, and
projects the invoking profile through the exact VM-side
`/etc/containers/registries.conf.d/shimmy-profile.conf` symlink before engine
policy validation. Rootless validation and a local fingerprint record precede
Podman's global default connection commit. Running containers block a stop
unless `--stop-running` explicitly acknowledges their interruption.
`--restart` applies the same guard to the expected machine and refreshes stale
projection state. A dry run inspects and prints the transition without changing
machine, projection, record, or connection state.

On Linux, activation atomically selects the invoking profile through the exact
user `shimmy-active-profile.conf` drop-in, then validates a fresh current-user
local-rootless Podman process. It rejects VM lifecycle flags, remote/rootful
engines, unsafe or foreign link state, and masking registry variables. Both
platforms reject non-empty `CONTAINER_CONNECTION` and `CONTAINER_HOST` without
printing their values. Shimmy never creates, adopts, renames, or removes Podman
machines. Source the exact profile `shell-init.sh` after activation to select
PATH.

Redirect operations edit only the invoking profile's strict generated
`registries.conf`. They use replacement `location`, never a fallback-capable
mirror. Upsert is exact-prefix keyed and prefix-sorted; removal is exact, and
`--all` retains the required empty managed file. Dry-run renders the complete
candidate without a lock or filesystem mutation. Linux active edits validate
with a fresh process and roll back exact bytes on failure; inactive edits do
not contact Podman. Darwin active edits commit locally, print the exact
profile-local restart command, and never restart automatically. `--detach` is
valid only with `--all`; it removes only the exact invoking-profile Linux link
or Darwin VM link and local record. A stopped Darwin machine must be activated
first, while a machine proven absent permits record-only detach. See [registry
redirect guidance](../docs/registries.md).

## `catalog`

List a resolved named catalog from either installed profile. Publish, roll
back, and rebind remain restricted to the installed upstream profile.

```text
shimmy catalog list [--name <catalog>] [--format human|manifest]
shimmy catalog publish
shimmy catalog rollback
shimmy catalog rebind --checkout <absolute-path>
```

`list` resolves and validates the complete selected catalog before output. With
no `--name`, it uses the invoking profile's recorded catalog binding. An
explicit `--name <catalog>` reads that named registry without selecting
another profile or changing profile or catalog state. Human output identifies
the catalog and prints one bullet per tool. Manifest output emits
`shimmy_catalog_name` followed by one `shimmy_catalog_tool` record per tool.
Tools already installed in the invoking profile remain in this complete
catalog-membership view.

`publish` stages and validates tracked content from the clean committed
upstream `HEAD`, then atomically advances the immutable default generation.
`rollback` atomically restores the retained prior valid default generation,
including recovery when the current generation is invalid. `rebind` validates
and atomically replaces only the live upstream checkout path; it does not
modify either checkout. None of these operations changes an installed
profile's recorded tool versions.

List examples:

```sh
shimmy catalog list
shimmy catalog list --name upstream
shimmy catalog list --format manifest --name default
```

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
The same Skopeo runtime mounts a valid current invoking-profile registry policy
read-only, so verification inherits strict redirects without rewriting its
logical image references. Valid no-activation state omits the mount; invalid,
mismatched, stale, unsafe, or masking state fails closed.

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
```

Options:

- `--shim <tool[@version]>` selects a tool to install and is required. Repeat
  it to install multiple tools.
- `-h`, `--help` shows command help.

Additive installation preserves the invoking profile's recorded startup policy
and never modifies startup files. The installed launcher selects its enclosing
profile; it accepts no profile selector. The `upstream` profile never owns
persistent startup integration.

Examples:

```sh
shimmy install --shim task
shimmy install --shim aws --shim terraform
shimmy install --shim oc@4.20
```

## `uninstall`

Remove the current profile and its managed startup integration. Without
`--global`, this command operates only on the profile containing the invoked
launcher and preserves sibling profiles and shared catalogs.

```text
shimmy uninstall [--global] [--stop-running]
```

Options:

- `--global` removes every valid manifest-owned profile and registry-owned
  shared catalog. It preserves source checkouts and external skill exports and
  refuses unrecognized shared state.
- `--stop-running` acknowledges interruption of listed running containers when
  registry cleanup must stop a running macOS machine. It is rejected when no
  already-running machine needs to stop.
- `-h`, `--help` shows lifecycle command help.

Startup cleanup removes managed integration only from the `startup_file`
entries owned by each profile manifest; uninstall does not accept arbitrary
shell or startup-file targets. Uninstall validates ownership and locks before
mutation. On Linux it removes only an exact selected-profile link. On macOS it
detaches an exact recorded VM link, restarts an initially running projected
machine to clear cached policy, temporarily starts and returns a stopped
projected machine to stopped state, or removes only the record when the
deterministic machine is proven missing. It restores the initial running
machine and default connection before deleting profile state. Global uninstall
detaches every profile before deleting any; failed pre-commit cleanup
reprojects already-detached profiles and retains profiles and catalogs. The
standalone `profile redirect remove --all --detach` command remains available
for recovery and debugging.

Examples:

```sh
shimmy uninstall
shimmy uninstall --global
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

Show the current Profile, Podman Engine, Catalog, and Tools in distinct human
sections. The engine summary is read-only and reports the deterministic engine
and connection names, machine and reachability state, running-container count,
registry-policy state, activation state, and a safe recommended action when one
is available. It never prints connection URIs or environment override values.

Catalog output retains its source type/path, generation provenance, schema,
content fingerprint, health, and configured image references. Invalid or
unavailable catalog state is reported and returns failure without changing the
profile. Engine unavailability remains a status value and does not prevent
catalog or installed-tool reporting. Use `shimmy catalog list` for complete
catalog membership and `shimmy profile status` for detailed engine and registry
state.

```text
shimmy status [--format human|manifest]
```

Options:

- `--format human|manifest` selects human-readable or machine-readable output.
  The default is `human`.
- `-h`, `--help` shows command help.

Manifest output preserves the existing `shimmy_*` records and adds
`shimmy_engine_type`, `shimmy_engine_name`, `shimmy_engine_connection`,
`shimmy_engine_default_connection`, `shimmy_engine_machine_state`,
`shimmy_engine_reachable`, `shimmy_engine_activation`,
`shimmy_engine_registry_policy`, `shimmy_engine_running_container_count`, and
`shimmy_engine_recommended_action`. The recommended action is one of `none`,
`profile_activate`, `profile_activate_restart`, `podman_machine_init`,
`unset_override`, or `investigate`.

Examples:

```sh
shimmy status
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
              [--repair-startup]
```

Options:

- `--shim <name>` selects an installed tool to update. Repeat it to select
  multiple tools.
- `--all` selects all installed tools in the current profile. It does not
  enumerate sibling profiles and cannot be combined with `--shim`.
- `--pull` pulls images for selected external-image versions.
- `--build` builds images for selected local-build versions.
- `--repair-startup` repairs only the exact startup files recorded as owned by
  the current default profile. It is an informational no-op for manual policy.
- `-h`, `--help` shows command help.

With neither `--all` nor `--shim`, the command updates all tools already
installed in the current profile. A selected tool adopts the current catalog
default while retaining any other explicitly installed concrete versions.
Catalog publication alone never changes the profile. Startup repair is
unavailable for the `upstream` profile.

Examples:

```sh
shimmy update
shimmy update --shim terraform --pull
shimmy update --all --pull --build
shimmy update --repair-startup
```
