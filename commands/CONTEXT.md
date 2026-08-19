# Management commands

These executable entrypoints implement the installed `bin/shimmy` management
surface. The sourceable or executable repository `install.sh` bootstrap
invokes `install.sh` directly with its fixed jq/rg baseline; there is no
repository launcher. Commands parse arguments and orchestrate shared modules;
reusable behavior belongs in `../lib/`.

## Key files

- `install.sh` installs or removes the enclosing canonical profile; uninstall
  loads guarded profile-activation support for projection and engine cleanup.
- `catalog.sh` lists complete validated membership from the invoking profile's
  recorded catalog or an explicitly named registry. Its mutation actions
  publish clean committed `upstream` content to an immutable `default`
  generation, atomically restore its retained prior generation, or explicitly
  rebind the live upstream registry.
- `dispatch-tool.sh` validates exact manifest ownership and a fixed regular,
  executable, non-symlink `commands/run-tool.sh` target, then dispatches the
  profile-local logical tool without resolving the catalog checkout.
- `run-tool.sh` dispatches materialized tool runtime assets; it does not act as
  catalog availability authority.
- `agent-preflight.sh` validates concrete-version `image.conf` metadata and
  adds preview-only smoke arguments for local builds.
- `profile.sh` reports or explicitly activates the invoking profile's
  deterministic Podman engine, and manages strict profile-owned registry
  redirects without selecting an arbitrary profile or machine. Linux
  activation owns one exact user drop-in; Darwin activation projects one exact
  VM link, reports record/fingerprint freshness, requires explicit restart for
  stale running policy, and detaches only recognized invoking-profile state.
- `status.sh` resolves the enclosing profile's named catalog and reports
  installed profile state and validated tool metadata together with catalog
  source, generation provenance, schema, fingerprint, and health;
- `images.sh` provides explicit, non-mutating remote index and upstream-drift
  verification through catalog-default profile-local Skopeo and jq runtimes;
  the Skopeo runtime inherits a valid current invoking-profile redirect mount
  without changing the logical references supplied by image verification;
  `update.sh`, `skills.sh`, and `netinfo.sh` retain their corresponding public
  capabilities.

Installed commands derive profile identity from their profile root, resolve
its fixed named catalog through shared XDG registry state on every
catalog-aware invocation, and reject profile and installation-location
selectors. Installed install accepts only repeatable tool selection; update's
startup repair consumes the enclosing default profile's exact manifest ledger
and accepts no shell or path selector. Missing or invalid catalog state fails
before command mutation.
Every second-level command provides authoritative usage, options, and examples
through `--help`. The `catalog`, `images`, `profile`, and `skills` command groups also
provide action discovery without an action and action-specific third-level
help before profile or catalog validation.
Canonical skill sources are read from the resolved catalog; repository and
home exports are written only by explicit standalone skills operations and
are owned by the target manifest. Repository and home
`.agents/skills/<name>/` exports are one-file compatibility adapters
containing only `SKILL.md`.

## Related contexts

- [shared library](../lib/CONTEXT.md)
- [tests](../tests/CONTEXT.md)
