# Shimmy Install Profile Plan

## Problem

Shimmy currently treats profile path resolution and profile existence as separate concerns, but the command behavior does not make that separation obvious to users. Commands can resolve conventional paths for `default` or `upstream` even when the matching profile directory and manifest were never created.

The observed failure:

```text
FAIL: expected profile implementation to be executable: /Users/wade/.config/shimmy/profiles/default/shims/aws
```

is consistent with an install tree where the dispatcher shims and legacy manifest exist, but the selected profile implementation directory does not. The failure is not AWS-specific; AWS was simply the first shim selected by `shimmy test`.

## Direction

Make the first-class install experience a simple command:

```sh
shimmy install
```

That command should create a complete external-user install root with the default profile:

- `default`: the external-user runtime profile and the default for top-level commands.

The upstream profile should remain a reserved built-in maintainer profile, but it should be installed only when explicitly requested:

```sh
shimmy install --mode upstream
```

That explicit upstream install should keep the current bespoke source-checkout behavior: it records the checkout used for installation and dispatches installed tool commands back to that checkout.

The default runtime mode should remain `default`. Activation without an explicit mode should activate the dispatcher path and set `SHIMMY_MODE=default`.

## Reserved Modes

Treat `default` and `upstream` as reserved built-in modes rather than future custom modes.

`shimmy install` should create or repair the default profile. `shimmy install --mode default` may remain accepted as an explicit spelling of the same operation, but Quick Start documentation should prefer only:

```sh
shimmy install
```

`shimmy install --mode upstream` should create or repair the upstream profile. It should remain documented for maintainer workflows because upstream needs a checkout contract that normal external users do not need.

Future custom modes should be designed separately. The behavior of `default` and `upstream` should not be used as an implicit custom-mode contract.

## Correction To Current Behavior

The current bug is not just that one profile directory can be missing. The deeper issue is that mode resolution can produce valid-looking paths for profiles that do not exist.

Commands that select a mode should distinguish:

- mode name is syntactically supported
- profile path can be derived
- profile manifest exists
- profile implementation directory exists
- selected shim implementation exists and is executable

Activation, status, test, update, and dispatch should agree on these checks. Non-repair commands should either report `shimmy_installed=no` for inspection commands or fail with an explicit missing-profile message for execution commands. Diagnostics should include a repair hint that points to `shimmy install` or `shimmy update` for the selected profile. `shimmy install` and `shimmy update` should use the same checks to drive selected-profile cleanup and restoration.

## Proposed Behavior

### Bare Install

`shimmy install` should:

1. Create the shared install root.
2. Create shared dispatcher shims under `$SHIMMY_INSTALL_DIR/shims`.
3. Create `$SHIMMY_INSTALL_DIR/profiles/default`.
4. Copy runtime shim implementations into `$SHIMMY_INSTALL_DIR/profiles/default/shims`.
5. Write a root manifest for install-wide state.
6. Write a profile manifest for the default profile.
7. Generate activation that defaults to `SHIMMY_MODE=default`.

### Upstream Install

`shimmy install --mode upstream` should:

1. Resolve the source checkout from the current checkout or `SHIMMY_UPSTREAM_CHECKOUT_DIR`.
2. Create the shared install root if needed.
3. Create shared dispatcher shims under `$SHIMMY_INSTALL_DIR/shims` if needed.
4. Create `$SHIMMY_INSTALL_DIR/profiles/upstream`.
5. Create upstream exec wrappers under `$SHIMMY_INSTALL_DIR/profiles/upstream/shims`.
6. Write or update the root manifest so it records `profile=upstream` as an installed profile.
7. Write a profile manifest for the upstream profile, including `source_checkout`.
8. Generate activation that can select upstream mode through `shimmy activate --mode upstream`.

### Upstream Checkout Contract

The upstream profile should use a recorded checkout path, not a managed clone or runtime override. `shimmy install --mode upstream` should resolve `source_checkout` to an absolute path and persist it in the upstream profile manifest.

Commands that use upstream profile state should validate the recorded checkout before relying on it:

- the path exists and is a directory
- `shimmy` exists and is executable
- `scripts/`, `shims/`, `lib/repo/`, and `lib/shims/` are present
- `scripts/install-shimmy.sh`, `scripts/update-shimmy.sh`, `scripts/dispatch-shimmy.sh`, and `scripts/status-shimmy.sh` are present
- `lib/repo/shimmy-profile.sh` and `lib/repo/shimmy-catalog.sh` are present
- the selected upstream shim source exists before dispatching a tool command

