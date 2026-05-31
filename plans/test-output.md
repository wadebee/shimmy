# Shimmy Test Output Plan

## Goal

Make `shimmy test` output reflect Shimmy ownership boundaries so users can infer whether a tested shim is root-owned or profile-owned.

The root manifest can contain default shims such as `jq` and `rg`. Those default shims should be tested by default and reported in the root test output section. Additional selected profile shims should be tested only when requested with `--all` or `--shim <name>`, and their results should appear in the profile test output section.

## Plan

1. Model `shimmy test` as two visible phases: root tests first, then selected-profile tests.

2. Root phase:
   - Validate the root manifest.
   - Read `default_shim=` entries from the root manifest.
   - Smoke-test each selected root default shim by using the selected profile dispatcher, bin, and config paths to execute the installed shim safely.
   - Report root-owned shim results in the root output section.

3. Profile phase:
   - Validate the selected profile structure.
   - Read `shim=` entries from the selected profile manifest.
   - Run smoke tests for selected profile-owned shims only when `--all` or `--shim <name>` selects them.
   - Report profile-owned shim results in the profile output section.

4. Selection and ownership rules:
   - With no `--all` or `--shim`, smoke-test only root default shims.
   - With `--all`, smoke-test root default shims in the root section and profile-owned non-default shims in the profile section.
   - With `--shim <name>`, smoke-test only the requested shim.
   - An explicitly requested shim, such as `shimmy test --shim jq`, should report in the section that owns it (eg: a profile-only shim reports only in the profile section, a root-owned shim reports in the root section).
   - Do not double-count root default shims as profile-owned extras under `--all`.

5. Test coverage:
   - Default no-flag output shows root default shim tests for `jq` and `rg`.
   - `--all` shows root default shim output and additional profile-owned shim output separately.
   - `--shim jq` reports `jq` in the root section only.
   - `--shim <profile-only>` reports the requested shim in the profile section only.

6. Verification:
   - Run targeted repo tests with temporary install state.
   - Use live Shimmy-backed installed shims for smoke checks where required.
   - Keep output machine-readable enough for automation while improving human clarity.

## Assumptions

- `default_shim=` entries in the root manifest define root-owned default shims.
- `shim=` entries in the selected profile manifest define installed profile shims.
- Root-owned default shims still depend on the selected profile for runnable implementation files and smoke-test config.
- Existing `--all` and `--shim` semantics can be refined around ownership without changing install manifests.
