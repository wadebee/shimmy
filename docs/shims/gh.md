# GitHub CLI Shim

## Upstream

- Source and releases: <https://github.com/cli/cli>
- GitHub CLI documentation: <https://cli.github.com/manual/>
- Shim image: local build from `images/gh_2_94/Containerfile`

## Shimmy Usage

```sh
gh --version
gh auth login
gh pr create
```

Environment:

- `SHIMMY_GH_IMAGE` overrides the locally built runtime image.
- `SHIMMY_GH_IMAGE_BUILD=always` rebuilds the local image even when cached.
- `SHIMMY_GH_IMAGE_PULL=always` forces Podman to pull `SHIMMY_GH_IMAGE` when an image override is used.
- `SHIMMY_GH_BASE_IMAGE` overrides the Containerfile base image. Default: `alpine:3.22`.
- `SHIMMY_GH_VERSION` overrides the GitHub CLI release used in the local image. Default: `2.94.0`.
- `GH_CONFIG_DIR` is the standard GitHub CLI configuration directory override. When unset, Shimmy uses `$HOME/.config/gh`.
- GitHub CLI's `GH_*` environment variables, including `GH_TOKEN`, are forwarded. Prefer a persistent `gh auth login` configuration over placing long-lived tokens in the environment.

Mounts and runtime:

- `$PWD` is mounted read-write at `/work` and becomes the working directory.
- `GH_CONFIG_DIR` or `$HOME/.config/gh` is created during normal execution and mounted read-write at `/home/gh/.config/gh`.
- The container sets `GH_CONFIG_DIR=/home/gh/.config/gh`, so authentication and configuration persist on the host.
- The shim uses `-it` only when stdin and stdout are terminals.
- The shared Podman helper selects `linux/amd64` on Linux and `linux/arm64` on macOS.

Local image behavior:

- Shimmy builds `localhost/shimmy-gh-2_94:<context-hash>-<platform>` from `images/gh_2_94/Containerfile`.
- The image downloads the official GitHub CLI release archive for its target architecture and includes `git`, which GitHub CLI needs to work with local repositories.

Authentication:

Run `gh auth login` through the shim to persist the selected host, account, and token in the mounted configuration directory. Authenticated commands can then run from later shell sessions. `GH_TOKEN` supports non-interactive commands but may be visible to local processes and shell history; do not commit it.

## Examples

```sh
gh auth status
gh repo view
gh pr list
gh issue list
```
