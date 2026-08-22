# Bootstrap Rename, Activation, and Engine Status Plan
Completed: 2026-08-19

## Objective

Rename the ambiguous repository-root `install.sh` bootstrap to
`bootstrap.sh` without renaming the distinct installed-profile install command
or its implementation modules; add a safe, explicit checkout-bootstrap
convenience that installs a Shimmy profile and activates its Podman engine in
the same requested workflow; correct runtime activation guidance so a stale
running Darwin registry projection recommends `--restart`; and integrate a
concise Podman engine summary into both human and manifest `shimmy status`
output.

Success means:

- `bootstrap.sh` is the only repository-root bootstrap entrypoint and every
  current producer, consumer, validator, test, document, canonical skill, and
  resumable instruction uses that unambiguous name;
- the repository contains no root `install.sh` compatibility entrypoint after
  final implementation, while `commands/install.sh`, `lib/install/install.sh`,
  and the installed `shimmy install` command retain their current names and
  responsibilities;
- a human can run `. ./bootstrap.sh --activate` (or execute the same bootstrap
  form for automation) and receive a usable, activated profile when the
  existing activation safety checks permit the transition;
- the bootstrap automatically selects ordinary activation or Darwin
  `--restart` from authoritative profile state without accepting implicit
  workload interruption;
- activation failure leaves the successfully installed profile recoverable,
  reports that partial outcome accurately, and returns nonzero;
- installed additive `shimmy install --shim ...`, shell startup, and an
  unqualified checkout bootstrap remain non-activating;
- stale-projection tool failures print the exact
  `shimmy profile activate --restart` recovery command;
- `shimmy status` presents Profile, Podman Engine, Catalog, and Tools as clear
  human sections while preserving the current information; and
- `shimmy status --format manifest` adds stable, prefixed engine fields without
  changing or removing existing manifest fields.

Explicit exclusions:

- Do not preserve update or checkout compatibility for profiles installed by a
  pre-rename Shimmy version. Users must run the old installed
  `shimmy uninstall --global`, update or replace the checkout, and reinstall
  through `bootstrap.sh`.
- Do not retain a root `install.sh` forwarding wrapper, alias, symlink, or
  diagnostic stub in the accepted final tree. A temporary implementation-only
  bridge is permitted solely to keep intermediate refactoring steps executable
  and must be removed before the final acceptance gate.
- Do not bump the profile manifest, catalog schema, materialization layout, or
  profile version for this entrypoint rename. No in-place migration is
  supported or implied.
- Do not rename `commands/install.sh`, `lib/install/install.sh`,
  `lib/install/`, `tests/commands/install.sh`, or the installed
  `shimmy install` command. Their names correctly describe profile-bound
  installation and are outside the ambiguity being removed.
- Do not make activation the default for `. ./bootstrap.sh`; `--activate` is an
  explicit bootstrap request.
- Do not add `--activate` to the installed additive `shimmy install` surface.
- Do not make `shell-init.sh` start, stop, restart, or select a Podman engine.
- Do not accept or imply `--stop-running` through bootstrap activation. A
  workload-bearing transition must stop and require the existing separate,
  explicit profile activation acknowledgement.
- Do not provision, adopt, rename, delete, or reset Podman machines.
- Do not weaken connection, rootless-engine, registry-projection, lock,
  workload, rollback, or environment-override validation.
- Do not edit generated `.agents/skills/` adapters. Update canonical skill
  sources only; adapter refresh remains an explicit lifecycle operation.
- Do not implement custom or named profiles from
  `plans/profile-name-activation.md` as part of this work.

## Target layout and terminology

### Public workflows

```text
# Existing non-activating bootstrap remains valid.
. ./bootstrap.sh

# New explicit install-and-activate convenience.
. ./bootstrap.sh --activate
./bootstrap.sh --activate

# Installed tool addition remains non-activating.
shimmy install --shim task
```

- **Bootstrap activation** means the explicit `--activate` post-install step
  available only through the repository root bootstrap.
- **Root bootstrap** means only repository-root `bootstrap.sh`. Unqualified
  mentions of install continue to mean the installed profile-bound
  `shimmy install` command or its `commands/install.sh` and
  `lib/install/install.sh` implementation chain.
- **Pre-rename profile** means any installed profile whose materialized
  management code or bound source-checkout contract still expects root
  `install.sh`. It has no supported in-place update path to this change.
- **Activation state** means the authoritative internal state already produced
  by `shimmy_profile_state_read`, such as `active`, `stopped`,
  `alternate_running`, or `registry_restart_required`.
- **Recommended action** means a stable semantic action derived from activation
  state. Manifest output uses an enum rather than an absolute local command;
  human diagnostics render the exact command appropriate to the invoking
  profile.
- **Engine summary** means the concise projection of the existing profile
  activation and registry state into top-level `shimmy status`. The detailed
  `shimmy profile status` command remains available and unchanged in purpose.

### Hard-cut operator transition

Document this order for users with an existing installation; the uninstall
must use the old installed control plane before the checkout adopts the rename:

```text
1. From the currently installed profile, run: shimmy uninstall --global
   (honor its existing workload review and separate --stop-running gate if it
   reports containers that must be interrupted).
2. Update or replace the source checkout so it contains bootstrap.sh.
3. Reinstall with: . ./bootstrap.sh
   or explicitly request engine activation with: . ./bootstrap.sh --activate
```

There is no supported `shimmy update` path across this rename and no format or
profile-version migration. Documentation must not imply that a pre-rename
upstream profile remains valid after its bound checkout removes root
`install.sh`.

### Human status target

Preserve current status information while organizing it into sections similar
to the following:

```text
Shimmy Status

Profile
  name: default
  root: /Users/example/.config/shimmy/profiles/default

Podman Engine
  type: podman machine
  name: shimmy-default
  machine state: running
  connection: shimmy-default (default)
  reachable: yes
  running containers: 0
  activation: restart required
  registry policy: restart required
  action: shimmy profile activate --restart

Catalog
  name: default
  ...existing provenance and health fields...

Tools
  ...existing default-version and image descriptions...
```

