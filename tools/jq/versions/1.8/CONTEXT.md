# jq 1.8 runtime

`run.sh` is the stdin-friendly concrete remote-image wrapper. `refresh.sh`
pulls its effective image for `shimmy update --pull` using `smoke.conf`.

`image.conf` owns the public upstream tag, immutable runtime digest, registry
access, and required platforms consumed by the runtime and `shimmy status`.
