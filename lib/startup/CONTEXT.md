# Shell startup integration

`startup.sh` renders, adds, and removes the managed shell-initialization block for
supported POSIX-oriented shells. Fresh default bootstrap resolves conventional
paths for one normalized shell; sibling profiles inherit no persistent startup
ownership. Repair and uninstall consume the exact manifest-owned ledger without
re-resolving from the current home or shell. Any profile's generated asset may
be sourced directly to initialize PATH in the current shell.
Startup files remain external state, so only the exact managed marker block may
change and all operations must remain idempotent.