Use readable labels (`podman machine`, `restart required`, `yes`/`no`) in
human output while retaining stable machine values in manifest output. Omit
the human `action` line when no safe corrective action applies or the profile
is already active; never recommend an action that bypasses a safety check.

### Additive manifest fields

Add these exact fields to `shimmy status --format manifest`:

```text
shimmy_engine_type=podman_machine
shimmy_engine_name=shimmy-default
shimmy_engine_connection=shimmy-default
shimmy_engine_default_connection=shimmy-default
shimmy_engine_machine_state=running
shimmy_engine_reachable=true
shimmy_engine_activation=registry_restart_required
shimmy_engine_registry_policy=restart-required
shimmy_engine_running_container_count=0
shimmy_engine_recommended_action=profile_activate_restart
```

`shimmy_engine_recommended_action` uses a bounded enum:

- `none` when already active and current;
- `profile_activate` when ordinary activation is the safe next command;
- `profile_activate_restart` when the running Darwin engine must restart;
- `podman_machine_init` when the deterministic Darwin machine is missing;
- `unset_override` when a named connection or registry environment variable
  masks profile activation; and
- `investigate` when state is unreachable, invalid, unsupported, or otherwise
  lacks one safe automatic correction.

The manifest enum is portable and does not embed a workstation-specific
profile root. Human and error renderers may use the invoking profile's exact
absolute launcher when direct execution context requires it.

## Recorded design decisions

1. Rename the tracked executable root `install.sh` to `bootstrap.sh` and keep
   its sourced/executed POSIX-shell behavior, fixed jq/rg baseline, profile
   selection, startup policy, error cleanup, and caller-state preservation
   unchanged except for the public path and name-specific diagnostics.
2. Treat the rename as an intentional hard compatibility break. Do not add a
   permanent `install.sh` compatibility surface and do not teach new code to
   accept both names. Existing installations must be globally uninstalled with
   their old installed control plane and then reinstalled from the renamed
   checkout.
3. Do not bump manifest version 1, catalog schema 1, the
   `profile-materialized-root` layout identity, or any tool/profile version.
   The supported transition is removal and recreation, not format migration.
4. Update the source-checkout contract atomically: new checkout validation
   requires executable root `bootstrap.sh`; self-update invokes
   `$source_dir/bootstrap.sh`; bootstrap-context detection checks the renamed
   file; error identifiers and diagnostics say `bootstrap`, not root install.
   Old installed updaters are expected to fail against the renamed checkout
   and require the documented uninstall/reinstall path.
5. Preserve the semantically distinct installed install surfaces and their
   terminology. Broad searches must classify every occurrence before editing;
   references to `commands/install.sh`, `lib/install/install.sh`,
   `lib/install/`, `tests/commands/install.sh`, and `shimmy install` remain.
6. Update retained plans according to meaning rather than mechanically
   rewriting history. Change executable commands, session-bootstrap
   instructions, target inventories, and future implementation requirements to
   `bootstrap.sh`; retain historical statements only when the old filename is
   material to the recorded history, and add a concise supersession note when
   leaving one avoids ambiguity.
7. Treat removal of root `install.sh` as an accepted final-tree condition, not
   as a separately tested rejection or absence contract. Replace the existing
   onboarding assertion that `bootstrap.sh` is absent with a positive assertion
   that the renamed bootstrap exists and is executable. Do not add or retain an
   automated assertion whose sole purpose is to prove that root `install.sh`
   does not exist; review the rename, repository status, and classified search
   inventory instead.
8. A temporary bridge may exist only inside in-progress Chunk 3 when needed to
   keep mechanical passes executable. It is not a public compatibility
   commitment, must not appear in documentation, and must be removed before the
   Chunk 3 review gate. No Chunk 3 progress item can be marked complete while
   the bridge remains.
9. `--activate` is bootstrap-only and opt-in. It is accepted only when
   `SHIMMY_BOOTSTRAP_PROFILE` identifies a root `bootstrap.sh` checkout
   bootstrap; the installed `shimmy install` command keeps its current
   tool-selection-only contract.
10. The option applies after both fresh profile creation and a successful
   repeated checkout bootstrap. This makes retries idempotent and lets a user
   recover an installed-but-not-activated profile with the same command.
11. Bootstrap activation runs only after profile assets and startup integration
   have committed. It must not roll back a valid installation because an
   external Podman transition fails. Failure returns nonzero and says that the
   profile was installed but not activated, followed by exact recovery
   guidance.
12. Bootstrap activation delegates to the existing activation implementation.
   It first reads authoritative state only to choose the existing ordinary or
   restart path, then the selected activation path re-reads and validates state
   under its normal locks. A race causes a safe refusal, not an automatic
   stronger retry.
13. `registry_restart_required` selects existing Darwin activation with
   `restart_requested=1`; every other state enters ordinary activation and lets
   the existing state machine validate or reject it. The bootstrap never sets
   `stop_running_requested=1`.
14. An explicit `--activate` authorizes stopping an idle alternate Darwin VM or
   restarting the idle expected VM, selecting the expected global connection,
   and applying registry projection. Any running containers retain the current
   fail-before-stop behavior and require a separate command with explicit
   `--stop-running` acknowledgement.
15. Sourced and executed bootstraps have the same engine behavior. Only a
   sourced bootstrap can subsequently alter its parent shell's `PATH`; engine
   activation itself remains external/global state.
16. AI-agent instructions retain the current narrow workflow: absolute profile
   `status`, `activate --dry-run`, then separately approved exact activation.
   Canonical skills and `AGENTS.md` must not tell agents to use combined
   bootstrap activation because approval of installation is not approval to
   restart an engine. Human-facing documentation may recommend `--activate`.
17. One shared recommendation resolver owns activation-state-to-action mapping
   and human labels. Top-level status, runtime affinity diagnostics, and
   bootstrap selection consume that mapping rather than maintaining three
   divergent state tables.
18. The runtime affinity failure interface must render `--restart` specifically
    for `registry_restart_required`. Other existing affinity errors keep safe
    generic activation or inspection guidance according to the shared action.
19. `shimmy status` sources the profile activation helper and performs the same
    read-only engine inspection as `shimmy profile status`. Podman absence or
    unreachability is represented in output and does not by itself prevent
    catalog/tool status from being reported. Catalog validation retains its
    existing failure contract.
