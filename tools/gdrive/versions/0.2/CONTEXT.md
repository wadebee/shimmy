# Google Drive MCP 0.2 runtime

`run.sh` validates OAuth configuration and builds from `container/` unless an
image override is selected. `refresh.sh` rebuilds and cleans stale local images
for `shimmy update --build` without bypassing an image override.

`image.conf` owns the local context/repository, configured Node base digest,
public registry access, and required platforms consumed by build/cache helpers
and `shimmy status`.

## Child contexts

- [container build context](container/CONTEXT.md)
