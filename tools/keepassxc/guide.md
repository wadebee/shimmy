# KeePassXC CLI Shim

## Upstream

- Project site: <https://keepassxc.org/>
- Source repository: <https://github.com/keepassxreboot/keepassxc>
- CLI documentation: <https://keepassxc.org/docs/KeePassXC_UserGuide.html#_command_line_interface>
- Shim image: `docker.io/linuxserver/keepassxc@sha256:15e9b84880352c7ca30ed8ef6a71d45e0f9417b9dec85d0a7ad1275ce659a3d6` from `versions/2.7/image.conf`

## Usage

The shim exposes `keepassxc-cli` as the stable `keepassxc` command:

```sh
keepassxc --version
keepassxc db-info vault.kdbx
keepassxc show vault.kdbx entry/path
```

Commands that open or modify a database may prompt for credentials or write to
files. Those operations are intentionally available through normal KeePassXC
CLI behavior; review paths and arguments before running them.

Environment:

- `SHIMMY_KEEPASSXC_IMAGE` - override the container image.
- `SHIMMY_KEEPASSXC_IMAGE_PULL=always` - force pulling the configured image.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`
