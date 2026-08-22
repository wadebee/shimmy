# npx Shim

## Upstream

- npm `npx` documentation: <https://docs.npmjs.com/cli/v11/commands/npx>
- npm `exec` documentation: <https://docs.npmjs.com/cli/v11/commands/npm-exec>
- Official Node container image: <https://hub.docker.com/_/node>
- Node 24 release information: <https://nodejs.org/en/blog/release/v24.18.0>
- Shim image: `docker.io/library/node@sha256:5711a0d445a1af54af9589066c646df387d1831a608226f4cd694fc59e745059` from `versions/24.18/image.conf`

## Purpose

This shim exposes only `npx`, using the `npx` executable included with npm in
the official Node 24.18.0 Bookworm image. It does not install public `node` or
`npm` shims and does not require Node.js on the host.

## Shimmy Usage

For a tracking first install:

```sh
shimmy shim add npx
```

For an explicitly pinned first default instead:

```sh
shimmy shim add npx@24.18
```

Then invoke `npx` normally:

```sh
npx --version
npx cowsay@1.6.0 hello
npx --yes node-llama-cpp@3.19.1 inspect gpu
```

An unqualified first install tracks the catalog default recorded by the
profile. An exact first install makes `24.18` the pinned default. Catalog
publication does not mutate either profile: `shimmy profile sync` explicitly
adopts registry current, while `shimmy shim sync npx` remains bounded by the
profile's existing catalog pin.

Pin package versions when repeatability matters. The wrapper does not add
`--yes` or `--no`; use `--yes` only when you deliberately intend to bypass
npx's package-install confirmation.

Environment:

- `SHIMMY_NPX_IMAGE` - override the container image.
- `SHIMMY_NPX_IMAGE_PULL=always` - force pulling the configured image.

Mounts and I/O:

- `$PWD` -> `/work` read-write, with `/work` as the container working directory.
- Stdin is always open. A TTY is allocated only when both stdin and stdout are terminals.
- Host `HOME`, npm credentials, `~/.npm`, and other persistent npm configuration or caches are not mounted.

Packages missing from the mounted project are fetched into disposable
container state and will generally be downloaded again on a later invocation.
npx may prefer dependencies already present in the mounted project. A
`node_modules` tree created on macOS can contain native addons or executables
that are incompatible with the Linux container; use a clean directory or
container-compatible project dependencies when that occurs.

## Security Boundary

npx can download and execute arbitrary package code with network access and
read-write access to the current directory. Review package names, pin versions,
retain the install prompt unless intentionally bypassing it, and do not run an
untrusted package from a directory containing sensitive files.

## GPU Diagnostic

`npx --yes node-llama-cpp@3.19.1 inspect gpu` is an observational check that
exercises public package fetch and execution. Its CPU/GPU report does not prove
GPU acceleration. On macOS, GPU access through Podman additionally requires a
LibKrun-backed machine, `/dev/dri` passthrough, and suitable patched
Mesa/Vulkan userspace; this generic Node image and wrapper provide none of
those. The diagnostic does not download a model or perform inference.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`
