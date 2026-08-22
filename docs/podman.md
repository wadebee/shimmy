# Podman for Shimmy

Every Shimmy tool wrapper runs a short-lived container through Podman. Podman
is an explicit dependency; Shimmy does not install it, provision machines, or
adopt existing machines.

Official installation guidance: <https://podman.io/docs/installation>

## Initial setup

Verify the CLI from the shell that will run Shimmy:

```sh
podman --version
podman info
```

On macOS, create the deterministic machine for each intended profile in a
normal user shell before bootstrap or profile creation:

```sh
podman machine init shimmy-default
podman machine init shimmy-team-one
```

If the configuration home is outside the normal home share, use the exact
same-path `--volume` form printed by Shimmy. Do not rename or substitute
`podman-machine-default`; Shimmy does not adopt or migrate it.

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

On Linux, activation requires a local rootless engine and manages only the
Shimmy-owned user registry drop-in. On macOS, profile `<name>` owns the
pre-existing `shimmy-<name>` machine. Only one Podman-managed VM can run, so a
profile switch may stop an idle alternate VM. Shimmy never directly creates,
deletes, renames, or adopts a VM.

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

If status reports that the recorded active profile's deterministic machine is
stopped, recover it through the ordinary named activation workflow:

```sh
"$profile_root/bin/shimmy" profile status
"$profile_root/bin/shimmy" profile activate team-one --dry-run
"$profile_root/bin/shimmy" profile activate team-one
```

The dry run reports the managed machine start and registry projection without
changing either. Do not substitute a direct `podman machine start`; activation
also validates and reconciles registry, connection, active-record, and exact
AI-skill-link authority.

If status reports a stale registry projection, use the exact named command it
prints, normally:

```sh
"$profile_root/bin/shimmy" profile activate team-one --restart
```

The ordinary workload acknowledgement boundary still applies.

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