Git metadata should be optional. If `git -C <checkout> rev-parse HEAD` succeeds, `status` may report the current source ref as diagnostic output. A copied but otherwise complete source tree should still be valid for upstream dispatch and repair.

If the recorded checkout is missing or no longer looks valid, activation, status, test, update, and dispatch should report a stale upstream checkout with a direct repair message:

```text
rerun ./shimmy install --mode upstream from the desired Shimmy checkout
```

The install-time `SHIMMY_UPSTREAM_CHECKOUT_DIR` override should remain supported for selecting the checkout to record, but dispatch should not silently route through a runtime checkout override. Keeping the manifest as the selected source of truth makes upstream behavior deterministic and easier to diagnose.

### Manifest Split

Split the current manifest into two scopes:

- root manifest: `$SHIMMY_INSTALL_DIR/install-manifest.txt`
- profile manifest: `$SHIMMY_INSTALL_DIR/profiles/<mode>/install-manifest.txt`

The root manifest should answer, "Where is this Shimmy install, and what global integration did it create?" It should hold install-wide state such as:

```text
shimmy_install_manifest_version=1
install_dir=...
dispatcher_dir=...
control_bin=...
activate_file=...
default_mode=default
profile=default
startup_shell=...
startup_file=...
```

The profile manifest should answer, "What is installed for this mode?" It should hold profile-specific state such as:

```text
shimmy_profile_manifest_version=1
mode=default
profile_implementation_dir=...
bin_dir=...
config_dir=...
shim_source=copied-source-shim
shim=aws
shim=jq
shim=rg
shimmy_source_url=...
shimmy_source_ref=...
shimmy_previous_source_ref=...
```

The upstream profile manifest should additionally include:

```text
source_checkout=...
shim_source=generated-exec-wrapper
```

The root manifest should record only profiles that are actually installed. After a bare install it should list `profile=default`; after an explicit upstream install it should also list `profile=upstream`.

Field ownership should be explicit:

Root manifest durable state:

```text
shimmy_install_manifest_version=1
install_dir=...
dispatcher_dir=...
control_bin=...
activate_file=...
default_mode=default
profile=default
startup_shell=...
startup_file=...
```

Root-scoped `shimmy_*` lifecycle fields may also live in the root manifest when they describe the whole install rather than one profile.

Profile manifest durable state:

```text
shimmy_profile_manifest_version=1
mode=default
config_dir=...
bin_dir=...
profile_implementation_dir=...
shim_source=copied-source-shim
shim=aws
shim=jq
shim=rg
shimmy_source_url=...
shimmy_source_ref=...
shimmy_previous_source_ref=...
```

Profile-scoped `shimmy_*` lifecycle fields should live in the selected profile manifest. `source_checkout` should live only in the upstream profile manifest.

`shimmy_skill` entries should move out of root and profile install manifests. The dedicated skills manifest under each skills target should be the only durable owner of generated skill audit state:

```text
.shimmy-skills-manifest.txt
```

That manifest should continue to store repeated entries such as:

```text
shimmy_skill=repo|shimmy-install|...|...
shimmy_skill=repo|shimmy-tool-jq|...|...
```

Root and profile manifests should not duplicate those entries. If status needs to report skills later, it should read the relevant `.shimmy-skills-manifest.txt` rather than treating install/profile manifests as skill audit logs.

The profile manifest should not persist `install_dir` once the root manifest is authoritative. Profile paths can be resolved from the root `install_dir` plus `mode`; storing both creates drift risk.

The following concepts should be derived by `status` rather than persisted as durable manifest state, and should be emitted with scoped status keys:

```text
shimmy_manifest_path=...
shimmy_profile_manifest_path=...
shimmy_profile_dir=...
shimmy_profile_images_dir=...
shimmy_profile_shim_lib_dir=...
shimmy_installed=...
shimmy_path_active=...
shimmy_available_shim=...
```

If `shim_dir` remains useful as a distinct status concept, emit it as `shimmy_profile_shim_dir`; otherwise prefer `shimmy_profile_bin_dir`.

`manifest_path` should be derived by readers rather than stored as durable state. Commands that open a manifest already know its path, and `status` can print the path it resolved without requiring the manifest to repeat it.

Profile commands should use the selected profile manifest as the source of truth for profile behavior. Install inspection commands such as `shimmy status --format manifest` can combine root manifest state with selected profile state, but the root manifest should not be treated as a default-profile substitute when `profiles/default` is missing.

