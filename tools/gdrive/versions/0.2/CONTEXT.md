# Google Drive MCP 0.2 runtime

`run.sh` validates OAuth configuration and builds from `container/` unless an
image override is selected. `refresh.sh` rebuilds and cleans stale local images
for `shimmy update --build` without bypassing an image override.

`status.conf` supplies the local-build description rendered by `shimmy status`.

## Child contexts

- [container build context](container/CONTEXT.md)
