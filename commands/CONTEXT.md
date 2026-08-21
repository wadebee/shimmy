# Management commands

These executable entrypoints implement the installed `bin/shimmy` management
surface. The sourceable or executable repository `bootstrap.sh` entrypoint
invokes `commands/install.sh` with its fixed jq/rg baseline; there is no
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
- `catalog-target.sh` is an uninstalled private candidate for target-schema
  default-catalog status, retained tools inspection, active-profile-backed
  remote image verification, clean-main publication, and rollback. It requires
  an explicit disposable configuration root and has no route from the current
  installed dispatcher.
- `shim-target.sh` is an uninstalled private candidate for version-2
  profile-local shim list/add/remove/set-version/sync/test behavior. It resolves
  only the active disposable target profile and its retained catalog pin,
  prepares images before mutation, regenerates the shim AI-skill bundle, and
  reconciles exact active user links in one bounded rollback workflow. It has no
  route from the current installed dispatcher.
- `ai-skill-target.sh` is an uninstalled private candidate for active-profile
  bundle/link list and repair behavior. It classifies malformed and unsupported
  bundle state, reports exact destructive collisions, and never sweeps the
  recorded user skills root.
- `profile-target.sh` is an uninstalled private candidate for arbitrary safe
  profile list/status/create/activate/sync/startup-repair/delete and
  invoking-profile redirect behavior. It
  requires launcher-supplied disposable installation and invoking identities,
  permits redirect mutation only from the active invoking profile, and commits
  engine/registry authority before the active record and exact AI-skill links
  with bounded compensation. It has no current public dispatcher route.
- `bootstrap-target.sh` is the executable half of the private pristine target
  bootstrap. It publishes the default catalog, materializes the jq/rg/Skopeo
  profile baseline, activates it, reconciles exact user links and startup, and
  removes the disposable installation root if initial activation fails.
- `admin-target.sh` is the private installation-wide status/network/uninstall
  candidate. Status aggregates profile failures, network inspection resolves
  the active profile first, and uninstall removes only validated owned state,
  exact startup blocks, and recognized direct home skill links.
- `dispatch-tool.sh` validates exact manifest ownership and a fixed regular,
  executable, non-symlink `commands/run-tool.sh` target, then dispatches the
  profile-local logical tool without resolving the catalog checkout.
- `run-tool.sh` dispatches materialized tool runtime assets; it does not act as
  catalog availability authority.
- `agent-preflight.sh` validates concrete-version `image.conf` metadata and
  adds preview-only smoke arguments for local builds.
- `profile.sh` reports or explicitly activates the invoking profile's
  deterministic Podman engine, and manages strict profile-owned registry
  redirects without selecting an arbitrary profile or machine. Its detailed
  status fields remain the compatibility surface while shared profile helpers
  own side-effect-free activation labels and recommended recovery actions. Linux
  activation owns one exact user drop-in; Darwin activation projects one exact
  VM link, reports record/fingerprint freshness, requires explicit restart for
  stale running policy, and detaches only recognized invoking-profile state.
- `status.sh` uses the shared profile state reader and recommendation resolver
  to report a read-only Podman engine summary before the enclosing profile's
  named catalog and installed tool metadata. Human output has Profile, Podman
  Engine, Catalog, and Tools sections; manifest output preserves existing
  records and adds stable `shimmy_engine_*` fields without exposing connection
  URIs or override values. Engine failures remain status values while catalog
  validation retains its existing exit behavior;
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