20. Human `shimmy status` is intentionally reformatted into sections; it is a
    presentation surface, not a parsing contract. Manifest output is the
    automation contract and changes additively only.
21. Existing detailed `shimmy profile status` manifest keys and human output
    remain available. Refactor their formatting to reuse common state/action
    helpers only when this does not rename or remove that command's current
    fields.
22. Status engine inspection may add Podman query latency. Use the existing
    bounded state reader and test seam; do not add image pulls, container runs,
    machine mutation, or registry network access.
23. No new rejection-only test is added merely to prove that arbitrary
    interfaces lack `--activate`. The non-activation behavior of installed
    additive install is covered as a durable engine-mutation safety boundary
    by extending an existing lifecycle scenario at the lowest practical cost.

## Verified implementation inventory

The following is the verified baseline, not permission to ignore newly
discovered dependencies during implementation.

- Root `install.sh` is currently the sourceable/executable checkout bootstrap.
  It supplies fixed jq/rg requests, delegates installation to
  `commands/install.sh`, then sources the installed `shell-init.sh` only in its
  caller. The target name is root `bootstrap.sh`; the subordinate installed
  install files are not rename targets.
- `commands/install.sh` sources `lib/install/install.sh`; the installed
  launcher dispatches additive install to the same command.
- `lib/install/request.sh` distinguishes bootstrap requests using
  `SHIMMY_BOOTSTRAP_PROFILE` plus executable `$ROOT_DIR/install.sh` and already
  restricts bootstrap-only startup options. The executable check must move to
  `$ROOT_DIR/bootstrap.sh`.
- `lib/install/install.sh` commits profile assets, updates startup integration,
  and then prints install/status/PATH guidance. It already sources
  `lib/profile/activation.sh` and `lib/registries/registries.sh` for uninstall
  and cleanup behavior.
- `lib/profile/activation.sh` is the sole engine state machine. It classifies
  Darwin stale projection as `registry_restart_required`, implements ordinary
  and restart activation, guards running workloads, and owns rollback.
- `lib/runtime/podman.sh` enforces installed Darwin runtime affinity. Its
  current common error printer always says `profile activate`, even when the
  caller has already identified a restart-required registry projection.
- `commands/status.sh` currently reports profile/catalog/tool materialization,
  sources the registry helper, but does not source or display activation state.
- `commands/profile.sh` and `shimmy_profile_status_print` already expose the
  detailed read-only engine and registry view and are the semantic baseline for
  top-level status.
- Primary behavioral coverage is in `tests/lib/profile-activation.sh`,
  `tests/lib/runtime.sh`, `tests/commands/status.sh`,
  `tests/commands/profile.sh`, `tests/commands/onboarding.sh`, and
  `tests/commands/install.sh`. The profile tests provide a purpose-built Podman
  seam and must be reused rather than contacting the developer's live engine.
- `lib/profile/profile.sh` defines the upstream source-checkout contract and
  currently requires executable `<checkout>/install.sh` with the diagnostic
  `invalid_source_checkout_missing_install_sh`.
- `lib/update/management.sh` clones `shimmy_source_url`, validates the checkout,
  and executes `$source_dir/install.sh`. A hard rename intentionally makes old
  installed updater implementations incompatible; the new implementation must
  invoke `$source_dir/bootstrap.sh`.
- Repository fixture and lifecycle coverage directly encoding the root name
  includes `tests/support.sh`, `tests/lib/runtime.sh`, and command groups for
  onboarding, startup, catalog, lifecycle, profiles, install, and update.
- The verified search baseline contains 115 live `install.sh` occurrences
  across 33 non-plan files. At least 24 files unambiguously reference the root
  bootstrap; the remaining matches must be classified so subordinate install
  commands and modules retain their correct names.
- User/contributor documentation is distributed across `README.md`,
  `BOOTSTRAP.md`, `commands/README.md`, `docs/podman.md`,
  `docs/prompt-shimmy-project.md`, `CONTRIBUTING.md`, and `AGENTS.md`.
- Canonical agent lifecycle guidance lives in
  `plugins/shimmy/skills/shimmy-install/SKILL.md` and
  `plugins/shimmy/skills/shimmy-init/SKILL.md`. Generated exports under
  `.agents/skills/` are not implementation targets.
- Retained `plans/profile-name-activation.md` explicitly excludes implicit
  bootstrap activation. The opt-in `--activate` design does not conflict with
  that boundary and does not implement the plan's custom-profile scope.
- Eight other retained plan files contain 46 `install.sh` occurrences. They
  include active/resumable commands and historical descriptions, so
  implementation must classify them under the recorded retained-plan decision
  instead of applying a blind replacement. This authoritative plan uses the old
  name intentionally when defining the transition and is not part of that
  inventory count.

## Unresolved

None.

## Progress Checklist

- [x] Chunk 1 — Centralize activation recommendations and correct exact runtime
  recovery guidance.
- [x] Chunk 2 — Add the read-only Podman Engine section and additive manifest
  fields to top-level status.
- [x] Chunk 3 — Rename the root bootstrap contract atomically to `bootstrap.sh`
  and remove the ambiguous root `install.sh` surface.
- [x] Chunk 4 — Add safe bootstrap `--activate`, align guidance, and run
  integrated acceptance.

Chunk 1 was accepted by the user on 2026-08-19. Chunk 2 was implemented,
verified, and accepted by the user at 2026-08-19 12:40:41 EDT. Chunk 3 was
implemented, verified, and accepted by the user at 2026-08-19 13:23:40 EDT.
Chunk 4 was implemented, verified, and accepted by the user at
2026-08-19 14:15:01 EDT.

## Reasoning-level calculation

Score one point for each material implementation burden: public contract
change, persistent or external state interaction, cross-ownership coordination,
compatibility or safety boundary, and broad verification surface. Use `medium`
for 0–2 points, `high` for 3–4 points, and `xhigh` for 5 points.

