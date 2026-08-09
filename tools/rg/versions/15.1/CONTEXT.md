# ripgrep 15.1 runtime

`run.sh` is the concrete remote-image runtime and supports preview output.
`refresh.sh` pulls its effective image for `shimmy update --pull` using
`smoke.conf`.

`image.conf` owns the public upstream tag, immutable runtime digest, registry
access, and required platforms consumed by the runtime and `shimmy status`.
