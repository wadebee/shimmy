# Sourceable installer and shell-initialization refactor

## Status

QA reviewed; proposed for implementation. This document does not preserve the
current activation command, profile manifest schema, retired options, retired
environment variables, or earlier installed-profile layouts.

## QA review findings

The design is internally consistent after the following execution constraints
are made explicit:

- The manifest-v4 transition, `activate.sh` to `shell-init.sh` ownership
  change, profile-structure validation, installed launcher validation, and
  public activation-command removal form one atomic review boundary. Do not
  leave a checkpoint that renders v4 while any v3 or `activate.sh` consumer is
  still active.
- Tests must change with the behavior they cover. Do not defer all test work to
  a final test-only pass; each chunk below owns its focused fixtures and
  assertions.
- A sourced file can avoid calling `exit`, changing shell options, or leaking
  state, but it cannot override the calling shell's `errexit` behavior. If a
  caller with `set -e` sources a failing installer as a simple command, the
  caller's shell may exit. Test failure cleanup both with ordinary shell
  options and with the dot command used as a conditional command.
- PATH normalization needs explicit coverage for duplicate profile entries and
  leading, middle, and trailing empty entries. A simple `for` loop over a
  colon-separated PATH is not sufficient evidence that empty entries retain
  their meaning.
- Profile commit and persistent startup-file integration are separate
  transactions. A startup update may fail after a valid profile commit; the
  required guarantee is that root `install.sh` does not source `shell-init.sh`
  after that failure. The plan does not promise rollback of an already
  committed profile when external startup-file mutation fails.
- Root checkout validation is duplicated necessarily before repository
  libraries can be trusted and sourced. Keep its required-path contract aligned
  with `shimmy_upstream_checkout_invalid_reason` through focused tests.
- The repository test runner is intentionally monolithic. Every approved code
  checkpoint runs `./tests/test.sh`; focused disposable-shell checks supplement
  rather than replace it.
- Checked-in skill distributions and fingerprints must be regenerated only
  after canonical guidance is final, then verified by the normal test suite.

No backward-compatibility or migration requirement was added by this review.

## Objective

Make the repository `install.sh` the single onboarding entrypoint for both
installation and immediate use:

```sh
source ./install.sh
shimmy status
```

When sourced, `install.sh` must install the selected profile and initialize the
calling shell only after the complete install request succeeds. When executed,
the same file must remain suitable for automation and self-update:

```sh
./install.sh --no-startup
```

Remove the public `shimmy activate` command. Retain shell initialization as a
small generated profile asset used by the sourceable installer, persistent
default-profile startup integration, and explicit maintainer profile
selection.

Backward compatibility and in-place migration are explicitly out of scope.
Use the refactor to remove obsolete branches, variables, tests, and terminology
rather than retaining aliases, warnings, shims, or transitional layouts.

## Target user experience

### Default onboarding

From the repository root:

```sh
source ./install.sh
shimmy status
```

The first command installs the default profile, applies its normal persistent
startup integration, and places that profile's `bin/` directory first on the
current shell's `PATH`. `shimmy` and the installed tool dispatchers are
available as soon as the command returns successfully.

### Fixed bootstrap baseline

```sh
source ./install.sh
command -v jq rg
```

Every new default or upstream profile includes exactly the `jq` and `rg` tool
kinds and their catalog-default concrete versions. The repository installer
does not accept tool selection. Install additional tools only after onboarding
through the installed management surface:

```sh
shimmy install --shim oc
shimmy install --shim oc@4.18
```

`shimmy install` requires at least one explicit `--shim` request. Omitting the
option must fail without installing any implicit default set.

### Upstream maintainer profile

```sh
source ./install.sh --profile upstream
shimmy status --format manifest
```

Sourcing an upstream install initializes that profile in the current shell but
does not create or modify persistent startup integration. Sourcing either
profile again must move that profile's `bin/` directory to the front of
`PATH`, making profile switching deterministic.

### Automation and self-update

```sh
./install.sh --profile default --no-startup
```

Executed mode performs the same installation transaction and exits. Any
shell initialization performed inside that process naturally disappears when
the process exits. Callers that require parent-shell mutation must source the
file.

Self-update may continue invoking a fetched checkout's `install.sh` by absolute
path. Executed path resolution must therefore remain independent of the
caller's working directory.

## Recorded design decisions

### One file, two process semantics

- Do not add `setup.sh`, `activate`, `enable`, or another onboarding wrapper.
- Do not attempt to launch, replace, signal, or terminate the parent shell.
- Do not attempt to detect sourced mode. Run one logical flow: perform the
  install in an isolated child and then source the installed shell-init asset.
  The environment persists only when the entrypoint itself was sourced.
- Document `source ./install.sh` as the human-oriented Bash and Zsh form and
  `. ./install.sh` as the portable POSIX form.
- Treat sourced mode as interactive onboarding. Noninteractive scripts and CI
  should execute `./install.sh` rather than source it.

### Source-safe root entrypoint

The root `install.sh` is the only file intentionally safe to source. It must:

- omit top-level `set -eu`; shell options belong to the caller;
- never execute a top-level `exit`, `exec`, `trap`, `cd`, or shell-option
  mutation;
- run strict validation and `commands/install.sh` in an isolated child process
  that may continue using `set -eu`;
- pass `SHIMMY_BOOTSTRAP_PROFILE` only to that child rather than exporting it
  into the calling shell;
- source the installed shell-init file only after the full install command,
  including explicitly requested startup integration, returns success;
- return a nonzero status on validation or installation failure without
  explicitly terminating the calling shell; callers that already use
  `set -e` must source it in a conditional command if they intend to recover
  from failure;
- leave the caller's current working directory, positional parameters, shell
  options, traps, functions, and non-Shimmy variables unchanged;
- remove every temporary bootstrap variable and helper function before
  returning; and
- intentionally persist only the environment changes rendered by the installed
  shell-init asset.

Use one narrowly prefixed internal entry function if it improves cleanup and
argument isolation. Do not use non-POSIX `local` declarations. Capture the
function's status, remove the function and its prefixed variables, and end with
a simple success/failure command that works both when sourced and executed.
Normalizing all failures to status 1 is acceptable if it materially simplifies
complete cleanup; success must remain status 0.

### Fixed bootstrap tool policy

- The repository `install.sh` always requests exactly `jq` and `rg` when it
  creates or refreshes a profile.
- The fixed baseline applies equally to `default` and `upstream`.
- Move the existing `SHIMMY_DEFAULT_KINDS='jq rg'` policy out of the shared
  catalog and replace it with one narrowly scoped bootstrap-layer constant or
  function. Remove `shimmy_default_kind_list`; catalog discovery must not own
  installer product policy.
- Validate both baseline kinds through the catalog before profile mutation.
- Do not expose `--shim` from repository `install.sh`. Reject it before
  mutation with guidance to finish onboarding and run
  `shimmy install --shim <kind>`.
- Limit the public repository bootstrap options to profile selection, explicit
  startup integration, and help. Profile removal remains `shimmy uninstall`;
  tool selection and internal refresh controls remain outside bootstrap.
  External skill export remains an explicit installed `shimmy skills`
  operation.
- Preserve explicitly installed non-baseline kinds and concrete versions when
  the repository installer refreshes an existing valid profile. The fixed
  baseline is merged into existing manifest ownership; it is not a request to
  reduce the profile to two tools.
- Require one or more explicit `--shim` values from the installed
  `shimmy install` command. Remove the current no-selection fallback that
  expands to the shared jq/rg default list.
- Keep `shimmy install --shim <kind>@<version>` as the only user-facing path for
  adding non-default concrete versions.
Self-update must not reconstruct the installed tool selection as root-installer
`--shim` arguments. The existing valid manifest already owns the installed
kinds and concrete versions, and additive profile staging must preserve them.
Remove the self-update argument-building loops that forward every manifest kind
and non-default version to fetched `install.sh`.

### Profile-packaged skills only

