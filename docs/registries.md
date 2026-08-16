# Registry redirects

Each installed profile owns one generated containers/image version-2 file at
`<profile-root>/registries.conf`. Use `shimmy profile redirect`; do not edit the
file directly.

## Prepare redirects

```sh
shimmy profile redirect --prefix docker.io \
  --location registry.corp.example/docker
shimmy profile redirect list
shimmy profile redirect remove --prefix docker.io
shimmy profile redirect remove --all
```

The direct option form is an idempotent upsert keyed by the exact logical
prefix. Entries are sorted by prefix. Repeating an identical mapping is a
no-op, changing its location replaces only that entry, exact removal preserves
siblings, and `--all` leaves the required empty managed file. `--dry-run`
validates and prints the complete candidate without locking or changing the
filesystem.

Prefixes and locations must name a fully qualified registry, optionally with a
numeric port and safe lowercase namespace path. Schemes, wildcards, tags,
digests, traversal, empty segments, trailing slashes, quotes, whitespace, and
unsupported characters are rejected. Authentication, certificates, transport
security, signature policy, and short-name search remain operator concerns.

## Managed format

The file is a regular non-symlink with mode `0644`, exact profile/version
markers, and only strict replacement tables:

```toml
# Managed by Shimmy for profile "default". Use `shimmy profile redirect`; do not edit.
# shimmy_registry_redirects_version=1

[[registry]]
prefix = "docker.io"
location = "registry.corp.example/docker"
```

Shimmy does not emit `[[registry.mirror]]`. A `location` replacement has no
configured upstream fallback: if the physical endpoint cannot serve the
requested logical digest, the operation fails. Redirects do not rewrite image
metadata, manage credentials, weaken TLS, or change signature policy.

Fresh installs and valid pre-feature upgrades create an empty managed file.
Additive installs and updates validate and preserve an existing file
byte-for-byte. Each profile is independent; uninstall removes only its valid
owned file and preserves operator policy and sibling profiles.

## Linux activation

On Linux, `shimmy profile activate` atomically selects the invoking profile by
managing only this user drop-in:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/containers/registries.conf.d/shimmy-active-profile.conf
```

The path is an absolute symlink to that profile's authoritative
`registries.conf`. Activation first rejects remote or rootful engines,
connection overrides, registry configuration overrides, unsafe parent paths,
and foreign or damaged content at the owned link. It then installs or switches
the link and validates a fresh local-rootless Podman process. Failed validation
restores the exact prior link. Operator `registries.conf` files and every other
drop-in are preserved.

An edit to the active Linux profile is also validated in a fresh Podman process
after the new file is installed. Failure restores the prior file bytes.
Inactive-profile edits remain engine-independent. Use the exact active profile
to detach and empty its policy:

```sh
shimmy profile redirect remove --all --detach
```

Detach refuses an absent, sibling-owned, foreign, or damaged link. Profile and
global uninstall remove the exact active link only when it targets the profile
being removed. The containing operator-owned directories are retained.

`profile status` and `profile redirect list` report config health, active-link
ownership, masking variable names, and an evidence-based policy state:

- `current` means the exact Linux link selects this profile, no masking
  registry variable is set, and a fresh local-rootless engine is reachable.
- `inactive` means no Shimmy link exists or a valid sibling profile is active.
- `invalid` means owned-path state is damaged or foreign, a registry override
  masks the link, or the selected policy cannot be validated.

Unset `CONTAINERS_REGISTRIES_CONF` and
`CONTAINERS_REGISTRIES_CONF_OVERRIDE` before Linux activation or active edits.
Shimmy reports only the masking variable name, never its value.

## Current client boundary

Darwin remains preparation-only until its machine projection is implemented:
an empty policy is `inactive` and a non-empty policy is `prepared`. Tool
containers, including Skopeo, do not yet receive this file. Linux activation
applies the policy to fresh host-side Podman processes only; it does not claim
container-client coverage. Preparing an inactive profile does not contact
Podman or a registry.