| Chunk | Score | Recommended reasoning | Basis |
| --- | ---: | --- | --- |
| 1 — Recommendation and runtime guidance | 3/5 | `high` | Public diagnostics, profile/runtime coordination, and safety-sensitive state-to-action mapping. |
| 2 — Top-level engine status | 4/5 | `high` | Additive automation schema, command/profile coordination, redaction and compatibility boundaries, and a broad state matrix. |
| 3 — Atomic bootstrap rename | 5/5 | `xhigh` | Public compatibility break, persisted source binding, broad cross-tree coordination, semantic match classification, and broad regression verification. |
| 4 — Bootstrap activation | 5/5 | `xhigh` | Public workflow change, external engine mutation, install/profile coordination, workload and authorization safeguards, and full integrated verification. |

The former combined engine/status chunk is split because the side-effect-free
recommendation contract can be implemented and reviewed independently before
top-level status makes it a new public manifest surface. The root rename remains
one atomic chunk: splitting its implementation, fixtures, current documentation,
and canonical guidance would leave an accepted intermediate checkout with
conflicting public contracts. Each chunk should start in a fresh implementation
session when practical, especially Chunks 3 and 4.

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

## Chunk 1 — Activation recommendation and runtime guidance

### Goal

Create one tested, side-effect-free recommendation model from existing
activation state and use it to correct restart-required runtime recovery
guidance without changing engine state or the public profile-status schema.

### Files

Primary change surface:

- `lib/profile/activation.sh`
- `lib/profile/CONTEXT.md`
- `lib/runtime/podman.sh`
- `lib/runtime/CONTEXT.md`
- `tests/lib/profile-activation.sh`
- `tests/lib/runtime.sh`
- `tests/lib/CONTEXT.md`

### Implementation requirements

1. Add a recommendation resolver in the profile activation module. It must
   consume already-resolved activation, machine, override, and registry state
   and produce the exact bounded manifest enum defined above plus human
   label/command information without issuing a Podman command itself.
2. Keep `shimmy_profile_state_read` as the only engine discovery path. Do not
   duplicate Podman machine, connection, workload, registry, or reachability
   queries in runtime diagnostic code.
3. Define deterministic action precedence for masking overrides, missing
   machine, ordinary activation, restart-required projection, already-active
   state, and invalid/unreachable/unsupported state. Unknown or unsafe state
   must resolve to `investigate`, never to a stronger mutation.
4. Update runtime affinity failure rendering so the known
   `registry_restart_required` case prints the exact absolute launcher with
   `profile activate --restart`. Other existing affinity failures retain safe
   generic activation or inspection guidance according to the shared action.
5. Preserve override-value redaction, existing PATH guidance, workload checks,
   and all runtime affinity validation. This chunk changes recommendation text,
   not activation behavior.
6. Keep detailed `shimmy profile status` fields and formatting compatible. If
   it consumes shared labels, do not rename or remove its current human or
   manifest output.
7. Update the closest profile, runtime, test, and command contexts for the new
   shared recommendation ownership.

### Verification checklist

- [x] Profile activation library tests positively prove action mapping for
  active, ordinary activation, restart-required, missing-machine, override,
  and investigate-only states without Podman mutation.
- [x] Runtime tests prove a stale Darwin registry projection names the exact
  absolute `profile activate --restart` command and retains PATH guidance.
- [x] Existing runtime redaction and affinity validation coverage passes.
- [x] Existing detailed profile status tests pass without renamed or removed
  fields if that command consumes the shared resolver.
- [x] Run focused groups concurrently:
  `./tests/test.sh --jobs 3 --group lib-profile-activation --group lib-runtime --group commands-profile`.
- [x] Review `git diff --check`, executable modes, full
  `git diff`, and `git status --short` for accidental mutation-path,
  generated-adapter, or unrelated changes.

### Human review gate

Reviewers confirm the state-to-action mapping is complete and conservative,
restart-required guidance is exact, profile status remains compatible, and no
new engine discovery or mutation path was added. Stop before Chunk 2 pending
explicit acceptance.

Accepted by the user on 2026-08-19.

## Chunk 2 — Top-level engine status

### Goal

Use Chunk 1's recommendation model to expose a concise read-only engine section
and the exact additive engine manifest fields through top-level status without
mutating Podman or changing existing catalog/tool contracts.

### Files

Primary change surface:

- `commands/status.sh`
- `commands/README.md`
- `commands/CONTEXT.md`
- `tests/commands/status.sh`
- `tests/commands/CONTEXT.md`

### Implementation requirements

1. Consume Chunk 1's shared recommendation resolver; do not introduce a second
   state-to-action table in `commands/status.sh`.
2. Keep `shimmy_profile_state_read` as the only engine discovery path. Do not
   duplicate Podman machine, connection, workload, registry, or reachability
   queries in `commands/status.sh` or runtime diagnostic code.
3. Extend `commands/status.sh` to load activation support, resolve engine and
   registry policy state read-only, and print the defined Profile, Podman
   Engine, Catalog, and Tools sections. Preserve all current catalog provenance,
   health, installed-tool, concrete-version, and image-description information.
4. Add the exact `shimmy_engine_*` manifest fields from the target schema. Keep
   every existing `shimmy_*` manifest field unchanged and continue to print
   useful catalog error output before returning nonzero for invalid catalog
   state.
5. Render connection default status without exposing connection URIs. Continue
   redacting the values of `CONTAINER_CONNECTION`, `CONTAINER_HOST`,
   `CONTAINERS_REGISTRIES_CONF`, and
   `CONTAINERS_REGISTRIES_CONF_OVERRIDE`; output only the masking variable
   names already exposed by current profile status.
6. Ensure unavailable Podman, stopped/missing machines, stale registry state,
   invalid metadata, overrides, unsupported hosts, and reachable active state
   remain status values rather than top-level status crashes. Engine inspection
   must not alter the existing catalog-health exit behavior.
7. Keep detailed `shimmy profile status` behavior compatible. If common label
   or recommendation rendering is shared, retain its existing human and
   manifest fields and registry detail block.
8. Update command documentation and closest context files to describe the new
   top-level engine summary, additive manifest schema, and read-only behavior.
9. Use the existing fake-Podman seam for status tests so the offline default
   suite never inspects or mutates the developer's live Podman engine.

