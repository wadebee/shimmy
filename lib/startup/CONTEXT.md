# Shell startup integration

`startup.sh` renders, adds, and removes the managed shell-initialization block for
supported POSIX-oriented shells. Only the `default` profile may use it for
persistent integration; its block sources the canonical default
`shell-init.sh`. An unqualified default bootstrap manages zsh startup plus
Bash login and non-login interactive startup files; explicit shell or file
selection remains scoped to the requested targets. The `upstream` profile has
no persistent startup integration.
Either profile's generated asset may be sourced directly to initialize PATH in
the current shell.
Startup files remain external state, so only the exact managed marker block may
change and all operations must remain idempotent.