- Canonical `agent/` skill sources and the checked-in `plugins/` bundle remain
  unconditional profile payload assets.
- Repository `install.sh`, installed `shimmy install`, self-update, and
  uninstall do not accept `--no-skills` or `--skills-target`.
- Remove bootstrap's post-commit external skills transaction. Profile lifecycle
  operations never write repository or home `.agents/skills` targets.
- Delete `profile_external_integrations_apply`; after profile commit, invoke
  requested startup-file integration directly before normal completion.
- Remove `SKIP_SKILLS`, `REQUESTED_SKILLS_TARGET`, target validation from the
  install request parser, skills-target retry messages, and related branches.
- Remove self-update forwarding of `--no-skills`; no suppression flag is needed
  when profile lifecycle has no external skills side effect.
- Keep the standalone `shimmy skills` command and its explicit
  `--target repo|profile|plugin` behavior unchanged in this refactor.

Future changes to external skill discovery, automatic target selection, or the
standalone skills lifecycle are outside this plan. This refactor only removes
skills concerns from profile bootstrap and lifecycle orchestration.

### Checkout-root resolution

A sourced POSIX file cannot portably discover its own path. Resolve the source
checkout using this order:

1. If `dirname "$0"` resolves to a checkout satisfying the bootstrap contract,
   use it. This covers normal execution and absolute-path self-update.
2. Otherwise, if the canonical current working directory satisfies the same
   contract, use it. This covers `source ./install.sh` from the checkout root.
3. Otherwise fail before mutation with guidance to change to the checkout root
   and source `./install.sh`.

Do not add Bash-, Zsh-, or Ksh-specific source-path introspection. Validate the
resolved checkout using the existing required source paths and executable
entrypoint requirements.

### Internal shell initialization

Replace the profile-root `activate.sh` asset with:

```text
<profile-root>/shell-init.sh
```

The generated file is an owned, regular, non-symlink file with mode 0644. It
must remain small POSIX shell code and must:

- remove every exact occurrence of its profile `bin/` path from `PATH` and
  prepend exactly one occurrence;
- preserve the order and meaning of every other `PATH` entry, including empty
  entries if present;
- retain the existing macOS `/opt/podman/bin` fallback when Podman is present
  there but otherwise unresolved;
- export `PATH`;
- be idempotent when sourced repeatedly;
- clean all temporary variables before returning; and
- avoid exporting a Shimmy profile selector or other activation state.

Moving the selected profile path to the front fixes the current inability to
switch back to a profile whose path already exists later in `PATH`.

The default profile's managed startup block must source the canonical default
`shell-init.sh`. The upstream profile must never own persistent startup state;
its shell initialization occurs through sourced bootstrap or explicit sourcing
of its installed `shell-init.sh`.

`--no-startup` means “do not mutate persistent shell startup files.” It must
not disable immediate current-shell initialization when `install.sh` is
sourced.

### Public management surface

The installed launcher exposes only:

```text
install
uninstall
netinfo
skills
status
test
update
```

Remove `activate` from launcher dispatch, help, examples, documentation, and
skills. Delete `commands/activate.sh`; do not retain a compatibility alias,
deprecation warning, hidden command, or forwarding stub. The launcher's normal
unknown-command behavior is sufficient for `shimmy activate` after the
refactor.

### Atomic profile schema boundary

Rename an individually owned profile-root asset and change the installed
command surface atomically. Bump both manifest identity versions from 3 to 4:

```text
shimmy_install_manifest_version=4
shimmy_profile_manifest_version=4
```

Keep `shimmy_install_layout=profile-flat-root` because the overall flat profile
model remains accurate. Manifest v4 structure validation requires
`shell-init.sh` and does not recognize `activate.sh` as an owned asset.

Do not migrate or update manifest-v3 profiles in place. Do not remove their
files automatically. Current code must reject non-v4 profile manifests through
the normal unsupported-manifest path. Users who need old-profile removal must
use the version that created that profile; no new migration workflow is part
of this change.

Remove the special version-2 shared-root detector. Unknown files at the Shimmy
config root remain unmanaged siblings and are preserved. Keep strict rejection
tests for malformed or wrong-version manifests located at the selected profile
root; schema validation is a safety property, not backward-compatibility code.

### Deprecated surface removal

Remove rather than preserve or test these obsolete behaviors:

- the unused `SHIMMY_INSTALL_SOURCE_MODE` variable;
- all `SHIMMY_PROFILE_ACTIVE` assertions and compatibility fixtures;
- the no-op `--copy` request branch;
- the custom removed-branch handling for `--symlink`;
- the unused hidden `--refresh-shims` request branch and `REFRESH_SHIMS` state;
- repository-installer `--shim` forwarding;
- shared `SHIMMY_DEFAULT_KINDS`, `shimmy_default_kind_list`, and the implicit
  jq/rg fallback when an installed install request omits `--shim`;
- `--no-skills`, `--skills-target`, `SKIP_SKILLS`,
  `REQUESTED_SKILLS_TARGET`, and install-request skills-target validation;
- the profile installer's post-commit external skills transaction and its
  partial-success retry guidance;
- the now-redundant `profile_external_integrations_apply` wrapper;
- self-update `--no-skills` forwarding;
- tests dedicated to ignored `SHIMMY_INSTALL_DIR`,
  `SHIMMY_CONTROL_INSTALL_DIR`, and `SHIMMY_UPSTREAM_DIR` values;
- tests dedicated to the retired `--install-dir` spelling; retain one generic
  unknown-option test instead;
- `shimmy_version_two_install_reject` and its call sites;
- dead activation helpers such as `shimmy_activate_block_read`;
- unused startup summary helpers discovered during implementation; and
- activation-specific variables, function names, comments, and messages.

Unknown options must continue to fail before mutation through the ordinary
request parser. Do not add special errors for removed option names.

## Implementation workstreams

### 1. Refactor the root bootstrap

Update `install.sh` to implement the source-safe contract:

- replace top-level strict mode and `exec` with a cleanup-safe entry flow;
- parse bootstrap-only `--profile default|upstream` without mutating the
  caller's positional parameters;
- preserve executable absolute-path behavior required by
  `lib/update/management.sh`;
- validate the source checkout before installation;
- invoke `commands/install.sh` as a child with command-scoped bootstrap
  profile state;
- inject the fixed `jq` and `rg` baseline into that internal child request;
- reject caller-supplied `--shim` before mutation and direct additional tool
  selection to installed `shimmy install`;
- reject all skills-related bootstrap options through the generic unsupported
  option path; do not add replacement bootstrap controls;
- reject repository-bootstrap uninstall and hidden internal refresh requests;
- resolve the selected canonical profile path after successful install;
- verify `shell-init.sh` is a regular, non-symlink readable file before
  sourcing it;
- source it and propagate success or failure without exiting the caller; and
- rewrite help around the sourced onboarding and executed automation modes.

Do not duplicate the full install option parser in the root entrypoint. It must
recognize enough of the bootstrap surface to reject tool selection before
mutation and may inspect the bootstrap-only leading profile selector, but
`lib/install/request.sh` remains authoritative for the supported integration
options passed to the child install request.

### 2. Rename and improve the profile shell-init asset

Update the installation lifecycle consistently:

- rename `SHIMMY_ACTIVATE_FILE` to `SHIMMY_SHELL_INIT_FILE`;
- rename `write_activate_file` and related locals to shell-init terminology;
- stage `shell-init.sh` instead of `activate.sh`;
- update collision validation, backup, restore, atomic commit, rollback, and
  uninstall ownership lists;
- update profile structure validation;
- update default startup-block rendering to source `shell-init.sh`;
- ensure self-update and additive install replace the owned shell-init asset;
  and
- preserve unknown profile-root siblings during every transaction.

Use an atomic same-directory temporary file and rename when committing the
profile shell-init asset, matching the manifest's ownership behavior.

### 3. Remove the public activation command

