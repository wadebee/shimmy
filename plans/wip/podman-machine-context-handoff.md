# Podman Machine Context Handoff

**Date:** 2026-08-30  
**Purpose:** Resume the macOS Podman machine-context design in a fresh session without repeating the lifecycle implementation or exploratory discussion.

## Requested outcome for the next session

Evaluate and prepare a decision-complete follow-up for binding each macOS Shimmy installation to one stable, observed Podman machine context. Do not reopen the completed hybrid engine-lifecycle design unless this new context boundary requires a deliberate schema or lifecycle revision.

The user reports that the complete default test run takes approximately 70 minutes. Design verification around focused fake-Podman groups and a separate opt-in native acceptance gate; do not add more live VM cycles to the default full suite.

## Repository state at handoff

- Branch: `main`
- HEAD: `b5c8b5ed1255484e8e25c23ec03b585b6dd0702a` (`fix(engine): sync guest marker after write to preserve data integrity`)
- `main` is two commits ahead of `origin/main`.
- The only working-tree change before this handoff was the updated acceptance evidence in `plans/wip/hybrid-podman-engine-lifecycle.md`; this new handoff file is an additional intentional change.
- The hybrid lifecycle plan reports Chunk 4 implementation, focused verification, and native destructive acceptance complete. Explicit final human acceptance and moving the plan to `plans/complete/` remain pending.
- A final `./tests/test.sh --jobs 3` attempt emitted no output for approximately 16 minutes and was interrupted. It provides neither pass nor failure evidence. Relevant focused groups passed, including all six `lib-catalog` tests and all 11 selected engine, activation, and uninstall tests.

## Key discoveries

### Podman resolves multiple state roots

On macOS, unset XDG variables do not mean Podman ignores XDG semantics. Podman applies fallback locations:

```text
XDG_CONFIG_HOME -> $HOME/.config
XDG_DATA_HOME   -> $HOME/.local/share
```

Machine state is split:

```text
registration and locks:
$XDG_CONFIG_HOME/containers/podman/machine/<provider>/

VM disks, EFI state, cache, and related data:
$XDG_DATA_HOME/containers/podman/machine/<provider>/
```

When `XDG_DATA_HOME` is unset, the data fallback is `$HOME/.local/share`. The user's normal Podman 5.8 installation currently uses the `applehv` provider, but provider identity must remain observed rather than hardcoded. Podman versions and configurations may select another provider.

Authoritative Podman references:

