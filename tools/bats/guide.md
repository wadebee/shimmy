# Bats Shim

## Upstream

- Source repo README: <https://github.com/bats-core/bats-core/blob/master/README.md>
- Installation and Docker usage: <https://bats-core.readthedocs.io/en/stable/installation.html>
- Latest release: <https://github.com/bats-core/bats-core/releases/latest>
- Official image: <https://hub.docker.com/r/bats/bats>
- Shim image: `docker.io/bats/bats@sha256:5322b877351fda0cc435de8c6116de7d0a2ec79d7c680132a0ef329a633bc66f` from `versions/1.14/image.conf`

## Upstream README Summary

Bats-core is a TAP-compliant testing framework for Bash 3.2 and newer. Test files are Bash scripts with `@test` functions, and Bats runs them as shell-based behavioral tests for UNIX programs and shell code.

## Top-Level Command Summary

Bats is option-oriented rather than subcommand-oriented. Common usage patterns:

- `bats --version` - print the installed Bats version.
- `bats test` - run tests in the `test` path.
- `bats --tap test` - emit TAP output for a test directory or file.
- `bats --filter PATTERN test` - run only tests whose names match a pattern.
- `bats --formatter junit test` - emit JUnit XML output.

## Shimmy Usage

```sh
bats --version
bats test
bats --tap test
```

Environment:

- `SHIMMY_BATS_IMAGE` - override the container image.
- `SHIMMY_BATS_IMAGE_PULL=always` - force pulling the configured image.

Mounts and I/O:

- `$PWD` -> `/work` read-write, with `/work` as the container working directory.
- Stdin is always open. A TTY is allocated only when both stdin and stdout are terminals.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `bats` to run the shell tests for my backup scripts and summarize any failures."
- Software dev: "Run `bats --tap test` in this repo and show which shell tests failed."
- Platform engineer: "Use `bats --filter` to rerun only the failing smoke tests in this shell-based tool suite."
