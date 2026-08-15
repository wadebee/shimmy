# Installation lifecycle

`install.sh` is the sourceable orchestration implementation for the public
`commands/install.sh` entrypoint. The root `install.sh` invokes it only to
bootstrap one canonical profile with internally supplied jq/rg requests; an
installed profile-local launcher invokes it only for its enclosing profile and
requires one or more explicit `--shim` requests. It selects fresh, additive,
refresh, or uninstall lifecycle flows while resolving availability from the
profile's shared named catalog.
The root entrypoint sources the installed `shell-init.sh` into its caller when
it is sourced; execution retains initialization only inside the bootstrap
process. The generated asset changes PATH only and does not activate Podman or
set connection variables.

## Files

- `request.sh` parses install inputs, renders distinct installed `install` and
  `uninstall` guidance, resolves the canonical XDG profile path, and validates
  requested tools and versions.
- `catalog-lifecycle.sh` owns serialized `upstream` registration and explicit
  rebind plus clean-HEAD, same-filesystem staged publication of immutable
  `default` generations. It validates and fingerprints the one archived
  payload copy, rechecks checkout state, atomically advances the registry, and
  retains the prior valid generation. Explicit rollback validates the retained
  generation and atomically swaps registry authority, including recovery from
  an invalid current generation.
- `manifest.sh` preserves and renders the profile-local version-2 manifest,
  including its fixed `catalog=default` or `catalog=upstream` binding.
- `profile-assets.sh` stages the profile-local control plane, launcher,
  implementations, dispatchers, and only manifest-selected tool metadata and
  concrete version assets. It re-resolves and compares the catalog before
  commit so a live catalog change cannot produce a mixed materialization.
- `launcher-template.sh` becomes the installed profile's self-contained
  `bin/shimmy`, including dispatch for the profile engine control plane.
- `startup.sh` renders the profile's `shell-init.sh` asset and applies
  persistent startup integration only for `default`. Unqualified checkout
  bootstraps manage zsh and both Bash startup modes; explicit startup options
  remain authoritative.
- `uninstall.sh` ordinarily removes only validated assets owned by the
  enclosing profile. Explicit global uninstall prevalidates all profile and
  catalog ownership, removes every owned profile and shared registry, and
  preserves bound source checkouts and external skill exports.

Profiles contain no canonical management plugin or tool skill sources; those
remain in the named catalog. Manifest version 2 and the
`profile-materialized-root` identity reject legacy, mixed, and damaged layouts
before install or refresh mutation. Profile install and uninstall do not write
or remove repository or home shared-skill targets; those targets are managed
only through explicit standalone `shimmy skills` commands. Uninstall still
removes legacy `agent/` or `plugins/` directories from a valid current profile.

Profile uninstall never removes shared catalog registry state. Initial
default bootstrap publishes from a clean committed checkout through the same
generation transaction used later; initial upstream bootstrap registers its
live checkout without replacing an existing different binding.
