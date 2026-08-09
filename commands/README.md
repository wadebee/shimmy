# Commands

Files in this directory are executable management entrypoints invoked by a
profile-local `bin/shimmy` launcher. The minimal root `install.sh` bootstrap
also invokes `commands/install.sh` to create one canonical profile. These
entrypoints orchestrate metadata and shared behavior from `../lib/`; do not
put tool-specific runtime logic here.

See [CONTEXT.md](CONTEXT.md) for ownership and [tools](../tools/CONTEXT.md) for
tool runtime behavior.