### Verification checklist

- [x] Command-status tests prove the human section labels and exact
  restart-required action using deterministic fake engine state.
- [x] Command-status tests prove all exact additive `shimmy_engine_*` manifest
  fields while retaining representative existing profile, catalog, tool,
  version, and image fields.
- [x] Status under unavailable/unsupported fake engine state still reports
  catalog and installed tools without mutation or live Podman access.
- [x] Existing detailed profile status tests pass without renamed or removed
  fields.
- [x] Run focused groups concurrently:
  `./tests/test.sh --jobs 3 --group commands-status --group commands-profile`.
- [x] Review `git diff --check`, executable modes, and `git diff` for accidental
  generated-adapter or unrelated changes.

Verification evidence recorded on 2026-08-19:

- The required concurrent command-status/profile run passed all 8 tests.
- The additional onboarding regression run passed all 11 tests after its
  top-level status calls were routed through the explicit unsupported-host test
  seam.
- Shell syntax checks, `git diff --check`, executable-mode review, full diff
  review, and status review passed without live Podman mutation or generated
  adapter changes.

### Human review gate

Reviewers confirm the human layout is concise, the manifest names/action enum
are acceptable as a stable automation surface, stale runtime guidance is exact,
and status remains read-only. Stop after recording verification and lessons;
Chunk 3 requires separate explicit acceptance.

Accepted by the user at 2026-08-19 12:40:41 EDT.

## Chunk 3 — Atomic root bootstrap rename

### Goal

Make root `bootstrap.sh` the sole checkout bootstrap and update the complete
source-checkout, self-update, test, documentation, canonical-skill, and retained
plan contract without changing the distinct installed install command or
bumping any persisted version.

### Files

Primary change surface:

- `install.sh` renamed to `bootstrap.sh`
- `lib/install/request.sh`
- `lib/install/startup.sh`
- `lib/install/CONTEXT.md`
- `lib/profile/profile.sh`
- `lib/profile/CONTEXT.md`
- `lib/update/management.sh`
- `lib/update/CONTEXT.md`
- `tests/support.sh`
- `tests/lib/runtime.sh`
- `tests/commands/onboarding.sh`
- `tests/commands/startup.sh`
- `tests/commands/catalog.sh`
- `tests/commands/lifecycle.sh`
- `tests/commands/profiles.sh`
- `tests/commands/install.sh`
- `tests/commands/update.sh`
- `tests/commands/skills.sh`
- `tests/lib/CONTEXT.md`
- `tests/commands/CONTEXT.md`
- `README.md`
- `BOOTSTRAP.md`
- `CONTRIBUTING.md`
- `AGENTS.md`
- root and affected child `CONTEXT.md` files
- `commands/README.md`
- `docs/podman.md`
- `docs/prompt-shimmy-project.md`
- `tools/oc/guide.md`
- `plugins/shimmy/skills/shimmy-install/SKILL.md`
- `plugins/shimmy/skills/shimmy-escalation/SKILL.md`
- retained files under `plans/` whose executable instructions or future target
  inventories refer to the root bootstrap

### Implementation requirements

1. Use a Git-preserving file rename from executable root `install.sh` to
   executable root `bootstrap.sh`. Preserve `#!/bin/sh`, source-safe behavior,
   caller state, argument semantics, and executable mode.
2. Update the renamed script's help, source-root discovery, validation,
   diagnostics, temporary variable names when they encode the obsolete file
   identity, and examples to identify `bootstrap.sh`. Do not rename neutral
   internal `shimmy__bootstrap_*` names.
3. Change bootstrap-context checks in `lib/install/request.sh` from
   `$ROOT_DIR/install.sh` to `$ROOT_DIR/bootstrap.sh` while retaining
   `SHIMMY_BOOTSTRAP_PROFILE` validation and bootstrap-only option boundaries.
4. Change the source-checkout validator to require executable
   `<checkout>/bootstrap.sh` and emit a correspondingly named stable invalid
   reason. Update every producer and consumer of that reason in tests,
   diagnostics, catalog binding, and update validation.
5. Change new self-update code to invoke `$source_dir/bootstrap.sh`. Do not add
   fallback to `install.sh`: old installed profiles are intentionally outside
   the new compatibility contract.
6. Update clean-source, update-source, minimal-checkout, stale-checkout, shell
   inventory, onboarding, startup, catalog, lifecycle, and profile test
   fixtures so they construct and exercise the renamed source contract.
7. Preserve subordinate install terminology and paths exactly where they remain
   correct. In particular, do not rename `commands/install.sh`,
   `lib/install/install.sh`, `lib/install/`, `tests/commands/install.sh`,
   installed launcher dispatch, install manifest files, or `shimmy install`.
8. Update current user, contributor, project-prompt, tool-guide, and canonical
   management-skill instructions so all root bootstrap commands use
   `bootstrap.sh`. Explain the hard-cut transition: before adopting the renamed
   checkout, run the old installed `shimmy uninstall --global`; then reinstall
   with `. ./bootstrap.sh`. Do not claim in-place update compatibility.
9. Do not change profile manifest version, catalog schema, layout identity, or
   migration readers. Verify fresh default and upstream profiles still use the
   existing manifest/schema values.
10. Classify the 115 live matches across 33 non-plan files and the 46 matches
    across eight other retained plans. Update commands, session-bootstrap
    blocks, future file inventories, and target terminology; retain only
    semantically historical occurrences and annotate them when an unqualified
    old path could recreate the removed surface.
11. Replace the existing onboarding assertion that root `bootstrap.sh` is
    absent with a positive assertion that it exists and is executable. Do not
    add or retain an automated assertion whose sole purpose is to prove root
    `install.sh` is absent.
12. If a temporary root `install.sh` bridge is used during mechanical passes,
    keep it untracked or explicitly marked implementation-only, do not document
    it as supported, and remove it before verification. The chunk cannot reach
    review with any file, symlink, generated artifact, or forwarding path at
    root `install.sh`; establish this by diff/status review and classified
    inventory, not by adding a negative test.
