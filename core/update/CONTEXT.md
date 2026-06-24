# Update lifecycle

`update.sh` is the sourceable implementation for the public
`commands/update.sh` entrypoint. It resolves installed profiles and refreshes
management assets, remote images, local images, and stale local-image state.

The entrypoint supplies the source-root paths before calling
`shimmy_update_run`.

## Files

- `request.sh` parses update CLI inputs and renders command help.
- `selection.sh` resolves target profiles and validates installed kinds and
  concrete version selections.
- `management.sh` refreshes management assets from an installed source URL.
- `profile.sh` discovers installed profiles and refreshes their assets.
- `update.sh` currently retains image-refresh orchestration pending version-
  local refresh hooks.
