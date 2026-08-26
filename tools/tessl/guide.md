# Tessl Shim

## Upstream

- Authoritative CLI docs: <https://docs.tessl.io/reference>
- Latest release/version source: <https://www.npmjs.com/package/@tessl/cli?activeTab=versions>
- Changelog: <https://docs.tessl.io/changelog>
- npm package: <https://www.npmjs.com/package/@tessl/cli>
- Shim image: local build from `versions/0.1/image.conf` and `container/`

The Tessl CLI is distributed through npm as `@tessl/cli`. Public Tessl documentation and npm package metadata do not currently expose a source repository README for the CLI, so this doc links to the authoritative docs and package page instead.

## Upstream README Summary

Tessl is a package manager for agent skills and project context. The CLI supports authentication, project initialization, installing and managing skills or tiles, evaluating codebase scenarios, running an MCP server, and updating the CLI itself.

## Top-Level Command Summary

- `tessl login` / `logout` / `whoami` - manage authentication.
- `tessl init` - initialize a project.
- `tessl install` / `uninstall` / `list` / `search` - manage context packages.
- `tessl skill` - create, import, lint, or publish skills.
- `tessl tile` - lint, pack, publish, unpublish, or archive tiles.
- `tessl eval` - run evaluation workflows.
- `tessl scenario` - generate, list, view, or download scenarios.
- `tessl mcp start` - start the Tessl MCP server.
- `tessl cli update` - update the CLI.

## Shimmy Usage

```sh
tessl --help
tessl whoami
tessl skill lint
```

Environment:

- `SHIMMY_TESSL_IMAGE` - override the runtime image entirely.
- `SHIMMY_TESSL_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `SHIMMY_TESSL_IMAGE_PULL=always` - force pulling `SHIMMY_TESSL_IMAGE` when using an override.
- `SHIMMY_TESSL_BASE_IMAGE` - override the configured base image. Default: `docker.io/library/node@sha256:78839ac448c23517f8eab2e8f7943d9b4f73979eb7f8bed2c73dbf72ff869e7b`.
- `SHIMMY_HOST_CA_BUNDLE=/absolute/path/to/bundle.pem` - mount one host CA
  bundle read-only and expose it to Node as `NODE_EXTRA_CA_CERTS`.

Local image behavior:

- Shimmy builds `localhost/shimmy-tessl-0_1:<image-input-hash>-<platform>` from the version's `image.conf` and `container/` inputs.
- Shimmy version `0.1` preserves the existing unpinned `@tessl/cli` installation: each image build installs the current package version published by npm.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.tessl` -> `/root/.tessl` when it exists.
- `SHIMMY_HOST_CA_BUNDLE` -> `/tmp/shimmy-host-ca-bundle.pem` read-only when
  configured.

Forwarded environment:

- `SHIMMY_TESSL_*`

Host CA trust:

- `SHIMMY_HOST_CA_BUNDLE` remains host-only. The Tessl Node process receives
  `NODE_EXTRA_CA_CERTS=/tmp/shimmy-host-ca-bundle.pem`.
- Node adds certificates from `NODE_EXTRA_CA_CERTS` to its built-in trusted
  roots and reads the file at process startup. Application code that
  explicitly supplies a TLS `ca` option can override that default behavior.
  Shimmy mounts the supplied PEM file as-is and does not parse or merge it.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `tessl search` to find reusable skills for documenting my home lab services."
- Software dev: "Use `tessl skill lint` to validate this agent skill before I share it with the team."
- Platform engineer: "Use Tessl scenario commands to prepare codebase evals for recent platform repository commits."
