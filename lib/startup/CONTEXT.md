# Shell startup integration

`startup.sh` renders, adds, and removes the managed shell-initialization block for
supported POSIX-oriented shells. Only the `default` profile may use it for
persistent integration; its block sources the canonical default
`shell-init.sh`. The `upstream` profile has no persistent startup integration.
Startup files remain external state, so only the exact managed marker block may
change and all operations must remain idempotent.
