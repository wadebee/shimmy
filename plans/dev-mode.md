# Shimmy Dev Mode Plan

## Objective

Move Shimmy toward one external-style operating model with two explicit install profiles available by default:

- `default`: the normal external-user profile and the default for all top-level shimmy commands (eg: install,
  activate, update, status, netinfo and test operations).
- `upstream`: an opt-in git checkout-backed maintainer profile that exercises local source
  changes through activated commands.

The maintainer experience should remain comparable to the current repo-local
workflow, but implementation and skill guidance should prefer activated commands
and installed-state inspection over repo-relative paths.

## Core Invariants

- `default` is the default behavior and setting when mode is not provided `SHIMMY_MODE=default`.
- `upstream` is explicit through the common `--mode upstream` CLI flag across all top-level shimmy commands or by setting environment `SHIMMY_MODE=upstream`.
- CLI flags override environment selection.
- `SHIMMY_MODE` currently accepts only `default` or `upstream` but could support additional profiles in future iterations.
- The public CLI selector is always `--mode {value}`. Do not add profile-specific selection flags such as `--upstream`.
- Mode is resolved once near the command boundary, then all paths derive from the
  resolved mode in a normalize_path function.
- Each mode owns unique install, config, manifest, and bin paths.
- Path resolution must normalize mode-specific variables before downstream code uses them.
- Direct tool commands such as `rg` select a profile through activation unless a later checkpoint intentionally introduces mode-aware dispatcher wrappers.
- Runtime shims remain small POSIX shell wrappers.
- Upstream mode must not depend on ad hoc `../../../...` path traversal.

Example resolution shape:

```sh
case "${shimmy_mode}" in
  upstream)
    shimmy_base_path=${SHIMMY_UPSTREAM_DIR}
    ;;
  default)
    shimmy_base_path=${SHIMMY_INSTALL_DIR}
    ;;
esac
```

Prefer central helper functions over repeated inline conditionals so every command resolves paths the same way.

## Assumptions

- All top-level shimmy commands (eg: `shimmy install`, `shimmy activate`, `shimmy update`, `shimmy status`, and `shimmy test`) are the long-term public
  entrypoints for both profiles.
- The `upstream` profile can point at the current checkout through symlinks or generated wrappers instead of copying all shim files.
- The `default` profile keeps existing user-facing behavior unless a checkpoint explicitly changes it and receives review approval.
- Existing repo-local commands can remain during migration, but new skill and user workflows should converge on activated commands.

## Risks

- Ambient `SHIMMY_MODE=upstream` may make maintainers think they are testing a normal
  install when they are using git checkout-backed shims.
- Sharing directories between profiles could create hard-to-debug stale wrapper or manifest state.
- Introducing upstream mode without strong status output would make support and CI harder to reason about.
- Rewriting docs and skills too early could remove working maintainer guidance before the upstream profile is complete.

## Best Practices

- Keep profile selection boring: explicit flag, validated env var, deterministic default.
- Print the selected mode and important resolved paths in diagnostic commands.
- Make path helpers return absolute normalized paths where practical.
- Treat profile manifests as the source of truth for installed state.
- Add tests at each checkpoint before broadening the behavior surface.
- Stop at each review gate before implementing the next checkpoint.

## Checkpoint 1: Profile Model And Path Resolution

Implement the shared profile vocabulary and path resolution layer.

Work items:

- Add canonical mode parsing for `default` and `upstream` using a new global command flag `--mode`.
- Add CLI mode selection support where command parsing already exists.
- Add `SHIMMY_MODE` support with strict validation.
- Establish precedence: explicit flag, then `SHIMMY_MODE`, then `default`.
- Add centralized helpers for resolving:
  - mode
  - install base path
  - config base path
  - bin path
  - manifest path
  - source checkout path, for upstream only
- Ensure default and upstream paths are unique after resolution.
- Avoid downstream code reading raw `SHIMMY_INSTALL_DIR` or `SHIMMY_UPSTREAM_DIR`
  directly after mode resolution.

Verification:

- Unit or shell tests cover flag precedence over `SHIMMY_MODE`.
- Tests reject invalid `SHIMMY_MODE` values.
- Tests prove `default` and `upstream` profiles resolve to different base, bin, config, and manifest paths.
- Existing default-mode install path behavior still passes.

Review gate:

- Confirm naming, precedence, and resolved path layout before wiring install,
  activate, or test behavior to the new profile model.

## Checkpoint 2: Install, Activate, And Test Profile Selection

Make public commands profile-aware while preserving default behavior.

Work items:

- Teach `shimmy install` to target `default` unless `--mode upstream` is provided.
- Teach `shimmy activate` to emit activation for `default` unless `--mode upstream` is provided.
- Teach `shimmy status` to execute against the selected profile.
- Teach `shimmy test` to execute against the selected profile.
- Define the scope of `SHIMMY_MODE` for direct tool commands:
  - activation-only selection, where `shimmy activate --mode upstream` changes `PATH`, or
  - runtime dispatcher selection, where installed command wrappers inspect
    `SHIMMY_MODE`.
- Prefer flags for one-off usage:

```sh
shimmy install --mode upstream
shimmy activate --mode upstream
shimmy test --mode upstream
```
- Support persistent session usage:

