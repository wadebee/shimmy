# Profile Podman Activation and Registry Redirect Plan

## Objective

Add a profile-aware Shimmy control plane that treats Podman engine selection and
strict registry redirection as one coherent profile lifecycle.

On macOS, each installed profile is bound by convention to one pre-existing
rootless Podman machine and its rootless system connection:

```text
default  -> shimmy-default
upstream -> shimmy-upstream
```

An explicit `shimmy profile activate` operation must stop an idle alternate
Podman machine, start the invoking profile's deterministic machine, select its
connection as Podman's global default, install or validate that machine's
profile-specific registry projection, and verify the resulting engine. If the
alternate machine has running containers, activation must fail before stopping
it unless the caller supplies the explicit `--stop-running` acknowledgement.
The canonical `shimmy-init`, `shimmy-install`, and `shimmy-escalation` skills
must use this control plane from AI Agent shells with narrow outer-command
approvals.

Each installed profile also owns one strict generated containers/image
version-2 `registries.conf`. A mapping such as:

```text
docker.io/bats/bats@sha256:<digest>
  -> docker.my-corp-repo.com/bats/bats@sha256:<digest>
```

uses a `[[registry]]` table containing `prefix` and replacement `location`.
Shimmy continues to pass the logical digest-pinned reference; the shared
containers/image resolver used by Podman, Buildah, and Skopeo performs
longest-prefix matching and physical endpoint rewriting. The feature must not
use fallback-capable `[[registry.mirror]]` tables or introduce a Shimmy-specific
image mapper.

Success means:

- `shimmy profile status` reports the invoking profile's deterministic engine,
  connection, activation, workload, environment-override, and registry
  projection state without mutation;
- `shimmy profile activate [--restart] [--stop-running] [--dry-run]` is the only
  Shimmy operation that starts or stops a Podman machine, is bound to the
  invoking installed profile, and leaves the previous engine selected when a
  pre-stop validation fails;
- macOS activation makes `shimmy-default` or `shimmy-upstream` the sole running
  Podman-managed VM and global default rootless connection, while Linux
  activation selects the invoking profile's registry policy without managing a
  VM;
- a tool wrapper from an inactive macOS profile fails with targeted activation
  guidance instead of silently using its sibling profile's engine;
- `shimmy profile redirect --prefix ... --location ...` atomically upserts a
  strict redirect in only the invoking profile, and `list` and `remove` honor
  the same ownership boundary;
- Podman and explicitly configured registry clients use the active profile's
  policy, while inactive profiles can be prepared without contacting or
  switching the engine;
- AI Agent skills may perform an explicitly requested profile activation using
  the exact profile-local launcher approval, but never provision, delete, or
  rename Podman machines; and
- installation, update, uninstall, rollback, tests, skills, README, bootstrap,
  contributor guidance, Podman guidance, and tool guidance all describe the
  same activation and registry semantics.

Explicit exclusions:

- Do not install Podman or run `podman machine init`, `rm`, `reset`, `set`, or
  other provisioning/destructive machine operations from Shimmy code, tests,
  or agent skills. Users create the required named machines explicitly with
  Podman. Shimmy never adopts or renames `podman-machine-default`.
- Do not make sourcing `shell-init.sh` start, stop, or restart a VM. Persistent
  shell startup remains non-mutating and only selects PATH; engine activation is
  an explicit control-plane operation.
- Do not add `--machine`, `--profile`, arbitrary profile names, a machine-name
  environment override, or compatibility aliases. The invoking launcher fixes
  both profile and machine identity.
- Do not automatically interrupt running containers. Only the explicit
  `--stop-running` option may acknowledge that consequence, and the command must
  report the affected containers before mutation or in dry-run output.
- Do not automate arbitrary remote Podman services, rootful Linux engines, or
  Windows in this version. Linux support is the current user's local rootless
  engine; VM lifecycle automation is Darwin-only.
- Do not set or clear `CONTAINER_CONNECTION`, `CONTAINER_HOST`,
  `CONTAINERS_REGISTRIES_CONF`, or
  `CONTAINERS_REGISTRIES_CONF_OVERRIDE` in a parent shell. Activation detects
  overrides that would defeat its selected engine or registry policy and fails
  before mutation with corrective guidance.
- Do not modify operator-owned main `registries.conf` files or non-Shimmy
  drop-ins. Shimmy owns only profile files and the exact host or machine
  projections recorded below.
- Do not manage registry credentials, `auth.json`, Podman secrets, corporate
  certificate authorities, `policy.json`, signature storage, TLS-disable
  settings, `insecure`, `blocked`, short-name aliases, or unqualified search
  registries.
- Do not alter checked-in image references, `image.conf`, Containerfiles,
  refresh hooks, image overrides, or implement image rewriting in
  `lib/runtime/image.sh` or `lib/images/images.sh`.
- Do not inject registry configuration into every tool container. Version 1
  opts in only verified containers/image registry clients; Skopeo is the first.
- Do not edit generated copies under `.agents/skills/`. Canonical skill changes
  live in `plugins/shimmy/skills/`, `tools/<tool>/SKILL.md`, and the generic
  template; external adapters change only through an explicit `shimmy skills
  update` operation outside implementation.

Authoritative upstream references:

