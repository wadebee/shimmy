# Shim Families Handoff Plan

## Goal

Refactor Shimmy so users install and run logical tool families, while Shimmy dispatches to concrete versioned variants underneath.

The user-facing command should always be the family name:

```sh
shimmy install --shim oc
oc version

shimmy install --shim jq
jq --version
```

Every family must have:

- a family dispatcher at `shims/<family>`;
- at least one concrete versioned variant at `shims/<family>_<major>_<minor>`;
- a required default variant mapping;
- a family smoke config;
- variant smoke configs for every concrete variant.

Backward compatibility is not required for this feature. Use that freedom to make the model regular instead of preserving the current mixed "some shims are direct wrappers, some shims are dispatchers" shape.

## Core Model

Use two catalog object types:

- **Family**: the stable user-facing tool command. Examples: `jq`, `rg`, `oc`, `terraform`.
- **Variant**: the concrete implementation for one tool version. Examples: `jq_1_7`, `rg_14_1`, `oc_4_20`.

Do not use a `Kind` classifier. If the object appears in the family list, it is a family dispatcher. If it appears in a family's variant list, it is a concrete variant.

Relationship rules:

- Users request families.
- Runtime PATH exposes families.
- Family dispatchers choose variants.
- Variants run Podman or local image build logic.
- Every family has exactly one default variant at any point in time.
- Every default variant points to a concrete major.minor variant, not to an unversioned wrapper.

## Required Default Variant

Every family must define a default variant.

For single-variant tools, the implementation agent must determine the underlying tool's current major.minor version and create that concrete variant. The family default then points to it.

Example for a single-variant `jq` family:

```text
family: jq
variant: jq_1_7
default: jq_1_7
```

Example for `oc`:

```text
family: oc
variants: oc_4_18 oc_4_20 oc_4_22
default: oc_4_20
```

This means a family command is always runnable after install. If no selector is provided at runtime, the family dispatcher uses its default variant.

For `oc`, unset `SHIMMY_OC_VERSION` should dispatch to `oc_4_20` instead of failing. If `SHIMMY_OC_VERSION` is set to an unsupported value, the dispatcher should still fail clearly and list supported values plus the default.

## Version Discovery For Existing Shims

For each existing non-`oc` catalog shim, determine the underlying tool major.minor version before creating the first variant.

Current catalog families to migrate:

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

`oc` already has concrete variants, but its default must be set to `oc_4_20`.

Discovery rules:

- Prefer non-mutating CLI version commands through the existing shim or candidate variant, such as `--version`, `version`, or `--help` when no version command exists.
- For local-build shims, inspect the checked-in `images/<tool>/Containerfile` and run the built tool's version command when practical.
- For remote-image shims, inspect the default image reference and run a non-mutating version command when practical.
- Do not guess a major.minor version from `latest` tags alone.
- If a tool exposes a semantic version with more components, use `major.minor` for the variant label.
- If a tool exposes a non-semver release identifier, stop and document the naming decision before implementation. Do not invent a fake major.minor.
- Record the discovered version and evidence in the implementation PR or commit summary.

Variant naming:

```text
<family>_<major>_<minor>
```

Examples:

```text
oc_4_20
jq_1_7
terraform_1_13
gcloud_532_0
```

For family names with hyphens, append the version suffix to the full family name:

```text
opnsense-mcp-admin_0_9
opnsense-mcp-read-only_0_9
```

If a tool's real version format makes this awkward, pause and document the exception in the plan or PR. The default should be regular naming, not one-off aliases.

## Runtime Shim Shape

After the refactor, family shims are dispatchers only.

`shims/<family>` responsibilities:

- POSIX shell with `#!/bin/sh` and `set -eu`.
- Read optional selector environment, such as `SHIMMY_OC_VERSION`.
- If the selector is unset, use the catalog-defined default variant.
- If the selector is set, map it to a supported concrete variant.
- Print a clear error for unsupported selectors.
- `exec` the selected sibling variant shim.
- Do not call Podman directly.
- Do not contain tool-specific image, mount, or credential logic.

`shims/<family>_<major>_<minor>` responsibilities:

- POSIX shell with `#!/bin/sh` and `set -eu`.
- Contain the existing Podman or local-build runtime behavior.
- Preserve the family-specific image env var conventions where practical.
- Mount `$PWD` to `/work` unless a tool has a documented reason not to.
- Use Shimmy's shared Podman helper for platform and preview behavior.
- Remain directly testable by maintainers.

Selector environment:

- Multi-variant families should have a documented selector env var, for example `SHIMMY_OC_VERSION`.
- Single-variant families may omit selector documentation until a second variant exists, but the dispatcher should still be capable of default dispatch.
- When adding a second variant later, add or document the family selector in the same change.

## Catalog Design

Replace the flat supported-shim catalog with family and variant helpers in `lib/repo/shimmy-catalog.sh`.

Recommended helper surface:

```sh
shimmy_family_list
shimmy_family_variant_list <family>
shimmy_family_default_variant <family>
shimmy_family_selector_env <family>
shimmy_variant_family <variant>
shimmy_variant_label <variant>
shimmy_is_family <name>
shimmy_is_variant <name>
```

Example outputs:

```text
shimmy_family_list
# aws go gcloud gdrive jq netcat nmap oc opnsense-mcp-admin ...

shimmy_family_variant_list oc
# oc_4_18 oc_4_20 oc_4_22

shimmy_family_default_variant oc
# oc_4_20

shimmy_family_selector_env oc
# SHIMMY_OC_VERSION

shimmy_variant_family oc_4_20
# oc

shimmy_variant_label oc_4_20
# 4.20
```

For a single-variant family:

```text
shimmy_family_variant_list jq
# jq_1_7

shimmy_family_default_variant jq
# jq_1_7

shimmy_variant_family jq_1_7
# jq

shimmy_variant_label jq_1_7
# 1.7
```

Implementation guidance:

- Remove the need for `shimmy_shim_kind`.
- Remove the need for `companion_shim_list`; installing a family always installs the dispatcher plus selected variant(s).
- If transitional helpers make the refactor easier, keep them internal and delete them before finalizing.
- Keep catalog data POSIX-shell-native. Do not introduce JSON, YAML, Python, or jq requirements.

## Install Behavior

`shimmy install --shim <name>` should treat `<name>` as a family name.

Default behavior:

```sh
shimmy install --shim jq
# installs family dispatcher jq plus default variant jq_<major>_<minor>

shimmy install --shim oc
# installs family dispatcher oc plus default variant oc_4_20
```

Selecting a non-default variant needs a documented syntax. Recommended syntax:

```sh
shimmy install --shim oc@4.18
shimmy install --shim terraform@1.13
```

Rules:

- `<family>` installs the family dispatcher and the default variant.
- `<family>@<version-label>` installs the family dispatcher and the requested variant.
- Direct variant install names such as `oc_4_20` are optional maintainer shortcuts, not the primary user interface.
- If the requested family does not exist, fail with available families.
- If the requested variant label does not exist, fail with available labels and creation guidance.
- Do not prompt for the default path. The default variant exists specifically so `shimmy install --shim <family>` is deterministic.

Failure example:

```text
ERROR: unsupported oc variant: 4.19
Available oc variants: 4.18, 4.20, 4.22
Default oc variant: 4.20
Run one of:
  shimmy install --shim oc
  shimmy install --shim oc@4.18
  shimmy install --shim oc@4.20
  shimmy install --shim oc@4.22
```

Creation guidance:

```text
To add a new oc variant from a Shimmy source checkout, add:
  shims/oc_<major>_<minor>
  shims/oc_<major>_<minor>.conf
  images/oc_<major>_<minor>/Containerfile when local-build behavior is needed
  catalog family metadata
  status/update/test/docs/skill coverage
```

## Manifest Behavior

Backward compatibility is not required, so replace `shim=` manifest semantics with family-aware state.

Recommended profile manifest keys:

```text
family=jq
family_variant=jq|default|jq_1_7

family=oc
family_variant=oc|default|oc_4_20
family_variant=oc|4.18|oc_4_18
```

Rules:

- `family=` records installed user-facing dispatchers.
- `family_variant=<family>|<label>|<variant>` records installed concrete variants.
- The label `default` should be present for each installed family and point to the default concrete variant installed for that family.
- If a non-default variant is installed, keep its version label too.
- Avoid storing only concrete variants without family context.
- Update `status --format manifest`, install, update, test, and uninstall together.