13. Update canonical skills only. Do not hand-edit `.agents/skills/`; any
    accepted adapter refresh remains an explicit later profile-local
    `shimmy skills update --target repo` lifecycle operation.

### Verification checklist

- [x] Root `bootstrap.sh` is executable and positively exercises sourced and
  executed onboarding behavior, including caller cwd, positional parameters,
  flags, functions, traps, cleanup, fixed jq/rg baseline, and PATH selection.
- [x] Source-checkout validation accepts the new minimal contract, rejects a
  checkout missing `bootstrap.sh` with the renamed reason, and retains all
  other directory/template validation.
- [x] New self-update fixtures and both default/upstream self-update flows invoke
  `bootstrap.sh`, preserve profile isolation and source bindings, and clean
  temporary clones.
- [x] Fresh default and upstream bootstraps retain manifest version 1, catalog
  schema 1, and `profile-materialized-root` layout identity.
- [x] Documentation and canonical skills state the required hard-cut global
  uninstall/reinstall transition and contain no current command recommending
  root `install.sh`.
- [x] A classified full-tree search confirms remaining `install.sh` matches
  refer only to subordinate install code, test module names, deliberately
  historical text with a supersession note, or generated adapters awaiting
  their explicit lifecycle refresh.
- [x] Diff and status review confirm the Git-preserving rename and that no
  temporary root bridge, alias, symlink, forwarding path, or compatibility
  fallback remains; no automated root-absence assertion is required.
- [x] Run affected groups with default bounded concurrency:
  `./tests/test.sh --jobs 3 --group lib-runtime --group commands-onboarding --group commands-startup --group commands-catalog --group commands-lifecycle --group commands-profiles --group commands-install --group commands-update --group commands-skills`.
- [x] Review `git diff --check`, executable modes, full `git diff`, and
  `git status --short` for accidental subordinate-install renames,
  generated-adapter edits, or unrelated changes.

Verification note: the bounded nine-group run passed every selected group
except `commands-lifecycle`, where a retained test positively proved an
unmanaged sentinel survived uninstall and then attempted to `rmdir` its
nonempty disposable profile root. The baseline contained the same impossible
cleanup. Removing that proved-preserved fixture before `rmdir` fixed the test;
the required serial diagnostic rerun then passed all 19 lifecycle tests. A
final focused onboarding rerun passed all 11 tests after the diagnostic wording
was aligned to `bootstrap`.

### Human review gate

Reviewers confirm the root naming ambiguity is removed, the hard compatibility
break and uninstall/reinstall procedure are explicit, subordinate installed
install surfaces retain their names, no migration/version change or bridge
remains, source checkout and self-update use the new contract, and focused
verification passes. Stop before Chunk 4 pending explicit acceptance.

Accepted by the user on 2026-08-19 at 13:23:40 EDT.

## Chunk 4 — Explicit safe bootstrap activation

### Goal

Add bootstrap-only `--activate`, delegate its post-install operation to the
existing state machine with automatic restart selection and unchanged workload
safeguards, then align all user, contributor, and canonical agent guidance and
run integrated acceptance.

### Files

Primary change surface:

- `bootstrap.sh`
- `lib/install/request.sh`
- `lib/install/install.sh`
- `lib/install/CONTEXT.md`
- `tests/commands/onboarding.sh`
- `tests/commands/install.sh`
- `tests/commands/skills.sh`
- `tests/commands/CONTEXT.md`
- `README.md`
- `BOOTSTRAP.md`
- `CONTRIBUTING.md`
- `AGENTS.md`
- `docs/podman.md`
- `docs/prompt-shimmy-project.md`
- `plugins/shimmy/skills/shimmy-install/SKILL.md`
- `plugins/shimmy/skills/shimmy-init/SKILL.md` only if wording must change to
  consume exact recommendations while preserving narrow approvals

### Implementation requirements

1. Add `--activate` to root `bootstrap.sh` help and the bootstrap request parser.
   Accept it only in checkout-bootstrap context and preserve all current
   profile, shell, startup-policy, fixed jq/rg, sourcing, and help behavior.
2. After profile asset commit and startup integration succeed, resolve the
   recommendation through Chunk 1's shared helper. Invoke existing activation
   with restart only for `profile_activate_restart`; use ordinary activation
   for all other states so existing validation emits authoritative failures.
3. Never translate bootstrap activation into `--stop-running`. When activation
   would stop a VM with workloads, retain the existing workload listing and
   refusal. The error must provide the exact separate retry command, including
   `--restart` when applicable and explaining that `--stop-running` is an
   explicit interruption acknowledgement.
4. Treat activation as post-commit external work. On failure, retain the valid
   profile and startup integration, return nonzero, state `installed but not
   activated`, and provide exact retry/status guidance. Do not attempt to
   uninstall or roll back installed files as compensation for Podman failure.
5. On success, retain the current source/execution distinction: a sourced
   bootstrap selects the installed PATH afterward; an executed bootstrap cannot
   alter its parent shell. Shell initialization remains PATH-only.
6. Keep no-option bootstrap behavior non-activating and installed additive
   install engine-neutral. Extend existing tests only as needed to protect this
   durable external-mutation boundary; do not create generic absence tests.
7. Cover fresh and repeated bootstrap activation. At minimum prove a stopped
   target uses ordinary activation and a running stale target with zero
   workloads automatically uses restart and creates a current projection
   record through the fake seam.
8. Prove a workload-blocked or injected activation failure returns nonzero
   after installation, retains a valid profile, performs no unacknowledged
   machine stop, and is recoverable by a later explicit or repeated activation.
9. Update human documentation with both explicit flows:
   `. ./bootstrap.sh` followed by manual status/dry-run/activate, and
   `. ./bootstrap.sh --activate` for a single requested human workflow. Document
   the idle-VM restart/switch effect and workload refusal before presenting the
   convenience.
10. Update `AGENTS.md`, the reusable project prompt, and canonical management
    skills so AI agents continue using absolute launcher status, dry-run, and
    separately approved activation. State explicitly that the combined option
    does not collapse those authorization gates.
11. Do not edit `.agents/skills/`. Adjust `tests/commands/skills.sh` only for
    semantic assertions against canonical sources; any generated adapter update
    remains a separately authorized post-implementation lifecycle action.
