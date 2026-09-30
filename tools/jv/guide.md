# jv Shim

## Upstream

- Source repository: <https://github.com/santhosh-tekuri/jsonschema>
- Release: <https://github.com/santhosh-tekuri/jsonschema/releases/tag/v6.0.3>
- CLI release assets: `jv-v6.0.3-linux-amd64.tar.gz` and `jv-v6.0.3-linux-arm64.tar.gz`
- Shim image: local build from `versions/6.0/image.conf` and `container/`

The `jv` CLI validates JSON Schema files against JSON or YAML instances. The
CLI release is independently versioned from the Go library; this shim tracks
CLI release `v6.0.3` as concrete version `6.0`.

## Shimmy Usage

```sh
jv --version
jv schema.json instance.json
jv schema.json -
```

Environment:

- `SHIMMY_JV_IMAGE` - override the runtime image entirely.
- `SHIMMY_JV_IMAGE_BUILD=always` - rebuild the local image.
- `SHIMMY_JV_IMAGE_PULL=always` - force pulling an overridden image.
- `SHIMMY_JV_BASE_IMAGE` - override the pinned Alpine build base image.

The default image installs the upstream v6.0.3 platform release asset using a
pinned multi-platform Alpine base image. The build needs registry access to
download the release asset.

Mounts:

- `$PWD` -> `/work` read-write.
- A present `SHIMMY_HOST_CA_BUNDLE` -> `/tmp/shimmy-host-ca-bundle.pem` read-only, with `SSL_CERT_FILE` set to that container path. The host control variable is not forwarded.

A bundle must be an absolute, readable, nonempty file. During a local build it is a temporary `shimmy-host-ca-bundle` secret before network work, not an image layer or identity input. Cached images are not rebuilt when it changes; use `SHIMMY_JV_IMAGE_BUILD=always` to refresh build-time trust. `SSL_CERT_FILE` can replace public roots, so provide a combined bundle when needed.

Container I/O is stdin-friendly via `podman run --rm -i`. The runtime selects
native `linux/amd64` or `linux/arm64` through Shimmy's shared platform helper.

## Quick-Start Prompts

- "Use `jv` to validate this JSON document against the schema in this directory."
- "Run `jv --output detailed` and explain the schema validation errors."