- Delete `commands/activate.sh`.
- Remove its launcher case and help row.
- Remove the redundant `eval "$(shimmy activate)"` example.
- Update the command context and management-surface descriptions.
- Ensure installed command staging no longer includes an activation entrypoint.
- Keep installed launchers profile-bound; this refactor does not reintroduce
  installed `--profile` selection.

### 4. Establish manifest v4

- Render v4 install and profile manifest identities.
- Validate v4 in shared profile helpers and the self-contained installed
  launcher template.
- Update manifest error text and test fixtures.
- Replace claimed `activate.sh` ownership with `shell-init.sh` ownership.
- Remove the config-root version-2 guard and its duplicate calls before and
  during install.
- Retain all current manifest parsing, identifier safety, duplicate ownership,
  source-checkout, and profile-identity validation.

### 5. Simplify bootstrap and startup request logic

- Remove `SHIMMY_INSTALL_SOURCE_MODE`; path resolution already yields the
  resolved profile and no caller uses the mode value.
- Remove `--copy`, `--symlink`, and hidden `--refresh-shims` branches plus
  `REFRESH_SHIMS` state and validation.
- Remove `SHIMMY_DEFAULT_KINDS` and `shimmy_default_kind_list` from the catalog.
  Bootstrap supplies its fixed internal jq/rg selection; an installed
  `shimmy install` request without `--shim` fails before mutation.
- Remove self-update construction of root `--shim` arguments. Verify management
  refresh preserves every kind and version already recorded in the valid
  profile manifest while ensuring jq and rg remain installed.
- Remove install-request parsing and state for `--no-skills` and
  `--skills-target`.
- Remove the profile installer's external skills transaction so successful
  profile commit proceeds directly to normal install completion after any
  requested startup integration.
- Remove `profile_external_integrations_apply` and call the startup integration
  routine directly; do not retain a generic external-integration abstraction
  for a single operation.
- Remove self-update `--no-skills` forwarding.
- Replace “manual activation only” terminology with “no persistent startup
  integration” or “manual shell initialization,” depending on context.
- For rejected upstream startup mutation, direct the user to source the exact
  installed upstream `shell-init.sh` or source the repository installer with
  `--profile upstream`; never reference a removed launcher command.
- Preserve default-only startup ownership, explicit startup overrides,
  idempotent managed markers, and exact uninstall cleanup.

### 6. Update tests around intent, not compatibility

Delete `tests/commands/activate.sh` and its runner/context registration. Add or
rename a focused onboarding/shell-init module that covers:

- `. ./install.sh` installs the default profile in an isolated disposable XDG
  environment, records exactly jq and rg in a fresh manifest, and makes
  `shimmy`, `jq`, and `rg` resolvable later in the same shell process;
- repository `install.sh --shim <kind>` fails before mutation with guidance to
  use installed `shimmy install`;
- installed `shimmy install` without `--shim` fails before mutation;
- installed `shimmy install --shim <kind>` adds the requested kind without
  changing the jq/rg baseline or unrelated existing kinds;
- rerunning repository installation preserves explicitly added kinds and
  concrete versions while continuing to ensure jq and rg are present;
- all existing bootstrap fixtures that pass `--shim` are rewritten around the
  fixed jq/rg baseline; scenarios needing another kind add it afterward with
  the installed `shimmy install --shim <kind>` command;
- all bootstrap, installed install, update, and uninstall fixtures drop
  `--no-skills`;
- `source`/dot failure returns nonzero while a command after it can still run,
  proving the calling shell was not exited;
- sourced help does not install or change `PATH`;
- sourced install does not change caller shell options, traps, positional
  parameters, or working directory and leaves no bootstrap helpers or
  temporary variables;
- `--no-startup` avoids startup-file mutation while still initializing the
  sourced current shell;
- executing `./install.sh` remains valid for automation;
- absolute-path execution from a different working directory remains valid for
  self-update;
- self-update preserves non-baseline kinds and non-default versions without
  forwarding root-installer `--shim` options;
- default and upstream sourced installs each select the expected profile;
- switching default → upstream → default changes `command -v shimmy` and
  manifest status deterministically;
- repeated sourcing leaves one selected profile path occurrence;
- shell-init retains `/opt/podman/bin` fallback behavior;
- an install or startup-integration failure does not source shell-init;
- profile bootstrap and lifecycle tests assert only profile-local canonical
  skill and plugin payload ownership; they do not create external skills
  targets;
- missing, symlinked, or damaged shell-init assets fail safely;
- `shimmy` help omits `activate` and lists every remaining command with a
  description;
- the removed activation command file is absent from installed payloads;
- startup integration sources `shell-init.sh` and remains idempotent;
- update refreshes and uninstall removes the owned shell-init asset;
- v4 manifests are rendered and accepted;
- v3, malformed, duplicated, unsafe, and wrong-profile manifests at a profile
  root remain rejected without mutation; and
- generic unknown options fail before mutation without dedicated retired-name
  behavior.

Remove tests whose only purpose is demonstrating ignored retired environment
variables, special errors for retired flags, config-root version-2 migration
guidance, `SHIMMY_PROFILE_ACTIVE` having no effect, bootstrap skills-target
integration, or `--no-skills` suppression. Preserve collision,
symlink traversal, profile isolation, partial-profile, manifest safety,
startup ownership, dispatcher binding, and self-update coverage.

Keep focused `commands/skills.sh` tests for explicit target ownership,
manifest-tracked cleanup, export behavior, and collision handling. Rewrite
their setup to bootstrap profiles without skill options, then invoke
`shimmy skills` explicitly for every external target operation.

Run sourced-installer scenarios in disposable child shells so test execution
cannot alter the test runner's own `PATH`, options, traps, functions, or
working directory.

### 7. Update active guidance and generated skill distributions

Update active documentation and contexts together with implementation:

- `README.md` onboarding and management-command table;
- `CONTRIBUTING.md` maintainer profile workflow;
- root and child `CONTEXT.md` files for commands, install, startup, profiles,
  tests, and canonical skills;
- `docs/testing.md`, `docs/podman.md`, and
  `docs/prompt-shimmy-project.md`;
- tool guides that instruct maintainers to activate upstream, including the OC
  guide;
- canonical `agent/core/shimmy-install/SKILL.md`; and
- checked-in repository and plugin skill exports plus their manifests or
  fingerprints through the existing canonical export workflow.

Describe `source ./install.sh` as onboarding and immediate profile selection.
Describe direct sourcing of installed `shell-init.sh` only as an advanced path
when the source checkout is unavailable. Remove “activated shimmy command,”
“manual-activation-only,” and `eval ... shimmy activate` guidance.

Document that canonical skills and the plugin bundle are packaged with every
profile while repository and home skill targets remain explicit standalone
`shimmy skills` operations. Remove bootstrap `--no-skills` and
`--skills-target` examples and guidance.

Document jq and rg as the complete bootstrap tool baseline. Every additional
tool example must use `shimmy install --shim <kind>` after onboarding; do not
show `./install.sh --shim ...` or `source ./install.sh --shim ...`.
Audit tests, tool guides, contributor workflows, skills, and self-update
fixtures for direct repository-installer `--shim` calls; convert every active
example and fixture to the fixed bootstrap followed by installed management
when a non-baseline tool is required.

Historical completed plan records do not need wholesale rewriting. Update a
historical record only if it explicitly claims its embedded command is current
operational guidance; otherwise preserve it as design history.

## File impact inventory

Expected primary implementation changes:

```text
install.sh
commands/activate.sh                         (delete)
lib/catalog/catalog.sh
lib/install/install.sh
lib/install/request.sh
lib/install/profile-assets.sh
lib/install/startup.sh
lib/install/uninstall.sh
lib/install/manifest.sh
lib/install/launcher-template.sh
lib/profile/profile.sh
lib/startup/startup.sh
lib/update/update.sh                         (wording)
lib/update/management.sh                     (remove shim forwarding; validate absolute execution)
```

Expected primary test changes:

