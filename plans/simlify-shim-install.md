# Simplify Shim Install Semantics

## Goal

Refactor Shimmy lifecycle commands so install, update, and uninstall have distinct ownership semantics:

- `shimmy install` installs missing shims into the selected profile.
- `shimmy update` refreshes or replaces already-installed shims.
- `shimmy uninstall` removes installed assets.

Backwards compatibility is not a constraint for this change.

## Planned Behavior

- Bare `shimmy install` installs the root default shim set into the default profile. The default set is currently `jq` and `rg`.
- `shimmy install --shim <name>` adds missing shims to the selected profile instead of replacing the profile's shim list.
- `shimmy install <name>` is not a valid call and should be removed from the launcher/library path if present.
- Duplicate install attempts should not refresh existing shim assets. They should exit successfully with a warning that points users to `shimmy update --shim <name>`.
- Bare `shimmy update` refreshes root manifest/code and default shims only.
- Bare `shimmy update` does not refresh every profile-owned non-default shim.
- `shimmy update --shim <name>` refreshes an already-installed shim in the selected profile.
- `shimmy update --shim <name>` fails when the shim is not installed and prints warning guidance to run `shimmy install --shim <name>`.
- `shimmy update --all` refreshes root and profile logic, manifests, and shims for all installed profiles.

## Implementation Notes

- Remove `--add-shim` from the public install surface.
- Keep `--shim <name>` as the only user-facing install selector for named shims.
- Preserve profile manifest shim ownership while appending new shim entries idempotently.
- Add an internal installer refresh mode for `shimmy update` so update can refresh installed assets without using install's additive behavior.
- Refactor default update behavior so it refreshes root/default assets only.
- Add explicit `--all` handling for full root plus all-profile refresh.
- Update help text, README guidance, and behavioral tests together.

## Test Plan

- Verify bare `shimmy install` installs `jq` and `rg`.
- Verify `shimmy install --shim <name>` appends a missing shim without removing existing profile shims.
- Verify duplicate `shimmy install --shim <name>` exits successfully with warning guidance to use `shimmy update --shim <name>`.
- Verify `shimmy install <name>` is rejected.
- Verify bare `shimmy update` refreshes root/default shims only.
- Verify `shimmy update --shim <name>` refreshes an installed selected-profile shim.
- Verify `shimmy update --shim <name>` fails for a missing shim with `shimmy install --shim <name>` guidance.
- Verify `shimmy update --all` refreshes all installed profiles and their manifest-owned shims.

## Risks

- Existing tests and scripts that used `./shimmy install --shim <name>` as an exact profile replacement need to adapt to additive semantics.
- Duplicate install warnings should avoid making common repair/bootstrap workflows too noisy.
- `update --shim` must validate profile ownership before touching files so missing shims do not get implicitly installed through the update path.
- Bare `update` and `update --all` must be clearly separated so users do not accidentally refresh profile-owned non-default shims.
