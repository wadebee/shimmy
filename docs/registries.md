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
validates and renders the candidate without mutation.

Prefixes and locations must be fully qualified registries with optional ports
and safe lowercase namespace paths. Schemes, wildcards, tags, digests,
traversal, empty segments, trailing slashes, quotes, and whitespace are
rejected. Redirects do not manage credentials, TLS, private CAs, signatures,
or short-name search.

## Semantics

Shimmy emits replacement `location` tables, not fallback mirrors. If the
physical endpoint cannot serve a logical digest, the operation fails without
contacting a public fallback. Profiles own independent policy files.

Mutation requires the invoking profile to be active. On Linux, the active
profile is selected through the exact Shimmy-owned user drop-in:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/containers/registries.conf.d/shimmy-active-profile.conf
```

It is an absolute link to the active profile's authoritative file. Foreign,
damaged, masked, rootful, or remote state fails closed, and failed validation
restores the previous exact link.

On macOS, activation projects an absolute link into the deterministic profile
machine at:

```text
/etc/containers/registries.conf.d/shimmy-profile.conf
```

The host config must be readable at the same absolute path in the VM. Shimmy
records the exact profile, machine, path, and fingerprint. A running machine
with stale policy requires the exact named restart command printed by status,
for example:

```sh
"$profile_root/bin/shimmy" profile activate team-one --restart
```

Running workloads still require separate `--stop-running` acknowledgement.

## Detach and uninstall

Explicit recovery can detach the exact active projection while clearing all
redirects:

```sh
shimmy profile redirect delete --all --detach
```

Profile deletion and global uninstall perform their own guarded projection
cleanup. They preserve operator policy, source checkouts, and Podman machines.
Foreign or damaged paths are never replaced or removed.

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