Open implementation question:

- If the default variant is also installed under its version label, decide whether to emit both:

```text
family_variant=oc|default|oc_4_20
family_variant=oc|4.20|oc_4_20
```

Recommendation: emit both. It makes "what is default?" and "which version labels are installed?" independently parseable.

## Status Behavior

Update `scripts/status-shimmy.sh` around families.

Human installed output should show family dispatchers and variants:

```text
installed_families:
- jq:
  default: 1.7 (jq_1_7)
- oc:
  default: 4.20 (oc_4_20)
  installed_variants:
  - 4.18 (oc_4_18)
  - 4.20 (oc_4_20)
```

Human available output should show families and available variant labels:

```text
available_families:
- aws:
  default: 2.27 (aws_2_27)
- oc:
  default: 4.20 (oc_4_20)
  variants: 4.18, 4.20, 4.22
```

Manifest output should be additive and shell-readable:

```text
shimmy_available_family=oc
shimmy_available_family_default=oc|4.20|oc_4_20
shimmy_available_family_variant=oc|4.18|oc_4_18
shimmy_available_family_variant=oc|4.20|oc_4_20
shimmy_available_family_variant=oc|4.22|oc_4_22
```

Since compatibility is not required, existing `shimmy_available_shim=` keys may be removed, but update README, tests, and skills in the same change.

## Test Behavior

Update `scripts/test-shimmy.sh` with focused POSIX-only tests.

Required coverage:

- Catalog helper tests:
  - `shimmy_family_list` includes every migrated family;
  - `shimmy_family_variant_list oc` returns `oc_4_18 oc_4_20 oc_4_22`;
  - `shimmy_family_default_variant oc` returns `oc_4_20`;
  - representative single family default resolves to its discovered major.minor variant;
  - variant label and variant family helpers work.
- Install resolver tests:
  - `--shim jq` installs `jq` plus its default concrete variant;
  - `--shim oc` installs `oc` plus `oc_4_20`;
  - `--shim oc@4.18` installs `oc` plus `oc_4_18`;
  - unsupported `oc@4.19` fails with available labels and default label;
  - bare install still installs the configured default families.
- Runtime dispatcher tests:
  - family dispatcher with no selector uses default;
  - family dispatcher with supported selector uses selected variant;
  - unsupported selector fails clearly.
- Manifest tests:
  - profile manifest records `family=` and `family_variant=`;
  - default labels are present;
  - concrete variant labels are present.
- Status tests:
  - human status shows installed families and defaults;
  - manifest status emits family and variant keys;
  - available status reports family defaults and variant labels.

Avoid live Podman work for catalog and resolver tests. Use preview rendering or non-mutating version checks for runtime smoke coverage.

## Update Behavior

`scripts/update-shimmy.sh` should operate on families and installed variants.

Recommended behavior:

- `shimmy update --shim jq` refreshes the `jq` dispatcher and installed `jq` variants.
- `shimmy update --shim oc` refreshes the `oc` dispatcher and installed `oc` variants.
- `shimmy update --shim oc@4.18` refreshes only that concrete variant plus required family metadata.
- `--pull` and `--build` apply to concrete variants according to their image strategy.

Status/update image descriptions should move from family names to variant names where the image actually lives. Family descriptions should explain dispatch/default state.

## Documentation Ripple Effects

Update docs in the same implementation change.

Required docs:

- `README.md`
  - Add a "Shim Concepts" or "Shim Families" section near install/profile/manifest documentation.
  - Explain that every user-facing command is a family dispatcher.
  - Explain concrete variants and default variants.
  - Show `shimmy install --shim oc`, `shimmy install --shim oc@4.18`, and unset-selector default dispatch.
  - Document the new manifest fields.
- `docs/prompt-shimmy-project.md`
  - Replace flat supported-shim guidance with family/variant guidance.
  - Require major.minor variant creation for every shim.
  - Require a default variant for every family.
  - Require selector/default dispatcher behavior for family shims.
