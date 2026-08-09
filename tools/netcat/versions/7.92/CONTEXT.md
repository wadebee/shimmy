# Netcat 7.92 runtime

`run.sh` uses the local build context in `container/`. `refresh.sh` rebuilds
and cleans stale local images for `shimmy update --build` unless an image
override is selected.

`image.conf` owns the local context/repository, configured UBI base digest,
public registry access, and required platforms consumed by build/cache helpers
and `shimmy status`.

## Child contexts

- [container build context](container/CONTEXT.md)
