# Shell startup integration

`startup.sh` renders, adds, and removes the managed shell-initialization block for
supported POSIX-oriented shells. Only the `default` profile may use it for
persistent integration; its block sources the canonical default
`shell-init.sh`. Fresh default bootstrap resolves conventional paths for one
normalized shell; later bootstrap, repair, and uninstall consume the exact
manifest-owned ledger without re-resolving from the current home or shell. The
`upstream` profile has no persistent startup integration.
Either profile's generated asset may be sourced directly to initialize PATH in
the current shell.
Startup files remain external state, so only the exact managed marker block may
change and all operations must remain idempotent.
