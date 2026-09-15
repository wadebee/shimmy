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

Container I/O is stdin-friendly via `podman run --rm -i`. The runtime selects
native `linux/amd64` or `linux/arm64` through Shimmy's shared platform helper.

## Quick-Start Prompts

- "Use `jv` to validate this JSON document against the schema in this directory."
- "Run `jv --output detailed` and explain the schema validation errors."