```text
tests/test.sh
tests/commands/activate.sh                   (delete)
tests/commands/onboarding.sh                 (add, final name may vary)
tests/commands/install.sh
tests/commands/lifecycle.sh
tests/commands/management.sh
tests/commands/profiles.sh
tests/commands/startup.sh
tests/commands/update.sh
tests/commands/dispatcher.sh
tests/commands/skills.sh
tests/commands/status.sh
tests/commands/test.sh
tests/support.sh                              (only if a narrow helper is useful)
```

Documentation, context, skill, and checked-in export changes follow the active
guidance audit rather than this list being exhaustive.

# Progress Checklist

This checklist is the resumability source of truth. Update it immediately after
each implementation pass, validation pass, human decision, and lessons-learned
entry. Do not mark a chunk complete until all four boxes for that chunk are
checked.

Resume record:

```text
Last approved chunk: 3
Current chunk: 4
Last known-good revision or diff base: c2b0584f8545d0fd5e593baa292a8f6bb54c84e7
Last validation command and result: ./tests/test.sh (exit 0; all 79 tests passed); git diff --check (exit 0)
Outstanding human decision: approve the Chunk 4 fixed bootstrap baseline, explicit installed selection, tests, and validation evidence
```

- [x] Chunk 0 implementation/inventory complete
- [x] Chunk 0 validation evidence captured
- [x] Chunk 0 human review approved
- [x] Chunk 0 lessons recorded
- [x] Chunk 1 implementation complete
- [x] Chunk 1 validation evidence captured
- [x] Chunk 1 human review approved
- [x] Chunk 1 lessons recorded
- [x] Chunk 2 implementation complete
- [x] Chunk 2 validation evidence captured
- [x] Chunk 2 human review approved
- [x] Chunk 2 lessons recorded
- [x] Chunk 3 implementation complete
- [x] Chunk 3 validation evidence captured
- [x] Chunk 3 human review approved
- [x] Chunk 3 lessons recorded
- [x] Chunk 4 implementation complete
- [x] Chunk 4 validation evidence captured
- [ ] Chunk 4 human review approved
- [ ] Chunk 4 lessons recorded
- [ ] Chunk 5 implementation complete
- [ ] Chunk 5 validation evidence captured
- [ ] Chunk 5 human review approved
- [ ] Chunk 5 lessons recorded
- [ ] Chunk 6 implementation complete
- [ ] Chunk 6 validation evidence captured
- [ ] Chunk 6 human review approved
- [ ] Chunk 6 lessons recorded
- [ ] Chunk 7 implementation complete
- [ ] Chunk 7 validation evidence captured
- [ ] Chunk 7 human review approved
- [ ] Chunk 7 lessons recorded
- [ ] Chunk 8 implementation complete
- [ ] Chunk 8 validation evidence captured
- [ ] Chunk 8 human review approved
- [ ] Chunk 8 lessons recorded

If execution is interrupted, resume the current chunk only. Read this checklist,
the latest entry in `# Lessons Learned`, the diff since the recorded known-good
base, and every applicable `CONTEXT.md` before making another change. Do not
restart completed chunks or discard uncommitted work.

# Ordered Implementation Chunks

This is one breaking schema and command-surface transition implemented on one
branch without final-state compatibility scaffolding. Start each chunk in a
fresh Codex context when practical. A new context reads only the objective,
recorded design decisions, its chunk, the progress checklist, accumulated
lessons, applicable context files, and the current diff. Earlier chunks are
inputs, not work to repeat.

## Human-in-the-loop review protocol

After every chunk, stop before beginning the next chunk and provide the human
reviewer with:

1. the chunk objective and concise behavior-level result;
2. changed, added, and deleted files grouped by implementation, tests, and
   guidance;
3. exact validation commands, exit statuses, and any skipped checks;
4. the focused diff or recorded revision range;
5. known risks, assumptions, and deliberately deferred work; and
6. a proposed `# Lessons Learned` entry.

The reviewer must explicitly approve the chunk or request changes. Requested
changes remain part of the same chunk and require revalidation. After approval,
record the revision or diff base, update all four checklist boxes and the resume
record, complete the approved lesson row, and only then start the next chunk. If the
workflow uses commits, create the checkpoint commit only after the reviewer
approves its diff; otherwise record an immutable diff base or patch identifier.

For a transient failure, preserve the worktree, record the failed command and
its output summary in the resume record, and keep the chunk's unchecked boxes
unchecked. Do not broaden the scope, silently skip validation, or advance to the
next chunk.

## Chunk 0: Baseline, inventory, and decision lock

Goal: establish a reproducible pre-change baseline and confirm that the plan's
file inventory matches the active tree. This chunk changes only this plan if an
inventory correction is necessary.

Implementation:

- Read `CONTRIBUTING.md`, root `CONTEXT.md`, and every child `CONTEXT.md` on the
  path to files in the first implementation chunk.
- Record `git status --short`, the starting revision, and any pre-existing user
  changes. Preserve unrelated changes throughout the refactor.
- Run the complete old-name and retired-option audit and save the active-tree
  match inventory, excluding `plans/`.
- Map each match to Chunks 1 through 7 so no deletion or guidance update is
  orphaned.
- Confirm the intended manifest-v4 break, lack of v2/v3 migration, fixed jq/rg
  baseline, removal of bootstrap lifecycle skill options, and activation-command
  removal with the human reviewer before product changes.

Validation evidence:

```sh
./tests/test.sh
git diff --check
```

Also capture `git status --short` and the audit match counts. If the baseline
suite fails, stop and classify the failure as pre-existing or plan-blocking;
do not mix an unrelated repair into this refactor without human approval.

Human review gate: approve the baseline, dirty-worktree boundaries, active-tree
inventory, and breaking decisions.

Post-processing: update the resume record and checklist, then add the first
entry under `# Lessons Learned`, including any corrected file inventory or test
assumption.

### Chunk 0 execution record

Recorded on 2026-08-09 from starting revision
`fdd8f98cefe90d1d901c37c8c19985a95a7699b0`. `git status --short` produced no
output before the audit, so there are no pre-existing user changes to preserve.
The audit excluded `plans/` and `.git/`.

Exact retired-name and option matches at the starting revision:

| Pattern | Matching lines | Files |
| --- | ---: | ---: |
| `shimmy activate` | 10 | 7 |
| `commands/activate.sh` | 3 | 2 |
| `activate.sh` | 17 | 13 |
| `SHIMMY_ACTIVATE_FILE` | 4 | 4 |
| `SHIMMY_PROFILE_ACTIVE` | 7 | 3 |
| `SHIMMY_INSTALL_SOURCE_MODE` | 2 | 1 |
| `manual-activation-only` | 12 | 10 |
| `SHIMMY_DEFAULT_KINDS` | 2 | 1 |
| `shimmy_default_kind_list` | 2 | 2 |
| `--no-skills` | 25 | 10 |
| `--skills-target` | 7 | 3 |
| `SKIP_SKILLS` | 3 | 2 |
| `REQUESTED_SKILLS_TARGET` | 6 | 2 |
| `--copy` | 1 | 1 |
| `--symlink` | 1 | 1 |
| `--refresh-shims` | 2 | 2 |
| `REFRESH_SHIMS` | 3 | 2 |
| `profile_external_integrations_apply` | 2 | 1 |
| `shimmy_version_two_install_reject` | 3 | 2 |
| `shimmy_activate_block_read` | 1 | 1 |
| `SHIMMY_INSTALL_DIR` | 1 | 1 |
| `SHIMMY_CONTROL_INSTALL_DIR` | 1 | 1 |
| `SHIMMY_UPSTREAM_DIR` | 1 | 1 |
| retired `--install-dir` test coverage | 4 | 2 |
| literal manifest-v3 identities | 7 | 5 |
| `version-3` guidance | 4 | 4 |
| repository-bootstrap `install.sh ... --shim` invocations | 16 | 8 |

The broader wording audit found 43 lowercase `activation` matches in 18 files
and 107 lowercase `activate` matches in 36 files. These totals intentionally
include legitimate runtime helpers such as `shimmy_podman_path_activate`; Chunk
7 must classify rather than mechanically remove those generic matches.