- [containers/image registry configuration](https://github.com/containers/container-libs/blob/main/image/docs/containers-registries.conf.5.md)
  defines `prefix`, `location`, mirror fallback, and longest-prefix behavior.
- [containers/image registry implementation](https://github.com/containers/image/blob/main/pkg/sysregistriesv2/system_registries_v2.go)
  is the implementation authority for configuration merging, pull-source
  ordering, and the process-local registry cache.
- [Podman machine start](https://docs.podman.io/en/latest/markdown/podman-machine-start.1.html)
  documents named start, the one-active-machine constraint, and current
  connection-update behavior.
- [Podman machine stop](https://docs.podman.io/en/latest/markdown/podman-machine-stop.1.html)
  documents named VM shutdown.
- [Podman machine init](https://docs.podman.io/en/latest/markdown/podman-machine-init.1.html)
  documents explicit names, rootless operation, generated root/rootless system
  connections, and host-volume configuration. It is user guidance, not a
  Shimmy mutation surface.
- [Podman machine list](https://docs.podman.io/en/latest/markdown/podman-machine-list.1.html)
  documents the `Name`, `Running`, `RemoteUsername`, and related discovery
  fields.
- [Podman system connection list](https://docs.podman.io/en/latest/markdown/podman-system-connection-list.1.html)
  documents connection names, URIs, default state, and machine association.
- [Podman environment variables](https://docs.podman.io/en/latest/markdown/podman.1.html#environment-variables)
  documents that `CONTAINER_CONNECTION` and `CONTAINER_HOST` override the
  default connection and that registry variables replace normal configuration
  discovery.
- [Podman troubleshooting](https://github.com/containers/podman/blob/main/troubleshooting.md)
  confirms that macOS registry configuration must be installed inside the
  Podman machine.

## Target layout and terminology

### Public command surface

```text
shimmy profile
shimmy profile --help

shimmy profile status [--format human|manifest]

shimmy profile activate [--restart] [--stop-running] [--dry-run]

shimmy profile redirect --help
shimmy profile redirect --prefix <logical-prefix> --location <physical-location>
                        [--dry-run]
shimmy profile redirect list [--format human|manifest]
shimmy profile redirect remove (--prefix <logical-prefix> | --all)
                               [--detach] [--dry-run]
```

`profile` is a launcher-level command group. `status`, `activate`, and
`redirect` are sibling subcommands. The option-bearing `profile redirect` form
is an idempotent upsert; there is no `set`, `mirror`, `registries`, or
compatibility alias. Every operation is bound to the profile containing the
invoked installed launcher. There is no repository `shimmy` launcher.

Human profile switching is intentionally two-phase because an executable
cannot change its parent shell's PATH:

```sh
profile_root=${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream
"$profile_root/bin/shimmy" profile activate
. "$profile_root/shell-init.sh"
```

Activation prints the exact source command on success. Agents use the absolute
target launcher for activation and subsequent management operations; when a
tool must run in a separate agent shell, they either invoke its absolute
profile dispatcher or source the target `shell-init.sh` in that same command.

### Stable definitions

- **Invoking profile** is the canonical `default` or `upstream` profile that
  owns the installed launcher used for the command.
- **Expected machine** is `shimmy-<invoking-profile>` on Darwin. The mapping is
  code-defined and cannot be overridden.
- **Expected rootless connection** has exactly the same name as the expected
  machine. The `-root` connection is not the normal profile engine.
- **Profile activation** is an explicit state transition. On Darwin it makes
  the expected machine the only running Podman-managed VM, validates its
  rootless connection and registry projection, and sets that connection as
  Podman's global default. On Linux it atomically selects the profile's user
  registry drop-in and validates the local rootless engine.
- **Shell selection** is sourcing `shell-init.sh` to put one profile's `bin/`
  first on PATH. It does not imply engine activation.
- **Active profile** on Darwin means the expected machine is running, no other
  machine is running, the expected rootless connection is Podman's global
  default, no overriding connection environment is present, `podman info`
  succeeds through that connection, and any recorded registry projection is
  valid. On Linux it means the exact active host registry link points to the
  invoking profile and the local rootless engine validates it.
- **Running workload** means at least one container reported by `podman
  --connection <running-machine> ps`. Activation does not infer safety from VM
  state alone.
- **Authoritative profile config** is the generated regular non-symlink
  `<profile-root>/registries.conf`.
- **Linux active link** is
  `${XDG_CONFIG_HOME:-$HOME/.config}/containers/registries.conf.d/shimmy-active-profile.conf`.
  It exists only for local-rootless Linux activation.
- **Darwin machine projection** is
  `/etc/containers/registries.conf.d/shimmy-profile.conf` inside the expected
  machine. It points directly to the invoking profile's authoritative config at
  the same absolute host-home path exposed inside the VM; it never points to a
  global active-profile link.
- **Projection record** is the optional validated
  `<profile-root>/machine-projection.txt` that records successful Shimmy
  ownership of that exact machine link. It prevents uninstall from leaving a
  dangling external projection.
- **Registry-client mount** is a read-only bind of the active invoking
  profile's authoritative config to
  `/etc/containers/registries.conf.d/shimmy-profile.conf` inside Skopeo.
- **Logical prefix** is a fully qualified registry or registry/repository
  namespace retained in Shimmy image metadata, such as `docker.io` or
  `registry.redhat.io/openshift4`.
- **Physical location** is the replacement registry or registry/path prefix,
  such as `docker.my-corp-repo.com` or
  `registry.corp.example/redhat`.
- **Redirect** is a version-2 `[[registry]]` table containing only `prefix` and
  `location`. It has no alternate source and no upstream fallback.

### Repository layout

```text
commands/profile.sh                 profile help, parsing, and orchestration
lib/profile/activation.sh           profile/machine state transition helpers
lib/registries/CONTEXT.md           registry ownership and projection invariants
lib/registries/registries.sh        config, link, projection, mount, and rollback
tests/commands/profile.sh           public lifecycle and transaction coverage
tests/lib/profile-activation.sh     isolated state-machine/helper coverage
tools/skopeo/versions/1.22/run.sh   active-profile read-only config mount
```

The complete `commands/`, `lib/`, and `tests/` trees are already materialized
into every profile. Top-level profile data files require explicit staging,
preservation, validation, rollback, and uninstall handling.

### Managed paths and formats

```text
<config-home>/shimmy/profiles/default/registries.conf
<config-home>/shimmy/profiles/upstream/registries.conf
<profile-root>/machine-projection.txt                # optional, Darwin only
<config-home>/shimmy/.profile-activation.lock        # transient mkdir lock
<config-home>/containers/registries.conf.d/shimmy-active-profile.conf
                                                      # Linux symlink only
/etc/containers/registries.conf.d/shimmy-profile.conf
                                                      # Darwin VM symlink only
```

The generated registry file is narrow and self-identifying:

```toml
# Managed by Shimmy for profile "default". Use `shimmy profile redirect`; do not edit.
# shimmy_registry_redirects_version=1

[[registry]]
prefix = "docker.io"
location = "docker.my-corp-repo.com"
```

The projection record is also strict and profile-specific:

```text
shimmy_machine_projection_version=1
profile=default
machine=shimmy-default
target=/absolute/config/home/shimmy/profiles/default/registries.conf
config_fingerprint=<cksum>-<size>
```

## Recorded design decisions

1. **Use the shared containers/image contract.** Shimmy passes the logical,
   digest-pinned image reference unchanged. It does not implement another
   resolver or rewrite image metadata.
2. **Make profile activation explicit.** `shell-init.sh`, managed startup files,
   profile installation, and update never contact Podman or mutate machine
   state. Only `shimmy profile activate` owns engine switching.
3. **Bind activation to the invoking profile.** `default` always maps to
   `shimmy-default`; `upstream` always maps to `shimmy-upstream`. There is no
   target profile or machine argument and no environment override.
4. **Require pre-existing Podman machines.** A missing expected Darwin machine
   fails without mutation and prints the exact user-shell command `podman
   machine init shimmy-<profile>`, including same-path volume guidance when the
   config home is not covered by the normal home share. Shimmy and its skills do
   not run that command.
5. **Do not adopt the Podman default machine.** `podman-machine-default` and its
   storage remain external. Migration guidance explains that Podman has no
   Shimmy-supported rename/adoption path; users create named machines and move
   or retire prior workloads themselves.
6. **Treat Darwin activation as a global engine transition.** Podman supports
   only one active managed VM. An explicit activation may stop one idle running
   machine, including an externally named machine, then start the expected one.
   The command reports both names before mutation.
7. **Guard running containers.** Before stopping a reachable running machine,
   query its rootless connection and list running container IDs/names. A
   non-empty result fails before mutation unless `--stop-running` is present.
   Failure to inspect workloads also fails closed. `--stop-running` is an
   acknowledgement, not a promise that rollback can resume containers.
8. **Keep restart explicit.** If the expected machine is already active,
   `profile activate` is idempotent and does not stop it. `--restart` requests a
   stop/start of the expected machine and uses the same workload guard.
   `--stop-running` is valid only when activation will stop a running machine.
9. **Select the connection deliberately.** Validate the exact expected
   rootless machine connection, start with stdin detached so Podman cannot
   prompt to update a connection, and commit the global connection only with
   `podman system connection default <expected>`. Do not depend on
   `podman machine start --update-connection`; installed Podman 5.8.1 lacks that
   option even though newer upstream documentation includes it.
10. **Reject connection overrides before activation.** Non-empty
    `CONTAINER_CONNECTION` or `CONTAINER_HOST` makes the parent shell ignore the
    global default and therefore causes activation and restart to fail before
    mutation. Status reports the exact masking variable without exposing
    secrets. Runtime affinity may accept no silent mismatch.
11. **Make external-state rollback best effort and explicit.** Hold one
    config-root activation lock; snapshot the running machine and default
    connection; validate all discoverable preconditions; stop the prior
    machine; start and validate the target; reconcile projection; and change
    the global default last. On a post-stop failure, stop only a newly started
    target, restart the prior machine, restore its prior default connection,
    and report each rollback result. A `--stop-running` transition is documented
    as potentially unable to restore interrupted workloads.
12. **Do not guess through concurrent activation.** Use a validated adjacent
    `mkdir` lock, fail visibly on contention, never delete an apparently stale
    lock automatically, and re-read machine/workload/default state after taking
    the lock.
13. **Keep Linux local and rootless.** Linux activation manages no VM and no
    Podman system connection. It atomically switches the Linux active link to
    the invoking profile and validates a fresh local rootless Podman process.
    Remote or rootful Linux fails before activation mutation with manual
    guidance.
14. **Separate PATH selection from engine state.** A shell can have profile A
    on PATH while profile B's machine is active. On Darwin, installed wrappers
    detect that mismatch and fail with the absolute profile-A activation
    command. They never run against the sibling engine. Source-checkout previews
    and runtimes remain outside this installed-profile affinity check.
15. **Make registry configuration profile-owned.** Every valid current profile
    has one required regular non-symlink `registries.conf`. Fresh installs and
    one-time upgrades create an empty valid file; later install/update
    transactions preserve its validated bytes.
16. **Project directly into each Darwin machine.** The fixed machine-side link
    targets that machine's owning profile config directly. This removes the
    macOS host-global active-link race and means stopped profile machines retain
    their own policy. Verify same-path readability inside the VM before link
    installation; never copy profile content into the VM.
17. **Record external projection ownership and applied policy.** Create the
    projection record only after the exact VM link is installed and validated.
    Record the deterministic POSIX `cksum`/size fingerprint of the authoritative
    config that the newly started or restarted service is expected to read.
    Remove the record only after an exact detach or after proving the expected
    machine no longer exists. Profile and global uninstall refuse while a valid
    record remains, preventing a dangling link when the profile file is deleted.
18. **Make first projection part of activation.** After starting a previously
    stopped target, install/validate the VM link through a fixed root SSH script
    before the first engine API validation that may load registry policy, then
    record the current config fingerprint. If an already-running target needs
    projection repair or its recorded fingerprint differs from the current
    config, ordinary activation fails with the exact `--restart` command;
    restart/workload rules apply before registry readiness can be reclaimed.
19. **Use a Linux-only active host link.** Linux activation atomically points
    the distinctive user drop-in to the invoking profile. It refuses foreign
    files, directories, unsafe parents, dangling links, and unrecognized
    symlink targets. Darwin does not create this host link.
20. **Expose only strict redirects.** Accept exact non-wildcard registry or
    namespace prefixes and physical registry/path locations. Reject schemes,
    tags, digests, empty or traversing path segments, trailing slashes, quotes,
    whitespace, and unsupported characters; allow ports.
21. **Make redirect mutation independent of engine switching.** Upsert and
    remove edit only the invoking profile. They never start, stop, activate, or
    restart a machine. Inactive edits receive local schema validation. Active
    Linux edits validate with a fresh local process. Active Darwin edits print
    the exact `shimmy profile activate --restart` follow-up because the remote
    Podman service may retain a process-local registry cache.
22. **Make redirect operations deterministic.** Upsert is keyed by exact logical
    prefix, identical input is a no-op, replacement preserves other entries,
    output is prefix-sorted, exact removal preserves siblings, and `--all`
    leaves the required empty managed file.
23. **Keep detach explicit.** `profile redirect remove --all --detach` removes
    the Linux active link only when it points to the invoking profile. On
    Darwin it removes only the exact recognized machine projection and record;
    the expected machine must be running/reachable or proven absent. It never
    starts or stops a machine. A stopped existing machine produces exact
    activation/start guidance.
24. **Use atomic profile transactions.** Serialize config edits with a
    profile-adjacent `mkdir` lock; validate the complete existing file; render
    a non-`.conf` same-directory temporary regular file with mode `0644`; rename
    atomically; and restore the exact prior file/link/record on post-commit
    validation failure. Clean only validated known temporary paths.
25. **Fail closed on ownership anomalies.** Refuse symlinked or non-regular
    authoritative files, wrong-profile/version markers, malformed generated
    structure, duplicate prefixes, foreign host/VM links, invalid projection
    records, unsafe parents, and unexpected lock state. Never adopt an
    unrecognized path.
26. **Keep dry runs side-effect free.** Activation dry-run may inspect machine,
    connection, and running-container state but creates no lock and performs no
    stop/start/default/projection mutation. Redirect dry-run validates and
    renders the full candidate plus active/restart/detach effects without
    filesystem, SSH, or Podman mutation.
27. **Respect containers configuration precedence.** Active operations fail
    before mutation when `CONTAINERS_REGISTRIES_CONF` or
    `CONTAINERS_REGISTRIES_CONF_OVERRIDE` is non-empty. List/status reports the
    masking state. Preserve operator main files and drop-ins and validate the
    effective engine configuration rather than claiming Shimmy is the only
    source.
28. **Mount only into verified registry clients.** Skopeo mounts the invoking
    profile config read-only only when that same profile is active and the
    config/projection state is valid. Missing active state omits the mount only
    when no Shimmy activation exists; a profile mismatch or damaged active
    state fails closed. `shimmy images verify` inherits this through its
    profile-local Skopeo runtime.
29. **Account for registry caching.** containers/image caches parsed registry
    policy inside a long-running process. A newly activated Darwin machine sees
    its already-projected file at service use and records that config
    fingerprint; changing the active profile file makes the fingerprint stale
    and requires explicit `profile activate --restart` before Podman policy is
    claimed current. Fresh Skopeo containers and local Linux Podman processes
    read current policy without that VM restart.
30. **Update canonical agent behavior.** `shimmy-install` owns target-profile
    selection and invokes its absolute `profile activate`; `shimmy-init` may
    now run that exact activation command from an AI Agent shell after narrow
    approval; `shimmy-escalation` remains the wrapper-smoke approval owner but
    delegates inactive-machine remediation to `shimmy-init`.
31. **Keep agent authority narrow.** An ordinary wrapper failure permits
    read-only inspection and an approval request for the exact absolute
    `<profile-root>/bin/shimmy profile activate` command. If the workload guard
    trips, the skill reports containers and asks for explicit user confirmation
    before adding `--stop-running`. No skill requests a broad `podman`, shell,
    or scripting-language prefix or runs machine provisioning/removal.
32. **Preserve canonical/exported skill ownership.** Change the three canonical
    management skills and the canonical generic/tool profile-selection text.
    Verify portable and target exports contain the new workflow. Do not
    silently rewrite existing repository/home adapters; documentation tells
    users to run explicit `shimmy skills update` after accepting the new
    catalog generation.
33. **Keep authentication and trust separate.** A physical registry must serve
    the requested digest and may require separate login, CA, or signature
    policy. Shimmy does not copy credentials or weaken TLS/signature checks.
    Skopeo's existing auth-secret behavior remains unchanged.
34. **Scope redirection to image reads.** Document and test pull, run-on-miss,
    build-base, Skopeo inspect/copy-source, and image verification. Do not claim
    push, search, or registry-wide network interception.

## Verified implementation inventory

This is a verified baseline, not permission to ignore dependencies discovered
during implementation.

- `lib/install/launcher-template.sh` owns installed command help/dispatch and
  currently has no `profile` group.
- `lib/install/startup.sh` renders `shell-init.sh` as PATH-only initialization.
  That non-mutating boundary should be preserved; activation is new installed
  control-plane behavior, not generated startup behavior.
- Root `install.sh` sources the generated shell init after bootstrap. It must
  not activate a VM implicitly, but its help and success guidance must point to
  the explicit activation step.
- `lib/profile/profile.sh` resolves canonical profile paths, validates manifest
  version 2 and the materialized structure, and is the natural owner for
  deterministic machine/config path derivation.
- `lib/runtime/podman.sh` resolves `/opt/podman/bin/podman`, performs generic
  readiness/platform checks, and derives privileged connections. It needs
  reusable read-only machine/connection/affinity primitives, while lifecycle
  transactions belong in `lib/profile/activation.sh`.
- `lib/install/profile-assets.sh` copies complete control trees but explicitly
  stages, backs up, commits, and restores top-level files. `registries.conf` and
  the optional projection record must join those transactions.
- `lib/install/uninstall.sh` currently removes only profile-owned paths and
  never inspects external machine projections. It must refuse recorded
  projection ownership until explicit detach; it must never stop or remove a
  machine during uninstall.
- `commands/catalog.sh`, `commands/images.sh`, and `commands/skills.sh` provide
  command-group parsing/help patterns. `commands/status.sh` remains the broad
  installed-profile/catalog report; engine lifecycle inspection belongs in the
  new `shimmy profile status` and must not make ordinary status depend on
  Podman.
- `commands/README.md`, `README.md`, `BOOTSTRAP.md`, `docs/podman.md`,
  `CONTRIBUTING.md`, `AGENTS.md`, and `docs/prompt-shimmy-project.md` currently
  describe profile selection as sourcing only and generic `podman machine
  start`; all are change surfaces.
- All canonical `tools/*/SKILL.md` files and
  `docs/templates/generic-shim/SKILL.md` repeat the source-only profile switch
  workflow. Update that common text semantically and classify tool-specific
  occurrences rather than mechanically replacing unrelated uses of “profile”.
- `plugins/shimmy/skills/shimmy-init/SKILL.md` currently forbids agent-started
  machines; `shimmy-install` describes source-only switching; and
  `shimmy-escalation` redirects stopped-machine recovery to the user. All three
  are required change surfaces. `shimmy-create-tool` and
  `shimmy-tool-local-build` need only consistency review unless their shared
  readiness wording contradicts the new workflow.
- `plugins/shimmy/.agent-plugin/plugin.json` describes the packaged control
  plane and should mention profile activation/machine lifecycle without
  changing the plugin version solely for this implementation plan.
- `tests/commands/skills.sh` owns canonical skill inventory/export behavior and
  checked-in adapter fingerprint checks. Canonical changes require export
  assertions, not edits to generated `.agents/skills/` copies.
- `tools/skopeo/versions/1.22/run.sh` is the current direct containers/image
  client; its tests, guide, and canonical skill own the mount contract.
  `commands/images.sh` and `lib/images/images.sh` call the profile-local Skopeo
  runtime and therefore inherit the mount without reference rewriting.
- `tools/oc/SKILL.md` currently contains registry mirror guidance and must use
  strict redirect terminology while retaining Red Hat signature-policy
  caveats. `tools/task` guidance concerning explicit `CONTAINER_HOST` must
  explain its conflict with deterministic profile activation.
- `tests/commands/management.sh` enumerates launcher help and profile binding;
  `profiles.sh`, `startup.sh`, `onboarding.sh`, `lifecycle.sh`, `install.sh`,
  and `skills.sh` cover the affected ownership and guidance boundaries.
  `tests/test.sh` explicitly registers test modules.
- `tests/context-tree.sh` enumerates retained `lib/` contexts, so the new
  `lib/registries/CONTEXT.md` and test modules require coordinated context and
  runner changes.
- The default suite uses disposable XDG/HOME state and must never stop/start a
  developer VM. Management state-machine tests may use a purpose-built Podman
  command seam, but that does not replace native live acceptance and may not be
  used to claim tool-runtime behavior.
- Current local inspection found Podman 5.8.1, one running
  `podman-machine-default`, matching rootless/root connections, and no
  `--update-connection` option in local `podman machine start --help`. The new
  deterministic machines therefore require explicit user provisioning, and
  connection selection must use the stable `podman system connection default`
  operation instead of assuming a newer start flag.
- Upstream states that only one Podman-managed VM may run. Machine init creates
  same-name rootless and `-root` connections, and `CONTAINER_CONNECTION` or
  `CONTAINER_HOST` overrides the global default.
- The containers/image registry loader caches parsed policy per process and
  exposes explicit cache invalidation for long-running callers. This supports a
  required Darwin restart boundary after active policy edits.
- `plans/registry-image-remap.md` is an unrelated untracked draft proposing a
  Shimmy-specific mapper. It remains untouched and is superseded for this
  request by this containers/image-native plan.

## Unresolved

None.

## Progress Checklist

- [ ] Chunk 1 — Add explicit profile engine activation and update canonical agent/profile workflows (active only after explicit approval)
- [ ] Chunk 2 — Add strict profile registry redirects, engine projection, Skopeo integration, and lifecycle completion (blocked on accepted Chunk 1)

## Execution protocol

For every chunk:

1. Read `AGENTS.md`, `CONTEXT.md`, every child context on the path to a changed
   file, this plan, and the chunk's target files.
2. Execute only that chunk's scope.
3. Run its verification checklist and record `[x]`, `[ ]`, or `[~]` with notes.
4. Update the cumulative **Lessons learned** block.
5. Summarize changes, tests, failures, uncertainties, and remaining risks.
6. Stop for human review and explicit acceptance before starting the next
   chunk.

Repository paths in this plan are relative to `<repo>` so it remains portable
across workstations and sessions.

## Chunk 1 — Profile engine activation and agent workflows

### Goal

Deliver a coherent, independently useful `shimmy profile status/activate`
control plane with deterministic Darwin machines, workload-aware switching,
connection affinity, rollback, non-mutating shell initialization, canonical
agent behavior, tests, and user/contributor guidance. This chunk does not add
registry files or redirect commands.

### Files

Primary control plane and contexts:

- `commands/profile.sh` (new, executable)
- `commands/CONTEXT.md`
- `lib/profile/activation.sh` (new)
- `lib/profile/profile.sh`
- `lib/profile/CONTEXT.md`
- `lib/runtime/podman.sh`
- `lib/runtime/CONTEXT.md`
- `lib/install/launcher-template.sh`
- `lib/install/startup.sh`
- `lib/install/install.sh`
- `lib/install/CONTEXT.md`
- `install.sh`
- `CONTEXT.md`

Tests and test contexts:

- `tests/commands/profile.sh` (new; activation portion)
- `tests/lib/profile-activation.sh` (new)
- `tests/commands/management.sh`
- `tests/commands/profiles.sh`
- `tests/commands/startup.sh`
- `tests/commands/onboarding.sh`
- `tests/commands/install.sh`
- `tests/commands/skills.sh`
- `tests/commands/CONTEXT.md`
- `tests/lib/CONTEXT.md`
- `tests/CONTEXT.md`
- `tests/test.sh`

Canonical skills and guidance:

- `plugins/shimmy/skills/shimmy-init/SKILL.md`
- `plugins/shimmy/skills/shimmy-install/SKILL.md`
- `plugins/shimmy/skills/shimmy-escalation/SKILL.md`
- `plugins/shimmy/skills/shimmy-create-tool/SKILL.md` (consistency review)
- `plugins/shimmy/skills/shimmy-tool-local-build/SKILL.md` (consistency review)
- `plugins/shimmy/.agent-plugin/plugin.json`
- `docs/templates/generic-shim/SKILL.md`
- `tools/*/SKILL.md` profile-selection paragraphs
- `tools/task/guide.md` and `tools/task/SKILL.md` override caveat
- `README.md`
- `BOOTSTRAP.md`
- `commands/README.md`
- `docs/podman.md`
- `CONTRIBUTING.md`
- `AGENTS.md`
- `docs/prompt-shimmy-project.md`

Expected unchanged surfaces that must be checked:

- `.agents/skills/**`
- registry/image configuration and all `image.conf` files
- `lib/images/images.sh` and `commands/images.sh`
- tool runtimes except generic affinity behavior inherited from shared Podman
  helpers
- profile/catalog manifest schema versions and fields

### Implementation requirements

1. Add `profile` to installed launcher help and dispatch. Implement group,
   `status`, and `activate` help before profile or Podman validation. Reject
   missing operations, unknown operations/options, `--profile`, `--machine`,
   and machine/profile environment selectors without mutation.
2. Derive expected machine and rootless connection solely from the canonical
   invoking profile. Keep installed commands bound to their enclosing profile;
   source execution of `commands/profile.sh` may support help/testing but may
   not invent a source-checkout profile.
3. Implement `profile status --format human|manifest` as read-only. Report
   profile, host OS, expected engine type/name, expected/default connection,
   machine running state, alternate running machine, running-container count
   when inspectable, activation classification, and connection override state.
   Missing expected machine is `unavailable`, not silently mapped to
   `podman-machine-default`.
4. On Darwin activation, require an exact machine-list entry and exact same-name
   rootless connection. Reject multiple running machines, inconsistent
   machine/connection metadata, a root connection selected as normal, or an
   uninspectable running engine before any stop.
5. Acquire the global activation `mkdir` lock, re-read state, and inspect
   `podman --connection <running-machine> ps` immediately before a stop. Print
   affected IDs/names. Without `--stop-running`, fail if any are running;
   failure to query is also non-mutating failure.
6. Make ordinary activation idempotent for an already selected expected
   machine. `--restart` forces the target stop/start through the same guard.
   Reject `--stop-running` when no stop is planned so an acknowledgement cannot
   be accidentally carried into an unrelated future transition.
7. Start the expected machine by exact name with stdin detached. Do not pass an
   option absent from supported local Podman. Validate rootless target access
   explicitly with `podman --connection <expected> info`; set the Podman global
   default connection only after all target validation succeeds.
8. Implement the rollback sequence and status reporting recorded above. Unit
   seams must cover every failure boundary: prior inspection, stop, target
   start, target validation, default connection commit, target cleanup, prior
   restart, and prior-default restoration. Never claim full rollback after
   `--stop-running`; report workload uncertainty.
9. On Linux, reject `--restart` and `--stop-running`; verify local, non-remote,
   rootless Podman readiness without machine lifecycle. Chunk 1 reports the
   profile ready but does not yet create a registry active link.
10. Reject non-empty `CONTAINER_CONNECTION`/`CONTAINER_HOST` before activation
    and show correction. Status reports them. Never print connection secrets or
    URI credentials.
11. Extend installed-runtime Podman preflight on Darwin to identify a canonical
    materialized profile and require its expected connection to be the active
    default before a real tool run. Keep preview and source-checkout execution
    unchanged. Provide the exact absolute `profile activate` command in
    mismatch/unreachable guidance.
12. Keep `shell-init.sh` PATH-only and source-safe. Update comments/help/tests to
    explicitly separate PATH selection from engine activation; do not insert
    Podman calls or connection variables into startup files.
13. Update bootstrap success/help and onboarding docs to show explicit named
    machine creation as a user prerequisite on macOS, then profile activation.
    Explain that existing `podman-machine-default` data is not migrated or
    removed by Shimmy.
14. Rewrite `shimmy-init` so it may inspect state and, for an explicit desired
    profile or a failed wrapper with an identifiable profile, request approval
    for the exact absolute profile-local `bin/shimmy profile activate` command.
    It must use dry-run/status first, stop on missing machines with exact
    user-shell init guidance, and ask for separate confirmation before adding
    `--stop-running`.
15. Update `shimmy-install` to activate the target via its absolute launcher
    before telling a user/agent to source its shell init. Record that agent
    shells do not retain sourcing across tool calls and should use absolute
    paths or same-command sourcing.
16. Update `shimmy-escalation` to run `shimmy-init` profile readiness before
    wrapper smoke approvals, delegate lifecycle mutation to the exact
    profile-activate command, and retain narrow non-mutating wrapper prefixes.
    Remove the blanket prohibition on agent machine start only where the new
    control plane and explicit activation approval apply.
17. Keep machine provisioning and removal prohibited in every skill. An old
    installed profile lacking `profile activate` falls back to user-shell
    guidance, not direct agent `podman machine start/stop` orchestration.
18. Update the packaged plugin description and canonical generic/tool skill
    profile-selection paragraphs. Use a terminology inventory to update all 19
    canonical tool skills without altering tool-specific meanings of profile,
    connection, privilege, or credentials.
19. Add skill export tests proving refreshed portable/target outputs contain
    activation and workload-guard guidance. Preserve checked-in generated
    adapter files/fingerprints and document the explicit post-release `shimmy
    skills update` action.
20. Update root and child contexts with the new control-plane ownership. Keep
    manifest schemas unchanged and ensure full-tree profile update
    materializes the new command/library atomically.

### Verification checklist

- [ ] Launcher/group/action help is complete and non-mutating; `--profile`,
  `--machine`, arbitrary names, obsolete aliases, and unknown options fail.
- [ ] Status deterministically classifies Linux local readiness and Darwin
  missing, stopped, target-running, alternate-running, mismatched-default,
  overridden, unreachable, and invalid metadata states.
- [ ] Activation maps only `default -> shimmy-default` and `upstream ->
  shimmy-upstream`; a missing target prints exact user-run init guidance and
  never adopts `podman-machine-default`.
- [ ] Idle alternate-machine switching stops the exact prior machine, starts
  the target, validates its rootless connection, and commits the global default
  last; already-active activation is a no-op.
- [ ] Running-container discovery blocks before stop without
  `--stop-running`; dry-run and error output identify workloads; explicit
  acknowledgement reaches the stop path.
- [ ] `--restart` uses the same guard; irrelevant `--stop-running`, Linux
  restart flags, uninspectable workloads, and concurrent activation locks fail
  without mutation.
- [ ] Failure-injection tests verify target cleanup, previous-machine restart,
  prior-default restoration, exact rollback reporting, and workload rollback
  uncertainty after acknowledged interruption.
- [ ] Start is noninteractive and compatible with the supported Podman client
  lacking `--update-connection`; tests prove no implicit/default connection
  change occurs before the explicit final commit.
- [ ] Non-empty `CONTAINER_CONNECTION` and `CONTAINER_HOST` block activation and
  appear in status without secret/URI leakage.
- [ ] Darwin installed wrappers reject inactive-profile/default-connection
  mismatch with the exact activation command; source previews and existing
  Linux runtime behavior remain unchanged.
- [ ] Generated shell init and managed startup blocks remain PATH-only,
  idempotent, safe under `set -e`/conditional sourcing, and free of Podman
  lifecycle or connection mutation.
- [ ] `shimmy-init`, `shimmy-install`, and `shimmy-escalation` consistently use
  exact profile-local activation approvals, workload confirmation, no machine
  provisioning, and narrow wrapper smokes.
- [ ] Canonical generic and tool skills no longer describe source-only profile
  switching; tool-specific connection/credential semantics remain intact.
- [ ] Skill portable/target export tests contain new canonical behavior while
  `.agents/skills/` generated copies remain unchanged.
- [ ] Fresh and refreshed disposable profiles contain and dispatch
  `commands/profile.sh` plus `lib/profile/activation.sh` without a manifest
  schema change; sibling profile and catalog isolation still pass.
- [ ] Updated README, bootstrap, Podman, command, contributor, agent, project
  prompt, template, plugin, and tool guidance all distinguish provisioning,
  engine activation, shell selection, and wrapper approval.
- [ ] New/changed runnable shell files pass `dash -n`, retain executable modes,
  and context/test runners include the new modules.
- [ ] `./tests/test.sh` passes without starting or stopping any real machine.
- [ ] On a dedicated macOS acceptance host with pre-provisioned
  `shimmy-default` and `shimmy-upstream`, activate each direction, verify global
  default/rootless affinity, verify idle switching, verify workload refusal,
  exercise an explicitly authorized workload switch, and verify rollback from
  an induced target-start failure. Record `[~]` with exact infrastructure gaps
  if this dedicated environment is unavailable.

### Human review gate

Reviewers must confirm the explicit activation UX, deterministic names,
pre-existing-machine requirement, global default-connection behavior,
workload acknowledgement, rollback limitations, source-only PATH boundary,
agent approval model, and broad canonical guidance update. All automated checks
must pass and native Darwin acceptance must be complete or explicitly deferred
as `[~]`. Stop before Chunk 2.

## Chunk 2 — Strict registry redirects and profile projection

### Goal

Extend the accepted activation model with profile-owned strict registry files,
Linux activation links, deterministic Darwin projection/ownership, redirect
commands, Skopeo integration, complete install/uninstall transactions, tests,
and registry documentation without changing logical image references.

### Files

Primary implementation and contexts:

- `commands/profile.sh`
- `commands/CONTEXT.md`
- `lib/profile/activation.sh`
- `lib/profile/profile.sh`
- `lib/profile/CONTEXT.md`
- `lib/registries/registries.sh` (new)
- `lib/registries/CONTEXT.md` (new)
- `lib/CONTEXT.md`
- `lib/runtime/podman.sh` and `lib/runtime/CONTEXT.md`
- `lib/install/profile-assets.sh`
- `lib/install/install.sh`
- `lib/install/uninstall.sh`
- `lib/install/request.sh`
- `lib/install/CONTEXT.md`
- `CONTEXT.md`

Tests and test contexts:

- `tests/commands/profile.sh` (redirect/projection portion)
- `tests/lib/profile-activation.sh`
- `tests/commands/management.sh`
- `tests/commands/lifecycle.sh`
- `tests/commands/onboarding.sh`
- `tests/commands/profiles.sh`
- `tests/commands/startup.sh`
- `tests/commands/install.sh`
- `tests/commands/images.sh`
- `tests/commands/skills.sh`
- `tests/commands/CONTEXT.md`
- `tests/lib/CONTEXT.md`
- `tests/CONTEXT.md`
- `tests/context-tree.sh`
- `tests/test.sh`

Registry-client and canonical guidance:

- `tools/skopeo/versions/1.22/run.sh`
- `tools/skopeo/tests/skopeo.sh`
- `tools/skopeo/guide.md`
- `tools/skopeo/SKILL.md`
- `tools/oc/guide.md`
- `tools/oc/SKILL.md`
- `plugins/shimmy/skills/shimmy-init/SKILL.md`
- `plugins/shimmy/skills/shimmy-install/SKILL.md`
- `README.md`
- `BOOTSTRAP.md`
- `commands/README.md`
- `docs/registries.md` (new)
- `docs/podman.md`
- `CONTRIBUTING.md`
- `AGENTS.md`
- `docs/prompt-shimmy-project.md`
- `docs/templates/generic-shim/AGENTS.md`

Expected unchanged surfaces that must still be checked:

- `.agents/skills/**`
- `lib/runtime/image.sh`
- `lib/images/images.sh`
- `commands/images.sh`
- every version-owned `image.conf` and Containerfile
- non-Skopeo tool runtimes
- manifest schema versions and existing fields

### Implementation requirements

1. Add redirect group/upsert/list/remove help and parsing to `commands/profile.sh`
   without reopening accepted activation semantics. Preserve direct option-form
   upsert and reject `mirror`, `set`, `registries`, `--machine`, and profile
   selectors.
2. Add canonical registry/projection paths during profile resolution. Require a
   valid profile-specific `registries.conf`; allow an optional exact projection
   record only on Darwin-aware lifecycle paths.
3. Implement strict endpoint parsing, exact managed-file parsing, deterministic
   rendering, upsert, exact removal, full removal, list/status reporting,
   locking, temporary staging, atomic rename, rollback, and mount resolution in
   `lib/registries/registries.sh`.
4. On new install or valid pre-feature upgrade, stage an empty authoritative
   config. On update/additive install, hold the registry lock through profile
   commit and preserve validated config and optional record byte-for-byte.
   Refuse malformed, symlinked, wrong-profile, or unmanaged collisions before
   replacing any profile asset.
5. Add both top-level formats to profile structure validation, backup/restore,
   staged commit, rollback, fixtures, and owned cleanup. Keep manifest version 2
   because canonical filenames/markers provide ownership; a required schema
   change is a plan divergence requiring review.
6. Extend Linux `profile activate` to validate registry environment overrides,
   safely create the user drop-in directory, and atomically install the exact
   Linux active link before fresh local-rootless engine validation. Roll back
   link/default profile state on failure.
7. Extend Darwin activation to validate same-path target readability and manage
   only `/etc/containers/registries.conf.d/shimmy-profile.conf` through a fixed
   root SSH script with validated arguments. Never interpolate registry
   endpoints or untrusted machine output into remote shell code.
8. Install the projection before the first target engine policy validation.
   Accept an absent path or exact recognized Shimmy link; refuse regular files,
   directories, foreign links, wrong targets, or unsafe parent state. Create the
   local projection record with the exact current config fingerprint only after
   remote validation; roll back both states together on failure.
9. If an already-running target lacks a valid required projection or its
   projection record fingerprint differs from the current config, do not repair
   or claim readiness without a restart. Apply accepted `--restart` and
   `--stop-running` semantics. A stopped target may be started, projected before
   first registry-sensitive validation, and accepted without an extra restart
   only when native acceptance proves the cache has not loaded earlier; update
   the record fingerprint only after successful validation.
10. Make `profile status` and redirect list report authoritative config health,
    projection record/link health, active/inactive profile, masking registry
    variables, and Darwin cache freshness as `current`, `restart-required`, or
    `unverified` only when evidence supports it. Do not invent a freshness claim
    from file existence alone.
11. Keep redirect edits engine-independent. Inactive edits never contact
    Podman. Active Linux edits perform fresh process validation and roll back on
    parse failure. Active Darwin edits commit the valid profile file and print
    the exact restart command; they do not stop the machine themselves.
12. Implement `remove --all --detach` with exact ownership. Linux removes only
    the invoking profile's active link. Darwin requires the expected machine
    running/reachable to inspect/remove the exact VM link, or proves the machine
    absent before clearing a stale ownership record. A stopped existing machine
    fails with activation guidance and no detach mutation.
13. Make profile/global uninstall refuse any valid projection record and print
    exact detach guidance. After detach, uninstall removes the valid
    authoritative file and exact Linux link if applicable while preserving
    sibling configs, machines, connections, operator policy, and external skill
    exports.
14. Reject non-empty `CONTAINERS_REGISTRIES_CONF` and
    `CONTAINERS_REGISTRIES_CONF_OVERRIDE` before active link/projection or
    active-engine validation. Inactive config edits remain available with
    explicit unvalidated status.
15. Add a shared runtime resolver that accepts only a valid authoritative file
    belonging to the active invoking profile. Missing Shimmy activation may
    mean no mount; an inactive invoking profile, dangling/foreign link, invalid
    projection record, malformed config, or unsafe path fails closed before
    registry traffic.
16. Mount the resolved config read-only in Skopeo at
    `/etc/containers/registries.conf.d/shimmy-profile.conf`. Preserve image,
    pull, platform, workdir, I/O, and auth-secret argv exactly. On Darwin rely
    only on a profile path whose same-path VM visibility activation verified.
17. Keep Skopeo as the only version-1 opt-in. `shimmy images verify` inherits
    the mount without changes to its image references or verification logic.
    Non-Skopeo runtimes remain unchanged.
18. Create `docs/registries.md` as normative guidance for strict location
    replacement, command examples, namespace matching, independent profile
    preparation, activation/restart, list/remove/detach, config precedence,
    no-fallback behavior, credentials/CA/signatures, Skopeo coverage, and
    uninstall recovery.
19. Keep `docs/podman.md` normative for deterministic machine creation,
    same-path volume visibility, activation switching, workload interruption,
    rootless connections, registry cache restart, and manual remote/rootful
    cases. Link rather than duplicate between the two guides.
20. Update OC and Skopeo guidance, generic template/agent guidance, README,
    bootstrap, commands, contributor, project prompt, and canonical management
    skills so no surface reintroduces mirror terminology, source-only
    activation, arbitrary machines, automatic provisioning, or broad approval.
21. Explain that `[[registry.mirror]]` falls back to the primary, physical
    registries must preserve digests, Skopeo's auth secret remains independent,
    and mounting registry policy does not install a corporate CA.
22. Verify complete-tree materialization, sibling isolation, default/upstream
    independent redirects, catalog operations, update rollback, profile
    uninstall, global uninstall, skill export, and source-loss runtime behavior
    against the new required/optional top-level files.

### Verification checklist

- [ ] Redirect help, upsert/list/remove, dry-run, detach constraints, and all
  unknown/obsolete inputs are complete and non-mutating.
- [ ] Endpoint validation accepts hosts, ports, and safe namespace paths and
  rejects schemes, wildcards, tags, digests, traversal, empty segments,
  trailing slashes, quotes, whitespace, and unsafe characters.
- [ ] Managed parsing accepts only exact profile/version markers and strict
  tables; deterministic rendering, no-op upsert, replacement, exact removal,
  full removal, and profile isolation pass.
- [ ] Fresh installs/upgrades create empty configs; refresh/additive install
  preserve config/record bytes; invalid files/records fail before mutation;
  profile transaction rollback restores every top-level asset.
- [ ] Linux activation link creation/switch/idempotence/collision/rollback and
  local-rootless validation work only in disposable config roots and preserve
  all operator files.
- [ ] Darwin tests prove deterministic target projection, same-path visibility,
  fixed root-write/rootless-validation separation, exact link collision
  handling, record creation/fingerprint freshness, rollback, restart
  requirements, and no profile content copy.
- [ ] Active Darwin redirect edits never restart automatically and produce the
  exact profile-local `activate --restart` command; workload guard behavior is
  inherited from Chunk 1.
- [ ] Detach removes only exact owned links/records, handles a proven missing
  machine, refuses a stopped/unreachable existing machine, and never starts,
  stops, provisions, deletes, or renames a machine.
- [ ] Profile/global uninstall refuse recorded projection ownership and succeed
  after detach while preserving machines, connections, sibling profiles,
  catalogs, operator policy, and external skills.
- [ ] Registry environment overrides block active mutation/validation, appear
  in status/list, and do not prevent inactive profile preparation.
- [ ] Config/link/record transaction tests prove lock exclusion,
  same-directory staging, mode `0644`, atomic replacement, exact rollback,
  cleanup, and unsafe-path refusal.
- [ ] Registry-client resolution emits the exact mount only for an active valid
  invoking profile, omits it only for valid absent activation, and fails closed
  for profile mismatch or damaged state.
- [ ] Skopeo previews contain the exact read-only mount while preserving all
  existing argv/auth behavior; `images verify` inherits it and non-Skopeo
  runtime previews remain unchanged.
- [ ] Canonical skills and docs consistently distinguish profile activation,
  machine provisioning, registry redirects, cache restart, auth/trust, and
  fallback mirrors; generated `.agents/skills/` copies remain unchanged.
- [ ] Default tests use disposable state/command seams and neither pull images,
  contact corporate registries, nor mutate a developer machine.
- [ ] New/changed shell files pass `dash -n`, executable modes and retained
  contexts are correct, and `./tests/test.sh` passes.
- [ ] Dedicated rootless Linux acceptance configures distinct redirects in both
  profiles, activates each, proves Podman and direct Skopeo use the physical
  digest endpoint, proves `images verify` inherits it, proves no fallback when
  the physical endpoint is unavailable, and detaches cleanly.
- [ ] Dedicated macOS acceptance uses pre-provisioned deterministic machines,
  proves each machine retains only its owning profile projection, switches in
  both directions, validates restart after active edits, proves Podman/Skopeo/
  `images verify` route to the physical endpoint with no public fallback, and
  verifies detach/uninstall boundaries. Record unavailable infrastructure as
  `[~]` with exact impact and proposed disposition.

### Human review gate

Reviewers must confirm strict redirect/no-fallback semantics, profile config
ownership, Linux versus Darwin projection, deterministic machine lifecycle,
projection record/uninstall recovery, registry cache restart behavior, Skopeo
scope, and all documentation/skill boundaries. All automated checks must pass,
and every live acceptance item must be complete or explicitly dispositioned as
`[~]`. Stop after this review; there is no later chunk.

## Risk register

- **Interrupting workloads:** Stopping a VM interrupts its running containers
  and rollback may not restore them. Mitigation: inspect by exact rootless
  connection, fail without `--stop-running`, display affected containers, and
  make the acknowledgement explicit in CLI and skills.
- **Partial engine switch:** Stop may succeed while target start or validation
  fails. Mitigation: global lock, prevalidation, default-connection commit last,
  ordered cleanup/restart/restore, exact rollback reporting, and dedicated live
  failure acceptance.
- **Wrong engine or override:** A global default can be masked by environment or
  point to an unrelated connection. Mitigation: deterministic mapping, exact
  connection validation, override rejection, affinity checks, and status.
- **Existing default-machine data:** Enforcing new names does not move images,
  containers, or volumes from `podman-machine-default`. Mitigation: no adoption
  or deletion, conspicuous migration guidance, and user-controlled retirement.
- **Concurrent profiles:** PATH is shell-local but the running VM/default
  connection is user-global. Mitigation: explicit activation, one global lock,
  inactive-profile runtime failure, and no claim that sourcing changes engine.
- **Unexpected Podman version behavior:** Start flags differ between local 5.8.1
  and newer docs. Mitigation: avoid the optional start flag, detach stdin,
  explicitly set the default after validation, and test the supported client.
- **External-state ownership:** Profile uninstall could leave a dangling VM
  symlink. Mitigation: exact projection record, detach requirement, missing-
  machine recovery, and no guessing across stopped/unreachable machines.
- **Remote bind-source mismatch:** macOS bind sources resolve in the VM and a
  custom config home may not be shared. Mitigation: verify same-path visibility,
  give exact machine-init volume guidance, and never silently omit active
  policy.
- **Registry cache staleness:** The remote Podman service may retain parsed
  configuration. Mitigation: projection before initial policy use, explicit
  activation restart after active edits, freshness status that does not
  overclaim, and native route acceptance.
- **Overwriting administrator policy:** Main files and other drop-ins may contain
  unrelated settings. Mitigation: distinctive exact owned paths/markers,
  collision refusal, merged-policy validation, and no operator-file edits.
- **Configuration precedence:** Later drop-ins or environment files can replace
  a prefix. Mitigation: report/reject masking environment, document basename
  precedence, inspect effective configuration, and prove actual routes live.
- **Symlink loader compatibility:** Current containers/image follows `.conf`
  symlinks but its man page is not an explicit compatibility guarantee.
  Mitigation: isolate links behind tests and require native Linux/Darwin
  acceptance on supported Podman upgrades.
- **Unexpected upstream access:** Mirror tables fall back to the primary.
  Mitigation: generate replacement primary locations only and prove no fallback
  with the physical endpoint unavailable.
- **Authentication/trust mismatch:** Corporate endpoints may require separate
  credentials, CA roots, or signature policy. Mitigation: document prerequisites
  and fail closed without weakening security.
- **Incomplete client coverage:** Software in arbitrary tool containers does not
  inherit engine policy. Mitigation: opt in only verified registry clients,
  cover Skopeo/images verify, and state the boundary.
- **Skill authority drift:** Canonical skills, checked-in adapters, and external
  exports have different lifecycles. Mitigation: change canonical sources,
  verify explicit export/update behavior, preserve generated copies, and tell
  users when refresh is required.

## Lessons learned

### Initial

- The containers/image contract already models strict logical-prefix to
  physical-location replacement; a Shimmy mapper would duplicate and conflict
  with upstream identity semantics.
- Upstream “mirror” is a fallback-capable construct. Shimmy's intended behavior
  is correctly named `redirect` and uses replacement `location`.
- The current `shimmy-init` artifact is an agent skill, not a `shimmy init`
  management command, and it currently forbids machine startup. That is a
  policy boundary which this plan deliberately narrows for explicit profile
  activation.
- Podman permits only one managed VM at a time, so a profile-to-machine mapping
  necessarily makes activation a global lifecycle transition rather than a
  shell-local selector.
- Sourcing cannot safely own that transition: persistent startup may run in
  every new shell, and an executable cannot mutate its parent PATH. Explicit
  engine activation followed by shell sourcing is the honest two-phase UX.
- The invoking installed launcher already provides a trustworthy profile
  identity. Deterministic `shimmy-<profile>` naming removes `--machine` and its
  ambiguity without adding a profile selector.
- A running VM is not equivalent to an idle VM. Container inspection and an
  explicit interruption acknowledgement are required before stop.
- Podman 5.8.1 on the planning host lacks the newer documented
  `machine start --update-connection` option. Stable explicit connection-default
  selection is safer than version-dependent start behavior.
- Profile-specific Darwin machines allow direct per-profile registry projection
  and eliminate the old macOS global active-link race. Linux still needs one
  active user drop-in because its local engine is shared.
- Registry configuration is cached per process. A long-running remote service
  needs an explicit restart boundary after active policy changes, while fresh
  local commands and Skopeo containers do not.
- External VM links have a different lifecycle from profile files. A local
  ownership record and detach-before-uninstall rule prevent dangling policy
  projections without treating Podman machines as Shimmy-owned resources.
- Canonical skills are catalog-owned; checked-in and external adapters are
  separate explicit exports. Updating agent behavior does not authorize
  rewriting generated `.agents/skills/` copies.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this complete plan,
   and every retained child context for the active chunk. Read the three
   canonical management skills and the exact source/test files listed by that
   chunk.
2. Recheck the worktree and preserve the unrelated untracked
   `plans/registry-image-remap.md`. Treat the verified inventory as a baseline
   and add newly discovered dependencies without reopening recorded decisions.
3. Start only the first unchecked chunk. Chunk 1's non-negotiable boundaries
   are: explicit profile-bound activation; deterministic `shimmy-default` and
   `shimmy-upstream`; no Podman provisioning/removal; workload guard; global
   connection commit last; PATH-only shell init; exact agent approval; no
   registry implementation yet.
4. After Chunk 1 is accepted, Chunk 2's non-negotiable boundaries are: shared
   containers/image `prefix`/`location`; no mirrors or Shimmy mapper; one
   profile-owned config; Linux-only active host link; direct deterministic
   Darwin projection plus ownership record; restart after active remote edits;
   Skopeo-only initial mount; detach before uninstall; no auth/CA management.
5. Implement and verify only the active chunk, update its checklist and Lessons
   learned, and stop at its human review gate. Surface every `[~]` item with
   completed evidence, remaining gap, impact, next action, and whether
   acceptance requires explicit deferral.
