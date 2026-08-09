# Core-to-lib flattening refactor

## Objective

Make the following non-backward-compatible layout change consistently across
implementation, tests, documentation, contexts, and skills:

- rename the repository shared-module directory from `core/` to `lib/`
- replace the repository management launcher with one minimal root
  `install.sh` bootstrap
- install one self-contained `bin/shimmy` launcher in each installed profile;
  the repository contains no runnable `shimmy` launcher
- install each profile's control, runtime, configuration, and manifest assets
  directly in that profile's canonical XDG-rooted directory instead of below
  a shared bundled `core/` directory
- remove `--install-dir` from the complete management-command surface
- remove Shimmy-defined public environment overrides for installation and
  profile-state locations
- remove all shared-module and installed-layout `core` variables and paths
- give persistent shell startup integration and shared agent-skill targets
  explicit ownership outside the independent profile roots

The work is divided into reviewable chunks for execution across fresh AI
sessions. Every accepted chunk must leave repository bootstrap and installed
profile dispatch operational. Backward compatibility and in-place migration
from the version-2 layout are explicitly out of scope.

## Target layout and terminology

### Repository

```text
shimmy/
  install.sh
  agent/
  commands/
  lib/
    install/
      launcher-template.sh
  plugins/
  tests/
  tools/
```

### Profile installations

Resolve the XDG and Shimmy roots as follows:

```text
<config-home> = $XDG_CONFIG_HOME when it is set, non-empty, and absolute
                $HOME/.config otherwise
<shimmy-config-root> = <config-home>/shimmy
<profiles-root> = <shimmy-config-root>/profiles
<profile-root> = <profiles-root>/<profile-name>
```

`XDG_CONFIG_HOME` is an upstream standard and is the only supported location
input. Shimmy does not place its profile directories directly under the
generic `<config-home>/profiles` path; the `shimmy/` application namespace
prevents collisions with other applications.

