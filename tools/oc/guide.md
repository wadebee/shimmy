# OpenShift CLI (`oc`)

Shimmy exposes one public `oc` wrapper with retained concrete tracks `4.18`,
`4.20`, and `4.22`. The catalog default is `4.20`; no concrete implementation
commands are installed.

## Install and select versions

```sh
shimmy shim add oc
shimmy shim add oc@4.18
shimmy shim set-version oc@4.18
shimmy shim list --format manifest
shimmy shim sync oc
shimmy shim test oc@4.18
```

An unqualified add is interactive and records tracking policy. An explicit
first add is noninteractive and records pinned policy. Retained versions can
also be selected per invocation:

```sh
oc version
SHIMMY_OC_VERSION=4.18 oc version
```

Unsupported or uninstalled selector values fail before Podman.

## Runtime

Each track uses a version-owned local image based on the authenticated Red Hat
`ose-cli-rhel9` multi-platform digest in its `image.conf`. The runtime mounts
`$PWD` at `/work`, selects the native `linux/amd64` or `linux/arm64` platform,
adds a TTY only when stdin and stdout are terminals, and forwards `KUBECONFIG`
when set. When `SHIMMY_HOST_CA_BUNDLE` names an absolute, readable file, every
retained track mounts it read-only at `/tmp/shimmy-host-ca-bundle.pem` and sets
`SSL_CERT_FILE` to that path. It does not automatically mount `$HOME/.kube`;
referenced paths must be reachable inside the container.

`SSL_CERT_FILE` changes Go system-root file discovery and can replace the
normal public roots, so provide a combined public and corporate bundle when
both are required. Explicit kubeconfig CA data and CLI certificate-authority
arguments can still take precedence.

Version-specific settings are:

- `SHIMMY_OC_4_18_IMAGE`, `SHIMMY_OC_4_18_IMAGE_BUILD`,
  `SHIMMY_OC_4_18_IMAGE_PULL`, and `SHIMMY_OC_4_18_BASE_IMAGE`.
- Equivalent `SHIMMY_OC_4_20_*` and `SHIMMY_OC_4_22_*` variables for those
  tracks.

Image and build-argument changes affect cache identity. A strict profile
redirect may replace `registry.redhat.io`, but it is not a fallback and does
not provide credentials, Red Hat signatures, or signature policy. The redirect
itself does not provide corporate CA trust; use `SHIMMY_HOST_CA_BUNDLE` for the
exact-file runtime opt-in described above.

## Validation

```sh
./commands/run-tool.sh oc --preview-shim version
SHIMMY_OC_VERSION=4.18 ./commands/run-tool.sh oc --preview-shim version
./tests/test.sh --group tools-oc
shimmy catalog verify --tool oc@4.20
shimmy shim test oc@4.20
```

Catalog verification of these authenticated bases requires an explicitly
selected Skopeo auth secret. Native acceptance requires the version-owned
`--help` smoke after a local build on Linux `amd64` and Apple Silicon macOS
`arm64`.

## Adding a track

Add `versions/<major.minor>/` with `run.sh`, `refresh.sh`, `smoke.conf`,
`image.conf`, and `container/Containerfile`. Extend catalog metadata only; do
not add public implementation commands or shared implementation-name maps.
