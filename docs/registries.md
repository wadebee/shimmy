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

## Prepared-only boundary

Chunk 3 stores and validates policy but does not project it into a Linux engine,
a macOS Podman machine, or a tool container. `profile status` and `redirect
list` therefore report an empty policy as `inactive` and a non-empty policy as
`prepared`, never `current`. Preparing a redirect does not contact Podman or a
registry and does not mean an engine consumes it. Platform projection and
fresh-process validation require later reviewed chunks.
