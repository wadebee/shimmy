# Flux CLI Shim

Shimmy exposes Flux CLI v2.9.4 as the independently installable `flux@2.9`
tool. The official image also contains `kubectl`; Shimmy does not install Flux
controllers or plugins.

## Install and use

```sh
shimmy shim add flux@2.9
shimmy shim test flux@2.9
flux version --client
flux check --pre
```

Many Flux commands mutate Kubernetes clusters or Git repositories. Review the
active Kubernetes context, namespace, Git repository, and exact command before
running bootstrap, reconcile, suspend, resume, create, delete, or uninstall
operations. Provider tokens can be written into Kubernetes Secrets during
bootstrap.

## Runtime

The runtime uses the official non-root `65534:65534` image entrypoint, keeps
stdin open, and adds a TTY only when stdin and stdout are terminals. It mounts
`$PWD` read-write at `/work` and uses `/work` as the working directory. Host
permissions therefore determine whether the non-root process can write files
in the current directory.

The shared runtime helper selects native `linux/amd64` or `linux/arm64`. Image
settings are:

- `SHIMMY_FLUX_IMAGE` overrides the immutable default from
  `versions/2.9/image.conf`.
- `SHIMMY_FLUX_IMAGE_PULL=always` forces an image pull.

The host CA option described below affects processes inside the running
container. It does not configure Podman's trust for pulling the Flux image.

## Kubernetes credentials

Set `SHIMMY_FLUX_KUBECONFIG` to one absolute, readable regular file to mount
that exact file read-only:

```sh
SHIMMY_FLUX_KUBECONFIG="$HOME/.kube/config" flux get sources all
```

The container receives the file at `/tmp/shimmy-flux-kubeconfig` and receives
only `KUBECONFIG=/tmp/shimmy-flux-kubeconfig`. Shimmy does not pass the host
pathname into the container and does not mount `$HOME/.kube` automatically.

As a project-local alternative, place a kubeconfig below the current directory
and refer to its container path explicitly:

```sh
flux --kubeconfig=/work/config/kubeconfig get kustomizations
```

Paths referenced from inside a kubeconfig must also be available inside the
container. Prefer embedded certificate and key data when practical.

## Git providers and credentials

Shimmy forwards these established Flux CLI inputs by name when they are set:

- `FLUX_NS_FOLLOWS_KUBE_CONTEXT`
- `GITHUB_TOKEN`
- `GITLAB_TOKEN`
- `BITBUCKET_TOKEN`

It does not automatically mount `~/.ssh`, SSH-agent sockets, registry
credentials, or other host credential directories. Project-local inputs can
be placed below the current directory and referenced through `/work/...`.

## Corporate CA bundle

When `SHIMMY_HOST_CA_BUNDLE` names one absolute, readable file, Shimmy mounts
it read-only at `/tmp/shimmy-host-ca-bundle.pem` and sets
`SSL_CERT_FILE=/tmp/shimmy-host-ca-bundle.pem`.

Flux is a Go program, so `SSL_CERT_FILE` can replace the normal public system
root file. Supply a combined public and corporate CA bundle when both trust
sets are required. Explicit Flux `--ca-file` arguments, kubeconfig
certificate-authority settings, and other client-specific TLS configuration
can take precedence.

## Validation

```sh
./commands/run-tool.sh flux --preview-shim version --client
./tests/test.sh --group tools-flux
shimmy catalog verify --tool flux@2.9 --format manifest
shimmy shim test flux@2.9
```

Native acceptance requires the version-owned `flux version --client` smoke on
Linux `amd64` and Apple Silicon macOS `arm64`.
