# Nmap 7.98 runtime

`run.sh` owns opt-in LAN, network, privilege, and capability controls.
`refresh.sh` pulls its effective image for `shimmy update --pull` using the
declared smoke command.

`image.conf` owns the public upstream tag, immutable runtime digest, registry
access, and required platforms consumed by the runtime and `shimmy status`.
