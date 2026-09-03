---
name: shimmy-tool-keepassxc
description: Guidance for using, changing, testing, and troubleshooting the KeePassXC CLI shim.
---

> Shimmy active-profile reconciliation unconditionally overwrites this exact bundle-declared skill destination without backup, never deletes unrelated skill names, and profile copies must not be edited.

# KeePassXC CLI Shim

Use this skill when working with the KeePassXC CLI tool, its tests, docs, or usage through Shimmy.

## Current behavior

- Default tool track: KeePassXC 2.7
- Default image: `docker.io/linuxserver/keepassxc@sha256:15e9b84880352c7ca30ed8ef6a71d45e0f9417b9dec85d0a7ad1275ce659a3d6`
- Container entrypoint: `keepassxc-cli`
- Image override: `SHIMMY_KEEPASSXC_IMAGE`
- Pull override: `SHIMMY_KEEPASSXC_IMAGE_PULL=always`
- Mount: `$PWD` to `/work`
- Platform: shared Podman helper selects native `linux/amd64` or `linux/arm64`

## Safety

KeePassXC CLI can read and modify password databases. Prefer non-mutating commands
such as `--version`, `help`, and `db-info` while validating a setup. Do not put
passwords, keys, or database secrets in command arguments or shell history.

## Validation

- Preview: `./commands/run-tool.sh keepassxc --preview-shim --version`
- Runtime smoke: `keepassxc --version`
- Focused tests: `./tests/test.sh --keepassxc`