12. Update root/install/test context documentation to reflect the optional
    post-install engine phase and its partial-failure boundary.

### Verification checklist

- [x] Root help documents `--activate`, its effects, workload boundary, and
  source-versus-execution PATH behavior before any installation occurs.
- [x] Fake-Podman onboarding tests prove stopped-machine ordinary activation
  and running stale-machine automatic restart, projection, record, connection,
  and successful PATH selection.
- [x] A post-commit activation failure test proves nonzero status, retained
  valid installed state/startup ownership, exact recovery guidance, and no
  unacknowledged workload interruption.
- [x] Existing no-option sourced/executed onboarding remains non-activating and
  preserves caller cwd, positional parameters, flags, functions, traps, and
  temporary-variable cleanup.
- [x] Existing installed additive install coverage proves tool installation
  remains engine-neutral and preserves profile registry/projection state.
- [x] Canonical skill tests prove human bootstrap convenience and AI-agent
  narrow approval guidance coexist without generated adapter edits.
- [x] Run focused groups concurrently:
  `./tests/test.sh --jobs 3 --group commands-onboarding --group commands-install --group commands-skills --group lib-profile-activation`.
- [x] Run the complete bounded-parallel acceptance suite with
  `./tests/test.sh`; rerun only any failing group serially for diagnosis.
- [x] Review `git diff --check`, executable modes, full `git diff`, and
  `git status --short`; verify no generated `.agents/skills/`, external profile,
  startup file, or live Podman state was changed by tests.

Verification evidence recorded on 2026-08-19:

- The required four-group bounded run passed all 35 focused tests.
- The complete bounded run passed every offline and fake-engine group. Its sole
  failure was the live-Podman `commands-test` smoke being unable to reach the
  engine from the sandbox; the required serial diagnostic rerun outside the
  sandbox passed all 3 tests.
- Shell syntax checks, `git diff --check`, executable-mode review, full diff and
  status review passed. Tests used disposable profile/startup roots, changed no
  generated `.agents/skills/` adapters, and the only live Podman operations
  were the existing non-mutating smoke checks in the elevated diagnostic run.

### Human review gate

Reviewers confirm `--activate` is explicit and bootstrap-only, automatic
restart selection remains protected by workload checks, partial failure is
clear and recoverable, no agent approval boundary was collapsed, documentation
matches behavior, and the full suite passes or every partial verification item
has an explicit accepted disposition.

Accepted by the user at 2026-08-19 14:15:01 EDT.

## Risk register

- **Intentional hard update break:** A pre-rename installed updater clones a new
  checkout and executes `install.sh`; a pre-rename upstream control plane also
  validates that filename in its bound checkout. Removing the file makes those
  old paths fail. Mitigation: this is an accepted incompatibility; document and
  require old-control-plane `shimmy uninstall --global` before checkout
  adoption, followed by fresh `bootstrap.sh` installation.
- **Incomplete semantic rename:** A missed producer, validator, fixture, skill,
  or resumable instruction can recreate the old surface or make a valid new
  checkout appear damaged. Mitigation: update the source contract atomically,
  classify all 115 live matches and 46 matches across eight other retained
  plans, run the broad affected group set, and review the rename through diff,
  status, and the classified inventory without adding a root-absence test.
- **Install/bootstrap terminology damage:** Mechanical replacement could rename
  correct profile-bound install files or commands. Mitigation: preserve the
  explicit subordinate path allowlist in the design and review every remaining
  match semantically.
- **Unversioned hard transition:** Manifest/schema versions do not distinguish
  a pre-rename installation. Mitigation: do not claim automatic detection or
  migration; make global uninstall/reinstall the supported operator procedure
  and keep the persisted formats unchanged as explicitly requested.
- **Temporary bridge leakage:** A bridge used to stage mechanical edits could
  accidentally become a de facto compatibility API. Mitigation: never document
  it, mark its removal as a completion condition, and fail the Chunk 3 and final
  review gates while any root `install.sh` path remains.
- **Unexpected VM interruption:** Explicit bootstrap activation can restart the
  expected idle VM or stop an idle alternate VM. Mitigation: opt-in flag,
  documented effect, existing workload enumeration/refusal, and no implicit
  `--stop-running`.
- **Post-commit partial failure:** Podman activation can fail after profile and
  startup state commit. Mitigation: do not attempt cross-system rollback;
  return nonzero, report the installed state, preserve retryability, and test
  recovery.
- **State/read race:** Recommendation is resolved before activation takes its
  locks. Mitigation: activation re-reads and validates under its existing
  locks; do not auto-retry with stronger options when state changes.
- **Status latency or environmental reachability:** Top-level status now asks
  Podman for read-only state. Mitigation: reuse the bounded state reader,
  degrade to explicit unavailable/unreachable values, avoid registry/image
  network calls, and keep catalog/tool reporting available.
- **Automation compatibility:** Human status formatting changes materially.
  Mitigation: explicitly treat human output as presentation, preserve all
  information, and make manifest changes additive with exact tests.
- **Divergent action guidance:** Bootstrap, status, and runtime errors could
  recommend different commands. Mitigation: centralize semantic action mapping
  and test each consumer, especially the restart-required case.
- **Secret disclosure:** Podman connection URIs or environment override values
  could leak through combined status. Mitigation: emit connection names and
  masking variable names only; preserve existing redaction tests.
- **Approval-boundary regression:** Agents might interpret `--activate` as
  authorization bundled with install. Mitigation: retain explicit agent
  workflow in `AGENTS.md` and canonical skills and never use the convenience in
  agent instructions.
- **Live engine mutation during tests:** New status/installer tests might touch
  the developer's Podman machine. Mitigation: use the existing purpose-built
  fake seam and disposable XDG roots for every engine-aware scenario.

## Lessons learned

### Initial

- Root `install.sh` is not only documentation: it is the public sourced/executed
  entrypoint, a source-checkout validity marker, and the executable selected by
  installed self-update. The rename is therefore an intentional interface and
  checkout-contract break even though bootstrap behavior is otherwise
  unchanged.
