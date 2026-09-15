# yq Shim

## Upstream and image

This tool wraps [Mike Farah's yq](https://github.com/mikefarah/yq), the standalone
Go data processor with jq-like expressions. It is distinct from the Python
program also named yq that requires jq.

- [Selected release: v4.53.6](https://github.com/mikefarah/yq/releases/tag/v4.53.6)
- [Manual](https://mikefarah.gitbook.io/yq/)
- [Upstream container instructions](https://github.com/mikefarah/yq/blob/v4.53.6/README.md#run-with-docker-or-podman)
- [Publisher Dockerfile](https://github.com/mikefarah/yq/blob/v4.53.6/Dockerfile)

Concrete version `4.53` uses the official `docker.io/mikefarah/yq` image.
`versions/4.53/image.conf` owns the immutable top-level index digest, discovery
tag, public registry access, and required `linux/amd64` and `linux/arm64`
platforms. The shared Podman helper selects the native platform.

## Usage

```sh
yq --version
yq '.service.name' config.yaml
printf 'name: shimmy\n' | yq '.name'
yq -o=json '.' config.yaml
yq eval-all '. as $item ireduce ({}; . * $item)' base.yaml override.yaml
```

`eval` is the default command and evaluates each document separately.
`eval-all` evaluates all input documents together. Quote expressions so the
host shell does not expand them. Paths must be relative to the current
directory or use the container's `/work` path; arbitrary host absolute paths
are not mounted.

To intentionally edit the first input file in place:

```sh
yq -i '.service.enabled = true' config.yaml
```

Ordinary evaluation writes to stdout. `-i`/`--inplace`, `--split-exp`, or host
shell redirection explicitly request file writes. Review the expression and
target files before using them.

## Runtime

- Stdin remains open (`podman run --rm -i`) without allocating a TTY.
- `$PWD` mounts read-write at `/work`, which is the working directory.
- Rootless Podman maps its invoking user to container UID/GID `1000:1000`
  using `--userns keep-id:uid=1000,gid=1000`. The process runs as that non-root
  identity, matching the upstream yq user, without changing host file ownership.
- Networking is disabled; all Linux capabilities are dropped and
  `no-new-privileges` is enabled. Image pulls still require registry access.
- Host home directories, credentials, and environment variables are not
  forwarded. `env`, `strenv`, and `envsubst` see only the container environment.
- Upstream's `system` operator remains disabled unless explicitly enabled by
  the caller. Any commands it invokes must already exist in the container;
  host companion executables are unavailable.

Environment settings:

| Variable | Effect |
|---|---|
| `SHIMMY_YQ_IMAGE` | Override the image; it must supply a yq entrypoint usable as UID/GID 1000. |
| `SHIMMY_YQ_IMAGE_PULL=always` | Pull the configured image before execution. |

## Dependencies and limitations

Basic data processing needs no companion CLI, plugins, credentials, or runtime
network access. Podman and its rootless user mapping are Shimmy prerequisites.

The official Alpine image omits `tzdata`. Named-timezone operations such as
`tz("America/New_York")` require a separately prepared image containing that
database. The initial tool deliberately uses the user-selected official image;
it does not install packages at runtime. See upstream's
[timezone note](https://github.com/mikefarah/yq/blob/v4.53.6/README.md#missing-timezone-data).

On SELinux-enforcing hosts, the workspace must have a container-compatible
label. This wrapper follows Shimmy's standard mount and does not relabel host
files automatically. User-namespace mapping addresses ownership, not SELinux
labels. See [Podman's volume and user-namespace guidance](https://docs.podman.io/en/stable/markdown/podman-run.1.html).

## Validation and adoption

```sh
./commands/run-tool.sh yq --preview-shim --help
./tests/test.sh --group tools-yq --group lib-runtime --group lib-catalog
./commands/run-tool.sh yq --version
```

Source changes become available through explicit catalog publication from a
clean committed attached `main`. Once the published catalog contains this
version, use the installed control plane:

```sh
shimmy catalog verify --tool yq@4.53 --format manifest
shimmy shim add yq@4.53
shimmy shim test yq@4.53
```

Publication and profile adoption are separate operations. Feature acceptance
requires the version-owned smoke on native Linux `amd64` and native Apple
Silicon macOS `arm64`.
