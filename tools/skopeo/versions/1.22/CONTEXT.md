# Skopeo 1.22 runtime

`run.sh` is the concrete remote-image runtime, `refresh.sh` pulls its effective
image for `shimmy update --pull`, and `smoke.conf` supplies the non-mutating
smoke command.

`image.conf` owns the public upstream tag, immutable runtime digest, registry
access, and required platforms consumed by the runtime and `shimmy status`.
