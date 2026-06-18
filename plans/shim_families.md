# Shim Kinds Handoff Plan

## Goal

Refactor Shimmy so users install and run logical tool kinds, while Shimmy dispatches to concrete versioned implementations underneath.

The user-facing command should always be the kind name:

```sh
shimmy install --shim oc
oc version

shimmy install --shim jq
jq --version
```

Every kind must have:

- a kind dispatcher at `shims/<kind>`;
- at least one concrete version at `shims/<kind>_<major>_<minor>`;
- a required default version mapping;
- a kind smoke config;
- version smoke configs for every concrete version.

Backward compatibility is not required for this feature. Use that freedom to make the model regular instead of preserving the current mixed "some shims are direct wrappers, some shims are dispatchers" shape.

## Core Model

Use two catalog object types:

- **Kind**: the stable user-facing tool command. Examples: `jq`, `rg`, `oc`, `terraform`.
- **Version**: the concrete implementation for one tool version. Examples: `jq_1_7`, `rg_14_1`, `oc_4_20`.

Reserve these terms for possible future dimensions:

- **Family**: do not use for this dispatch model. It may later describe an organizational grouping such as networking, coding, or AI.
- **Variant**: do not use for this dispatch model. It may later describe another dimension such as CPU architecture, OS, or image strategy.

Relationship rules:

- Users request kinds.
- Runtime PATH exposes kinds.
- Kind dispatchers choose versions.
- Versions run Podman or local image build logic.
- Every kind has exactly one default version at any point in time.
- Every default version points to a concrete major.minor version, not to an unversioned wrapper.

## Required Default Version

Every kind must define a default version.

For tools that currently have one concrete version, the implementation agent must determine the underlying tool's current major.minor version and create that concrete version. The kind default then points to it.

Example for a current one-version `jq` kind:

```text
kind: jq
versions: jq_1_7
default: jq_1_7
```

Example for `oc`:

```text
kind: oc
versions: oc_4_18 oc_4_20 oc_4_22
default: oc_4_20
```

This means a kind command is always runnable after install. If no selector is provided at runtime, the kind dispatcher uses its default version.

For `oc`, unset `SHIMMY_OC_VERSION` should dispatch to `oc_4_20` instead of failing. If `SHIMMY_OC_VERSION` is set to an unsupported value, the dispatcher should still fail clearly and list supported values plus the default.

## Version Discovery For Existing Shims

For each existing non-`oc` catalog shim, determine the underlying tool major.minor version before creating the first concrete version.

Current catalog kinds to migrate:

```text
aws
go
gcloud
gdrive
jq
netcat
nmap
opnsense-mcp-admin
opnsense-mcp-read-only
rg
task
terraform
textual
```

`oc` already has concrete versions, but its default must be set to `oc_4_20`.

Discovery rules:

- Prefer non-mutating CLI version commands through the existing shim or candidate version, such as `--version`, `version`, or `--help` when no version command exists.
- For local-build shims, inspect the checked-in `images/<tool>/Containerfile` and run the built tool's version command when practical.
- For remote-image shims, inspect the default image reference and run a non-mutating version command when practical.
- Do not guess a major.minor version from `latest` tags alone.
- If a tool exposes a semantic version with more components, use `major.minor` for the version label.
- If a tool exposes a non-semver release identifier, stop and document the naming decision before implementation. Do not invent a fake major.minor.
- Record the discovered version and evidence in the implementation PR or commit summary.

Version naming:

```text
<kind>_<major>_<minor>
```

Examples:

```text
oc_4_20
jq_1_7
terraform_1_13
gcloud_532_0
```

For kind names with hyphens, append the version suffix to the full kind name:

```text
opnsense-mcp-admin_0_9
opnsense-mcp-read-only_0_9
```

If a tool's real version format makes this awkward, pause and document the exception in the plan or PR. The default should be regular naming, not one-off aliases.

## Runtime Shim Shape

After the refactor, kind shims are dispatchers only.

`shims/<kind>` responsibilities:

- POSIX shell with `#!/bin/sh` and `set -eu`.
- Read optional selector environment, such as `SHIMMY_OC_VERSION`.
- If the selector is unset, use the catalog-defined default version.
- If the selector is set, map it to a supported concrete version.
- Print a clear error for unsupported selectors.
- `exec` the selected sibling version shim.
- Do not call Podman directly.
- Do not contain tool-specific image, mount, or credential logic.