Match ownership for later chunks:

- Chunk 1 owns PATH rendering and focused current-name coverage in
  `lib/install/startup.sh`, `tests/commands/activate.sh`, and any narrow
  disposable-shell support added to `tests/support.sh`.
- Chunk 2 owns the atomic command/schema/asset boundary in
  `commands/activate.sh`, `lib/install/{install,launcher-template,manifest,profile-assets,request,startup,uninstall}.sh`,
  `lib/profile/profile.sh`, `lib/startup/startup.sh`, `tests/test.sh`, and the
  affected command tests for activation, install, lifecycle, management,
  profiles, and startup.
- Chunk 3 owns the dual-mode root `install.sh`, checkout resolution, sourced
  shell cleanup, and onboarding coverage in `tests/commands/` plus any narrow
  `tests/support.sh` helper.
- Chunk 4 owns bootstrap baseline and explicit installed selection matches in
  `lib/catalog/catalog.sh`, `lib/install/{install,request}.sh`,
  `lib/update/management.sh`, and affected install, lifecycle, management,
  profiles, skills, startup, and update tests.
- Chunk 5 owns lifecycle skill-option and external-integration matches in
  `lib/install/{install,request}.sh`, `lib/update/management.sh`,
  `tests/support.sh`, and affected install, lifecycle, profiles, skills, and
  startup tests. Explicit standalone `shimmy skills` behavior remains.
- Chunk 6 owns the remaining retired parser/state/version-two/startup-summary
  helpers and compatibility-only fixtures in `lib/install/{install,request}.sh`,
  `lib/profile/profile.sh`, `lib/startup/startup.sh`, and affected dispatcher,
  install, profiles, skills, and command-test fixtures, including the dedicated
  ignored-variable and `--install-dir` assertions.
- Chunk 7 owns active wording, examples, contexts, and generated distributions
  in `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `commands/CONTEXT.md`,
  `lib/{install,profile,startup}/CONTEXT.md`, `tests/CONTEXT.md`,
  `tests/commands/CONTEXT.md`, `docs/{netinfo,podman,prompt-shimmy-project,testing}.md`,
  `docs/network-tools.md`, `tools/{oc/guide.md,rg/CONTEXT.md}`, canonical
  `agent/core/shimmy-{install,init,escalation}` guidance, and the matching
  checked-in `plugins/shimmy/skills/` exports and fingerprints.

The active inventory corrects the expected-impact list by explicitly adding
the init/escalation skill wording, network and netinfo guidance, the ripgrep
context, `AGENTS.md`, and retired `--install-dir` coverage. No product file is
changed in this chunk.

Validation evidence:

```text
./tests/test.sh   exit 0; All 69 Shimmy tests passed.
git diff --check exit 0 after this record was added.
git status --short: plans/refactor-install.md is the only changed path.
```

Human confirmation remains required for the manifest-v4 break without v2/v3
migration, the fixed jq/rg bootstrap baseline, removal of bootstrap lifecycle
skill options, and removal of the public activation command before Chunk 1
begins.

## Chunk 1: PATH precedence behavior and sourced-shell test support

Goal: implement and prove the final PATH normalization behavior before crossing
the schema boundary. Keep manifest v3, `activate.sh`, and the public activation
command unchanged in this chunk.

Implementation:

- Refactor the generated shell code so the selected profile bin path is removed
  from every exact PATH entry and prepended exactly once.
- Preserve all other entries in order, including empty leading, middle, and
  trailing entries, and retain the conditional macOS `/opt/podman/bin` fallback.
- Keep the generated code POSIX, idempotent, non-exporting except for `PATH`, and
  free of temporary variables after sourcing.
- Add narrow disposable-child-shell helpers only where they reduce duplication;
  do not let a sourced scenario mutate the main test runner.
- Extend the existing activation tests or add the future onboarding test module
  to cover repeated sourcing, profile switching, PATH duplicates, empty entries,
  variable cleanup, and Podman fallback behavior under the current filename.

Validation evidence:

```sh
./tests/test.sh
git diff --check
```

Human review gate: inspect the generated POSIX shell, exact PATH-before/PATH-after
test cases, macOS fallback, and absence of caller-state leakage.

Post-processing: update the resume record and checklist and add a lesson about
the PATH algorithm or disposable-shell harness.

### Chunk 1 execution record

The generated manifest-v3 `activate.sh` now parses PATH entries with an
explicit colon-delimited loop. It removes every selected-profile entry,
prepends that entry once, retains the order and count of all other entries
including leading, middle, and trailing empties, and cleans every temporary
variable. The existing conditional `/opt/podman/bin` append remains after PATH
normalization.

Focused disposable `/bin/sh` coverage in `tests/commands/activate.sh` proves a
normal PATH, duplicate selected-profile entries mixed with all three empty-entry
positions, default/upstream/default switching, repeated sourcing, temporary
variable cleanup, and a deterministic injected Podman fallback. Manifest v3,
the `activate.sh` filename, and the public `activate` command remain unchanged.

Validation evidence:

```text
dash -n lib/install/startup.sh tests/commands/activate.sh   exit 0
./tests/test.sh                                            exit 0; all 69 tests passed
git diff --check                                           exit 0
```

The first full-suite attempt failed in the new duplicate/empty-entry assertion.
Inspection of the generated file showed that `printf` consumed one `%` from
the intended `${value%%:*}` shell expansion and rendered `${value%:*}`. The
renderer now escapes both percent signs as `%%%%`; the complete suite then
passed. No product behavior outside PATH rendering changed.

## Chunk 2: Atomic manifest-v4, shell-init, and command-surface boundary

Goal: cross the breaking schema boundary in one checkpoint. No active v4
consumer may expect `activate.sh`, and no installed launcher may expose
`activate` after this chunk. This is an internal, non-release checkpoint: until
Chunk 3 is approved, current-shell selection uses direct sourcing of the
installed `shell-init.sh`.

Implementation:

- Bump both manifest identities to 4 in rendering, shared validation, error
  messages, fixtures, and the self-contained launcher template.
- Rename all owned asset constants, functions, locals, staging paths, collision
  checks, backup/restore paths, commit temporaries, structure checks, update
  behavior, and uninstall ownership from activation to shell-init terminology.
- Generate and atomically commit `shell-init.sh` as a regular non-symlink 0644
  file, preserving rollback of directories, launcher, manifest, dispatchers, and
  the shell-init asset on commit failure.
- Update default startup blocks to source the canonical `shell-init.sh`; remove
  dead activation-block helpers where they cease to have callers.
- Delete `commands/activate.sh`; remove launcher dispatch, help, examples, staged
  command exposure, and command-context registration.
- Update tests in the same checkpoint: v4 acceptance, v3/wrong/malformed
  rejection, shell-init ownership and mode, collision and symlink safety,
  startup/update/uninstall behavior, unknown sibling preservation, launcher help,
  and absence of the removed command and file.
- Rename `tests/commands/activate.sh` to `tests/commands/onboarding.sh` if that is
  the selected final module name, update `tests/test.sh`, and update the closest
  test context.

Validation evidence:

```sh
./tests/test.sh
git diff --check
```

Run focused disposable installs for both profiles and inspect their manifests,
owned root assets, launcher help, startup block, and uninstall results. Do not
test a compatibility alias.

Human review gate: review the complete schema-boundary diff as a unit. Reject the
chunk if any renderer, validator, transaction, launcher, update, uninstall, or
test fixture remains on the old identity or filename.

Post-processing: update the resume record and checklist and add a lesson about
atomic schema changes, rollback, or ownership validation.

### Chunk 2 execution record

Manifest rendering, shared profile validation, and the self-contained installed
launcher now require identity version 4. The owned profile shell asset is
`shell-init.sh`: staging, collision checks, backup/restore, same-directory
temporary commit, failure cleanup, structure validation, startup rendering,
refresh, and uninstall use that identity consistently. Both profiles render a
regular non-symlink mode-0644 asset. Manifest-v3 profiles are rejected without
in-place refresh.

The public activation command and its installed entrypoint were deleted. The
launcher omits activation from dispatch, help, and examples; direct sourcing of
the installed `shell-init.sh` is the current-shell selection path until Chunk 3.
Default startup blocks source the canonical shell-init file. Upstream startup
mutation errors identify the exact file that can be sourced manually.

Implementation changes:

- deleted `commands/activate.sh`;
- updated `lib/install/{install,launcher-template,manifest,profile-assets,request,startup,uninstall}.sh`;
- updated `lib/profile/profile.sh`, `lib/startup/startup.sh`, and
  `lib/update/update.sh`.

Test changes:

- replaced `tests/commands/activate.sh` with
  `tests/commands/onboarding.sh` and updated `tests/test.sh`;
- updated install, lifecycle, management, profiles, startup, update, and shared
  support coverage for v4 identity, shell-init ownership/mode, additive and
  self-update replacement, startup sourcing, command absence, damaged-asset
  safety, uninstall, and manifest-v3 rejection.

Guidance changes were limited to the closest command, install, profile, startup,
and command-test `CONTEXT.md` files. The full active-guidance and generated-skill
audit remains assigned to Chunk 7.

Validation evidence:

```text
dash -n lib/install/install.sh lib/install/request.sh lib/install/manifest.sh lib/install/profile-assets.sh lib/install/startup.sh lib/install/uninstall.sh lib/install/launcher-template.sh lib/profile/profile.sh lib/startup/startup.sh lib/update/update.sh tests/support.sh tests/test.sh tests/commands/onboarding.sh tests/commands/lifecycle.sh tests/commands/management.sh tests/commands/profiles.sh tests/commands/startup.sh tests/commands/update.sh
  exit 0
