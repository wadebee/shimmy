# jq Shim

## Upstream

- Source repo README: <https://github.com/jqlang/jq/blob/master/README.md>
- Latest release: <https://github.com/jqlang/jq/releases/latest>
- Manual: <https://jqlang.github.io/jq/manual/>
- Shim image: `ghcr.io/jqlang/jq:1.8.1`

## Upstream README Summary

jq is a lightweight command-line JSON processor. The upstream README introduces jq as a filter language for slicing, transforming, selecting, and formatting JSON streams from files, APIs, and shell pipelines.

## Top-Level Command Summary

jq is filter-oriented rather than subcommand-oriented. Common top-level usage patterns:

- `jq . file.json` - pretty-print JSON.
- `jq -r FILTER` - emit raw strings instead of JSON strings.
- `jq -c FILTER` - emit compact JSON.
- `jq -s FILTER` - slurp all input into one array before filtering.
- `jq -n FILTER` - run a filter without input.

## Shimmy Usage

```sh
echo '{"name":"shimmy"}' | jq -r .name
jq .foo file.json
```

Environment:

- `JQ_IMAGE` - override the container image.
- `JQ_IMAGE_PULL=always` - force pulling the configured image.

Mounts:

- `$PWD` -> `/work` read-write.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `jq` to extract IP addresses and hostnames from this router inventory JSON."
- Software dev: "Write a jq filter that returns only failed checks from this CI API response."
- Platform engineer: "Use `jq` to turn this Terraform output JSON into a table of service names and endpoints."
