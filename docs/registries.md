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

## Darwin activation

On macOS, `shimmy profile activate` projects the invoking profile into its
deterministic Podman machine at exactly:

```text
/etc/containers/registries.conf.d/shimmy-profile.conf
```

The VM path is an absolute symlink to the authoritative host profile path,
which must be readable at the same absolute path inside the machine. Shimmy
never copies registry content into the VM. A fixed root SSH script may create
or remove only that exact link after validating its arguments and parent
directories. A separate rootless SSH process validates the same-path source,
the exact link target, readability, and content fingerprint before Podman
engine policy validation runs. Regular files, directories, foreign links,
wrong targets, unsafe parents, and masking registry variables fail closed.

After remote validation, Shimmy writes a strict mode-`0644` local ownership
record at `<profile-root>/machine-projection.txt`. It binds the profile,
machine, target, and deterministic configuration fingerprint. Activation and
profile updates include the link and record in their rollback and preservation
boundaries.

If the expected machine is already running and its link or recorded
fingerprint is absent or stale, ordinary activation makes no change and prints
the exact required command:

```sh
"$profile_root/bin/shimmy" profile activate --restart
```

Restart uses the normal workload guard; running containers require explicit
`--stop-running` acknowledgement. Editing a running Darwin profile commits the
local file without restarting the VM and prints the same absolute restart
command. A profile with no projection record remains engine-independent while
redirects are prepared.

Darwin detach uses the same public command as Linux:

```sh
shimmy profile redirect remove --all --detach
```

For a running, reachable expected machine, standalone detach removes only the
exact VM link and matching record, then empties the managed file as one
rollback-aware transaction. A stopped existing machine must first be activated
for this standalone operation. If machine metadata proves the expected machine
is absent, Shimmy may remove the valid record locally without SSH. Foreign or
damaged state is never replaced.

Profile and global uninstall perform their own transactionally guarded cleanup.
They retain every record and config until all exact links are detached and the
initial machine/default-connection state is restored. Running projected
machines restart after detach to clear cached policy; stopped projected
machines are temporarily started and restored to stopped. Global cleanup
detaches both profiles before deleting either and reprojects earlier profiles
if a later detach fails. `--stop-running` is required only when listed existing
workloads would be interrupted. Manual detach remains recovery/debugging
functionality, not an uninstall prerequisite.

Darwin status reports link state, record path, current and recorded
fingerprints, and evidence-based policy freshness:

- `current` means the exact link and record match the current config in a
  reachable expected machine and no registry override masks it.
- `restart-required` means a running machine needs explicit reprojection.
- `unverified` means the stopped, missing, or unreachable machine prevents
  current remote evidence.
- `invalid` means local or remote owned state is malformed, foreign, masked,
  or inconsistent.

## Registry clients

Linux activation applies the policy to fresh host-side Podman processes, and
Darwin activation applies it to the selected machine's Podman engine. Shimmy
also mounts the current invoking profile's authoritative file read-only into
the Skopeo container at:

```text
/etc/containers/registries.conf.d/shimmy-profile.conf
```

Skopeo is the only initial tool-container opt-in. `shimmy images verify`
inherits the same policy because it already performs remote inspection through
the profile-local Skopeo runtime. Logical image references remain unchanged;
containers/image performs longest-prefix replacement inside the client.

A valid profile with no Shimmy activation omits the mount, so redirects may be
prepared without affecting client execution. A sibling active profile,
damaged or unsafe owned path, invalid managed file, stale Darwin projection,
or non-empty `CONTAINER_CONNECTION`, `CONTAINER_HOST`,
`CONTAINERS_REGISTRIES_CONF`, or `CONTAINERS_REGISTRIES_CONF_OVERRIDE` fails
Skopeo closed instead of silently running without the expected policy.
Source-checkout previews are not bound to an installed profile and retain
their unmounted behavior.

Policy mounting does not install registry credentials, a corporate CA, or a
signature policy. Private registry access still requires the explicit
`SHIMMY_SKOPEO_AUTH_SECRET` auth-file secret. A TLS endpoint signed by a
private CA must already be trusted by the selected Skopeo image; Shimmy does
not mount host certificate directories or disable verification. Existing
operator configuration in the image can still affect containers/image
precedence, so verify the effective digest route after changing drop-ins.

If the physical endpoint cannot serve a redirected digest, Skopeo and
`images verify` fail; Shimmy never adds a public-upstream fallback. Preparing
an unprojected profile does not contact Podman or a registry.
