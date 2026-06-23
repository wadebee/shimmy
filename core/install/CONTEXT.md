# Installation lifecycle

`install.sh` is the sourceable implementation for the public
`commands/install.sh` entrypoint. It manages install request resolution,
manifests, profile assets, startup integration, and uninstall cleanup.

The entrypoint supplies the source-root paths before calling
`shimmy_install_run`.