- [machine configuration scope](https://docs.podman.io/en/latest/markdown/podman-machine-list.1.html)
- [observed machine configuration and image directories](https://docs.podman.io/en/stable/markdown/podman-machine-info.1.html)
- [supported machine providers](https://docs.podman.io/en/stable/markdown/podman-machine.1.html)

### `podman machine ls` is context-scoped

`podman machine ls` enumerates registrations in the effective Podman configuration context. It is not a global AppleHV inventory. Changing `HOME`, `XDG_CONFIG_HOME`, or `XDG_DATA_HOME` can create a separate collection of machine registrations and data for the same macOS account.

The native acceptance used a disposable effective home and configuration root. Ordinary `podman machine ls` showed only `podman-machine-default`, while the same command under the disposable environment showed `chunk4-external`. This was environmental state-root selection, not a kernel namespace or security boundary.

### Podman removal can leave provider residue

After prior successful machine removals, the user's normal directories contained no Shimmy JSON registration or Shimmy VM disk, but retained small Shimmy-named EFI files, ignition socket nodes, and lock files. Read-only process inspection also found two parentless `gvproxy` processes for `shimmy-default` and no corresponding `vfkit` process.

Podman's troubleshooting guide documents that `podman machine rm` can leave a hanging `gvproxy` process requiring manual termination:

- [Podman troubleshooting: hanging gvproxy after machine removal](https://github.com/containers/podman/blob/main/troubleshooting.md)

This is not evidence that the removed Shimmy VM disks or registrations still exist, but it is an unresolved housekeeping/postcondition concern.

### Disposable acceptance state remains operationally separate

The final native lifecycle acceptance created:

- external fixture `chunk4-external`;
- owned shared machine `shimmy-default`;
- owned isolated machine `shimmy-isolated-one`.

Shimmy's guarded uninstall removed both owned machines and preserved `chunk4-external`, exactly matching the ownership contract. The external fixture remained visible only when Podman was invoked with:

```text
HOME=/private/tmp/shimmy-chunk4-native-20260830-codex/home
XDG_CONFIG_HOME=/private/tmp/shimmy-chunk4-native-20260830-codex/xdg
```

Confirm its current state before any cleanup; do not assume that ordinary `podman machine ls` can see it.

## Current Shimmy implementation

Shimmy currently inherits the invoking process's Podman context.

- `shimmy_engine_podman_run` invokes the resolved Podman binary without normalizing or pinning `HOME` or XDG variables.
- Bootstrap and profile state are XDG-aware; Shimmy configuration lives below `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy`.
- Therefore, changing effective `HOME` or XDG roots can cause a later invocation to address a different Podman machine inventory.
- Per-machine ownership remains fail-closed and redundant. It requires strict engine records, current machine and connection identity, stable inspect evidence, and an exact guest ownership token before destructive action.
- The created-identity fingerprint currently covers machine name, provider, creation time, observed configuration directory, socket path, connection URI, SSH identity path/user, and rootful state.
- The installation does not currently persist a first-class Podman context containing effective user/home plus both machine configuration and image directories.
- On Linux, Shimmy uses the invoking user's native local rootless engine and performs no `podman machine` lifecycle operations.

Relevant code and context:

- `CONTEXT.md`
- `lib/engine/CONTEXT.md`
- `lib/engine/podman.sh`
- `lib/engine/ownership.sh`
- `lib/engine/state.sh`
- `commands/bootstrap.sh`
- `lib/install/lifecycle.sh`
- `lib/install/uninstall.sh`

## Recommended pinned-context design

Treat a **Podman machine context** as installation identity, separate from each individual engine's identity.

Proposed conceptual fields:

```text
uid
effective_home
machine_config_dir
machine_image_dir
provider
```

Required behavior:

1. Fresh macOS bootstrap resolves these values from the actual user environment and `podman machine info` before machine mutation.
2. Bootstrap validates normalized absolute paths and persists one immutable context for the installation.
3. Every later macOS machine query or mutation re-resolves the context before using Podman.
4. Any mismatch fails closed before machine start, stop, creation, removal, connection mutation, or active-engine transition.
5. Shimmy never silently rewrites or unsets `HOME`, XDG variables, or the configured provider to reach a different context.
6. Status and destructive dry-run output expose the recorded and observed context sufficiently to diagnose a mismatch without printing secrets.
7. Individual engine ownership proofs remain necessary. Matching the installation's Podman context does not itself prove ownership of any machine.

This design supports a stable custom XDG configuration while preventing one installation from drifting between multiple Podman inventories.

## Current behavior versus pinned context

| Concern | Current implementation | Recommended pinned-context design |
| --- | --- | --- |
| Podman state selection | Inherited independently on every invocation | Resolved and committed once at bootstrap |
| Effective `HOME`/XDG change | May select a different machine inventory | Detected before mutation and rejected |
| Machine configuration directory | Included indirectly in each machine fingerprint after creation | Also part of installation-wide pre-mutation identity |
| Machine image directory | Not a first-class installation field | Observed and pinned |
| Provider | Recorded per machine | Also checked as part of the installation context |
| Custom stable XDG roots | Supported implicitly | Supported explicitly if they continue matching |
| Ownership authority | Exact host, guest, connection, and inspect proof | Same proof; context matching is an additional prerequisite |
| Cleanup discoverability | Depends on recreating the invoking environment | Recorded context explains where Shimmy created and manages machines |
| Context drift | Can look like absence, collision, or unrelated inventory | Produces a dedicated fail-closed context-mismatch result |
| Test coverage | Fake Podman plus occasional disposable native environments | Focused fake context tests plus a separately scheduled native gate |

## Testing and runtime constraints

- Unit and behavioral lifecycle tests already use fake Podman seams. Add context-resolution, persistence, mismatch, and fail-closed assertions there without creating VMs.
- Avoid another broad lifecycle fixture when an existing scenario can assert the durable context boundary.
- Keep live creation, restart, and destructive removal out of the default full suite.
- Run one explicit native macOS acceptance workflow only when the context design changes. It should be separately scheduled or manually invoked and should report duration and exact mutations.
- Native cleanup must use the same recorded environment through Podman's supported lifecycle first, verify registrations/connections/data, and report residual provider artifacts or helper processes rather than silently hiding them.
- Do not treat a successful `podman machine rm` exit alone as proof of immaculate provider housekeeping.

## Unresolved decisions

1. **Schema boundary:** Decide whether the Podman context belongs in a new installation-level manifest or extends the existing engine aggregate schema. The existing plan treated identity-schema changes as one review unit across producers, readers, validators, journals, rollback, and fixtures.
2. **Upgrade boundary:** Decide whether this is fresh-bootstrap-only with old installations removed by their creating version, or whether a safe adoption/migration is required. Do not infer context ownership from existing machine names.
3. **Effective user identity:** Define the exact stable user fields. `uid` plus normalized effective `HOME` may be sufficient; resolving a separate macOS directory-service home adds platform coupling and needs justification.
4. **Observation source:** Define a stable parser for `podman machine info` across supported Podman versions and providers, including behavior when no machine exists yet.
5. **Provider changes:** Decide whether a changed configured provider is always a hard context mismatch, including when all owned machines are absent.
6. **XDG changes after bootstrap:** Define the recovery diagnostic and whether status may read a recorded context without mutating under the currently mismatched environment.
7. **Shimmy configuration discovery:** Clarify how an installed launcher finds its installation if the user's `XDG_CONFIG_HOME` changes while Podman context pinning correctly refuses mutation.
8. **Removal postconditions:** Decide whether Shimmy should only verify Podman registrations, connections, and VM disks, or also detect provider-specific EFI/socket/helper residue. Directly deleting or killing provider internals risks coupling Shimmy to Podman implementation details.
9. **Native gate environment:** Select a sustainable native acceptance environment and cadence that does not add to the user-reported approximately 70-minute default suite.
10. **Current plan closure:** Obtain explicit human acceptance of Chunk 4, resolve any remaining disposable fixture cleanup, commit the retained evidence, and move `hybrid-podman-engine-lifecycle.md` to `plans/complete/` independently of this follow-up design.

## Suggested first actions in the next session

1. Read `AGENTS.md`, `CONTRIBUTING.md`, root and engine `CONTEXT.md`, this handoff, and the current hybrid lifecycle plan.
2. Inspect git status and preserve the uncommitted retained-plan evidence.
3. Resolve the current external fixture and human acceptance gate without broadening that completed implementation.
4. Inspect the exact `podman machine info --format json` output for the supported Podman 5.8 environment using read-only commands.
5. Decide the installation-level schema and fresh-install/upgrade boundary before editing implementation or tests.
6. Produce a focused verification matrix that does not require rerunning the approximately 70-minute full suite during design iteration.
