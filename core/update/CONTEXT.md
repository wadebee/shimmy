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
- `refresh.sh` locates and invokes an installed concrete version's executable
  refresh hook. Hooks accept `pull` or `build`; they own image override
  handling, their safe runtime invocation where applicable, and local-image
  cleanup.
- `update.sh` retains setup and lifecycle orchestration only.
