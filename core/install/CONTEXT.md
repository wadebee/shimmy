# Installation lifecycle

`install.sh` is the sourceable orchestration implementation for the public
`commands/install.sh` entrypoint. It initializes shared install state and
selects fresh, additive, refresh, or uninstall lifecycle flows.

## Files

- `request.sh` parses install inputs, resolves profile paths, and validates
  requested tool kinds and versions.
- `manifest.sh` preserves and renders root and profile manifests.
- `profile-assets.sh` copies the control plane and creates profile wrappers,
  metadata, dispatchers, and optional management skills.
- `startup.sh` renders activation assets and applies startup-file integration.
- `uninstall.sh` removes selected profile assets and cleans up the final
  install root.

The entrypoint supplies the source-root paths before calling
`shimmy_install_run`.
