# Textual Shim

## Upstream

- Source repo README: <https://github.com/Textualize/textual/blob/main/README.md>
- Latest release: <https://github.com/Textualize/textual/releases/latest>
- Docs: <https://textual.textualize.io/>
- Shim image: local build from `versions/8.2/container/Containerfile`

## Upstream README Summary

Textual is a Python framework for building terminal and browser-capable user interfaces with a modern API. The upstream README highlights widgets, layouts, command palettes, testing support, and the ability to serve Textual apps through the web.

## Top-Level Command Summary

Common Textual developer CLI usage:

- `textual --help` - show CLI help.
- `textual run APP` - run a Textual app.
- `textual serve APP` - serve a Textual app for browser access.
- `textual console` - open the developer console.
- `textual diagnose` - print environment diagnostics.

## Shimmy Usage

```sh
textual --help
textual run app.py
```

Environment:

- `SHIMMY_TEXTUAL_IMAGE` - override the runtime image entirely.
- `SHIMMY_TEXTUAL_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `SHIMMY_TEXTUAL_IMAGE_PULL=always` - force pulling `SHIMMY_TEXTUAL_IMAGE` when using an override.
- `SHIMMY_TEXTUAL_BASE_IMAGE` - override the Containerfile base image. Default: `python:3.13-slim-bookworm`.
- `SHIMMY_TEXTUAL_VERSION` - override the Textual package version for local builds. Default: `8.2.7`.

Local image behavior:

- Shimmy builds `localhost/shimmy-textual-8_2:<context-hash>-<platform>` from `versions/8.2/container/Containerfile`.
- The image installs `textual==8.2.7` by default and `textual-dev`.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `textual run app.py` to launch this small dashboard for my home lab inventory."
- Software dev: "Use Textual CLI diagnostics to confirm the local TUI development environment is usable."
- Platform engineer: "Run this Textual admin app and summarize what operational controls it exposes."