### Status Manifest Output

`shimmy status --format manifest` should be a normalized inspection view, not a byte-for-byte dump of either manifest file. Because it combines root manifest state, selected profile manifest state, and derived status checks, output keys should be scope-prefixed.

Use `shimmy_` for install-wide root state and derived status facts. Use `shimmy_profile_` for selected profile state.

Example shape:

```text
shimmy_install_dir=...
shimmy_dispatcher_dir=...
shimmy_control_bin=...
shimmy_activate_file=...
shimmy_default_mode=default
shimmy_manifest_path=...
shimmy_installed=yes
shimmy_path_active=yes
shimmy_available_shim=...
shimmy_profile_mode=default
shimmy_profile_dir=...
shimmy_profile_manifest_path=...
shimmy_profile_config_dir=...
shimmy_profile_bin_dir=...
shimmy_profile_implementation_dir=...
shimmy_profile_images_dir=...
shimmy_profile_shim_lib_dir=...
shimmy_profile_shim_source=copied-source-shim
shimmy_profile_shim=aws
shimmy_profile_shim=jq
shimmy_profile_source_url=...
shimmy_profile_source_ref=...
```

For upstream status, include:

```text
shimmy_profile_source_checkout=...
```

Do not emit ambiguous unscoped keys such as `manifest_path`, `mode`, `bin_dir`, or `installed` from `status --format manifest`. If the raw manifest files keep shorter internal keys, status should translate them into this scoped output contract.

### Activation

`shimmy activate` should activate the install in default mode and export:

```sh
SHIMMY_MODE=default
```

`shimmy activate --mode upstream` should succeed only if the upstream profile manifest and implementation directory exist.

`shimmy activate --mode default` should succeed only if the default profile manifest and implementation directory exist.

### Status

`shimmy status --format manifest` should continue to default to mode `default`.

For a missing selected profile, status should be able to report enough diagnostic information to support repair, but it should not make the install look healthier than it is. A useful machine-readable shape would include:

```text
shimmy_profile_mode=default
shimmy_installed=no
shimmy_profile_dir=...
shimmy_profile_manifest_path=...
shimmy_profile_implementation_dir=...
shimmy_missing=profile_manifest
shimmy_missing=profile_implementation_dir
shimmy_repair_hint=shimmy install
shimmy_repair_hint=shimmy update
```

For an upstream profile, repair hints should use the selected mode:

```text
shimmy_repair_hint=shimmy install --mode upstream
shimmy_repair_hint=shimmy update --mode upstream
```

`shimmy status` and `shimmy test` should not mutate install state. They should report a root-listed missing profile as structurally incomplete when the root manifest lists `profile=<mode>` but the selected profile manifest or implementation directory is missing.

### Test And Dispatch

`shimmy test` should fail before running a shim if the selected profile is structurally incomplete.

The dispatcher should fail with a direct missing-profile or missing-manifest message before looking for a specific shim implementation. This avoids misleading tool-specific errors when the whole profile is absent. Dispatch should not repair install state implicitly.

### Update

`shimmy install` and `shimmy update` should share the same selected-profile cleanup and restoration behavior. With no explicit mode, both should repair the default profile and shared install root.

Mode-scoped install and update should repair the selected mode:

- `shimmy install` and `shimmy update` repair `default`.
- `shimmy install --mode default` and `shimmy update --mode default` repair `default`.
- `shimmy install --mode upstream` and `shimmy update --mode upstream` repair `upstream`.

For upstream, repair requires a valid recorded `source_checkout` or an explicitly resolved checkout such as the current checkout or `SHIMMY_UPSTREAM_CHECKOUT_DIR`. `shimmy update --mode upstream` should not guess a checkout if the upstream manifest is missing and no valid checkout can be resolved.

## Migration Plan

1. Add profile existence validation helpers in `lib/repo/shimmy-profile.sh`.
2. Teach the installer to create only the default profile during bare `shimmy install`.
3. Keep `shimmy install --mode default` accepted as an explicit default install, but omit it from Quick Start documentation.
4. Keep `shimmy install --mode upstream` as the explicit reserved maintainer-profile install path.
5. Add upstream checkout validation helpers that read `source_checkout` from the upstream profile manifest.
6. Add shared selected-profile repair helpers used by both install and update.
7. Preserve existing mode precedence: explicit flag, then `SHIMMY_MODE`, then `default`.
8. Migrate or rewrite legacy default installs so `$SHIMMY_INSTALL_DIR/profiles/default` is always created.
9. Migrate the current root manifest into split root/profile manifests.
10. Stop treating `$SHIMMY_INSTALL_DIR/install-manifest.txt` as a default-profile substitute after migration.
11. Move generated skill audit ownership to dedicated `.shimmy-skills-manifest.txt` files and stop writing `shimmy_skill` entries into root/profile install manifests.
12. Keep startup-file lifecycle fixes out of this plan.
13. Update activate, status, test, dispatch, update, uninstall, skills, README, CONTRIBUTING, and tests together.

