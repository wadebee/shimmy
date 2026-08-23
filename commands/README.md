# Shimmy command reference

The installed `bin/shimmy` launcher exposes five command groups. Invoking the
root, any group, or the `profile redirect` subgroup without a child command is
exactly equivalent to adding `--help`: status `0`, byte-identical stdout, empty
stderr, and no installed-state validation or mutation. Actions retain their
documented defaults or require their documented inputs. Explicit action help
also renders before installed-state validation:

```sh
shimmy
shimmy --help
shimmy profile
shimmy profile --help
shimmy profile redirect
shimmy profile redirect --help
shimmy profile redirect set --help
```

Human output is the default. Commands that accept `--format` support `human`
and stable line-oriented `manifest` output.

> **Overwrite warning:** profile activation and AI-skill reconciliation replace
> every exact bundle-declared user skill destination without backup or recovery.
> They never recursively delete the user skill root or unrelated names. Use an
> activation `--dry-run` to inspect exact collisions first.

## Admin

```text
shimmy admin status [--format human|manifest]
shimmy admin network [--target <host-or-ip> ...]
  [--host-name <name>] [--host-ip <ipv4>] [--host-prefix <bits>]
  [--host-lan <cidr>] [--format human|manifest]
shimmy admin uninstall [--stop-running]
```

- `status` aggregates the active record, default catalog, and every profile.
- `network` reports shell, host, VM, and container perspectives through the
  active profile.
- `uninstall` removes all validated Shimmy-owned installation state. It
  preserves checkouts, Podman machines, unrelated registry policy, unrelated
  skill names, and the user skill root.

Run uninstall without `--stop-running` first. The flag is only an explicit
acknowledgement for listed macOS workloads that must be interrupted.

## Profile

```text
shimmy profile list [--format human|manifest]
shimmy profile status [--format human|manifest]
shimmy profile create <name> [--restart] [--stop-running] [--dry-run]
shimmy profile activate <name> [--restart] [--stop-running] [--dry-run]
shimmy profile sync
shimmy profile repair-startup
shimmy profile delete <name> [--stop-running]
shimmy profile redirect list [--format human|manifest]
shimmy profile redirect set --prefix <logical> --location <physical> [--dry-run]
shimmy profile redirect delete (--prefix <logical> | --all)
  [--detach] [--dry-run]
```

Profiles use arbitrary safe lowercase names and materialize independently below
the installation's `profiles/` directory. The launcher is bound to its
containing profile. `list` and `create` are installation-wide; `status`, `sync`,
`repair-startup`, and redirect operations use the invoking profile.

Creation automatically activates the new profile. Activation dry-run is
non-mutating and reports exact engine, registry, active-record, and skill-link
effects. On Linux `--restart` and `--stop-running` are not applicable. On macOS
they remain guarded acknowledgements and Shimmy never provisions a missing
`shimmy-<profile>` machine.

`sync` is active-profile only. It fetches the recorded source, requires
`refs/heads/main`, stages a complete replacement, and retains the profile's
explicit shim policies while adopting catalog/source changes. `delete` accepts
only an inactive non-default profile.

Redirects are strict profile-owned replacement locations. Active Linux edits
revalidate after link selection; active macOS edits may require the exact
printed activation restart. `delete --all --detach` is recovery/debugging for
the recognized projection; ordinary lifecycle operations perform their own
exact cleanup.

## Catalog

```text
shimmy catalog status [--format human|manifest]
shimmy catalog tools [--generation <sha256-generation>]
  [--format human|manifest]
shimmy catalog verify [--tool <tool[@version]> ...] [--public-only]
  [--require-current-upstream] [--format human|manifest]
shimmy catalog publish
shimmy catalog rollback
```

Shimmy owns one installation-wide immutable catalog named `default`. `status`
and `tools` are local-only. `verify` uses active-profile jq and Skopeo to inspect
configured image indexes and optional upstream drift without changing catalog
or profile state.

`publish` must run from the clean attached local `main` checkout root. It stages
only tracked catalog content, validates it, creates or reuses the content-
addressed generation, then atomically advances current/previous. `rollback`
selects the retained previous valid generation. Neither command updates profile
pins or deletes retained generations.

## Shim

```text
shimmy shim list [--format human|manifest]
shimmy shim add <tool[@version]>
shimmy shim remove <tool[@version]>
shimmy shim set-version <tool@version>
shimmy shim sync [<tool[@version]> ...]
shimmy shim test [<tool[@version]> ...]
```

Selectors are unqualified `tool` or `tool@version` values. An unqualified add
requires an interactive terminal and records tracking policy; an explicit
version is noninteractive and records pinned policy when it creates the shim.

- `remove <tool>` removes the whole shim and its concrete versions.
- `remove <tool@version>` removes a retained non-selected version.
- `set-version` changes the direct `bin/<tool>` selection and pinned policy.
- `sync` refreshes selected materialized versions from the profile's pinned
  catalog; with no selector it processes every installed shim.
- `test` runs version-owned non-mutating smoke metadata; with no selector it
  tests every retained concrete version.

Mutations require the invoking profile to be active because materialized shim
changes and their tool-skill links commit together.

## AI skill

```text
shimmy ai-skill list [--format human|manifest]
shimmy ai-skill repair
```

`list` reports the active profile's control/shim bundles and exact destination
state. `repair` stages and validates both bundles, overwrites every exact
declared collision, removes recognized stale Shimmy links, and preserves
unrelated names. It never recursively cleans `$HOME/.agents/skills`.

## Source-only commands

`commands/bootstrap.sh` is the implementation behind root `bootstrap.sh`.
`commands/run-tool.sh` is a contributor/source dispatcher for previewing or
running a catalog tool without an installed profile. `commands/agent-preflight.sh`
prints deterministic safe wrapper smoke prefixes for AI-agent approval review.
They are not additional installed launcher groups.
