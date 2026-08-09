# Shell startup integration

`startup.sh` renders, adds, and removes the managed activation block for
supported POSIX-oriented shells. Only the `default` profile may use it for
persistent integration; its block sources the canonical default
`activate.sh`. The `upstream` profile is manual-activation-only. Startup files
remain external state, so only the exact managed marker block may change and
all operations must remain idempotent.