./tests/test.sh
  exit 0; all 70 tests passed
git diff --check
  exit 0
```

Focused validation used `/private/tmp/shimmy-chunk2.ajR7KM` and completed with
these results:

```text
env XDG_CONFIG_HOME=/private/tmp/shimmy-chunk2.ajR7KM/config HOME=/private/tmp/shimmy-chunk2.ajR7KM/home ./install.sh --profile default --shim jq --shell zsh --startup-file /private/tmp/shimmy-chunk2.ajR7KM/zshrc --no-skills
  exit 0
env XDG_CONFIG_HOME=/private/tmp/shimmy-chunk2.ajR7KM/config HOME=/private/tmp/shimmy-chunk2.ajR7KM/home ./install.sh --profile upstream --shim rg --no-startup --no-skills
  exit 0
env XDG_CONFIG_HOME=/private/tmp/shimmy-chunk2.ajR7KM/config HOME=/private/tmp/shimmy-chunk2.ajR7KM/home /private/tmp/shimmy-chunk2.ajR7KM/config/shimmy/profiles/default/bin/shimmy activate
  exit 1; ERROR: unknown command: activate
env XDG_CONFIG_HOME=/private/tmp/shimmy-chunk2.ajR7KM/config HOME=/private/tmp/shimmy-chunk2.ajR7KM/home /private/tmp/shimmy-chunk2.ajR7KM/config/shimmy/profiles/default/bin/shimmy uninstall --no-skills
  exit 0
env XDG_CONFIG_HOME=/private/tmp/shimmy-chunk2.ajR7KM/config HOME=/private/tmp/shimmy-chunk2.ajR7KM/home /private/tmp/shimmy-chunk2.ajR7KM/config/shimmy/profiles/upstream/bin/shimmy uninstall --no-skills
  exit 0
```

Direct inspection showed v4 identities for both profiles, only
`shell-init.sh` as the owned root shell asset, mode 0644, no activation help or
installed command file, a default startup block sourcing `shell-init.sh`, and
complete owned-root/startup-block removal. No checks were skipped.

## Chunk 3: Source-safe dual-mode repository installer

Goal: make root `install.sh` safe to source while retaining executed automation
and absolute-path self-update behavior. Keep tool-selection and skills-policy
changes outside this chunk unless needed to pass the new entrypoint's internal
request unchanged.

Implementation:

- Replace top-level strict mode, `exec`, and exit-based helpers with one
  cleanup-safe, narrowly prefixed flow.
- Resolve and validate the checkout in the recorded `$0` then canonical-PWD
  order, with contract tests aligned to
  `shimmy_upstream_checkout_invalid_reason`.
- Parse the bootstrap-only leading `--profile default|upstream`, help, and
  root-only rejection cases without shifting the caller's positional
  parameters or duplicating the installed request parser.
- Run strict validation and `commands/install.sh` in a child with
  command-scoped `SHIMMY_BOOTSTRAP_PROFILE`.
- After complete child success, resolve the canonical selected profile and
  verify that `shell-init.sh` is readable, regular, and non-symlink before
  sourcing it.
- Clean every root-bootstrap helper and temporary variable on success and every
  failure path. Preserve cwd, positional parameters, functions, traps, shell
  options, and unrelated variables.
- Intercept sourced help before mutation. Preserve executed install from the
  repository root and absolute-path execution from another cwd.
- Add disposable `/bin/sh` sourced scenarios plus Bash/Zsh-oriented syntax only
  where those shells are available. Cover ordinary failure recovery and a
  caller with `set -e` using the dot command in a conditional context; do not
  claim the caller's own `errexit` can be overridden.
- Prove `--no-startup` still initializes the current sourced shell and that an
  install or external startup-file failure never sources shell-init.

Validation evidence:

```sh
./tests/test.sh
git diff --check
```

Run the focused sourced, executed, absolute-path, help, failure-cleanup, and
default/upstream switching matrix in absolute disposable HOME/XDG roots.

Human review gate: inspect every top-level command in root `install.sh`, all
cleanup paths, checkout-resolution diagnostics, caller-state assertions, and
the distinction between external startup failure and profile commit.

Post-processing: update the resume record and checklist and add a lesson about
sourced POSIX behavior, shell-specific observations, or checkout resolution.

### Chunk 3 execution record

The repository `install.sh` is now a source-safe dual-mode entrypoint. It has no
top-level strict mode, exit, exec, trap, or directory change. One narrowly
prefixed function resolves the source checkout from the executed `$0` location
or canonical current directory, repeats the required checkout validation in a
strict child, invokes `commands/install.sh` with child-scoped bootstrap profile
state, and sources the installed profile's validated `shell-init.sh` only after
the complete install request succeeds. Executed absolute-path installation from
another directory remains valid.

All bootstrap variables and the helper function are removed on success and
recoverable failure. Sourced installs preserve caller working directory, shell
options, traps, functions, positional parameters, and unrelated variables.
Help does not install or alter PATH. `--no-startup` still initializes the
current sourced shell, while startup integration failure may leave a committed
profile but does not select it in PATH. Missing, symlinked, non-file, and
unreadable generated shell-init assets are rejected without sourcing.

Implementation changes:

- rewrote root `install.sh` as the dual-mode source-safe entrypoint;
- updated root `CONTEXT.md` for sourced and executed behavior.

Test changes:

- expanded `tests/commands/onboarding.sh` with disposable `/bin/sh`, Bash, and
  Zsh sourced scenarios, caller-state and cleanup assertions, failure recovery,
  help, startup failure, invalid checkout, shell-init validation, absolute
  execution, and repeated default/upstream switching;
- updated `tests/commands/CONTEXT.md` for the broader onboarding scope.

Validation evidence:

```text
dash -n install.sh tests/commands/onboarding.sh
  exit 0
./tests/test.sh
  exit 0; all 78 tests passed
git diff --check
  exit 0
