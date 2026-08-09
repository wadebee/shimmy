# Textual 8.2 runtime

`run.sh` builds from `container/` and retains TTY-aware behavior. `refresh.sh`
rebuilds and cleans stale local images for `shimmy update --build` without
bypassing an image override.

`image.conf` owns the local context/repository, configured Python base digest,
public registry access, and required platforms consumed by build/cache helpers
and `shimmy status`.

## Child contexts

- [container build context](container/CONTEXT.md)
