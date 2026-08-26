# GitHub CLI Shim

## Upstream

- Source and releases: <https://github.com/cli/cli>
- GitHub CLI documentation: <https://cli.github.com/manual/>
- Shim image: local build from `versions/2.94/image.conf` and `container/`

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
- `SHIMMY_GH_BASE_IMAGE` overrides the configured base image. Default: `docker.io/library/alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce`.
- `SHIMMY_GH_VERSION` overrides the GitHub CLI release used in the local image. Default: `2.94.0`.
- `SHIMMY_HOST_CA_BUNDLE` mounts one absolute, readable host CA bundle
  read-only and sets `SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem`.
- `GH_CONFIG_DIR` is the standard GitHub CLI configuration directory override. When unset, Shimmy uses `$HOME/.config/gh`.
- GitHub CLI's `GH_*` environment variables, including `GH_TOKEN`, are forwarded. Prefer a persistent `gh auth login` configuration over placing long-lived tokens in the environment.

Mounts and runtime:

- `$PWD` is mounted read-write at `/work` and becomes the working directory.
- `GH_CONFIG_DIR` or `$HOME/.config/gh` is created during normal execution and mounted read-write at `/home/gh/.config/gh`.
- `SHIMMY_HOST_CA_BUNDLE` is mounted read-only at
  `/tmp/shimmy-host-ca-bundle.pem` when configured.
- The container sets `GH_CONFIG_DIR=/home/gh/.config/gh`, so authentication and configuration persist on the host.
- The shim uses `-it` only when stdin and stdout are terminals.
- The shared Podman helper selects the native `linux/amd64` or `linux/arm64`
  platform from supported Linux/macOS host OS and CPU combinations.

GitHub CLI's Go HTTP client uses `SSL_CERT_FILE` for system-root file
discovery. This can replace the normal public root file, so provide a combined
public and corporate bundle when both are required.

Local image behavior:

- Shimmy builds `localhost/shimmy-gh-2_94:<image-input-hash>-<platform>` from the version's `image.conf` and `container/` inputs.
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
