# OPNsense CLI Shim

## Upstream

- Source repo README: <https://github.com/mihakralj/opnsense-cli/blob/main/README.md>
- Latest release page: <https://github.com/mihakralj/opnsense-cli/releases>
- Latest source commits: <https://github.com/mihakralj/opnsense-cli/commits/main>
- Source repo: <https://github.com/mihakralj/opnsense-cli>
- Shim image: local build from `images/opnsense-cli/Containerfile`

## Upstream README Summary

OPNsense CLI is a command-line utility for administering OPNsense firewall systems from FreeBSD, Linux, macOS, and Windows. It can run locally on the firewall or remotely through SSH, and supports inspecting system data, showing and staging configuration, importing/exporting changes, comparing XML, and managing backups.

The upstream repository does not currently publish tagged GitHub releases; Shimmy builds the Go module using the configured `OPNSENSE_CLI_VERSION`, which defaults to `latest`.

## Top-Level Command Summary

- `backup` - list available backup configurations.
- `commit` - commit staged configuration changes.
- `compare` - compare XML configuration files.
- `delete` - remove a backup XML configuration.
- `discard` - discard staged configuration changes.
- `export` - export configuration differences.
- `import` - import and stage an XML patch.
- `restore` - restore active configuration from backup.
- `run` - execute registered firewall commands.
- `save` - create a new backup.
- `set` - set a value or attribute in staged configuration.
- `show` - display active and staged configuration information.
- `sysinfo` - retrieve system information.

## Shimmy Usage

```sh
opnsense-cli --help
opnsense-cli -t root@firewall.example.net sysinfo
OPNSENSE_CLI_IMAGE_BUILD=always opnsense-cli --help
```

Environment:

- `OPNSENSE_CLI_IMAGE` - override the runtime image entirely.
- `OPNSENSE_CLI_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `OPNSENSE_CLI_IMAGE_PULL=always` - force pulling `OPNSENSE_CLI_IMAGE` when using an override.
- `OPNSENSE_CLI_BASE_IMAGE` - override the runtime image base. Default: `alpine:3.22`.
- `OPNSENSE_CLI_VERSION` - override the Go module version. Default: `latest`.

Local image behavior:

- Shimmy builds `localhost/shimmy-opnsense-cli:<context-hash>-<platform>` from `images/opnsense-cli/Containerfile`.
- The image installs the upstream `opnsense` binary and exposes it through the `opnsense-cli` shim name.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.ssh` -> `/root/.ssh` read-only when it exists.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `opnsense-cli -t root@firewall sysinfo` to summarize firewall system health."
- Software dev: "Show me the safe read-only OPNsense CLI commands I can run before changing firewall configuration."
- Platform engineer: "Use OPNsense CLI backup and compare commands to prepare a reviewable firewall config change."