## Test Coverage

Add or update tests for:

- bare `shimmy install` creates `profiles/default` and does not create `profiles/upstream`
- default profile contains executable copied source shims
- `shimmy install --mode default` remains accepted as an explicit default install path
- `shimmy install --mode upstream` creates `profiles/upstream`
- upstream profile contains executable generated wrappers tied to the recorded source checkout
- upstream profile records an absolute `source_checkout`
- upstream checkout validation requires executable `shimmy`, required lifecycle scripts, required repo helper libraries, and required shim helper libraries
- upstream checkout validation does not require Git metadata
- upstream activation, status, test, update, and dispatch report stale-checkout diagnostics when the recorded checkout is missing
- upstream activation, status, test, update, and dispatch report invalid-checkout diagnostics when required source files are missing
- upstream dispatch fails before looking for a specific tool implementation when the recorded checkout is invalid
- dispatcher shims are shared and route based on `SHIMMY_MODE`
- `shimmy activate` exports `SHIMMY_MODE=default`
- `shimmy activate --mode upstream` fails when upstream profile is absent
- `shimmy status --mode upstream --format manifest` reports missing profile state clearly
- `shimmy test` fails with profile-structure diagnostics when the selected profile is missing
- `shimmy status` and `shimmy test` report root-listed missing profiles as structurally incomplete without mutating install state
- missing-profile diagnostics include scoped `shimmy_missing` fields and repair hints for both `shimmy install` and `shimmy update`
- `shimmy install` and `shimmy update` use the same selected-profile cleanup and restoration path
- `shimmy update --mode upstream` repairs upstream when a valid recorded or explicitly resolved checkout exists, and fails clearly otherwise
- root manifest records install-wide state without profile-specific shim ownership
- profile manifests record mode-specific shims, implementation directories, source checkout, and lifecycle source refs
- profile manifests do not persist root-owned `install_dir`
- root and profile manifests do not contain `shimmy_skill` entries
- `.shimmy-skills-manifest.txt` remains the only durable owner of generated skill audit entries
- `shimmy skills update` refreshes skills from `.shimmy-skills-manifest.txt` without relying on root/profile install manifest `shimmy_skill` entries
- `shimmy_manifest_path`, `shimmy_profile_manifest_path`, `shimmy_profile_dir`, `shimmy_profile_images_dir`, `shimmy_profile_shim_lib_dir`, `shimmy_installed`, `shimmy_path_active`, and `shimmy_available_shim` are emitted as derived status fields rather than durable manifest fields
- `status --format manifest` reports combined root/status facts with `shimmy_` keys and selected profile facts with `shimmy_profile_` keys
- `status --format manifest` does not emit ambiguous unscoped keys such as `manifest_path`, `mode`, `bin_dir`, or `installed`
- `status --format manifest` reports both resolved root state and selected profile state without using the root manifest as a profile fallback
- legacy install state is repaired or reported according to the migration decision

## Concerns

- The upstream profile can become stale if the recorded checkout moves or is deleted. The chosen contract should fail clearly and direct maintainers to rerun `./shimmy install --mode upstream` from the desired checkout.
- Custom modes are not implemented yet. `default` and `upstream` should stay explicitly reserved so future custom-mode behavior does not inherit maintainer-specific upstream assumptions.
- Update and uninstall semantics need careful treatment. Since upstream is explicit, removing or repairing one profile should not accidentally create or remove the other profile.
- The root manifest has already caused mixed-layout ambiguity because it can look like default-profile state. Splitting root and profile fields fixes the role ambiguity, but migration must prevent older installs and scripts from breaking abruptly.
- `status` should remain useful for diagnostics without reporting `installed=yes` only because a dispatcher directory exists.

## Recommendation

The direction is sound if Shimmy keeps the external-user onramp default-first while preserving upstream as an explicit maintainer profile. The implementation should first harden profile existence validation and migration behavior, then split root/profile manifests and update the installer contract. That ordering reduces the risk of creating another mixed install layout while the command surface is in transition.