```

The initial complete-suite attempt stopped because replacing `install.sh`
temporarily removed its executable bit; mode 0755 was restored before behavioral
validation. A later failure test showed that a plain final `false` inside a
sourced file can trigger Bash 3.2 `errexit` before the dot command's conditional
caller recovers. The failure terminator now uses a negated successful command,
which returns status 1 without preempting cleanup; ordinary and conditional
failure scenarios both pass. No checks were skipped.

## Chunk 4: Fixed bootstrap baseline and explicit installed selection

Goal: move jq/rg baseline policy to bootstrap, make installed additions
explicit, and preserve existing manifest ownership during bootstrap refresh and
self-update.

Implementation:

- Add a narrowly scoped root-bootstrap jq/rg request and validate both kinds
  before profile mutation.
- Reject repository-installer `--shim` before mutation with installed-command
  guidance. Keep bootstrap profile selection and integration options within the
  recorded public surface.
- Remove `SHIMMY_DEFAULT_KINDS` and `shimmy_default_kind_list` from catalog
  policy and tests.
- Make installed `shimmy install` require one or more `--shim` values before
  mutation while preserving `kind@version` behavior.
- Ensure additive merge keeps unrelated kinds and concrete versions and keeps
  jq/rg present on repository reinstall.
- Remove manifest-to-root `--shim` argument reconstruction from self-update;
  prove fetched absolute execution plus existing-manifest merge preserves all
  owned kinds and versions.
- Rewrite bootstrap fixtures around the fixed baseline and add other kinds only
  through the installed launcher.

Validation evidence:

```sh
./tests/test.sh
git diff --check
```

Include focused fresh default/upstream manifest assertions, pre-mutation
rejection checks, additive kind/version preservation, and self-update evidence.

Human review gate: compare fresh, additive, repository-refresh, and self-update
manifest snapshots and verify that catalog discovery no longer owns product
defaults.

Post-processing: update the resume record and checklist and add a lesson about
policy placement, request validation, or manifest-preserving merge behavior.

### Chunk 4 execution record

The repository bootstrap now rejects caller-supplied `--shim` before profile
mutation and internally requests the fixed jq/rg baseline for both profiles.
Catalog discovery no longer defines installer defaults. Installed `shimmy
install` requires at least one explicit `--shim` while preserving additive
`kind@version` behavior. Repository refresh and fetched self-update rely on the
existing valid manifest merge rather than reconstructing root-installer shim
arguments, so unrelated kinds and concrete versions remain owned.

Implementation changes:

- updated root `install.sh` to document and inject the fixed baseline and reject
  public tool selection with installed-command guidance;
- removed `SHIMMY_DEFAULT_KINDS` and `shimmy_default_kind_list` from
  `lib/catalog/catalog.sh`;
- updated `lib/install/{install,request}.sh` for explicit installed selection;
- removed manifest-to-bootstrap selection reconstruction from
  `lib/update/management.sh`.

Test changes rewrote repository bootstrap fixtures without `--shim`, moved
non-baseline additions to installed launchers, and added exact fresh
default/upstream baseline assertions, pre-mutation rejection checks, additive
repository-refresh snapshots, status expectations, and self-update preservation
for `task` plus non-default `oc@4.18` ownership. Closest root, install, update,
and command-test contexts describe the new policy.

Validation evidence:

```text
dash -n install.sh lib/catalog/catalog.sh lib/install/request.sh lib/install/install.sh lib/update/management.sh tests/commands/onboarding.sh tests/commands/dispatcher.sh tests/commands/install.sh tests/commands/lifecycle.sh tests/commands/profiles.sh tests/commands/skills.sh tests/commands/startup.sh tests/commands/status.sh tests/commands/test.sh tests/commands/update.sh
  exit 0
./tests/test.sh
  exit 0; all 79 tests passed
git diff --check
  exit 0
```

The first two complete-suite attempts stopped on stale status assertions that
still modeled jq-only default and rg-only upstream profiles. Those assertions
now require both baseline kinds and treat rg as installed rather than available;
the complete suite then passed. No checks were skipped.

## Chunk 5: Remove skills concerns from profile lifecycle

Goal: make canonical skills and the plugin bundle unconditional profile payload
while keeping every external skills target an explicit standalone operation.

Implementation:

- Remove `--no-skills`, `--skills-target`, parser state, target validation,
  post-commit export, partial-success retry guidance, and self-update forwarding
  from bootstrap, install, update, and uninstall lifecycle paths.
- Remove `profile_external_integrations_apply`; invoke requested startup
  integration directly after profile commit.
- Retain profile staging of canonical `agent/` sources and the checked-in
  `plugins/` bundle.
- Keep `commands/skills.sh` behavior and explicit `repo|profile|plugin` target
  ownership unchanged.
- Rewrite lifecycle fixtures without skills options. Rewrite skills fixtures to
  bootstrap first, then invoke the installed `shimmy skills` command for every
  external target operation.
- Prove profile install/update/uninstall does not write or delete repository or
  home external skill targets.

Validation evidence:

```sh
./tests/test.sh
git diff --check
```

Human review gate: inspect lifecycle calls for any remaining implicit external
skills side effect and separately confirm standalone skills ownership,
collision, export, refresh, and cleanup tests remain intact.

Post-processing: update the resume record and checklist and add a lesson about
separating profile-owned payload from externally owned integrations.

## Chunk 6: Retired install-state and compatibility cleanup

Goal: remove the remaining obsolete branches and vocabulary without changing
the now-established target behavior.

Implementation:

- Remove `SHIMMY_INSTALL_SOURCE_MODE`, `--copy`, custom `--symlink`, hidden
  `--refresh-shims`, `REFRESH_SHIMS`, the config-root v2 detector and duplicate
  calls, `SHIMMY_PROFILE_ACTIVE` fixtures, dead startup summary helpers, and all
  other unused activation-specific helpers discovered by call-site audit.
- Delete tests dedicated only to ignored legacy install-directory environment
  variables, retired `--install-dir`, special retired-option errors, v2
  config-root guidance, and removed activation selector behavior.
- Retain one generic unknown-option pre-mutation test and all profile-root v3,
  malformed, unsafe, duplicate, collision, symlink, isolation, and ownership
  safety tests.
- Replace remaining active “manual activation” terminology with precise shell
  initialization or persistent-startup wording.
- Run a call-site and dead-code audit before deleting any helper; do not remove
  shared behavior solely because its old name contains “activate.”

Validation evidence:

```sh
./tests/test.sh
git diff --check
```

Also run the retired-name audit and classify every remaining match as an allowed
archival-plan reference or a defect.

Human review gate: review deletions separately from renames and confirm safety
coverage was retained even where compatibility coverage was removed.

Post-processing: update the resume record and checklist and add a lesson about
dead-code evidence, vocabulary cleanup, or safety-test preservation.

## Chunk 7: Active guidance, contexts, and generated distributions

Goal: make every active human and agent instruction describe the implemented v4
onboarding model, then regenerate checked-in skill distributions once.

Implementation:

- Update `README.md`, `CONTRIBUTING.md`, active docs, tool guides, root and child
  contexts, test descriptions, and canonical installation skill guidance.
- Audit every active bootstrap example: jq/rg arrive from onboarding; any other
  tool is added afterward through installed `shimmy install --shim`.
- Document sourced onboarding, executed automation, direct advanced sourcing of
  installed shell-init, default-only persistent startup, unconditional
  profile-packaged canonical/plugin skills, and explicit standalone external
  skills operations.
- Keep historical plans unchanged unless they claim to be current operational
  guidance.
- Use the existing canonical export workflow to regenerate `.agents/` and
  plugin skill distributions and their manifests/fingerprints. Do not hand-edit
  generated copies independently of the canonical source.
- Re-read every changed directory's `CONTEXT.md` and update only the closest
  context plus required parent link or description.

Validation evidence:

```sh
./tests/test.sh
git diff --check
```

Also inspect the generated-export diff and run the final active-guidance command
example audit.

Human review gate: review source guidance separately from generated copies,
confirm fingerprints are reproducible, and spot-check onboarding, maintainer,
startup, update, uninstall, and external-skills instructions.

Post-processing: update the resume record and checklist and add a lesson about
guidance drift, context-tree maintenance, or deterministic exports.

## Chunk 8: Final integrated validation and release-readiness audit

Goal: validate the complete target state from a clean disposable environment
without adding new feature scope.

Implementation:

- Run the complete repository suite and every focused validation listed below.
- Exercise sourced default/upstream switching, executed root and absolute-path
  install, additive installed management, self-update preservation, startup
  integration, update, partial/full uninstall, and failure cleanup in fresh
  absolute disposable HOME/XDG roots.
- Inspect manifest v4 and owned modes/paths directly and confirm unknown sibling
  preservation.
- Run the final active-tree forbidden-name and bootstrap-invocation audits,
  excluding archival plans only.
- Review `git diff --stat`, `git diff --check`, executable bits, new/untracked
  files, and unrelated user changes.
- Do not fix newly discovered unrelated issues in this chunk; report them for a
  separate decision.

Validation evidence: all commands and checks under `# Validation`, with exact
statuses recorded. A skipped check requires an explicit human waiver and reason.

