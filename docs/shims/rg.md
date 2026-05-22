# ripgrep Shim

## Upstream

- Source repo README: <https://github.com/BurntSushi/ripgrep/blob/master/README.md>
- Latest release: <https://github.com/BurntSushi/ripgrep/releases/latest>
- User guide: <https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md>
- Shim image: `docker.io/vszl/ripgrep:latest`

## Upstream README Summary

ripgrep recursively searches directories for regex patterns while respecting `.gitignore` and other ignore files by default. It is designed to be fast, Unicode-aware, and practical for source trees, logs, and large text collections.

## Top-Level Command Summary

ripgrep is option-oriented rather than subcommand-oriented. Common usage patterns:

- `rg PATTERN` - search recursively from the current directory.
- `rg PATTERN PATH` - search a specific path.
- `rg -n PATTERN` - show line numbers.
- `rg -t TYPE PATTERN` - limit search by file type.
- `rg --files` - list files that ripgrep would search.
- `rg --json PATTERN` - emit machine-readable search results.

## Shimmy Usage

```sh
rg --version
rg "pattern" .
rg --files
```

Environment:

- `RG_IMAGE` - override the container image.
- `RG_IMAGE_PULL=always` - force pulling the configured image.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `rg` to find every config file that mentions my old NAS hostname."
- Software dev: "Search this repo for all uses of a deprecated function and group results by file."
- Platform engineer: "Use `rg --files` and pattern searches to inventory Kubernetes manifests that set privileged containers."