- Existing installed profiles cannot self-update across a hard removal because
  their materialized `lib/update/management.sh` selects the old path. The user
  explicitly chose global uninstall/reinstall instead of a compatibility
  bridge or versioned migration.
- The repository contains distinct and correctly named install surfaces below
  `commands/`, `lib/install/`, and `tests/commands/`; broad terminology edits
  must not rename them.
- The reported VS Code Bash failure is not PATH selection: the installed
  wrapper runs and rejects a running `shimmy-default` engine whose registry
  projection and record are absent.
- Current runtime diagnostics lose state specificity after detecting
  `restart-required`; plain `profile activate` then fails and prints the actual
  `--restart` command.
- Profile activation already centralizes engine discovery, workload guards,
  restart behavior, projection ownership, locking, and rollback. Bootstrap and
  status should consume it rather than introduce another Podman control path.
- Root bootstrap, installed additive install, shell PATH selection, and engine
  activation have distinct ownership and authorization boundaries. The new
  convenience must not merge those boundaries implicitly.
- The existing retained named/custom-profile plan forbids implicit activation,
  not an explicit bootstrap option. This plan is compatible as long as it does
  not broaden profile identity or custom-profile scope.

### Chunk 1

- The installed runtime can consume `shimmy_profile_state_read` directly from
  its materialized profile helpers, eliminating its duplicate connection,
  reachability, and registry-projection queries while retaining the existing
  runtime-affinity boundary.
- Recommendation precedence is conservative and side-effect free: masking
  overrides, a missing deterministic machine, ordinary activation states,
  restart-required projection, and active state resolve before all unsafe or
  unknown states fall back to `investigate`.
- Connection and registry overrides must be classified before Podman discovery
  so their variable names can be reported without querying an engine or
  exposing their values.
- The detailed `shimmy profile status` field set and formatting did not need to
  change for the shared resolver; focused command-profile coverage confirms
  compatibility.

### Chunk 2

- Top-level status can inspect engine state before catalog resolution without
  changing catalog-health failure semantics; this also lets invalid catalog
  output retain useful Profile and Podman Engine context.
- The existing recommendation resolver supplies both the bounded manifest enum
  and exact human recovery command, so status needs no second action table.
- Unrelated status assertions must explicitly select a test host state now that
  top-level status performs real read-only discovery. Shared installed-command
  helpers use an unsupported-host seam, while dedicated status coverage uses
  the fake Podman seam for deterministic Darwin state.
- Connection metadata is retained internally for validation but only connection
  names, masking variable names, and bounded state values reach either output
  format; fake and secret URI values are covered by redaction assertions.

### Chunk 3

- The hard rename remained source-safe because the root bootstrap's neutral
  `shimmy__bootstrap_*` implementation did not need structural changes; only
  its public name, checkout marker, diagnostics, and consumers changed.
- A minimal checkout fixture containing executable `bootstrap.sh` and no
  compatibility entrypoint proves the new validator contract, while the
  default/upstream fetched-update successes prove new self-update code has no
  fallback to the removed name.
- Remaining `install.sh` matches classify into subordinate installed install
  code and test-module names, explicit hard-cut history, the authoritative
  transition plan, or generated adapters awaiting an explicit later skills
  lifecycle refresh. Current commands and resumable retained-plan inventories
  use `bootstrap.sh`.
- Fresh default and upstream lifecycle scenarios can positively retain manifest
  version 1, catalog schema 1, and `profile-materialized-root` without adding a
  migration or old-entrypoint rejection test.
- The broad acceptance run exposed a retained lifecycle fixture cleanup defect:
  after proving an unmanaged sentinel survived uninstall, the test attempted to
  remove its still-nonempty disposable root. Deleting the sentinel only after
  that proof restored the intended scenario progression without changing the
  production ownership contract.

### Chunk 4

- Bootstrap activation remains a post-commit installer phase by resolving the
  shared recommendation in the checkout process and invoking the newly
  installed absolute profile launcher for the transition. The separate process
  preserves the activation command's `set -e`, lock, and rollback behavior
  while keeping machine lifecycle logic out of the installer.
- A single pre-activation state read selects ordinary versus restart activation;
  the invoked state machine re-reads under its existing locks and safely refuses
  state races or workload-bearing transitions.
- Workload failure guidance retains the selected restart option and adds
  `--stop-running` only as a separately displayed acknowledgement command;
  bootstrap itself never sends that option.
- Reusing the profile activation fake at the onboarding boundary proves stopped
  starts, stale restarts, projection and record freshness, connection selection,
  PATH initialization, post-commit refusal, and repeat recovery through
  installed control assets without touching the developer's engine.
- Human guidance can advertise the combined convenience while agent guidance
  explicitly retains absolute-launcher status, dry-run, exact activation
  approval, and separate workload-interruption confirmation.
- The full suite's only initial failure was a sandbox-only live-Podman smoke;
  its elevated serial rerun passed, distinguishing environment reachability
  from a product regression without replacing the required live check.

## Session bootstrap

For a fresh implementation session:

1. Read `AGENTS.md`, `CONTRIBUTING.md`, root `CONTEXT.md`, this plan, and the
   context files named by the active chunk before editing.
2. Recheck `git status --short` and preserve unrelated work.
3. Treat `lib/profile/activation.sh` as the sole Podman engine state and
   mutation authority. Do not add a second machine lifecycle implementation.
4. Preserve these non-negotiable boundaries: `--activate` is explicit and
   `bootstrap.sh`-only; root `install.sh` remains until the atomic rename and is
   absent from the Chunk 3 review gate onward; subordinate install commands
   keep their names; no manifest/schema version changes; pre-rename profiles
   use global uninstall/reinstall rather than migration; shell initialization
   and installed additive install do not activate; workloads are never
   interrupted without separate `--stop-running`; no Podman machine is
   provisioned or removed; agent approval gates remain separate; generated
   `.agents/skills/` adapters are untouched.
5. All four chunks are implemented, verified, and accepted. This plan is
   complete.
6. Use fake Podman seams and disposable roots for tests. Follow the default
   bounded parallel runner guidance and use serial reruns only to diagnose a
   failure.
7. Keep this completed plan as the implementation and acceptance record for
   all four chunks.