`shims/<kind>_<major>_<minor>` responsibilities:

- POSIX shell with `#!/bin/sh` and `set -eu`.
- Contain the existing Podman or local-build runtime behavior.
- Preserve the kind-specific image env var conventions where practical.
- Mount `$PWD` to `/work` unless a tool has a documented reason not to.
- Use Shimmy's shared Podman helper for platform and preview behavior.
- Remain directly testable by maintainers.

Selector environment:

- Multi-version kinds should have a documented selector env var, for example `SHIMMY_OC_VERSION`.
- One-version kinds may omit selector documentation until a second version exists, but the dispatcher should still be capable of default dispatch.
- When adding a second version later, add or document the kind selector in the same change.

## Catalog Design

Replace the flat supported-shim catalog with kind and version helpers in `lib/repo/shimmy-catalog.sh`.

Recommended helper surface:

```sh
shimmy_kind_list
shimmy_kind_version_list <kind>
shimmy_kind_default_version <kind>
shimmy_kind_selector_env <kind>
shimmy_version_kind <version>
shimmy_version_label <version>
shimmy_is_kind <name>
shimmy_is_version <name>
```

Example outputs:

```text
shimmy_kind_list
# aws go gcloud gdrive jq netcat nmap oc opnsense-mcp-admin ...

shimmy_kind_version_list oc
# oc_4_18 oc_4_20 oc_4_22

shimmy_kind_default_version oc
# oc_4_20

shimmy_kind_selector_env oc
# SHIMMY_OC_VERSION

shimmy_version_kind oc_4_20
# oc

shimmy_version_label oc_4_20
# 4.20
```

For a one-version kind:

```text
shimmy_kind_version_list jq
# jq_1_7

shimmy_kind_default_version jq
# jq_1_7

shimmy_version_kind jq_1_7
# jq

shimmy_version_label jq_1_7
# 1.7
```

Implementation guidance:

- Do not add `Family` or `Variant` helpers for this dispatch model.
- Remove the need for `companion_shim_list`; installing a kind always installs the dispatcher plus selected version(s).
- If transitional helpers make the refactor easier, keep them internal and delete them before finalizing.
- Keep catalog data POSIX-shell-native. Do not introduce JSON, YAML, Python, or jq requirements.

## Install Behavior

`shimmy install --shim <name>` should treat `<name>` as a kind name.

Default behavior:

```sh
shimmy install --shim jq
# installs kind dispatcher jq plus default version jq_<major>_<minor>

shimmy install --shim oc
# installs kind dispatcher oc plus default version oc_4_20
```

Selecting a non-default version needs a documented syntax. Recommended syntax:

```sh
shimmy install --shim oc@4.18
shimmy install --shim terraform@1.13
```

Rules:

- `<kind>` installs the kind dispatcher and the default version.
- `<kind>@<version-label>` installs the kind dispatcher and the requested version.
- Direct version install names such as `oc_4_20` are optional maintainer shortcuts, not the primary user interface.
- If the requested kind does not exist, fail with available kinds.
- If the requested version label does not exist, fail with available labels and creation guidance.
- Do not prompt for the default path. The default version exists specifically so `shimmy install --shim <kind>` is deterministic.

Failure example:

```text
ERROR: unsupported oc version: 4.19
Available oc versions: 4.18, 4.20, 4.22
Default oc version: 4.20
Run one of:
  shimmy install --shim oc
  shimmy install --shim oc@4.18
  shimmy install --shim oc@4.20
  shimmy install --shim oc@4.22
```

Creation guidance:

```text
To add a new oc version from a Shimmy source checkout, add:
  shims/oc_<major>_<minor>
  shims/oc_<major>_<minor>.conf
  images/oc_<major>_<minor>/Containerfile when local-build behavior is needed
  catalog kind metadata
  status/update/test/docs/skill coverage
```

## Manifest Behavior

Backward compatibility is not required, so replace `shim=` manifest semantics with kind-aware state.

Recommended profile manifest keys:

```text
kind=jq
kind_version=jq|default|jq_1_7

kind=oc
kind_version=oc|default|oc_4_20
kind_version=oc|4.18|oc_4_18
```

Rules:

- `kind=` records installed user-facing dispatchers.
- `kind_version=<kind>|<label>|<version>` records installed concrete versions.
- The label `default` should be present for each installed kind and point to the default concrete version installed for that kind.
- If a non-default version is installed, keep its version label too.
- Avoid storing only concrete versions without kind context.
- Update `status --format manifest`, install, update, test, and uninstall together.

