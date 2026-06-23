# Update lifecycle

`update.sh` is the sourceable implementation for the public
`commands/update.sh` entrypoint. It resolves installed profiles and refreshes
management assets, remote images, local images, and stale local-image state.

The entrypoint supplies the source-root paths before calling
`shimmy_update_run`.
