# Registry redirects

Each profile owns `<profile-root>/registries.conf`, a strict containers/image
version-2 replacement policy. Use the invoking active profile's grouped
command; do not edit the file directly.

## Commands

```sh
shimmy profile redirect list
shimmy profile redirect set --prefix docker.io \
  --location registry.corp.example/docker --dry-run
shimmy profile redirect set --prefix docker.io \
  --location registry.corp.example/docker
shimmy profile redirect delete --prefix docker.io
shimmy profile redirect delete --all
```

`set` is an idempotent upsert keyed by exact logical prefix. Entries are
sorted. `delete --all` leaves the required empty managed file. `--dry-run`
validates and renders the candidate without mutation and reports
`would_recycle_podman_service=yes|no` for shared-engine policy.

Prefixes and locations must be fully qualified registries with optional ports
and safe lowercase namespace paths. Schemes, wildcards, tags, digests,
traversal, empty segments, trailing slashes, quotes, and whitespace are
rejected. Redirects do not manage credentials, TLS, private CAs, signatures,
or short-name search.

## Semantics

Shimmy emits replacement `location` tables, not fallback mirrors. If the
physical endpoint cannot serve a logical digest, the operation fails without
contacting a public fallback. Profiles own independent policy files.

The profile source remains authoritative. An inactive-profile mutation changes
only that source and cannot alter the active engine projection. An
active-profile mutation applies and validates both surfaces transactionally.
On Linux, the active profile is selected through the exact Shimmy-owned user
drop-in:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/containers/registries.conf.d/shimmy-active-profile.conf
```

It is an absolute link to the active profile's authoritative file. Foreign,
damaged, masked, rootful, or remote state fails closed, and failed validation
restores the previous exact link.

On macOS, each shared or owned isolated engine has one stable user drop-in:

```text
/var/home/core/.config/containers/registries.conf.d/shimmy-active-profile.conf
```

That drop-in targets the stable host-mounted engine projection at
`<config-root>/engines/<engine-id>/registries.conf`. Activation atomically
renders it from the selected profile and records the source and loaded
fingerprints. If the normalized effective policy changes, Shimmy stops only the
rootless `podman.service`; socket activation starts a new API process and Shimmy
validates the exact mapping. The VM and running containers remain up. Equal
policies switch without a recycle.

A stale managed projection is repaired through ordinary activation, without
`--restart`:

```sh
"$profile_root/bin/shimmy" profile activate team-one
```

`--restart` means VM restart recovery. `--stop-running` is not part of the
same-engine API service recycle path.

## Detach and uninstall

Explicit recovery can detach the exact active projection while clearing all
redirects:

```sh
shimmy profile redirect delete --all --detach
```

Profile deletion and global uninstall perform their own guarded projection
cleanup. Shared-profile deletion preserves the shared machine. Owned isolated
profile deletion removes the exact fully proven machine and all VM-local data;
global uninstall removes every fully proven owned shared or isolated machine.
That permanently destroys its containers, images, volumes, build caches, and
all other VM-local data. Legacy, external, ambiguous, foreign, damaged, and
Linux host-local engines remain preserved. Foreign or damaged paths are never
replaced or removed. Use `shimmy admin uninstall --dry-run` to inspect exact
machine and projection actions before mutation.

## Registry clients

Fresh host Podman processes use the active projection. The active profile's
Skopeo runtime also mounts its authoritative policy read-only, so:

```sh
shimmy catalog verify --public-only
```

uses the same redirects while preserving logical image references. Skopeo is
the initial tool-container opt-in. A sibling-active, stale, unsafe, masked, or
invalid policy fails closed. Private access still requires an explicit
`SHIMMY_SKOPEO_AUTH_SECRET`; Shimmy does not mount host credentials or disable
TLS verification.
