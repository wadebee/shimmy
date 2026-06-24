# AWS 2.31 runtime

`run.sh` is the concrete remote-image runtime, `refresh.sh` pulls its effective
image for `shimmy update --pull`, and `smoke.conf` supplies the non-mutating
smoke command.

`status.conf` supplies the image description rendered by `shimmy status`.