Human review gate: the reviewer receives the complete diff, validation matrix,
remaining audit matches with classifications, accepted waivers, and a direct
acceptance-criteria trace. Approval means the plan is implementation-complete;
it does not itself authorize publishing, merging, or deleting old user data.

Post-processing: complete the resume record and checklist and add the final
lesson, including any follow-up work that is explicitly outside this refactor.

# Lessons Learned

This is a cumulative execution log, not a retrospective written only at the
end. Complete the corresponding row after each chunk's human review. Record
evidence and the resulting change to later execution; avoid generic
observations.

| Chunk | Date/reviewer | Evidence or surprise | Action taken in this plan or implementation | Rule for later chunks |
| --- | --- | --- | --- | --- |
| QA | 2026-08-09 / Codex | Schema identity, owned filename, validation, and launcher command removal have the same compatibility boundary; caller `errexit` remains caller-owned. | Grouped the boundary in Chunk 2 and added ordinary plus conditional failure tests. | Never split identity consumers across approved checkpoints or claim a sourced file can neutralize caller `set -e`. |
| 0 | 2026-08-09 / user | The active-tree audit found broader shell-initialization wording and retired `--install-dir` coverage outside the initial primary inventory; generic `activate` matches also include legitimate Podman runtime helpers. | Added the omitted guidance and test paths to the execution inventory and assigned every match to Chunks 1-7. | Classify broad terminology matches by behavior; do not mechanically remove runtime helpers that use “activate” accurately. |
| 1 | 2026-08-09 / user | A literal `printf` renderer consumed one percent sign from the intended `${value%%:*}` expansion until the generated asset was inspected directly. | Escaped both percent signs in the renderer and retained disposable-shell assertions for duplicate and empty PATH entries. | Validate rendered shell text through behavior, not only the renderer's source syntax. |
| 2 | 2026-08-09 / user | Manifest identity, owned shell asset, and launcher command removal reached the same checkpoint with strict v3 rejection and v4 transaction coverage. | Kept rendering, validation, commit/rollback, startup, update, uninstall, launcher, and test fixtures on one v4 boundary. | Treat all producers and consumers of an owned schema identity as one review unit. |
| 3 | 2026-08-09 / user | A plain final `false` in a sourced file can trigger Bash 3.2 `errexit` before a conditional dot-command caller recovers, preventing source-safe cleanup. | End failure paths with a negated successful command so they return status 1 without bypassing cleanup, and retain both ordinary and conditional failure coverage. | Source-safe POSIX entrypoints must test failure cleanup in callers with `errexit`; a function's final status-producing command affects whether the caller can recover. |
| 4 | Pending | Pending | Pending | Pending |
| 5 | Pending | Pending | Pending | Pending |
| 6 | Pending | Pending | Pending | Pending |
| 7 | Pending | Pending | Pending | Pending |
| 8 | Pending | Pending | Pending | Pending |

When a lesson changes a later chunk, edit that chunk immediately and mention the
change in its row. Do not rewrite an approved earlier chunk's record except to
correct a factual error; append the correction to the current row instead.

# Validation

Required repository validation:

```sh
./tests/test.sh
git diff --check
```

The default suite must retain POSIX parse checks for every runnable and
sourceable shell file. Add focused disposable commands equivalent to:

```sh
env XDG_CONFIG_HOME=<absolute-temp-config> HOME=<absolute-temp-home> \
  PATH=/usr/bin:/bin /bin/sh -c '
    . ./install.sh --no-startup
    command -v shimmy
    command -v jq
    command -v rg
    shimmy status --format manifest
  '
```

Also validate:

- executed install from the repository root;
- executed install by absolute path from another working directory;
- sourced default and upstream profile precedence in the same disposable
  shell;
- persistent default startup behavior in a fresh disposable shell;
- failure return without caller termination;
- update and uninstall ownership of `shell-init.sh`; and
- checked-in skill export/manifests or fingerprints.

No live container execution is required when preview and management tests prove
the refactor. If a live smoke is run, use only an installed wrapper's declared
non-mutating `--version`, `version`, or `--help` behavior and follow the exact
Shimmy wrapper approval workflow.

Final active-tree audit, excluding archival plans, must find no implementation,
test, help, active documentation, context, or skill references to:

```text
shimmy activate
commands/activate.sh
activate.sh
SHIMMY_ACTIVATE_FILE
SHIMMY_PROFILE_ACTIVE
SHIMMY_INSTALL_SOURCE_MODE
manual-activation-only
SHIMMY_DEFAULT_KINDS
shimmy_default_kind_list
--no-skills
--skills-target
SKIP_SKILLS
REQUESTED_SKILLS_TARGET
```

The same audit must find no active repository-bootstrap invocation containing
`install.sh --shim` or `source ./install.sh --shim`.

References to generic English “activation” should remain only where that word
is materially clearer than “shell initialization”; prefer the latter
throughout the new architecture.

# Acceptance criteria

- A new user can run `source ./install.sh` from the checkout root and invoke
  `shimmy` immediately in the same shell.
- Every fresh profile contains exactly the jq and rg baseline kinds before any
  explicit installed management requests.
- Every profile contains its canonical agent sources and packaged plugin bundle
  without a skills opt-out.
- Bootstrap, install, update, and uninstall have no skills options, skip state,
  or external skills side effects.
- Repository `install.sh` has no public `--shim` option; additional kinds and
  concrete versions are installed only through explicit
  `shimmy install --shim <kind>[@<version>]` requests.
- Installed `shimmy install` rejects an omitted shim request without mutation.
- The sourced installer returns failures without exiting or contaminating the
  calling shell.
- Executed `./install.sh` remains automation-safe and absolute-path execution
  continues to support self-update.
- `--no-startup` controls only persistent startup mutation.
- Default and upstream profiles can be selected repeatedly with deterministic
  `PATH` precedence.
- The public installed launcher has no activation command or compatibility
  alias.
- Every new profile uses manifest v4 and owns `shell-init.sh`; prior manifests
  are rejected without migration or automatic deletion.
- Default startup integration, additive install, update, rollback, partial
  uninstall, and full uninstall consistently use the new owned asset.
- Obsolete flags, variables, migration guards, helpers, tests, messages, and
  guidance identified in this plan are removed.
- Active documentation, contexts, canonical skills, and generated skill
  distributions describe the same onboarding and profile-selection model.
- The complete repository suite passes.

# Out of scope

- Migrating manifest-v2 or manifest-v3 installations.
- Automatically deleting or rewriting earlier profile layouts.
- Making an installed `shimmy` launcher select a sibling profile.
- Adding profile selection through a new environment variable.
- Installing or provisioning Podman.
- Launching a nested shell or replacing the parent shell.
- Supporting arbitrary-directory sourcing with shell-specific source-path
  introspection.
- Preserving removed option names, variables, commands, files, or error text.
- Selecting bootstrap tool kinds or versions through repository `install.sh`.
- Automatically selecting or modifying repository or home agent-skill targets.
- Redesigning the standalone `shimmy skills` command.
