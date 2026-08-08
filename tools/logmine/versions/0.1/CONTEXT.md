# Logmine 0.1 runtime

`run.sh` builds from `container/` and mounts only the working directory at
`/work` inside the container.

`refresh.sh` rebuilds and cleans stale local images for `shimmy update --build`
without bypassing an image override.

`status.conf` supplies the local-build description rendered by `shimmy status`.

## Child contexts

- [container build context](container/CONTEXT.md)
