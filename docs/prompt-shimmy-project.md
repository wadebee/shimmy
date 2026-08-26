# Shimmy project guidance

Read root `CONTEXT.md` and every retained child context on the path to changed
files under `commands/`, `lib/`, or `tests/`. Tool and management-plugin
directories do not own context files.

## Architecture

- Root `bootstrap.sh` creates and activates a fresh `default` profile from a
  clean committed local `main` checkout. It derives the installation from
  `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy` and accepts only `--shell` and
  `--no-startup`.
- Installed management uses only the `admin`, `profile`, `catalog`, `shim`, and
  `ai-skill` groups.
- The installation owns one immutable catalog named `default`; profiles pin a
  validated generation and fingerprint.
- Profiles live at `profiles/<name>`, use arbitrary safe names, and carry only
  schema-2 manifests.
- `tools/<tool>/tool.conf` declares the default version and optional selector.
  Concrete versions own `run.sh`, `refresh.sh`, `smoke.conf`, `image.conf`, and
  a `container/` context when locally built.
- Canonical management and tool skills remain in the source/catalog payload.
  Active profiles materialize bundles and reconcile exact user skill links.
  The repository has no generated `.agents/skills` adapter tree.

## Runtime rules

Keep runtime and management shell POSIX-compatible. Preserve `$PWD:/work`,
tool-specific `SHIMMY_*` settings, argument forwarding, and `--preview-shim`
unless a documented contract requires otherwise. Use the shared Podman helper
for platform and engine checks and the shared image helper for image metadata,
local-build inputs, and cache identity. Shimmy does not install or provision
Podman itself. On macOS, its control plane transactionally owns shared and
explicit isolated machine lifecycle without adopting pre-existing machines.

Registry redirects are an explicit client capability. Skopeo is the initial
tool-container consumer, and `shimmy catalog verify` inherits its active-profile
policy. `shimmy catalog refresh <tool@version> [--dry-run]` also uses those exact
active-profile jq/Skopeo and authentication boundaries while updating only an
existing version's source `image.conf` from clean attached local `main`. It
must reject immutable-only discovery and cross-repository mirror boundaries,
re-resolve tags before mutation, and leave commit and publication explicit. Do
not add policy mounts to unrelated runtimes without focused review.

## Tool additions

Create a self-contained `tools/<tool>/` directory. Do not add tool-name case
statements or implementation-name maps to shared code. Choose `external` or
`local-build`, pin every repository default and non-`scratch` base to an
immutable multi-platform top-level digest, and require `linux/amd64` and
`linux/arm64`.

Validate metadata and previews, then use an installed active profile for:

```sh
shimmy catalog verify --tool <tool>@<version>
shimmy shim add <tool>@<version>
shimmy shim test <tool>@<version>
```

Native acceptance requires the version-owned smoke on Linux `amd64` and Apple
Silicon macOS `arm64`; cross-emulation is not acceptance.

## Profiles and agents

Use the exact profile launcher for status and activation:

```sh
profile_root=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<name>
"$profile_root/bin/shimmy" profile status
"$profile_root/bin/shimmy" profile activate <name> --dry-run
"$profile_root/bin/shimmy" profile activate <name>
. "$profile_root/shell-init.sh"
```

Running workloads require separate confirmation before `--stop-running`.
Missing recorded macOS machines are not recreated or adopted. Fresh shared and
isolated provisioning belongs only to Shimmy bootstrap/create/clone
transactions. Agents never substitute direct machine lifecycle commands.
Machine creation journals initializing intent before Podman mutation and
removes only an exactly identified created machine. An ambiguous init or
incomplete removal retains its journal and installation root for explicit
recovery; agents do not treat the retained name as ownership evidence.
Sourcing selects PATH; separate agent tool calls do not retain that sourcing.

Global uninstall removes completely proven owned macOS machines by default and
preserves legacy, external, ambiguous, and Linux host-local engines. Require a
dry run and disclose permanent loss of containers, images, volumes, build
caches, and all other VM-local data. Partial deletion uses forward recovery;
never claim rollback of a removed VM.

If a known Shimmy wrapper has an approved safe outer prefix, run the requested
operation with escalation on the first attempt. Sandbox-only engine errors mean
unverified, not inactive. Retry the same wrapper outside the sandbox and use
profile initialization only when that call proves an engine or profile fault.

## Verification

Run focused groups during implementation and `./tests/test.sh` as the final
integration gate. Inspect executable modes, context links, final asset
inventory, and `git diff --check`.
