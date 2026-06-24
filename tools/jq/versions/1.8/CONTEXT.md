# jq 1.8 runtime

`run.sh` is the stdin-friendly concrete remote-image wrapper. `refresh.sh`
pulls its effective image for `shimmy update --pull` using `smoke.conf`.

`status.conf` supplies the image description rendered by `shimmy status`.