Open implementation question:

- If the default version is also installed under its version label, decide whether to emit both:

```text
kind_version=oc|default|oc_4_20
kind_version=oc|4.20|oc_4_20
```

Recommendation: emit both. It makes "what is default?" and "which version labels are installed?" independently parseable.

## Status Behavior

Update `scripts/status-shimmy.sh` around kinds.

Human installed output should show kind dispatchers and versions:

```text
installed_kinds:
- jq:
  default: 1.7 (jq_1_7)
- oc:
  default: 4.20 (oc_4_20)
  installed_versions:
  - 4.18 (oc_4_18)
  - 4.20 (oc_4_20)
```

Human available output should show kinds and available version labels:

```text
available_kinds:
- aws:
  default: 2.27 (aws_2_27)
- oc:
  default: 4.20 (oc_4_20)
  versions: 4.18, 4.20, 4.22
```

Manifest output should be additive and shell-readable:

```text
shimmy_available_kind=oc
shimmy_available_kind_default=oc|4.20|oc_4_20
shimmy_available_kind_version=oc|4.18|oc_4_18
shimmy_available_kind_version=oc|4.20|oc_4_20
shimmy_available_kind_version=oc|4.22|oc_4_22
```

Since compatibility is not required, existing `shimmy_available_shim=` keys may be removed, but update README, tests, and skills in the same change.

## Test Behavior

Update `scripts/test-shimmy.sh` with focused POSIX-only tests.

Required coverage:

- Catalog helper tests:
  - `shimmy_kind_list` includes every migrated kind;
  - `shimmy_kind_version_list oc` returns `oc_4_18 oc_4_20 oc_4_22`;
  - `shimmy_kind_default_version oc` returns `oc_4_20`;
  - representative one-version kind default resolves to its discovered major.minor version;
  - version label and version kind helpers work.
- Install resolver tests:
  - `--shim jq` installs `jq` plus its default concrete version;
  - `--shim oc` installs `oc` plus `oc_4_20`;
  - `--shim oc@4.18` installs `oc` plus `oc_4_18`;
  - unsupported `oc@4.19` fails with available labels and default label;
  - bare install still installs the configured default kinds.
- Runtime dispatcher tests:
  - kind dispatcher with no selector uses default;
  - kind dispatcher with supported selector uses selected version;
  - unsupported selector fails clearly.
- Manifest tests:
  - profile manifest records `kind=` and `kind_version=`;
  - default labels are present;
  - concrete version labels are present.
- Status tests:
  - human status shows installed kinds and defaults;
  - manifest status emits kind and version keys;
  - available status reports kind defaults and version labels.

Avoid live Podman work for catalog and resolver tests. Use preview rendering or non-mutating version checks for runtime smoke coverage.

## Update Behavior

`scripts/update-shimmy.sh` should operate on kinds and installed versions.

Recommended behavior:

- `shimmy update --shim jq` refreshes the `jq` dispatcher and installed `jq` versions.
- `shimmy update --shim oc` refreshes the `oc` dispatcher and installed `oc` versions.
- `shimmy update --shim oc@4.18` refreshes only that concrete version plus required kind metadata.
- `--pull` and `--build` apply to concrete versions according to their image strategy.

Status/update image descriptions should move from kind names to version names where the image actually lives. Kind descriptions should explain dispatch/default state.

## Documentation Ripple Effects

Update docs in the same implementation change.

Required docs:

- `README.md`
  - Add a "Shim Concepts" or "Shim Kinds" section near install/profile/manifest documentation.
  - Explain that every user-facing command is a kind dispatcher.
  - Explain concrete versions and default versions.
  - Show `shimmy install --shim oc`, `shimmy install --shim oc@4.18`, and unset-selector default dispatch.
  - Document the new manifest fields.
- `docs/prompt-shimmy-project.md`
  - Replace flat supported-shim guidance with kind/version guidance.
  - Require major.minor version creation for every shim.
  - Require a default version for every kind.
  - Require selector/default dispatcher behavior for kind shims.
- `docs/shims/oc.md`
  - Present `oc` as a kind dispatcher.
  - State that `oc_4_20` is the default version.
  - Explain `SHIMMY_OC_VERSION` as optional because unset uses default.
  - Keep supported version details.
- `docs/testing.md`
  - Document kind, default version, and version smoke test expectations.