```sh
SHIMMY_MODE=upstream shimmy test
```

- Ensure command output identifies the selected mode when it affects behavior.

Verification:

- `shimmy install` without mode still uses the default profile.
- `SHIMMY_MODE=upstream shimmy install` targets the upstream profile.
- `SHIMMY_MODE=upstream shimmy install --mode default` targets the default profile.
- `shimmy activate --mode upstream` emits an upstream-profile `PATH`.
- `shimmy test --mode upstream` runs against the upstream-profile bin path.

Review gate:

- Confirm user-facing command names, flags, and output before introducing the
  upstream manifest and checkout-backed wrapper strategy.

## Checkpoint 3: Manifest And Directory Layout

Give each profile an inspectable installed state.

Work items:

- Define profile-specific manifest locations.
- Include at least these manifest fields:
  - `mode`
  - `install_dir`
  - `config_dir`
  - `bin_dir`
  - `manifest_path`
  - `shim_source`
  - `source_checkout`, for upstream only
- Add status output that shows the selected profile and resolved paths.
- Ensure manifests are generated consistently for both profiles.
- Ensure commands never infer profile state by walking from installed skill paths.

Verification:

- Default install writes only the default manifest.
- Dev install writes only the upstream manifest.
- `shimmy status --mode upstream` or equivalent output shows mode, bin path, manifest path, and source checkout.
- Tests prove profile manifests do not overwrite each other.

Review gate:

- Confirm manifest fields and directory layout before changing wrapper generation.

## Checkpoint 4: Checkout-Backed Dev Wrappers

Make the upstream profile exercise local source changes through activated commands.

Work items:

- Choose the upstream wrapper strategy:
  - symlink activated commands to checkout files, or
  - generate wrappers that exec checkout files.
- Record the chosen strategy in the upstream manifest as `shim_source`.
- Ensure `rg`, `jq`, and other activated commands in upstream mode run the current checkout implementation.
- Keep wrapper behavior POSIX-compatible.
- Avoid hardcoding per-tool repo paths outside the installer or wrapper generation logic.

Verification:

- Editing a repo-local shim is reflected through the upstream activated command after
  install, or after the documented regeneration step if generated wrappers are chosen.
- After upstream activation, `rg --version` exercises the upstream profile.
- If dispatcher wrappers are chosen, `SHIMMY_MODE=upstream rg --version` exercises the upstream profile without a separate activation step.
- Default activated commands are unaffected by upstream installation.
- Non-mutating live Podman checks still work for representative shims.

Review gate:

- Confirm maintainer workflow parity before migrating docs, skills, and CI away
  from repo-local examples.

## Checkpoint 5: Documentation, Skills, And Migration

Move guidance toward external-style operation without stranding maintainers.

Work items:

- Update `README.md`, `CONTRIBUTING.md`, and relevant docs with:
  - default profile behavior
  - upstream profile opt-in behavior
  - mode precedence
  - path resolution model
  - manifest inspection
  - activation examples
- Update Shimmy skills to prefer activated commands and manifest inspection.
- Remove `../../../...` assumptions from external/profile guidance.
- Keep repo-local commands documented only where they are intentionally testing
  source files directly.
- Add migration notes for maintainers moving from repo-local workflows to
  `shimmy install --mode upstream` and activated commands.

Verification:

- Docs describe one external-style model with two profiles.
- Skills explain when to use `SHIMMY_MODE=upstream` or `--mode upstream`.
- Docs and skills do not imply that default and upstream share paths.
- Examples use `SHIMMY_`-prefixed environment variables for Shimmy-defined
  behavior.

Review gate:

- Confirm that user-facing guidance is clear before updating CI or removing any
  older workflow references.

## Checkpoint 6: CI And End-To-End Verification

Prove both profiles work in automation.

Work items:

- Add or update CI to install and test the default profile.
- Add or update CI to install and test the upstream profile from the checkout.
- Run representative activated-command smoke checks for both profiles.
- Ensure CI output makes the selected mode visible.
- Keep live Podman execution for shim behavior tests.

Verification:

- Default profile CI covers normal external-user behavior.
- Upstream profile CI covers checkout-backed maintainer behavior.
- Tests verify default and upstream manifests, bin paths, and config paths remain
  independent.
- Existing behavioral tests still pass.

Review gate:

- Confirm the feature is ready for broader refactoring, cleanup, or deprecation
  of any repo-local-only workflow that is no longer needed.

## Open Decisions

- Should the preferred upstream wrapper strategy be symlinks or generated exec
  wrappers?
- Should direct tool commands use activation-only profile selection or
  `SHIMMY_MODE` runtime dispatcher selection?
- What are the exact default values for `SHIMMY_UPSTREAM_DIR` and any upstream-specific
  config directory variables?
- Should activation scripts warn when the selected profile differs from an
  already-active Shimmy path earlier on `PATH`?

## Completion Criteria

- Normal users can continue using `shimmy install`, `shimmy activate`, and
  `shimmy test` without learning about upstream mode.
- Maintainers can run `shimmy install --mode upstream`, activate the upstream profile, and test
  local source changes through normal commands such as `rg --version`.
- Default and upstream profile paths are unique, normalized, and inspectable.
- Skills and docs use external-style installed-state workflows by default.
- CI verifies both profiles independently.
