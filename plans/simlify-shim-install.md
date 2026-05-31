# Simplify Shim Install Semantics

## Goal

Refactor Shimmy lifecycle commands so install, update, and uninstall have distinct ownership semantics:

- `shimmy install` installs missing shims into the selected profile.
- `shimmy update` refreshes or replaces already-installed shims.
- `shimmy uninstall` removes installed assets.

Backwards compatibility is not a constraint for this change.

## Planned Behavior

- Bare `shimmy install` installs the root default shim set into the default profile. The default set is currently `jq` and `rg`.
- `shimmy install --shim <name>` addd missing shims to the selected profile instead of replacing the profile's shim list.
- `shimmy install <name>` is not a valid call and should be removed from library if present
- Duplicate install attempts should not refresh existing shim assets. They should exit successfully with a warning that points users to `shimmy update --shim <name>`.
- `shimmy update --shim <name>` refreshes an already-installed shim.
- `shimmy update --shim <name>` fails when the shim is not installed and prints warning guidance to run `shimmy install --shim <name>`.
- Full `shimmy update` without `--shim` continues to refresh all manifest-selected shims.

## Implementation Notes

- Remove `--add-shim` from the public install surface.
- Keep `--shim <name>` as the flag form for selecting shims to install, and allow positional shim names through the installed `shimmy install <shim>...` flow.
- Preserve profile manifest shim ownership while appending new shim entries idempotently.
- Add an internal installer refresh mode for `shimmy update` so update can refresh installed assets without using install's additive behavior.
- Update help text, README guidance, and behavioral tests together.

## Risks

- Existing tests and scripts that used `./shimmy install --shim <name>` as an exact profile replacement need to adapt to additive semantics.
- Duplicate install warnings should avoid making common repair/bootstrap workflows too noisy.
- `update --shim` must validate profile ownership before touching files so missing shims do not get implicitly installed through the update path.