- `CONTRIBUTING.md`
  - Add a short concept note so contributors understand that runtime behavior belongs in versions, not kind dispatchers.

## Agent Skill Ripple Effects

Update agent skills in the same implementation change.

Required skills:

- `.agents/skills/shimmy-create-tool/SKILL.md`
  - Define Kind and Version.
  - Do not use Family or Variant for this dispatch model.
  - Require every new shim to create a kind dispatcher, at least one major.minor version, and a default version mapping.
  - Require version discovery for one-version kinds.
  - Update the multi-version checklist into a generic kind/version checklist.
- `.agents/skills/shimmy-install/SKILL.md`
  - Document kind-aware install syntax.
  - Document default version resolution.
  - Document `kind@version-label` selection.
  - Update manifest contract from `shim=` to `kind=` and `kind_version=`.
- `.agents/skills/shimmy-tool-oc/SKILL.md`
  - Describe `oc` as the current multi-version kind.
  - State `oc_4_20` is the default.
  - Update validation examples for `shimmy install --shim oc` and `shimmy install --shim oc@4.18`.

After skill edits, run the repo skill installer for the changed skills. If it accepts one skill per invocation, run repeated commands:

```sh
./shimmy skills install --target repo shimmy-create-tool
./shimmy skills install --target repo shimmy-install
./shimmy skills install --target repo shimmy-tool-oc
```

## Implementation Sequence

1. Inventory current catalog shims and determine major.minor versions for all current one-version tools.
2. Design final version names and record discovery evidence.
3. Add kind/version catalog helpers.
4. Move existing runtime wrapper logic from each `shims/<kind>` into `shims/<kind>_<major>_<minor>`.
5. Replace each `shims/<kind>` with a small dispatcher.
6. Add or update kind and version `.conf` files.
7. Refactor install around kind requests and default version resolution.
8. Replace manifest write/read logic with kind-aware fields.
9. Update status and update behavior.
10. Update tests after each control-plane layer.
11. Update README, docs, and agent skills.
12. Run focused validation, then the full test suite.

## Validation Commands

Use direct repo commands with `login=false` in AI Agent environments unless profile/startup behavior is intentionally under test.

Minimum validation:

```sh
git diff --check
./scripts/test-shimmy.sh
```

Focused validation to add or run:

```sh
./shimmy install --install-dir /private/tmp/shimmy-kind-test --profile default --shim oc --no-startup --no-skills
./shimmy status --install-dir /private/tmp/shimmy-kind-test --format manifest
./shimmy status --install-dir /private/tmp/shimmy-kind-test --available --format manifest
```

Runtime default dispatch checks:

```sh
./shims/oc --preview-shim version
SHIMMY_OC_VERSION=4.18 ./shims/oc --preview-shim version
```

For concrete version live checks, use non-mutating commands and existing Podman approval rules:

```sh
./shims/oc_4_20 version
```

## Acceptance Criteria

- Every catalog kind has a kind dispatcher and at least one concrete major.minor version.
- Every kind has a required default version.
- Existing current one-version shims have been migrated to concrete major.minor versions based on discovered underlying tool versions.
- `oc` default version is `oc_4_20`.
- `shimmy install --shim <kind>` installs the kind dispatcher plus its default version.
- `shimmy install --shim oc` installs `oc` plus `oc_4_20`.
- `shimmy install --shim oc@4.18` installs `oc` plus `oc_4_18`.
- Kind dispatchers use default versions when no selector is provided.
- Unsupported selector values fail clearly and list supported values plus the default.
- Profile manifests use kind-aware fields.
- Status and available output report kinds, defaults, and versions.
- Docs and agent skills explain the kind/version/default model.
- Tests cover catalog, install, manifest, status, update, and runtime dispatch behavior.

## Risks And Design Constraints

- Version discovery can be expensive if every tool image must be pulled or built. Prefer existing local images and checked-in metadata first, but do not guess.
- Some tools may not expose semver. Pause and document exceptions instead of forcing fake major.minor labels.
- The word "version" is doing deliberate work here: concrete shim version and tool version label. Use "version label" when referring specifically to labels such as `4.20`.
- This is a broad refactor across shims, install, status, update, tests, docs, and skills. Keep commits or PR sections layered.
- Keep kind dispatchers small. Tool-specific runtime behavior belongs in concrete versions.
- Keep the catalog POSIX-shell-native.
- Do not introduce an interactive prompt for ordinary `shimmy install --shim <kind>`; default versions make that path deterministic.
