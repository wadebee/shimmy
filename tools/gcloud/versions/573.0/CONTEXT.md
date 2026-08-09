# Google Cloud CLI 573.0 runtime

`run.sh` owns Cloud SDK config and kubeconfig mount behavior; `refresh.sh`
pulls its effective image for `shimmy update --pull`; `smoke.conf` defines the
concrete smoke command.

`image.conf` owns the public upstream tag, immutable runtime digest, registry
access, and required platforms consumed by the runtime and `shimmy status`.
