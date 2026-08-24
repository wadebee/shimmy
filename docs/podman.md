# Podman for Shimmy

Every Shimmy tool wrapper runs a short-lived container through Podman. Podman
is an explicit dependency; Shimmy does not install Podman or adopt existing
machines. On macOS, fresh bootstrap transactionally provisions the
installation-owned shared machine named `shimmy-default`; explicit isolated profiles
provision installation-owned machines named `shimmy-<profile>`.

Official installation guidance: <https://podman.io/docs/installation>

## Initial setup

Verify the CLI from the shell that will run Shimmy:

```sh
podman --version
podman info
```

On macOS, leave the machine and connection name `shimmy-default` unused before fresh
bootstrap. Bootstrap fails before configuration mutation if either name already
exists; it never adopts, renames, or replaces a collision. If the configuration
home is outside the normal home share, use the exact same-path `--volume` form
printed by Shimmy.

Create and activate the fresh default profile:

```sh
. ./bootstrap.sh
podman info
jq --version
rg --version
```

Bootstrap always creates and activates `default` with jq, rg, and Skopeo.
Executing `./bootstrap.sh` is suitable for automation, but only sourcing can
select the installed `bin/` directory in the parent shell.

Bootstrap writes an `initializing` lifecycle phase before `podman machine init`.
Normal compensated failure removes an exactly identified just-created machine
and the fresh configuration root. If initialization ends before exact identity
is committed, or exact removal fails, Shimmy preserves the machine and reported
configuration/journal paths. This is deliberate ownership-safe recovery state,
not permission to retry bootstrap or delete/adopt the `shimmy-default` name directly.

## Profiles and engine authority

Inspect and activate an existing profile through an absolute launcher:

```sh
profile_root=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/team-one
"$profile_root/bin/shimmy" profile status
"$profile_root/bin/shimmy" profile activate team-one --dry-run
"$profile_root/bin/shimmy" profile activate team-one
. "$profile_root/shell-init.sh"
```

Activation aligns engine, registry projection, the installation active record,
and exact AI-skill links. It does not change a parent shell's PATH. Running
containers are listed and block an interrupting transition unless the user
separately acknowledges them with `--stop-running`.

When the requested profile is also the recorded active profile, activation can
repair its target-owned engine or registry state. A switch to a different
profile still requires the recorded prior profile to be fully active so it
remains a validated rollback source.

On Linux, all ordinary profiles bind to the shared local rootless engine and
activation manages only the Shimmy-owned user registry drop-in. On macOS, they
bind to the installation's owned shared machine: `shimmy-default` for fresh
installations or `shimmy` after compatibility migration. A shared-to-shared switch never stops
or starts the VM. If the normalized policy changes, Shimmy recycles only the
rootless `podman.service`, confirms `podman.socket` remains active, starts a new
API process through the exact connection, and validates the mapping. This is a
bounded API interruption; the VM and running containers remain up. An equal
policy needs no recycle.

Create an isolated macOS profile only when it needs a separate VM-local
container/image/volume namespace:

```sh
shimmy profile create build-lab --isolated --dry-run
shimmy profile create build-lab --isolated
```

Shimmy preflights profile, engine, machine, connection, and lifecycle-journal
names before mutation. It stages registry policy before starting the target,
records independent host and guest ownership evidence, prepares images on the
target engine, and commits profile authority last. Existing names are
collisions and are never adopted.

Clone preserves profile-owned reproducible state without transferring runtime
state or ownership evidence:

```sh
shimmy profile clone default team-two --dry-run
shimmy profile clone build-lab build-lab-two
shimmy profile clone build-lab shared-copy --shared
```

A shared source clones to the shared engine. An isolated or legacy-isolated
source clones to a newly owned isolated engine unless `--shared` overrides that
intent; `--isolated` forces a new isolated engine. The two overrides are
mutually exclusive.

Transitions between shared and isolated engines stage target registry policy,
inspect workloads on any machine that must stop, start and validate the target,
then commit the default connection, active profile, and skill links. Use
`--stop-running` only after reviewing listed workloads. A failed transition
restores the prior engine, projection, default connection, active record, and
skill links.

`--restart` is explicit VM recovery and is separate from normal service
recycle. `--stop-running` applies only to a VM transition that would interrupt
workloads, not to shared policy activation.

Unset connection and registry overrides before activation:

```sh
unset CONTAINER_CONNECTION CONTAINER_HOST
unset CONTAINERS_REGISTRIES_CONF CONTAINERS_REGISTRIES_CONF_OVERRIDE
```

Shimmy reports only a masking variable's name, not its value.

## Images

Each concrete version owns `image.conf`. Repository defaults and non-`scratch`
local-build bases are immutable top-level multi-platform digests that include
`linux/amd64` and `linux/arm64`. User image overrides remain outside that
guarantee.

Verify registry metadata explicitly through an installed profile:

```sh
shimmy catalog verify --public-only
shimmy catalog verify --tool jq@1.8 --public-only
SHIMMY_SKOPEO_AUTH_SECRET=registry-auth shimmy catalog verify
```