Each profile is a complete, independent installation. The current built-in
profiles produce these roots:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/default/
${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/
```

Every profile root has the same installed structure:

```text
<profile-root>/
  activate.sh
  install-manifest.txt
  bin/
    shimmy
    <generated tool dispatchers>
  commands/
  config/
    shims/
  implementations/
    <generated kind and version wrappers>
  lib/
  plugins/
  tests/
  tools/
  agent/
```

The Shimmy config root and profiles root are merge-owned containers. They do
not contain a shared launcher, shared manifest, shared runtime payload, or
shared dispatcher directory. Installing, refreshing, updating, or removing
one profile must not mutate any sibling profile.

The flat profile install does not contain `<profile-root>/.agents/skills`.
Installed skill commands use the canonical sources under
`<profile-root>/agent/core/` and `<profile-root>/tools/<kind>/agent/`. A
`.agents/skills` directory is created only at an explicit user-selected
`shimmy skills` target such as a repository or home agent profile, and remains
governed by its own skills manifest.

Persistent shell startup files and user-selected agent-skill targets are
external integration surfaces, not profile-root assets. The `default` profile
is the sole owner of Shimmy's persistent startup block. The `upstream` profile
is manual-activation-only. A skills target is owned by its skills manifest,
not by any profile that supplied the canonical skill sources.

Terminology used throughout this plan:

- `lib/` means shared POSIX shell modules.
- `agent/core/` means core management skills and is unrelated to the renamed
  shared-module tree.
- `install.sh` is the repository's minimal first-install and profile-bootstrap
  entrypoint. It is not a general management launcher.
- `bin/shimmy` exists only inside an installed profile. It is self-contained
  with that profile's payload, is bound to that profile root, and never
  depends on a repository launcher or a sibling profile.
- A profile root is the complete installed control/runtime root for exactly
  one profile; there is no shared install root or installed `core/` bundle.
- Bootstrap profile selection chooses a canonical location. An installed
  launcher has no profile-selection surface because its enclosing profile is
  its identity. Neither mechanism accepts a caller-supplied filesystem path.

## Recorded design decisions

These decisions are final for this refactor and must not be reopened during
implementation.

### Atomic transition

The source rename, profile-local installed flattening, repository-launcher
removal, minimal bootstrap introduction, per-profile launcher installation,
XDG path resolution, removal of public location and profile-selection
overrides, dispatcher change, manifest schema change, and minimum lifecycle
tests form one atomic first chunk. They span both path models and cannot be
split into independently operational states without temporary compatibility
machinery that this refactor does not need.

### Canonical XDG path and profile selection

- Resolve the config home from absolute, non-empty `XDG_CONFIG_HOME`, falling
  back to `$HOME/.config` only when `XDG_CONFIG_HOME` is unset or empty.
- Reject a non-empty relative `XDG_CONFIG_HOME` with a clear error; never
  reinterpret it relative to the current working directory.
- Keep the supported profile names `default` and `upstream`. Future built-in
  profiles must use the same `<profiles-root>/<profile-name>` convention.
- Accept `--profile default|upstream` only on the repository `install.sh`
  bootstrap. Omission selects `default`.
- Remove `SHIMMY_PROFILE_ACTIVE` and all environment- or argument-driven
  profile selection from installed management and dispatch. An installed
  launcher and every dispatcher derive their profile root from their own
  installed location.
- Activation prepends only the invoking launcher's `<profile-root>/bin` to
  `PATH`; it does not export a Shimmy profile selector. Switch profiles by
  invoking the desired profile's launcher by absolute path and evaluating its
  activation output.
- An installed launcher must reject `--profile` before mutation. It manages
  only its enclosing profile and never discovers, selects, updates, or removes
  a sibling profile.
- Remove `--install-dir` from install, uninstall, activate, status, update,
  test, skills, agent-preflight, and any internal forwarding path. Passing it
  must fail as an unknown argument without mutation.
- Remove `SHIMMY_INSTALL_DIR`, `SHIMMY_CONTROL_INSTALL_DIR`, and
  `SHIMMY_UPSTREAM_DIR` as public or internal location inputs. Because
  backward compatibility is out of scope, implementation must not inspect
  these retired names; setting one has no Shimmy semantics and cannot change
  behavior or relocate state.
- Retain `SHIMMY_UPSTREAM_CHECKOUT_DIR`: it selects the source checkout
  recorded by an upstream profile and does not relocate installed state.
- Repository tests isolate installations by setting an absolute disposable
  `XDG_CONFIG_HOME`; no private install-directory override replaces the public
  option that this refactor removes.

### Upstream maintainer profile and removed source mode

- Remove repository-versus-installed source-mode detection and all
  source-side launcher behavior. The repository exposes only `install.sh` for
  bootstrap; an installed launcher never detects, enters, or dispatches a
  source mode.
- `upstream` encapsulates maintainer functionality as a normal installed
  profile. Its canonical profile root is its identity, it uses the installed
  management command surface, and it obeys the same ownership and
  cross-profile isolation rules as `default`.
- The upstream profile's `bin/shimmy`, management commands, shared libraries,
  manifests, tests, metadata, plugins, and agent guidance are self-contained
  in that profile. They never load management behavior through a repository
  launcher or the recorded maintainer checkout.
- Only generated upstream tool implementations may execute code from the
  absolute, validated `source_checkout` recorded in the upstream manifest.
  Management code may parse and validate that field but never source or
  execute management code from it.
- Upstream self-update may execute the separately fetched update source after
  validating its bootstrap contract, but it must preserve and revalidate the
  upstream profile's recorded maintainer checkout. It must never replace
  `source_checkout` with the temporary fetched source, and removal of that
  temporary source after update must not break upstream tool dispatch.

### External startup and skills ownership

Profile isolation applies to the installed profile trees and to external
integration side effects:

- The `default` profile is the only profile allowed to create, repair, update,
  record, or remove a persistent Shimmy shell-startup block. Its managed block
  uses default-profile-specific start and end markers and sources only the
  canonical default profile's `activate.sh`.
- The `upstream` profile is manual-activation-only. Bootstrapping it behaves as
  `--no-startup`; `--shell`, `--startup-file`, `--repair-startup`, and any
  equivalent request to mutate persistent startup state must fail before
  mutation with guidance to use the upstream launcher's explicit activation
  command.
- Installing, refreshing, updating, or removing `upstream` never reads or
  writes a shell startup file. Removing `default` removes only its exact
  managed marker block and never removes the containing startup file.
- Only a valid default profile manifest may contain startup-shell and
  startup-file metadata. That metadata authorizes management of the exact
  default-profile marker block; it does not make the containing file a
  profile-owned path. An upstream manifest containing startup metadata is
  invalid.
- A repository bootstrap may install or update agent skills only when the user
  explicitly selects a skills target. Additive profile install, profile
  refresh, self-update, and profile uninstall never implicitly mutate a shared
  skills target.
- Each skills target has its own manifest and owns only the skill entries
  recorded there. Profile manifests do not record or claim a skills target.
  Installing skills from either profile updates that target-owned manifest
  idempotently; it does not create profile ownership or a removal reference.
- Removing a profile never removes shared skills. Skills are removed only by
  an explicit `shimmy skills uninstall --target <target>` operation, which
  validates the target's skills manifest, removes only its recorded entries,
  and preserves unknown siblings.
- Commit and validate the profile filesystem transaction before performing an
  explicitly requested startup or skills integration transaction. External
  integration is independently idempotent. If it fails, leave the valid
  profile installed, return a failure, and report the exact command needed to
  retry only the failed integration.

### Ownership boundaries

Treat every profile root as a container of individually owned paths, never as
a recursively replaceable bundle.

- `<shimmy-config-root>` and `<profiles-root>` are merge-owned containers.
  Create them as needed, never replace them, and remove them only with
  `rmdir` after a profile uninstall.
- A fresh profile install may proceed only when the profile root is absent or
  empty. A non-empty profile root without a valid current-schema manifest is
  unmanaged and must be rejected before mutation.
- Within a profile with a valid current-schema manifest, `commands`, `config`,
  `implementations`, `lib`, `tools`, `tests`, `plugins`, and `agent` are
  replace-owned root assets.
- `activate.sh` and `install-manifest.txt` are individually owned regular
  files. Write them with same-directory temporary files and atomic renames.
- Replace each claimed path independently. Remove a displaced symlink itself;
  never follow it, and reject symlinks in the profile-root parent chain.
- `bin/` is merge-owned within the profile. Replace or remove only entries
  derived from the fixed schema and validated installed-kind identifiers;
  never treat an arbitrary manifest path as owned and never replace the
  directory as a whole. Reject a new dispatcher collision until the requested
  command is recorded as owned.
- Preserve unknown siblings during additive install, refresh, self-update, and
  uninstall of a profile with a valid current-schema manifest.
- Profile uninstall removes only that profile's verified owned paths and uses
  `rmdir` for `bin/`, the profile root, profiles root, and Shimmy config root so
  unmanaged content and sibling profiles survive.
- Never translate the current `rm -rf "$SHIMMY_CORE_DIR"` behavior into
  recursive removal of a profile root, profiles root, or Shimmy config root.

### Repository bootstrap contract

- Remove `<repo>/shimmy`; do not add `<repo>/bin/shimmy`, a repository
  `shimmy` symlink, or another general-purpose repository launcher.
- Add one executable POSIX shell bootstrap at `<repo>/install.sh`. Keep it
  limited to validating repository source, resolving the canonical XDG root,
  and creating or refreshing the profile selected by its bootstrap-only
  `--profile default|upstream` option.
- The bootstrap may accept shim selection plus explicitly requested startup
  and skill integration choices after constructing that profile. Status,
  activation, dispatch, testing, uninstall, and general installed management
  remain outside its surface.
- Startup choices apply only to `default`. Skill installation requires an
  explicit target and is a separate post-commit integration step. A refresh of
  an existing profile, including self-update handoff, does not replay either
  external integration implicitly.
- `./install.sh` bootstraps `default`; `./install.sh --profile upstream`
  bootstraps `upstream` and records the intended maintainer checkout. There is
  no source-launcher mode to discover.
- Keep the installed launcher source as a non-user-facing repository asset at
  `<repo>/lib/install/launcher-template.sh`. It is copied or rendered by the
  bootstrap and is not runnable as the repository's management interface.
- Do not copy root `install.sh` into a profile. Once bootstrap completes, that
  profile's launcher and installed payload are sufficient for its normal
  commands. Update may stage fetched source explicitly, but the source
  checkout is not a standing operational launcher dependency.
- Repository-only maintenance uses explicit entrypoints such as
  `./tests/test.sh`, `./tests/context-tree.sh`, and
  `./commands/run-tool.sh`; it never depends on an uninstalled `shimmy`.

### Installed launcher contract

- Install exactly one executable regular launcher at
  `<profile-root>/bin/shimmy`; do not create `<profile-root>/shimmy`, a shared
  launcher above profile roots, or a launcher symlink.
- The launcher resolves its profile root as the parent of `bin/`, derives the
  profile name from that root's basename, validates that name as a supported
  profile, and requires its root to equal the canonical XDG path for that
  derived name before reading the manifest. The directory is authoritative;
  no manifest field or environment variable can select or redirect a profile.
- A valid current-schema profile manifest is mandatory before installed paths
  are loaded. Its recorded profile name must equal the directory-derived name.
  A missing, malformed, unsupported, or mismatched manifest reports a damaged
  profile; the launcher never falls back to repository or source mode.
- The launcher has no mode or profile detection machinery. Its location is
  its profile identity, and `--profile` is not part of any installed command.
- With no profile manifest, reject any existing `<profile-root>/bin/shimmy`,
  including a symlink, before mutation. With a valid current-schema manifest,
  the schema owns only the fixed relative launcher path `bin/shimmy`; require
  the existing path to be a regular non-symlink file before replacement.
- Install or refresh the launcher through a temporary regular file in the
  same directory, set mode `0755`, then atomically rename it. Failure must
  leave the prior launcher and all siblings unchanged.
- Do not record `control_bin` or another launcher-path field. The launcher path
  is always the schema-defined `<profile-root>/bin/shimmy`; duplicating it in
  the manifest would add a conflicting path authority and validation burden.
- Self-update validates and invokes `<fetched-source>/install.sh --profile
  <directory-derived-profile-name>` and refreshes only the invoking profile's
  complete control/runtime payload. It must not forward a caller-supplied or
  manifest-selected profile. Within merge-owned `bin/`, it refreshes only that
  installed launcher and its owned dispatchers.
- Activation puts the invoking `<profile-root>/bin` on `PATH`. For example:

  ```sh
  eval "$("${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/upstream/bin/shimmy" activate)"
  ```

  This switches the shell to the upstream profile without a selector
  variable.

### Profile manifest validation contract

- Each profile has exactly one manifest at
  `<profile-root>/install-manifest.txt`; there is no shared root manifest or
  profile registry.
- Profile manifests use `shimmy_install_manifest_version=3`,
  `shimmy_install_layout=profile-flat-root`,
  `shimmy_profile_manifest_version=3`, and the exact
  `shimmy_profile_name=<directory-derived-profile-name>`.
- Omit the ambiguous unscoped `shimmy_layout` key and redundant location
  fields such as `install_dir`, `bin_dir`, `config_dir`, and
  `profile_implementation_dir`, including `control_bin`.
- Treat the enclosing canonical directory as profile identity. Validate all
  manifest identity fields together and require
  `shimmy_profile_name=<directory-derived-profile-name>` before consuming any
  remaining metadata.
- Parse the manifest strictly as data; never source it or evaluate its values
  as shell. Require every singleton identity key exactly once and reject
  duplicate, missing, malformed, or unknown identity fields.
- Manifest records do not grant ownership of arbitrary filesystem paths.
  Fixed profile assets come from the schema. Validate each `kind` and
  `kind_version` value against its expected token grammar, reject duplicates
  and contradictory entries, and derive dispatcher paths only as safe direct
  children of `<profile-root>/bin`.
- Validate any remaining path-valued operational metadata for its specific
  purpose before use. In particular, `source_checkout` is upstream-only,
  absolute, and must pass source-checkout validation. Startup-file metadata is
  default-only and may authorize removal of Shimmy's exact
  default-profile-managed marker block only; it never authorizes deleting the
  containing file. An upstream manifest containing startup metadata is
  invalid. Profile manifests contain no shared-skills target or ownership
  metadata.
- Separate identity/ownership validation from operational-shape validation.
  Every mutating command requires valid identity and safe ownership data.
  Status, activation, and dispatch additionally require the assets they use.
  Uninstall may remove the remaining schema-owned assets from a partial
  profile, but must refuse mutation when identity or ownership is invalid.
- Apply this contract to bootstrap install, additive install, refresh, update,
  status, activation, dispatch, and uninstall. Remove installed profile
  enumeration and cross-profile selection machinery.
- An absent profile manifest is a fresh-install candidate only when the
  profile root is absent or empty. An existing manifest with invalid identity
  or ownership fields is unsupported or damaged and must fail closed.
- Bootstrap resolves exactly the requested canonical profile, while an
  installed command resolves exactly its enclosing profile. Neither scans
  sibling directories to choose an operational target.
- Before installing any v3 profile, detect the canonical version-2 shared
  manifest at `<shimmy-config-root>/install-manifest.txt` and fail before
  mutation with version-2 removal guidance.
- Do not scan the filesystem for version-2 custom-root installations. Document
  that users of the removed option must invoke the launcher in each old custom
  root with the old Shimmy version, uninstall every profile there, and then
  install canonical v3 profiles.
- Do not migrate, alias, or automatically delete version-2 installations.

An invalid or unsupported profile manifest must fail before mutation with:

```text
invalid or unsupported Shimmy profile manifest at <manifest-path> (expected shimmy_install_manifest_version=3, shimmy_install_layout=profile-flat-root, shimmy_profile_manifest_version=3, and shimmy_profile_name=<directory-derived-profile-name>); inspect or uninstall it with the Shimmy version that created it, then reinstall that profile
```

### Naming and scope

- Eliminate `SHIMMY_INSTALL_CORE_DIR`, `SHIMMY_CORE_DIR`, test helpers that
  encode an installed-core model, and equivalent aliases. Remaining such
  names are defects, not deferred compatibility.
- Eliminate `--install-dir`, `SHIMMY_INSTALL_DIR`,
  `SHIMMY_CONTROL_INSTALL_DIR`, `SHIMMY_UPSTREAM_DIR`, and equivalent install-
  location aliases from implementation, tests, documentation, contexts, and
  skills. Do not remove `SHIMMY_UPSTREAM_CHECKOUT_DIR`.
- Eliminate `SHIMMY_PROFILE_ACTIVE`, installed `--profile` parsing, all
  profile-selection precedence, and source-versus-installed launcher mode
  detection. Retain `--profile` only on the repository bootstrap.
- Eliminate repository `shimmy` and `bin/shimmy` entrypoints. The only
  repository entrypoint that creates an installed launcher is `install.sh`;
  the launcher template under `lib/install/` is not a public command.
- Rename `tests/core/` to `tests/lib/` and `test_core_*` functions in that
  grouping to `test_lib_*`.
- Retain `agent/core/` as the canonical source for core management skills.
  Selecting one canonical ownership model across `agent/`, `.agents/skills/`,
  tool-local skills, and plugin copies is separate follow-up work.
- Make only migration-required edits to canonical, plugin, and `.agents` skill
  files; do not broadly reconcile their existing differences.
- Rewrite migrated paths in persistent historical plans to the current model.
  Preserve their goals, decisions, completion state, and intentional uses such
  as `agent/core/` or upstream API paths.
- Preserve unrelated uses of the word `core`, including OPNsense API endpoints
  such as `/core/system/info` and `/core/firmware/status`. Cleanup searches
  require classification, not blind replacement.

## Verified migration inventory

### Shared source tree

- Rename the complete `<repo>/core/` tree to `<repo>/lib/`, including all shell
  modules and its nine `CONTEXT.md` files.
- Update moved-file self-references, especially:
  - `lib/install/install.sh`
  - `lib/netinfo/netinfo.sh`
  - `lib/runtime/image.sh`
  - `lib/update/update.sh`
- Update source-checkout structural validation in `lib/profile/profile.sh`.

### Management surface

- Remove `<repo>/shimmy` without replacement by another repository `shimmy`.
- Add the minimal `<repo>/install.sh` bootstrap.
- Add the non-user-facing `<repo>/lib/install/launcher-template.sh` used to
  create each profile-local launcher.
- Update these command entrypoints:
  - `commands/activate.sh`
  - `commands/agent-preflight.sh`
  - `commands/dispatch-tool.sh`
  - `commands/install.sh`
  - `commands/netinfo.sh`
  - `commands/skills.sh`
  - `commands/status.sh`
  - `commands/update.sh`

### Versioned runtimes and refresh hooks

Update shared runtime/helper paths in:

- `tools/aws/versions/2.31/run.sh`
- `tools/gcloud/versions/573.0/run.sh`
- `tools/gdrive/versions/0.2/run.sh`
- `tools/gdrive/versions/0.2/refresh.sh`
- `tools/gh/versions/2.94/run.sh`
- `tools/gh/versions/2.94/refresh.sh`
- `tools/go/versions/1.26/run.sh`
- `tools/jq/versions/1.8/run.sh`
- `tools/logmine/versions/0.1/run.sh`
- `tools/logmine/versions/0.1/refresh.sh`
- `tools/netcat/versions/7.92/run.sh`
- `tools/netcat/versions/7.92/refresh.sh`
- `tools/nmap/versions/7.98/run.sh`
- `tools/oc/versions/4.18/run.sh`
- `tools/oc/versions/4.18/refresh.sh`
- `tools/oc/versions/4.20/run.sh`
- `tools/oc/versions/4.20/refresh.sh`
- `tools/oc/versions/4.22/run.sh`
- `tools/oc/versions/4.22/refresh.sh`
- `tools/opnsense-mcp-admin/versions/1.0/run.sh`
- `tools/opnsense-mcp-admin/versions/1.0/refresh.sh`
- `tools/opnsense-mcp-read-only/versions/0.4/run.sh`
- `tools/opnsense-mcp-read-only/versions/0.4/refresh.sh`
- `tools/rg/versions/15.1/run.sh`
- `tools/skopeo/versions/1.22/run.sh`
- `tools/task/versions/3.45/run.sh`
- `tools/task/versions/3.45/refresh.sh`
- `tools/terraform/versions/1.15/run.sh`
- `tools/tessl/versions/0.1/run.sh`
- `tools/tessl/versions/0.1/refresh.sh`
- `tools/textual/versions/8.2/run.sh`
- `tools/textual/versions/8.2/refresh.sh`

Repeat the repository-wide scrub during implementation; this list is a
verified baseline, not permission to ignore new or previously missed matches.

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

## Chunk 1 — Atomic layout transition

### Goal

Atomically rename the source library, replace the repository launcher with a
minimal bootstrap, install one profile-bound launcher per canonical XDG
profile root, remove public location and profile-selection overrides,
introduce the version-3 manifest contract, and update enough lifecycle tests
to leave bootstrap and installed dispatch operational.

### Files

- rename `core/` to `lib/`
- remove `shimmy`
- add root `install.sh`
- add `lib/install/launcher-template.sh`
- all command entrypoints listed in **Management surface**
- all files under the renamed `lib/` tree, with primary behavior changes in:
  - `lib/profile/profile.sh`
  - `lib/install/request.sh`
  - `lib/install/profile-assets.sh`
  - `lib/install/install.sh`
  - `lib/install/uninstall.sh`
  - `lib/install/manifest.sh`
  - `lib/update/management.sh`
  - `lib/update/profile.sh`
  - `lib/update/refresh.sh`
  - `lib/update/update.sh`
- every versioned runtime and refresh hook in the verified inventory
- `.github/workflows/test.yml`
- minimum lifecycle coverage in:
  - `tests/test.sh`
  - `tests/support.sh`
  - `tests/context-tree.sh`
  - `tests/core/catalog.sh`
  - `tests/core/runtime.sh`
  - `tests/core/update.sh`
  - `tests/commands/install.sh`
  - `tests/commands/lifecycle.sh`
  - `tests/commands/update.sh`
  - `tests/commands/dispatcher.sh`
  - `tests/commands/management.sh`
  - `tests/commands/startup.sh`
  - `tests/commands/skills.sh`

Mechanically update any additional test that invokes the old repository
launcher or a renamed module path when required to keep the default suite
operational; defer the test-directory and function-name cleanup to Chunk 2.

Files may move before their context documents are rewritten in Chunk 3, but
links and runner paths required for a passing repository must be updated here.

### Implementation requirements

- Source every shared module from `lib/`; update shellcheck source comments.
- Resolve the selected canonical profile root exclusively from
  `XDG_CONFIG_HOME`, `$HOME`, and the profile name.
- Remove `--install-dir` parsing and forwarding and remove the three legacy
  Shimmy location variables named in the canonical-path contract.
- Restrict `--profile` parsing to root `install.sh`; remove
  `SHIMMY_PROFILE_ACTIVE` and make every installed management command and
  dispatcher derive its only profile from its own location.
- Install `commands`, `config`, `implementations`, `lib`, `tools`, `tests`,
  `plugins`, and `agent` directly under the selected profile root using the
  ownership rules above.
- Do not copy the repository `.agents/skills` tree into a profile root.
- Change dispatcher symlinks to `../commands/dispatch-tool.sh`; retain the
  existing recursion and broken-target protections.
- Implement the bootstrap, installed-launcher, and manifest contracts exactly
  as recorded above. Repository validation requires `install.sh`, `commands/`,
  `lib/`, `tools/`, and the launcher template; it never requires a repository
  `shimmy`.
- Validate the complete profile-local installed shape instead of treating
  directory existence as proof of an installation.
- Preserve sibling profiles, the selected manifest, generated dispatchers,
  and unmanaged siblings through additive install, refresh, and self-update.
- Remove source-mode detection and repository-launcher management dispatch.
  Keep upstream management profile-local, restrict recorded-checkout execution
  to generated tool implementations, and preserve that checkout through
  self-update.
- Profile uninstall removes only the selected profile's verified owned assets.
- Stage and validate replacement assets before mutation, commit the manifest
  last, and retain or restore the prior valid current-schema profile after a
  failure.
- Implement external startup and skills integration as separate idempotent
  post-commit transactions using the recorded ownership contract. Never roll
  back or damage a valid profile because a requested external integration
  failed.
- Add disposable unmanaged profile-root and sibling-profile sentinels to
  install, refresh, self-update, and uninstall coverage.

### Verification

- [x] `core/` is renamed to `lib/`; all direct source references and shellcheck
      comments use `lib/`.
- [x] Root `install.sh` is the only repository bootstrap, and the repository
      contains no `shimmy`, `bin/shimmy`, or equivalent management launcher.
- [x] `./install.sh` bootstraps `default`, and `./install.sh --profile
      upstream` bootstraps `upstream` from the intended maintainer checkout.
- [x] Unset or empty `XDG_CONFIG_HOME` resolves profiles below
      `$HOME/.config/shimmy/profiles`; an absolute value resolves them below
      `$XDG_CONFIG_HOME/shimmy/profiles`; a relative value fails before
      mutation.
- [x] No management command accepts or forwards `--install-dir`, and the
      removed Shimmy location variables are not read and cannot change a path
      or any other behavior.
- [x] Fresh install creates `activate.sh`, `install-manifest.txt`,
      `bin/shimmy`, `commands/`, `config/`, `implementations/`, `lib/`,
      `tools/`, `tests/`, `plugins/`, and `agent/` below the selected profile
      root, with no `<profile-root>/core`, `<profile-root>/shimmy`, or
      `<profile-root>/.agents/skills`.
- [x] Installed launcher is an executable regular file, uses same-directory
      atomic replacement, preserves all `bin/` siblings, and depends only on
      its own installed profile payload.
- [x] Installed launchers reject `--profile`, do not inspect
      `SHIMMY_PROFILE_ACTIVE`, and cannot select, update, or uninstall a
      sibling profile.
- [x] The upstream launcher and management commands load only profile-local
      assets. Only generated tool implementations execute through the
      validated recorded checkout; self-update preserves that checkout and
      does not record its temporary fetched source.
- [x] An unmanaged or symlinked pre-existing `bin/shimmy` is rejected before
      mutation; an existing launcher in a valid profile must be a regular
      non-symlink file at the schema-defined `bin/shimmy` path before
      replacement.
- [x] Dispatcher symlinks target exactly `../commands/dispatch-tool.sh`, load
      helpers from `<profile-root>/lib`, and are neither broken nor recursive.
- [x] Fresh installs reject non-empty unmanaged profile roots and all unmanaged
      claimed-path or dispatcher collisions before mutation.
- [x] Additive install, refresh, and self-update preserve the selected
      manifest, sibling profiles, and unknown siblings.
- [x] Unmanaged sentinels in the selected profile and sibling profiles survive
      install, refresh, self-update, and unrelated-profile uninstall.
- [x] Only `default` can write or remove its profile-specific persistent
      startup block; `upstream` is manual-activation-only and rejects every
      startup-mutating option before mutation.
- [x] Profile refresh, self-update, and uninstall do not implicitly change a
      shared skills target. Explicit skills uninstall removes only entries
      owned by the target's skills manifest and preserves unknown siblings.
- [~] A requested startup or skills integration failure leaves the committed
      profile valid and reports an independently repeatable repair command.
- [x] Profile uninstall removes owned assets and uses `rmdir`, never recursive
      profile-root or config-root deletion.
- [x] Each profile manifest contains both version `3` fields,
      `profile-flat-root`, and the exact directory-derived profile name, and
      contains no `shimmy_layout`, `control_bin`, or other redundant location
      fields.
- [~] Missing or duplicate identity fields, version 2, unknown versions, wrong
      layout label, wrong profile name, malformed values, unsafe kind tokens,
      duplicate ownership entries, and contradictory kind/version records
      fail before mutation with the specified remediation message.
- [x] Manifest values are never sourced or evaluated as shell, cannot claim
      arbitrary filesystem paths, and cannot redirect update or uninstall
      outside the directory-derived profile root.
- [~] A partial profile with valid identity and ownership data can be safely
      uninstalled; invalid identity or ownership data fails before mutation.
- [x] A canonical version-2 shared installation blocks v3 profile creation
      before mutation and reports removal guidance.
- [x] No `SHIMMY_INSTALL_CORE_DIR`, `SHIMMY_CORE_DIR`,
      `SHIMMY_INSTALL_DIR`, `SHIMMY_CONTROL_INSTALL_DIR`,
      `SHIMMY_UPSTREAM_DIR`, `SHIMMY_PROFILE_ACTIVE`, repository `shimmy`,
      `core/core`, old dispatcher target, or `--install-dir` remains in
      implementation.
- [x] Minimum bootstrap, fresh-install, dispatch, refresh, update, and
      uninstall tests pass at the review gate.
- Notes: The implementation paths are complete and the minimum suite covers
  both profiles, XDG fallback/absolute/relative resolution, additive install,
  self-update, dispatch, startup, skills ownership, and uninstall isolation.
  Failure-injection, the full malformed-manifest matrix, and broader partial-
  profile cases remain explicitly marked `[~]` for Chunk 2.

### Human review gate

Confirm the repository bootstrap is minimal, every operational launcher is
owned by exactly one installed profile, canonical profile roots and their flat
trees are understandable, manifest failures occur before mutation, and no
owned-path operation can erase sibling-profile or unmanaged state. Confirm
only `default` owns persistent startup integration and all shared skills remain
owned independently by their target manifests.

## Chunk 2 — Comprehensive test migration

### Goal

Complete the test and verification-harness migration, rename shared-library
tests, and provide exhaustive regression coverage for the recorded contracts.

### Files

- command tests:
  - `tests/commands/activate.sh`
  - `tests/commands/agent-preflight.sh`
  - `tests/commands/dispatcher.sh`
  - `tests/commands/install.sh`
  - `tests/commands/lifecycle.sh`
  - `tests/commands/management.sh`
  - `tests/commands/netinfo.sh`
  - `tests/commands/profiles.sh`
  - `tests/commands/skills.sh`
  - `tests/commands/startup.sh`
  - add `tests/commands/status.sh`
  - `tests/commands/test.sh`
  - `tests/commands/update.sh`
- rename `tests/core/` to `tests/lib/`, including:
  - `tests/lib/catalog.sh`
  - `tests/lib/runtime.sh`
  - `tests/lib/update.sh`
  - `tests/lib/CONTEXT.md`
- test infrastructure:
  - `tests/test.sh`
  - `tests/support.sh`
  - `tests/context-tree.sh`
  - `tests/profile-smoke.sh`

### Implementation requirements

- Use `tests/lib/`, `test_lib_*`, and `lib/` consistently in runner paths,
  function names, shellcheck comments, helper names, and documentation.
- Invoke `./install.sh` only for repository bootstrap work and invoke
  `<profile-root>/bin/shimmy` for all management of an installed profile.
  Invoke repository tests and source previews through their explicit scripts;
  there is no source launcher.
- Give every lifecycle scenario an absolute disposable `XDG_CONFIG_HOME` and
  derive expected default and upstream profile roots from it.
- Cover default-only, upstream-only, and combined-profile installs.
- Verify activation prepends the invoking profile's `bin/` to `PATH` without
  exporting a profile selector. Verify an installed launcher and its
  dispatchers remain bound to their enclosing profile even when a sibling is
  installed.
- Verify the upstream launcher and every management command remain
  profile-local while generated tool implementations execute through the
  recorded checkout. After self-update deletes its temporary fetched source,
  verify the manifest still records the original checkout and upstream tool
  dispatch still uses it.
- Verify `default` startup integration is idempotent and uses its
  profile-specific marker. Verify `upstream` never reads or writes startup
  files and rejects startup-mutating options without changing its profile,
  the default profile, or the requested startup file.
- Verify bootstrapping both profiles against one explicit skills target is
  idempotent and target-manifest-owned. Refreshing, self-updating, or removing
  either profile must preserve that target; only explicit skills uninstall may
  remove its recorded entries.
- Verify `--profile` is accepted by `./install.sh` and rejected by every
  installed launcher command before mutation. Verify
  `SHIMMY_PROFILE_ACTIVE` has no implementation semantics.
- Remove profile selection from repository and installed smoke-test harnesses;
  run profile-specific smoke behavior through the launcher being tested.
- Prove installing, refreshing, updating, and removing one profile never
  mutates the sibling profile. Removing the last profile may remove only empty
  merge-owned container directories.
- Cover file, directory, and symlink collisions for every claimed profile-root
  asset and every merge-owned container.
- Prove launcher refresh changes only owned entries within that profile's
  `bin/` and does not mutate sibling profile launchers or dispatchers.
- Cover malformed, missing, duplicate-key, version-2, unknown-version,
  wrong-label, copied wrong-profile, unsafe kind, duplicate ownership,
  contradictory kind/version, shell-syntax payload, and invalid
  source-checkout manifests, with unchanged profile assets after rejection.
- Cover partial installed shapes separately: status, activation, and dispatch
  report the missing assets, while uninstall safely removes only the remaining
  schema-owned assets when identity and ownership remain valid.
- Cover unset, empty, absolute, and relative `XDG_CONFIG_HOME` and prove that
  the removed CLI option and Shimmy location variables cannot relocate state.
- Verify source-checkout validation requires `install.sh`, `commands/`,
  `lib/`, `tools/`, and `lib/install/launcher-template.sh`, rejects stale
  `core/` layouts, and does not require a repository `shimmy`.
- Verify executable bits on launchers, command and library entrypoints,
  root `install.sh`, version runtimes, and refresh hooks. The launcher template
  is not a public executable; installation writes its copy with mode `0755`.

### Verification

- [x] All command tests assert the canonical profile-flat layout.
- [x] Shared-library tests live under `tests/lib/`, use `test_lib_*`, and run in
      the default suite.
- [x] Default-only, upstream-only, and combined-profile scenarios pass.
- [x] Repository bootstrap is the only source-side installation surface;
      repository tests and previews work without a repository `shimmy`.
- [x] Profile isolation, profile removal, and empty-container cleanup obey the
      ownership contract.
- [x] Default-only startup ownership, upstream manual activation, external
      integration retry behavior, and target-manifest-owned skill lifecycle
      scenarios pass with both profiles installed.
- [x] Each installed launcher is bound to one profile, rejects `--profile`,
      and cannot manage a sibling; activation switches profiles through
      `PATH` only.
- [x] Upstream management is self-contained, source-mode detection is absent,
      recorded-checkout execution is limited to generated tool
      implementations, and self-update preserves the original checkout.
- [x] Collision, symlink-safety, sentinel-preservation, launcher, dispatcher,
      strict manifest parsing, safe ownership, partial-profile, and manifest
      rejection cases pass.
- [x] XDG fallback, absolute override, relative-path rejection, removed-option,
      removed-variable, and removed-profile-selector cases pass.
- [x] Profile smoke and context-tree tests pass.
- [x] No test asserts legacy installed paths or uses installed-core aliases.
- [x] No test uses a private install-root override; isolation is achieved with
      disposable `HOME` and `XDG_CONFIG_HOME` values.
- [x] Required runnable files retain executable bits.
- Notes: `./tests/test.sh` passes all 68 tests. The comprehensive migration
  covers default-only, upstream-only, and combined profiles; the complete
  claimed-asset collision matrix; strict manifest mutations; damaged-profile
  reporting and safe uninstall; launcher, dispatcher, startup, skills, update,
  and XDG isolation. Failure injection found that startup integration errors
  were swallowed when called beneath `if !`; `lib/install/startup.sh` now
  returns the failed write so the committed-profile retry path is observable.

### Human review gate

Confirm test names and expected trees match the agreed design and no test was
silently omitted during the directory rename.

## Chunk 3 — Documentation, contexts, skills, and historical plans

### Goal

Align maintainer-facing, user-facing, and AI-facing guidance with the new
source and installed layouts without redesigning skill ownership.

### Files

- root and contributor docs:
  - `README.md`
  - `CONTEXT.md`
  - `CONTRIBUTING.md`
  - `AGENTS.md`
  - `commands/README.md`
- context tree:
  - `commands/CONTEXT.md`
  - `tests/CONTEXT.md`
  - `tests/lib/CONTEXT.md`
  - every `CONTEXT.md` under `lib/`
  - `agent/CONTEXT.md`
  - `agent/core/CONTEXT.md`
  - `agent/core/shimmy-create-tool/CONTEXT.md`
  - `agent/core/shimmy-escalation/CONTEXT.md`
  - `agent/core/shimmy-init/CONTEXT.md`
  - `agent/core/shimmy-install/CONTEXT.md`
  - `agent/core/shimmy-tool-local-build/CONTEXT.md`
- skill guidance:
  - every migration-matched `SKILL.md` under `agent/core/`
  - every migration-matched `SKILL.md` under `tools/*/agent/`
  - every migration-matched `SKILL.md` under `plugins/shimmy/skills/`
  - every migration-matched `SKILL.md` under `.agents/skills/`
- other documentation:
  - `docs/netinfo.md`
  - `docs/network-tools.md`
  - `docs/podman.md`
  - `docs/prompt-shimmy-project.md`
  - `docs/testing.md`
  - `docs/templates/generic-shim/SKILL.md`
  - every migration-matched `tools/*/guide.md`
- persistent historical plans:
  - `plans/context.md`
  - `plans/context_remaining.md`
  - `plans/multi-architecture-manifest.md`
  - any additional plan found by the repeat scrub

### Implementation requirements

- Describe `lib/` as the shared library, the canonical XDG path resolver, and
  each profile root as a complete flat control/runtime installation.
- Describe the minimal root `install.sh` bootstrap, the absence of a
  repository `shimmy`, and the one-launcher-per-installed-profile model.
- Explain that only `default` may manage persistent shell startup integration,
  `upstream` is manual-activation-only, and profile lifecycle operations never
  implicitly remove or refresh a shared skills target.
- Document shared skills as target-manifest-owned external state and make
  explicit skills uninstall the only supported removal path.
- Remove `--install-dir`, `SHIMMY_INSTALL_DIR`,
  `SHIMMY_CONTROL_INSTALL_DIR`, and `SHIMMY_UPSTREAM_DIR` from all current
  guidance. Retain and clearly distinguish `SHIMMY_UPSTREAM_CHECKOUT_DIR`.
- Remove `SHIMMY_PROFILE_ACTIVE` and installed-command `--profile` guidance.
  Document bootstrap-time profile choice and absolute profile-launcher
  activation as the only profile-switching mechanisms.
- Explain that disposable validation uses an absolute temporary
  `XDG_CONFIG_HOME`, not an installation-directory override.
- Remove any root-context link to a repository `bin/` launcher and keep all
  renamed context-tree links valid.
- Explicitly audit `agent/CONTEXT.md`, `agent/core/CONTEXT.md`, and all five
  leaf contexts while retaining the `agent/core/` name.
- Update only migration-related advice in canonical, plugin, and `.agents`
  skills; do not synchronize unrelated content.
- Rewrite stale source, test, launcher, and installed-layout paths in all
  persistent plans. Preserve intentional unrelated `core` references after
  reviewing each match.

### Verification

- [x] Root and contributor docs accurately describe `lib/`, root `install.sh`,
      the absence of a repository `shimmy`, profile-local `bin/shimmy`, XDG
      resolution, and independent profile-flat installations.
- [x] All context links and paths are valid; the context-tree test passes.
- [x] AI skill guidance contains no migrated `core/` path advice.
- [x] User, contributor, and AI guidance contains no removed install-location
      option, installed profile-selection option, or Shimmy environment
      override.
- [x] User, contributor, and AI guidance consistently describes default-only
      startup ownership, upstream manual activation, and target-owned shared
      skills.
- [x] The canonical management-skill context subtree was explicitly reviewed
      and remains at `agent/core/`.
- [x] No skill tree was moved or broadly reconciled.
- [x] Persistent historical plans use current migrated paths without losing
      their non-path history.
- [x] Every remaining `core` match in documentation is classified as an
      intentional concept, API path, or other unrelated use.
- Notes: Root, contributor, Podman, testing, network, prompt, tool-guide,
  context, canonical-skill, plugin-skill, and distribution-skill guidance now
  describes the version-3 flat XDG layout. The historical-plan scrub also
  updated `context-handoff.md`, `TODO.md`, and `oc_multi_version_shim.md` after
  they matched migrated launcher or profile-selection advice. Remaining
  documentation `core` matches are `agent/core/`, its parent context link,
  OPNsense API routes, or explicit removal history in this plan. Context-tree,
  diff-check, and all 68 repository tests pass. The skill-creator
  `quick_validate.py` check could not start because PyYAML is unavailable;
  repository skill export and context validation passed instead. A read-only
  skill forward-test clarified source-only escalation, user-owned Podman
  machine startup, and the distinction between external shared skill targets
  and the packaged profile-local `plugin` target.

### Human review gate

Confirm the wording is durable, context navigation is coherent, and future
maintainers or AI sessions will not be directed to legacy paths.

## Chunk 4 — Final scrub and end-to-end validation

### Goal

Remove remaining legacy naming, run full validation, and prepare the completed
refactor for acceptance.

This cleanup chunk may touch any previously modified file when the final scrub
finds a missed migration reference or verification defect.

### Verification

- [ ] Repository-wide search finds no unintended `core/core`,
      `SHIMMY_INSTALL_CORE_DIR`, `SHIMMY_CORE_DIR`, old dispatcher target,
      `<repo>/shimmy`, `<repo>/bin/shimmy`, source-launcher mode, or migrated
      source `core/` paths.
- [ ] Active implementation, tests, documentation, contexts, and skills contain
      no `--install-dir`, `SHIMMY_INSTALL_DIR`,
      `SHIMMY_CONTROL_INSTALL_DIR`, `SHIMMY_UPSTREAM_DIR`,
      `SHIMMY_PROFILE_ACTIVE`, installed-command `--profile`, or equivalent
      location/profile alias. Historical removal references in this plan are
      classified; bootstrap `--profile` and intentional
      `SHIMMY_UPSTREAM_CHECKOUT_DIR` uses remain.
- [ ] Every remaining `core` match is reviewed and documented as intentional,
      including `agent/core/`, ordinary prose, and upstream API paths.
- [ ] Repository-wide search finds no installed `.agents/skills` payload
      assumption; explicit `shimmy skills` targets remain supported.
- [ ] `./tests/test.sh` passes without a repository `shimmy`.
- [ ] `./tests/context-tree.sh` passes.
- [ ] Root `install.sh` remains a minimal bootstrap and repository status,
      activation, test, dispatch, update, and uninstall workflows use explicit
      scripts or the applicable installed profile launcher.
- [ ] A disposable fresh default install works.
- [ ] A disposable fresh upstream install works.
- [ ] Default and upstream installs occupy independent canonical profile roots;
      activating either profile and dispatching its installed shims works.
- [ ] Upstream behaves as a normal installed profile: its launcher and
      management plane use only profile-local assets, only generated tool
      implementations execute through `source_checkout`, and self-update does
      not substitute or retain a dependency on its temporary fetched source.
- [ ] Each profile has exactly one regular executable `bin/shimmy`; no shared
      or repository launcher exists, and neither launcher can manage the other
      profile.
- [ ] The directory-derived profile name is authoritative; copying one
      profile's manifest into the other is rejected, and manifests contain no
      `control_bin` or arbitrary owned-path field.
- [ ] Strict manifest parsing rejects duplicate identity, unsafe ownership,
      shell-evaluation payload, and invalid path-metadata cases before
      mutation; valid partial profiles remain safely uninstallable.
- [ ] Additive install, management refresh, and self-update work without
      changing unmanaged or sibling-profile sentinels.
- [ ] Removing either profile preserves the other; removing the last profile
      removes only its owned assets and empty merge-owned containers while
      preserving unmanaged content.
- [ ] Installing, refreshing, updating, or removing `upstream` never changes a
      startup file. Removing `default` removes only its exact managed block.
- [ ] Shared skills survive every profile refresh, update, and uninstall;
      explicit skills uninstall preserves unknown target siblings.
- [ ] The complete tree of each installed profile, including hidden paths,
      matches the target layout, and no shared control/runtime payload exists
      above the profile roots.
- [ ] The repository diff contains no stale workstation-specific absolute
      paths and no unintended executable-bit changes.
- Notes:

### Suggested commands

Set `<tmp-config-home>` to an absolute disposable directory and adjust the
selected shim as needed:

```sh
./tests/test.sh
./tests/context-tree.sh
XDG_CONFIG_HOME=<tmp-config-home> ./install.sh --profile default --no-startup --no-skills
XDG_CONFIG_HOME=<tmp-config-home> ./install.sh --profile upstream --no-startup --no-skills
XDG_CONFIG_HOME=<tmp-config-home> <tmp-config-home>/shimmy/profiles/default/bin/shimmy activate
XDG_CONFIG_HOME=<tmp-config-home> <tmp-config-home>/shimmy/profiles/default/bin/<shim> --version
XDG_CONFIG_HOME=<tmp-config-home> <tmp-config-home>/shimmy/profiles/default/bin/shimmy update
XDG_CONFIG_HOME=<tmp-config-home> <tmp-config-home>/shimmy/profiles/default/bin/shimmy uninstall
```

### Human review gate

Confirm the source and profile-local installed layouts are clear, all tests
pass, no removed path override remains, and no legacy path can be recreated.

## Risk register

### High risk

1. **Destructive profile-root replacement** — Flattening removes the safety
   boundary of a bundled directory. Fresh installs must reject non-empty
   unmanaged profile roots, and refresh and cleanup must use the explicit
   ownership rules and safe-path validation.
2. **XDG resolution and removed overrides** — Empty, relative, or inherited
   environment values must not place files outside the canonical application
   namespace, and legacy Shimmy location variables must not silently work.
3. **Cross-profile isolation** — Each profile contains a full independent
   payload. Selection, update, and uninstall mistakes must not mutate a sibling
   profile, a shared container, a startup file owned by `default`, or a shared
   skills target.
4. **Bootstrap/launcher boundary** — If the bootstrap grows into a second
   management launcher, or an installed launcher can infer or select another
   profile, the design recreates the ambiguity this change removes. Validate
   the boundary in command-surface tests.
5. **Merge-owned `bin/` collisions** — Replacing `bin/`, following a launcher
   symlink, or accepting an unproven launcher could destroy or hijack managed
   dispatch.
6. **Manifest identity and ownership validation** — Partial, duplicate, or
   mismatched identity, unsafe kind tokens, and path-like ownership values
   must be rejected before operational metadata is trusted or any asset is
   changed. Manifest data must never become an arbitrary deletion target.
7. **Dispatcher target integrity** — A stale central target can produce broken
   or recursive symlinks.
8. **Update handoff** — An installed launcher must pass its validated
   directory-derived profile name to the fetched source's bootstrap without
   accepting a caller- or manifest-selected target. Weak fetched-source or
   profile checks can refresh the wrong root. Upstream update must preserve its
   validated maintainer checkout and never record the temporary fetched source
   as `source_checkout`.
9. **Versioned runtime paths** — One missed `core/runtime` reference causes a
   tool-specific failure that broad lifecycle tests may not expose.

### Medium risk

10. **Test rename coordination** — Runner paths, functions, shellcheck comments,
    and contexts must move together so tests are not silently dropped.
11. **Context and historical-plan drift** — Stale actionable paths can cause
    later sessions to restore the old model.
12. **Skills duplication assumptions** — Removing the installed
    `.agents/skills` copy is safe only while canonical `agent/` and tool-local
    agent sources remain part of every profile payload and skill commands
    continue resolving them there. Shared targets remain independently owned
    by their skills manifests and are never removed by profile lifecycle.

## Lessons learned

Append concise, durable findings after each accepted chunk. Do not duplicate
the fixed design decisions above.

### Initial

- Path resolution and installer copy targets jointly create the current
  nested layout; renaming the repository directory alone cannot flatten it.
- The current dispatcher assumes `core/core` and `core/commands`, the launcher
  treats `../core` as its installed payload, and update detection checks
  `<install>/core`; these must change atomically.
- The current installer copies one repository-root launcher to both
  `<install>/bin/shimmy` and `<install>/core/shimmy`; the target design removes
  the repository launcher, exposes only a minimal `install.sh` bootstrap, and
  gives each profile one profile-bound launcher with file-level ownership in
  that profile's `bin/`.
- Directory renames also affect shellcheck source comments, context links,
  source-checkout validation, test support globs, and historical working plans.
- A shared install root makes profile isolation and uninstall ownership harder
  to reason about. The target gives every profile a complete payload below the
  canonical XDG Shimmy namespace.
- Removing `--install-dir` is incomplete unless all lifecycle forwarding and
  equivalent Shimmy location environment variables are removed together.
- Disposable tests do not need a private path override; an absolute temporary
  `XDG_CONFIG_HOME` provides standards-aligned isolation.
- A profile-local manifest confirms schema, identity, and safe ownership; it
  does not select a profile or provide launcher and deletion paths. The
  canonical enclosing directory remains authoritative.
- Persistent startup integration is a default-profile-owned external side
  effect, while shared skills are target-manifest-owned external state. Neither
  is part of an upstream profile transaction or profile-root deletion.

### Chunk 1

- Independent profile roots make dispatcher and uninstall ownership local and
  remove the need for cross-profile enumeration in every management command.
- Keeping the old manifest present until the final atomic rename allows staged
  directory replacement to fail closed while preserving a previously valid
  profile.

### Chunk 2

- Shell functions executed as the condition of `if !` do not reliably stop on
  an inner command failure under `set -e`; integration loops must explicitly
  propagate a failed external write before logging success.

### Chunk 3

- Durable guidance should describe a profile by the launcher that owns it,
  rather than teaching a separate selector that can disagree with execution
  identity.
- Shared skills need their own target-manifest ownership language everywhere
  profile lifecycle is documented; otherwise users can reasonably infer that
  uninstalling a supplying profile also owns or removes the shared target.
- The packaged `plugin` skills target is part of a profile payload, not a
  shared external integration target, and must be documented as that explicit
  exception to target-manifest ownership across profile lifecycle.

### Chunk 4

- _append after acceptance_

## Session bootstrap

At the start of a later session:

1. Read `AGENTS.md`, `CONTEXT.md`, this plan, the current chunk's files, and
   every context file on their paths.
2. Restate the non-backward-compatible target: source `core/` becomes `lib/`,
   the repository has one minimal `install.sh` bootstrap and no `shimmy`, each
   installed profile has one self-contained `bin/shimmy`, `--install-dir`,
   installed `--profile`, `SHIMMY_PROFILE_ACTIVE`, and equivalent Shimmy
   location variables are removed, and each profile is a complete flat install
   below `${XDG_CONFIG_HOME:-$HOME/.config}/shimmy/profiles/<profile>`. Only
   `default` owns persistent startup integration; `upstream` is
   manual-activation-only and encapsulates maintainer functionality as a normal
   installed profile. Its management plane is self-contained, only generated
   tool implementations execute through its validated recorded checkout, and
   self-update preserves that checkout. Shared skills are owned by their
   target manifests, never by profile lifecycle.
3. Work only on the current chunk and stop at its human review gate.
4. Before stopping, update its checklist and **Lessons learned**, then report
   tests, uncertainties, and remaining risks.
