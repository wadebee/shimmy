# Commands

Files in this directory are executable management entrypoints invoked by the
root `shimmy` launcher or installed management command. They orchestrate
metadata and shared behavior from `../core/`; do not put tool-specific runtime
logic here.

See [CONTEXT.md](CONTEXT.md) for ownership and [tools](../tools/CONTEXT.md) for
tool runtime behavior.
