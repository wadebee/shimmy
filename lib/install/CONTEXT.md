# Installation lifecycle

`install.sh` is the sourceable orchestration implementation for the public
`commands/install.sh` entrypoint. The root `bootstrap.sh` invokes it only to
bootstrap one canonical profile with internally supplied jq/rg requests; an
installed profile-local launcher invokes it only for its enclosing profile and
requires one or more explicit `--shim` requests. It selects fresh, additive,
refresh, or uninstall lifecycle flows while resolving availability from the
profile's shared named catalog.
The root entrypoint sources the installed `shell-init.sh` into its caller when
it is sourced; execution retains initialization only inside the bootstrap
process. Explicit bootstrap `--activate` runs only after profile and startup
commit, delegates ordinary or stale-restart activation to the profile state
machine, and leaves a recoverable installation on failure. It never implies
`--stop-running`. The generated asset changes PATH only and does not activate
Podman or set connection variables.

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
- `manifest.sh` preserves and renders the profile-local version-1 manifest,
  including its fixed `catalog=default` or `catalog=upstream` binding. Its
  explicitly target-prefixed renderer emits deterministic version-2 candidate
  manifests but is not called by the current lifecycle.
- `transaction.sh` is private target-only code for same-filesystem regular-file
  candidates. It snapshots prior bytes and mode, stages outside locks,
  requires the caller-declared catalog, activation, profile, or registry lock,
  revalidates the candidate, target, and caller authority under that lock,
  commits with atomic replacement, and reports exact rollback as `complete` or
  `incomplete` after post-commit failure injection.
- `profile-assets.sh` stages the profile-local control plane, launcher,
  dispatchers, explicit manifest-tuple smoke metadata, and only
  manifest-selected tool metadata and concrete version assets plus the
  authoritative registry file and optional Darwin projection record. It
  re-resolves and compares the catalog before commit so a live catalog change
  cannot produce a mixed materialization.
  Fresh and valid pre-feature profiles receive an empty managed file; later
  transactions lock and preserve validated config and record bytes.
- `launcher-template.sh` becomes the installed profile's self-contained
  `bin/shimmy`, including dispatch for the profile engine control plane.
- `startup.sh` renders the profile's `shell-init.sh` asset and applies
  persistent startup integration only for `default`. Fresh bootstrap records
  one normalized shell and either its conventional exact paths or manual
  policy. An identifiable running-shell discrepancy requires confirmation
  before catalog or profile mutation. Existing-profile operations inherit that
  state; only unqualified checkout repair writes its recorded managed paths.
- `uninstall.sh` ordinarily removes only validated assets owned by the
  enclosing profile. It acquires the activation lock before deterministic
  profile locks, tears down exact registry projections, restores Darwin engine
  state, and commits local deletion only after external cleanup succeeds. The
  Darwin transaction commits after every projection record is removed while
  every rollback backup still exists; backup deletion is post-commit cleanup
  and cannot re-enter projection rollback.
  Explicit global uninstall also holds the catalog lock, detaches every
  profile before deleting any, and preserves bound source checkouts and
  external skill exports.

Profiles contain no canonical management plugin or tool skill sources; those
remain in the named catalog. Manifest version 1 and the
`profile-materialized-root` identity reject legacy, mixed, and damaged layouts
before install or refresh mutation. Profile install and uninstall do not write
or remove repository or home shared-skill targets; those targets are managed
only through explicit standalone `shimmy skills` commands. Uninstall still
removes legacy `agent/` or `plugins/` directories from a valid current profile.

Profile uninstall never removes shared catalog registry state. Initial
default bootstrap publishes from a clean committed checkout through the same
generation transaction used later; initial upstream bootstrap registers its
live checkout without replacing an existing different binding.
Profile and global uninstall remove startup integration only from manifest-owned
`startup_file` entries, validated profile-owned registry files, and, on Linux,
the exact active Shimmy link when it targets a removed profile. They do not
accept shell or startup-file selectors. On Darwin they use a valid record to
remove only the exact VM link, restart a running projected machine to clear
cached policy, temporarily start a stopped projected machine, permit
record-only cleanup for a proven-missing machine, and restore the initial
machine/default state. Foreign links, operator containers configuration,
sibling profile files, and external skill exports remain outside that ownership
boundary.
