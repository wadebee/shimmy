# Tessl Shim

## Upstream

- Authoritative CLI docs: <https://docs.tessl.io/reference>
- Latest release/version source: <https://www.npmjs.com/package/@tessl/cli?activeTab=versions>
- Changelog: <https://docs.tessl.io/changelog>
- npm package: <https://www.npmjs.com/package/@tessl/cli>
- Shim image: local build from `images/tessl/Containerfile`

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

- `TESSL_IMAGE` - override the runtime image entirely.
- `TESSL_IMAGE_BUILD=always` - rebuild the local image even when cached.
- `TESSL_IMAGE_PULL=always` - force pulling `TESSL_IMAGE` when using an override.
- `TESSL_BASE_IMAGE` - override the Containerfile base image. Default: `node:25`.

Local image behavior:

- Shimmy builds `localhost/shimmy-tessl:<context-hash>-<platform>` from `images/tessl/Containerfile`.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.tessl` -> `/root/.tessl` when it exists.

Forwarded environment:

- `TESSL_*`

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

Status:

- `shims/tessl` exists in the repository, but `tessl` is not currently listed in the installer's supported shim set.

## Quick-Start Prompts

- Home labber: "Use `tessl search` to find reusable skills for documenting my home lab services."
- Software dev: "Use `tessl skill lint` to validate this agent skill before I share it with the team."
- Platform engineer: "Use Tessl scenario commands to prepare codebase evals for recent platform repository commits."