- `docs/shims/oc.md`
  - Present `oc` as a family dispatcher.
  - State that `oc_4_20` is the default variant.
  - Explain `SHIMMY_OC_VERSION` as optional because unset uses default.
  - Keep supported variant details.
- `docs/testing.md`
  - Document family, default variant, and variant smoke test expectations.
- `CONTRIBUTING.md`
  - Add a short concept note so contributors understand that runtime behavior belongs in variants, not family dispatchers.

## Agent Skill Ripple Effects

Update agent skills in the same implementation change.

Required skills:

- `.agents/skills/shimmy-create-tool/SKILL.md`
  - Define Family and Variant.
  - Remove or replace the `Kind` concept.
  - Require every new shim to create a family dispatcher, at least one major.minor variant, and a default variant mapping.
  - Require version discovery for single-variant families.
  - Update the multi-version checklist into a generic family/variant checklist.
- `.agents/skills/shimmy-install/SKILL.md`
  - Document family-aware install syntax.
  - Document default variant resolution.
  - Document `family@version-label` selection.
  - Update manifest contract from `shim=` to `family=` and `family_variant=`.
- `.agents/skills/shimmy-tool-oc/SKILL.md`
  - Describe `oc` as the current multi-variant family.
  - State `oc_4_20` is the default.
  - Update validation examples for `shimmy install --shim oc` and `shimmy install --shim oc@4.18`.

After skill edits, run the repo skill installer for the changed skills. If it accepts one skill per invocation, run repeated commands:

```sh
./shimmy skills install --target repo shimmy-create-tool
./shimmy skills install --target repo shimmy-install
./shimmy skills install --target repo shimmy-tool-oc
```

## Implementation Sequence

1. Inventory current catalog shims and determine major.minor versions for all single-variant tools.
2. Design final variant names and record discovery evidence.
3. Add family/variant catalog helpers.
4. Move existing runtime wrapper logic from each `shims/<family>` into `shims/<family>_<major>_<minor>`.
5. Replace each `shims/<family>` with a small dispatcher.
6. Add or update family and variant `.conf` files.
7. Refactor install around family requests and default variant resolution.
8. Replace manifest write/read logic with family-aware fields.
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
./shimmy install --install-dir /private/tmp/shimmy-family-test --profile default --shim oc --no-startup --no-skills
./shimmy status --install-dir /private/tmp/shimmy-family-test --format manifest
./shimmy status --install-dir /private/tmp/shimmy-family-test --available --format manifest
```

Runtime default dispatch checks:

```sh
./shims/oc --preview-shim version
SHIMMY_OC_VERSION=4.18 ./shims/oc --preview-shim version
```

For concrete variant live checks, use non-mutating commands and existing Podman approval rules:

```sh
./shims/oc_4_20 version
```

## Acceptance Criteria

- Every catalog family has a family dispatcher and at least one concrete major.minor variant.
- Every family has a required default variant.
- Existing single-variant shims have been migrated to concrete major.minor variants based on discovered underlying tool versions.
- `oc` default variant is `oc_4_20`.
- `shimmy install --shim <family>` installs the family dispatcher plus its default variant.
- `shimmy install --shim oc` installs `oc` plus `oc_4_20`.
- `shimmy install --shim oc@4.18` installs `oc` plus `oc_4_18`.
- Family dispatchers use default variants when no selector is provided.
- Unsupported selector values fail clearly and list supported values plus the default.
- Profile manifests use family-aware fields.
- Status and available output report families, defaults, and variants.
- Docs and agent skills explain the family/variant/default model.
- Tests cover catalog, install, manifest, status, update, and runtime dispatch behavior.

## Risks And Design Constraints

- Version discovery can be expensive if every tool image must be pulled or built. Prefer existing local images and checked-in metadata first, but do not guess.
- Some tools may not expose semver. Pause and document exceptions instead of forcing fake major.minor labels.
- This is a broad refactor across shims, install, status, update, tests, docs, and skills. Keep commits or PR sections layered.
- Keep family dispatchers small. Tool-specific runtime behavior belongs in concrete variants.
- Keep the catalog POSIX-shell-native.
- Do not introduce an interactive prompt for ordinary `shimmy install --shim <family>`; default variants make that path deterministic.