Verification inspects remote manifests without pulling target layers. Skopeo
is the initial tool-container consumer of active profile registry redirects.
Credentials remain explicit Podman secrets; Shimmy does not mount host auth,
private CA, or signature-policy directories implicitly.

Local-build image identity includes the complete context, image metadata,
ordered effective build arguments, and selected platform. Identical inputs
reuse the cache; changed inputs select a new reference.

## Native acceptance

Descriptor presence is not runtime acceptance. Run each new or rotated
concrete version's non-mutating smoke on native Linux `amd64` and native Apple
Silicon macOS `arm64`. Build local images natively before their smoke. Preview
and cross-emulation do not replace either host result.

## Linux notes

Normal Shimmy execution expects rootless Podman. Check rootless state and the
storage driver:

```sh
podman info --format '{{.Host.Security.Rootless}}'
podman info --format '{{.Store.GraphDriverName}}'
```

`overlay` is the preferred storage baseline. If subordinate UID/GID warnings
appear, inspect `/etc/subuid` and `/etc/subgid` and follow the distribution's
rootless Podman guidance. Storage migration and `podman system reset` can be
destructive and are not Shimmy lifecycle operations.

## macOS notes

The official pkg installer may place the CLI at `/opt/podman/bin/podman`.
Shimmy accounts for this location; add `/opt/podman/bin` to PATH for direct
manual use if needed.

Useful inspection commands are:

```sh
podman machine list
podman system connection list
```

If status reports that the shared machine is stopped, recover it through the
ordinary named activation workflow:

```sh
"$profile_root/bin/shimmy" profile status
"$profile_root/bin/shimmy" profile activate team-one --dry-run
"$profile_root/bin/shimmy" profile activate team-one
```

The dry run reports the explicit VM recovery and registry projection without
changing either. Do not substitute a direct `podman machine start`; activation
also validates and reconciles registry, connection, active-record, and exact
AI-skill-link authority. If only registry policy is stale, ordinary activation
recycles the API service without a VM restart:

```sh
"$profile_root/bin/shimmy" profile activate team-one
```

Inspect compatibility and migrate an updated schema-2 installation explicitly:

```sh
shimmy admin engine status --format manifest
shimmy admin engine migrate --dry-run
shimmy admin engine migrate
```

Migration records existing `shimmy-<profile>` machines as external
legacy-isolated engines without changing their lifecycle, then creates the
reserved shared `shimmy` engine for future profiles.

## Profile deletion

Inspect deletion before applying it:

```sh
shimmy profile delete build-lab --dry-run
shimmy profile delete build-lab
```

Deleting a shared profile removes only profile-owned files; it never removes
the shared engine. Deleting a profile whose isolated machine has complete
current Shimmy ownership proof permanently destroys that machine and all of
its VM-local containers, images, volumes, build cache, and other data. Running
containers require explicit `--stop-running` acknowledgement. Removal is
journaled so a retry can finish local cleanup after machine deletion.

Legacy-isolated, external, or ambiguously owned machines are preserved and the
command reports that preservation. Machine name or engine binding alone is
never ownership proof.

## Global uninstall

Inspect the complete destructive plan before applying it:

```sh
shimmy admin uninstall --dry-run
shimmy admin uninstall
```

On macOS, ordinary global uninstall removes every shared and isolated machine
whose current host record, guest token, exact connection, provider, and stable
inspect identity all prove that the current installation created it. Inactive
owned isolated machines are removed first and the active owned machine is
removed last. Legacy, external, mismatched, ambiguous, and Linux host-local
engines are reported with a preservation reason and are never deleted.

Removing an owned machine permanently destroys its containers, images,
volumes, build caches, and all other VM-local data. None of that data is
preserved. Running containers block all mutation until the user explicitly
retries with `--stop-running`.

Before the first machine stop or removal, Shimmy validates the complete local
cleanup set and writes one durable journal containing planned order, completed
engines, pending engines, and phase. Machine deletion is irreversible and is
not rolled back. A partial failure retains profiles, commands, engine evidence,
and the journal, then prints the exact retry. Retry accepts an already removed
engine only when journal and current absence agree; a machine or connection
that reappears at that name is a collision.

## Troubleshooting

If `podman info` fails, inspect the selected profile rather than starting an
arbitrary machine. If direct Podman works but a wrapper fails in an AI Agent
sandbox, retry the same wrapper through the outer-command approval boundary.
Approval for `podman info` does not approve Podman nested through a wrapper.

Source validation can avoid the engine entirely:

```sh
./commands/run-tool.sh jq --preview-shim --version
./commands/agent-preflight.sh
```

Use `shimmy admin network` when the host, VM, and container network
perspectives differ. See [Networking tools](network-tools.md).

## Hygiene

Inspect before pruning:

```sh
podman ps --all
podman images
podman system df
```

Podman prune operations and storage resets are outside Shimmy's lifecycle.
Review their effects independently, especially volumes and locally built
images.
