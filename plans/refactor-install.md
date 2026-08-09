# Sourceable installer and shell-initialization refactor

## Status

Proposed. This document is the implementation plan; it does not preserve the
current activation command, profile manifest schema, retired options, retired
environment variables, or earlier installed-profile layouts.

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
  terminating the calling shell;
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

## Execution sequence

This is one breaking schema and command-surface transition. Implement it on one
branch without compatibility scaffolding.

1. Add manifest-v4 constants and rename the owned profile shell-init asset
   throughout validation, staging, transaction, update, and uninstall code.
2. Make generated shell-init idempotently establish profile precedence and
   update default startup integration to source it.
3. Refactor root `install.sh` into the source-safe dual-mode entrypoint while
   enforcing the jq/rg baseline and preserving absolute executed self-update
   behavior.
4. Require explicit installed `shimmy install --shim` selection and remove
   catalog-owned bootstrap defaults plus self-update shim forwarding.
5. Remove bootstrap and profile-lifecycle skill flags, parser state, external
   skill export, retry guidance, and self-update forwarding.
6. Delete the activation command and remove launcher exposure.
7. Remove dead and retired install/activation branches, variables, helpers,
   messages, and compatibility tests.
8. Replace activation tests with sourced onboarding, shell hygiene, profile
   switching, and shell-init ownership coverage.
9. Update active documentation, contexts, canonical skill guidance, and
   checked-in skill distributions.
10. Run the complete validation matrix and perform a final old-name audit.

## Validation

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

## Acceptance criteria

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

## Out of scope

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
